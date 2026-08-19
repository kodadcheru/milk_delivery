from datetime import date
from decimal import Decimal
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.pagination import LargeResultsSetPagination
from apps.accounts.models import User, WalletTransaction, Notification
from apps.deliveries.models import DeliveryTask, LiveOrder
from apps.deliveries.serializers import DeliveryTaskSerializer
from apps.subscriptions.models import Subscription
from apps.products.models import Product


class DeliveryTaskListView(generics.ListAPIView):
    serializer_class = DeliveryTaskSerializer
    permission_classes = [permissions.AllowAny]
    pagination_class = LargeResultsSetPagination

    def get_queryset(self):
        user = self.request.user
        req_date = self.request.query_params.get("date", None)

        qs = DeliveryTask.objects.all().select_related("subscription__customer", "subscription__product", "driver").order_by("-delivery_date", "-id")
        if req_date:
            qs = qs.filter(delivery_date=req_date)

        if user and user.is_authenticated:
            if user.role == "CUSTOMER":
                return qs.filter(subscription__customer=user)
        return qs


class DeliveryTaskCompleteView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request, pk):
        try:
            task = DeliveryTask.objects.get(pk=pk)
        except DeliveryTask.DoesNotExist:
            return Response({"detail": "Delivery task not found"}, status=status.HTTP_404_NOT_FOUND)

        proof_url = request.data.get(
            "proof_image_url",
            "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80",
        )

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
            if customer.wallet_balance < Decimal("0.00"):
                customer.wallet_balance = Decimal("0.00")
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
    permission_classes = [permissions.AllowAny]

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
    permission_classes = [permissions.AllowAny]

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
            daily_volume_liters = sum(t.subscription.quantity for t in tasks)

        # Real calculation of GMV
        gross_revenue = sum(float(s.product.price_per_unit * s.quantity) for s in active_subs)
        if gross_revenue == 0.0 and total_deliveries > 0:
            gross_revenue = sum(float(t.subscription.product.price_per_unit * t.subscription.quantity) for t in tasks)

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
