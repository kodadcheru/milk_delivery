from datetime import date
from decimal import Decimal
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.pagination import LargeResultsSetPagination
from apps.core.permissions import IsAdminOrStaff
from apps.accounts.models import User, WalletTransaction, Notification
from apps.deliveries.models import DeliveryTask, LiveOrder
from apps.deliveries.serializers import DeliveryTaskSerializer
from apps.subscriptions.models import Subscription
from apps.products.models import Product


class DeliveryTaskListView(generics.ListAPIView):
    serializer_class = DeliveryTaskSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = LargeResultsSetPagination

    def get_queryset(self):
        user = self.request.user
        req_date = self.request.query_params.get("date", None)

        qs = DeliveryTask.objects.all().select_related("subscription__customer", "subscription__product", "subscription__product__category_ref", "driver", "hub", "order__customer").order_by("-delivery_date", "-id")
        if req_date:
            qs = qs.filter(delivery_date=req_date)

        # Scope by role
        if user.role == "CUSTOMER":
            return qs.filter(subscription__customer=user)
        elif user.role in (User.Roles.DELIVERY_PARTNER, "DRIVER"):
            return qs.filter(driver=user)
        elif user.role in (User.Roles.HUB_MANAGER, "PROVIDER") and user.assigned_hub:
            return qs.filter(hub=user.assigned_hub)
        # Admin/staff see all
        return qs


class DeliveryTaskCompleteView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            task = DeliveryTask.objects.get(pk=pk)
        except DeliveryTask.DoesNotExist:
            return Response({"detail": "Delivery task not found"}, status=status.HTTP_404_NOT_FOUND)

        # Authorization: only assigned driver or staff can complete
        if task.driver and task.driver != request.user and not request.user.is_staff:
            return Response({"detail": "Only the assigned driver can complete this delivery."}, status=status.HTTP_403_FORBIDDEN)

        # Prevent double-completion
        if task.status == DeliveryTask.Statuses.DELIVERED:
            return Response({"detail": "This delivery has already been completed."}, status=status.HTTP_409_CONFLICT)

        proof_url = request.data.get("proof_image_url", "")

        task.status = DeliveryTask.Statuses.DELIVERED
        task.proof_image_url = proof_url
        task.delivered_at = timezone.now()
        task.save()

        # Update linked LiveOrder if express order task
        if task.order:
            task.order.status = LiveOrder.Statuses.DELIVERED
            task.order.delivered_at = timezone.now()
            if proof_url:
                task.order.proof_image_url = proof_url
            task.order.save()

        # Deduct wallet balance for subscription deliveries
        if task.subscription and task.subscription.customer:
            customer = task.subscription.customer
            total_cost = task.subscription.product.price_per_unit * task.subscription.quantity
            customer.wallet_balance -= total_cost
            customer.save()

            WalletTransaction.objects.create(
                user=customer,
                amount=total_cost,
                transaction_type=WalletTransaction.Types.DEBIT,
                description=f"Morning Delivery #{task.id} ({task.subscription.product.name})",
            )

            Notification.objects.create(
                user=customer,
                title="🥛 Morning Delivery Complete!",
                message=f"Your delivery #{task.id} ({task.subscription.quantity}x {task.subscription.product.name}) was dropped at doorstep. ₹{total_cost} debited from wallet.",
                notification_type=Notification.Types.DELIVERY,
            )

        return Response(
            {
                "message": "Delivery completed successfully.",
                "task": DeliveryTaskSerializer(task).data,
            },
            status=status.HTTP_200_OK,
        )


class DeliveryTaskSkipView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            task = DeliveryTask.objects.get(pk=pk)
        except DeliveryTask.DoesNotExist:
            return Response({"detail": "Delivery task not found"}, status=status.HTTP_404_NOT_FOUND)

        task.status = DeliveryTask.Statuses.SKIPPED
        task.save()

        return Response(
            {
                "message": "Delivery marked as skipped.",
                "task": DeliveryTaskSerializer(task).data,
            },
            status=status.HTTP_200_OK,
        )


class DeliverySummaryView(APIView):
    permission_classes = [IsAdminOrStaff]

    def get(self, request):
        """Admin / Operations summary of today's total milk demand computed live from database."""
        today = date.today().isoformat()
        tasks = DeliveryTask.objects.all().select_related("subscription__product", "subscription__customer")

        total_deliveries = tasks.count()
        completed = tasks.filter(status=DeliveryTask.Statuses.DELIVERED).count()
        pending = tasks.filter(status=DeliveryTask.Statuses.PENDING).count()

        active_subs = Subscription.objects.filter(status=Subscription.Statuses.ACTIVE).select_related("product", "customer")
        
        # Real calculation of daily milk volume
        daily_volume_liters = sum(s.quantity for s in active_subs)
        if daily_volume_liters == 0 and total_deliveries > 0:
            daily_volume_liters = sum((t.subscription.quantity if t.subscription else 1) for t in tasks)

        # Real calculation of GMV
        gross_revenue = sum(float(s.product.price_per_unit * s.quantity) for s in active_subs)
        if gross_revenue == 0.0 and total_deliveries > 0:
            gross_revenue = sum(
                float(t.subscription.product.price_per_unit * t.subscription.quantity)
                for t in tasks if t.subscription and t.subscription.product
            )

        # Real customer subscribers count
        subscribers_count = User.objects.filter(role=User.Roles.CUSTOMER).count()
        if subscribers_count == 0:
            subscribers_count = active_subs.values("customer").distinct().count()

        # Real SLA fulfillment rate
        sla_rate = round((completed / total_deliveries * 100), 1) if total_deliveries > 0 else 100.0

        # Real product breakdown demand
        product_demand = {}
        for s in active_subs:
            p_name = s.product.name
            product_demand[p_name] = product_demand.get(p_name, 0) + s.quantity

        return Response(
            {
                "date": today,
                "total_deliveries": total_deliveries,
                "completed": completed,
                "pending": pending,
                "daily_volume_liters": round(daily_volume_liters, 1),
                "gross_revenue": f"{gross_revenue:,.2f}",
                "subscribers_count": subscribers_count,
                "sla_rate": sla_rate,
                "product_demand": product_demand,
            }
        )


class BottleReturnListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        """List bottle returns for the current user or all (for admin/driver)."""
        from apps.deliveries.models import BottleReturn

        user = request.user
        qs = BottleReturn.objects.all().select_related("customer", "driver", "hub", "product").order_by("-created_at")

        if user.role == User.Roles.CUSTOMER:
            qs = qs.filter(customer=user)
        elif user.role in (User.Roles.DELIVERY_PARTNER, "DRIVER"):
            qs = qs.filter(driver=user)
        elif user.role in (User.Roles.HUB_MANAGER, "PROVIDER") and user.assigned_hub:
            qs = qs.filter(hub=user.assigned_hub)

        data = []
        for b in qs[:50]:
            data.append({
                "id": b.id,
                "customer_name": f"{b.customer.first_name} {b.customer.last_name}".strip() or b.customer.username,
                "driver_name": f"{b.driver.first_name} {b.driver.last_name}".strip() if b.driver else "Unassigned",
                "hub_name": b.hub.name if b.hub else "",
                "product_name": b.product.name if b.product else "Glass Bottle",
                "quantity": b.quantity,
                "deposit_amount": str(b.deposit_amount),
                "status": b.status,
                "collected_date": str(b.collected_date),
                "returned_date": str(b.returned_date) if b.returned_date else None,
                "notes": b.notes,
            })
        return Response(data)

    def post(self, request):
        """Record a new bottle deposit or return."""
        from apps.deliveries.models import BottleReturn, LocationHub
        from apps.products.models import Product

        user = request.user
        customer_id = request.data.get("customer_id")
        product_id = request.data.get("product_id")
        quantity = int(request.data.get("quantity", 1))
        deposit_amount = Decimal(str(request.data.get("deposit_amount", "0")))
        notes = request.data.get("notes", "")

        customer = User.objects.filter(id=customer_id).first() if customer_id else user
        product = Product.objects.filter(id=product_id).first() if product_id else None
        hub = getattr(user, "assigned_hub", None) or LocationHub.objects.first()

        bottle = BottleReturn.objects.create(
            customer=customer,
            driver=user if user.role in (User.Roles.DELIVERY_PARTNER, "DRIVER") else None,
            hub=hub,
            product=product,
            quantity=quantity,
            deposit_amount=deposit_amount,
            status=BottleReturn.Statuses.DEPOSITED,
            notes=notes,
        )

        return Response({
            "message": f"Recorded {quantity} bottle deposit(s) for {customer.username}.",
            "id": bottle.id,
            "status": bottle.status,
        }, status=status.HTTP_201_CREATED)


class BottleReturnUpdateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, pk):
        """Mark a bottle return as RETURNED or LOST."""
        from apps.deliveries.models import BottleReturn

        bottle = BottleReturn.objects.filter(pk=pk).first()
        if not bottle:
            return Response({"detail": "Bottle return record not found"}, status=status.HTTP_404_NOT_FOUND)

        new_status = request.data.get("status")
        if new_status and new_status in dict(BottleReturn.Statuses.choices):
            bottle.status = new_status
            if new_status == BottleReturn.Statuses.RETURNED:
                bottle.returned_date = date.today()
                # Refund deposit to customer wallet
                if bottle.deposit_amount > 0:
                    customer = bottle.customer
                    customer.wallet_balance += bottle.deposit_amount
                    customer.save(update_fields=["wallet_balance"])

                    WalletTransaction.objects.create(
                        user=customer,
                        amount=bottle.deposit_amount,
                        transaction_type=WalletTransaction.Types.CREDIT,
                        description=f"🔄 Bottle deposit refund ({bottle.quantity}x returned)",
                    )
            bottle.save()

        return Response({
            "message": f"Bottle #{bottle.id} status updated to {bottle.status}.",
            "status": bottle.status,
            "returned_date": str(bottle.returned_date) if bottle.returned_date else None,
        })

