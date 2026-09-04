from datetime import date
from decimal import Decimal
from django.db import models
from django.db.models import F, Q, Case, When, Value, IntegerField
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.pagination import LargeResultsSetPagination
from apps.core.permissions import IsAdminOrStaff, IsAdminOrHubManager
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
        
        if user and user.is_authenticated and getattr(user, "role", "") == "CUSTOMER":
            today = date.today()
            # Auto-ensure today's daily order exists if customer has active subscriptions
            try:
                has_active = Subscription.objects.filter(customer=user, status=Subscription.Statuses.ACTIVE).exists()
                if has_active and not DeliveryTask.objects.filter(subscription__customer=user, delivery_date=today).exists():
                    from apps.deliveries.task_generator import generate_daily_tasks_for_date
                    generate_daily_tasks_for_date(target_date=today)
            except Exception:
                pass

            if req_date:
                try:
                    from datetime import datetime as _dt
                    filter_date = _dt.strptime(req_date, '%Y-%m-%d').date()
                    qs = qs.filter(delivery_date=filter_date)
                except (ValueError, TypeError):
                    pass
            return qs.filter(Q(subscription__customer=user) | Q(order__customer=user)).order_by("-delivery_date", "-id")

        hub_code = self.request.query_params.get("hub_code") or self.request.query_params.get("hub")
        if hub_code:
            if str(hub_code).isdigit():
                qs = qs.filter(Q(hub__hub_code=hub_code) | Q(hub__id=int(hub_code)))
            else:
                qs = qs.filter(hub__hub_code=hub_code)

        if req_date:
            try:
                from datetime import datetime as _dt
                filter_date = _dt.strptime(req_date, '%Y-%m-%d').date()
                qs = qs.filter(delivery_date=filter_date)
            except (ValueError, TypeError):
                pass

        # Scope by role
        if user.role in (User.Roles.HUB_MANAGER, "PROVIDER"):
            if getattr(user, "assigned_hub", None):
                return qs.filter(Q(hub=user.assigned_hub) | Q(subscription__hub=user.assigned_hub) | Q(hub__isnull=True))
            return qs
        elif user.role in (User.Roles.DELIVERY_PARTNER, "DRIVER"):
            if getattr(user, "assigned_hub", None):
                hub_filter = Q(hub=user.assigned_hub) | Q(subscription__hub=user.assigned_hub) | Q(order__hub=user.assigned_hub)
                return qs.filter(hub_filter).filter(Q(driver=user) | Q(driver__isnull=True))
            return qs.filter(driver=user)
        # Admin/staff see all
        if not user.is_superuser and getattr(user, 'assigned_hub', None):
            return qs.filter(Q(hub=user.assigned_hub) | Q(subscription__hub=user.assigned_hub) | Q(hub__isnull=True))
        return qs

    def list(self, request, *args, **kwargs):
        req_date = self.request.query_params.get("date", None)
        if req_date:
            try:
                from datetime import datetime as _dt, date as _d, timedelta as _td
                f_date = _dt.strptime(req_date, '%Y-%m-%d').date()
                if f_date in (_d.today(), _d.today() + _td(days=1)):
                    # Self-heal: auto-generate if active subscriptions exist but 0 tasks for this date
                    if not DeliveryTask.objects.filter(delivery_date=f_date).exists():
                        from apps.deliveries.task_generator import generate_daily_tasks_for_date
                        generate_daily_tasks_for_date(target_date=f_date)
            except Exception:
                pass
        return super().list(request, *args, **kwargs)


class DeliveryTaskCompleteView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            task = DeliveryTask.objects.get(pk=pk)
        except DeliveryTask.DoesNotExist:
            return Response({"detail": "Delivery task not found"}, status=status.HTTP_404_NOT_FOUND)

        # Authorization: only assigned driver or staff can complete, or auto-claim unassigned task
        if task.driver and task.driver != request.user and not request.user.is_staff:
            return Response({"detail": "Only the assigned driver can complete this delivery."}, status=status.HTTP_403_FORBIDDEN)

        # Strict Hub Check for Delivery Partner
        if request.user.role in (User.Roles.DELIVERY_PARTNER, "DRIVER") and getattr(request.user, "assigned_hub", None):
            task_hub = task.hub or (task.subscription.hub if task.subscription else None) or (task.order.hub if task.order else None)
            if task_hub and task_hub != request.user.assigned_hub:
                return Response({
                    "detail": f"You are strictly assigned to {request.user.assigned_hub.name} and cannot complete deliveries for {task_hub.name}."
                }, status=status.HTTP_403_FORBIDDEN)

        if not task.driver and request.user.role in (User.Roles.DELIVERY_PARTNER, "DRIVER"):
            task.driver = request.user

        # Prevent double-completion
        if task.status == DeliveryTask.Statuses.DELIVERED:
            return Response({"detail": "This delivery has already been completed."}, status=status.HTTP_409_CONFLICT)

        proof_url = request.data.get("proof_image_url", "")
        cash_collected = request.data.get("cash_collected", True)

        task.status = DeliveryTask.Statuses.DELIVERED
        task.proof_image_url = proof_url
        task.delivered_at = timezone.now()
        if task.is_cod or (task.order and getattr(task.order, "is_cod", False)):
            task.cash_collected = bool(cash_collected)
        task.save()

        # Update linked LiveOrder if express order task
        if task.order:
            task.order.status = LiveOrder.Statuses.DELIVERED
            task.order.delivered_at = timezone.now()
            if proof_url:
                task.order.proof_image_url = proof_url
            if getattr(task.order, "is_cod", False):
                task.order.cash_collected = bool(cash_collected)
                if cash_collected:
                    task.order.payment_status = "PAID (Cash Collected)"
            task.order.save()

        # Deduct wallet balance for subscription deliveries
        if task.subscription and task.subscription.customer:
            customer = task.subscription.customer
            unit_price = task.subscription.effective_unit_price or task.subscription.product.price_per_unit
            total_cost = unit_price * task.subscription.quantity

            if customer.wallet_balance >= total_cost:
                User.objects.filter(pk=customer.pk).update(wallet_balance=F("wallet_balance") - total_cost)
                customer.refresh_from_db(fields=["wallet_balance"])

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
            else:
                # Insufficient balance — record debt
                WalletTransaction.objects.create(
                    user=customer,
                    transaction_type=WalletTransaction.Types.DEBIT,
                    amount=total_cost,
                    description=f'Delivery #{task.id} - Outstanding balance (insufficient funds)',
                )
                Notification.objects.create(
                    user=customer,
                    title='⚠️ Low Wallet Balance!',
                    message=f'Delivery #{task.id} completed. ₹{total_cost} is outstanding. Please recharge your wallet.',
                    notification_type=Notification.Types.WALLET,
                )

        try:
            from apps.core.consumers import broadcast_hub_event
            hub_code = getattr(task.hub, "hub_code", "HUB-KDD-01") if task.hub else "HUB-KDD-01"
            broadcast_hub_event(hub_code, "delivery_updated", {
                "task_id": task.id,
                "status": task.status,
            })
        except Exception:
            pass

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

        # Authorization: only assigned driver or staff can skip, or auto-claim unassigned task
        if task.driver and task.driver != request.user and not request.user.is_staff:
            return Response({"detail": "Only the assigned driver can skip this delivery."}, status=status.HTTP_403_FORBIDDEN)

        # Strict Hub Check for Delivery Partner
        if request.user.role in (User.Roles.DELIVERY_PARTNER, "DRIVER") and getattr(request.user, "assigned_hub", None):
            task_hub = task.hub or (task.subscription.hub if task.subscription else None) or (task.order.hub if task.order else None)
            if task_hub and task_hub != request.user.assigned_hub:
                return Response({
                    "detail": f"You are strictly assigned to {request.user.assigned_hub.name} and cannot skip deliveries for {task_hub.name}."
                }, status=status.HTTP_403_FORBIDDEN)

        reason = request.data.get("reason", "")
        if reason:
            task.status = DeliveryTask.Statuses.FAILED
            task.failure_reason = reason
        else:
            task.status = DeliveryTask.Statuses.SKIPPED
            
        task.save()

        # Update linked LiveOrder if express order task
        if task.order:
            task.order.status = LiveOrder.Statuses.CANCELLED
            task.order.save(update_fields=["status"])

        # Notify customer about skipped drop with exact reason
        if task.target_customer:
            try:
                Notification.objects.create(
                    user=task.target_customer,
                    title="⚠️ Morning Drop Skipped",
                    message=f"Delivery #{task.id} could not be completed: {reason or 'Delivery partner skipped stop'}. Next drop will resume as scheduled.",
                    notification_type=Notification.Types.DELIVERY,
                )
            except Exception:
                pass

        try:
            from apps.core.consumers import broadcast_hub_event
            hub_code = getattr(task.hub, "hub_code", "HUB-KDD-01") if task.hub else "HUB-KDD-01"
            broadcast_hub_event(hub_code, "delivery_updated", {
                "task_id": task.id,
                "status": task.status,
            })
        except Exception:
            pass

        return Response(
            {
                "message": "Delivery marked as skipped.",
                "task": DeliveryTaskSerializer(task).data,
            },
            status=status.HTTP_200_OK,
        )


class DeliveryTaskStatusUpdateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            task = DeliveryTask.objects.get(pk=pk)
        except DeliveryTask.DoesNotExist:
            return Response({"detail": "Delivery task not found"}, status=status.HTTP_404_NOT_FOUND)

        new_status = request.data.get("status")
        valid_statuses = [
            DeliveryTask.Statuses.PENDING,
            DeliveryTask.Statuses.PICKED_UP,
            DeliveryTask.Statuses.ON_THE_WAY,
            DeliveryTask.Statuses.DELIVERED,
            DeliveryTask.Statuses.SKIPPED,
            DeliveryTask.Statuses.FAILED,
        ]
        if new_status not in valid_statuses:
            return Response({"detail": f"Invalid status '{new_status}'. Must be one of {valid_statuses}"}, status=status.HTTP_400_BAD_REQUEST)

        task.status = new_status
        task.save(update_fields=["status"])

        # Send real-time notification to customer
        if task.target_customer:
            try:
                hub_name = task.hub.name if task.hub else (task.subscription.hub.name if task.subscription and task.subscription.hub else "Depot")
                if new_status == DeliveryTask.Statuses.PICKED_UP:
                    Notification.objects.create(
                        user=task.target_customer,
                        title="📦 Milk Picked Up & Chilled",
                        message=f"Your milk delivery #{task.id} was picked up from {hub_name}. Partner is packing crates for delivery.",
                        notification_type=Notification.Types.DELIVERY,
                    )
                elif new_status == DeliveryTask.Statuses.ON_THE_WAY:
                    Notification.objects.create(
                        user=task.target_customer,
                        title="🛵 Partner is On The Way!",
                        message=f"Your delivery #{task.id} is the next stop! Partner is navigating to your doorstep.",
                        notification_type=Notification.Types.DELIVERY,
                    )
            except Exception:
                pass

        # Broadcast WebSocket event
        try:
            from apps.core.consumers import broadcast_hub_event
            hub_code = getattr(task.hub, "hub_code", "HUB-KDD-01") if task.hub else "HUB-KDD-01"
            broadcast_hub_event(hub_code, "task_status_updated", {
                "task_id": task.id,
                "status": task.status,
                "driver": request.user.username,
            })
        except Exception:
            pass

        return Response({
            "message": f"Task #{task.id} status updated to {task.status}",
            "task": DeliveryTaskSerializer(task).data,
        })


class DeliveryShiftStartRouteView(APIView):
    """
    Driver 1-tap action to mark all assigned pending tasks for today as PICKED_UP (Out for delivery route)
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        today = date.today()
        shift = request.data.get("shift", "ALL").upper()

        qs = DeliveryTask.objects.filter(
            driver=user,
            delivery_date=today,
            status=DeliveryTask.Statuses.PENDING,
        )

        if shift == "MORNING":
            qs = qs.exclude(slot_time__icontains="PM").exclude(slot_time__icontains="17:").exclude(slot_time__icontains="18:").exclude(slot_time__icontains="19:")
        elif shift == "EVENING":
            qs = qs.filter(Q(slot_time__icontains="PM") | Q(slot_time__icontains="17:") | Q(slot_time__icontains="18:") | Q(slot_time__icontains="19:"))

        updated_count = qs.update(status=DeliveryTask.Statuses.PICKED_UP)

        # Notify customers
        for task in DeliveryTask.objects.filter(driver=user, delivery_date=today, status=DeliveryTask.Statuses.PICKED_UP):
            if task.target_customer:
                try:
                    Notification.objects.create(
                        user=task.target_customer,
                        title="🛵 Delivery Route Started!",
                        message="Delivery partner has collected today's chilled farm batch and started the doorstep route!",
                        notification_type=Notification.Types.DELIVERY,
                    )
                except Exception:
                    pass

        return Response({
            "message": f"Successfully picked up {updated_count} delivery stops for today's route.",
            "updated_count": updated_count,
        })


class DeliverySummaryView(APIView):
    permission_classes = [IsAdminOrStaff]

    def get(self, request):
        """Admin / Operations summary of today's total milk demand computed live from database."""
        today = date.today().isoformat()
        user = request.user
        tasks = DeliveryTask.objects.all().select_related("subscription__product", "subscription__customer")
        active_subs = Subscription.objects.filter(status=Subscription.Statuses.ACTIVE).select_related("product", "customer")

        # Scope to user's hub
        if not user.is_superuser and getattr(user, 'assigned_hub', None):
            tasks = tasks.filter(Q(hub=user.assigned_hub) | Q(subscription__hub=user.assigned_hub))
            active_subs = active_subs.filter(Q(hub=user.assigned_hub) | Q(customer__assigned_hub=user.assigned_hub))

        total_deliveries = tasks.count()
        completed = tasks.filter(status=DeliveryTask.Statuses.DELIVERED).count()
        pending = tasks.filter(status=DeliveryTask.Statuses.PENDING).count()

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
        elif not user.is_superuser and user.assigned_hub:
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
        # Strict role restriction: Only delivery partners, hub managers, or admins can record bottle deposits
        if getattr(user, "role", "") == User.Roles.CUSTOMER and not (user.is_staff or user.is_superuser):
            return Response(
                {"detail": "Customers cannot record bottle deposits. Only delivery partners or hub managers can record bottle deposits."},
                status=status.HTTP_403_FORBIDDEN,
            )

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
    permission_classes = [permissions.IsAuthenticated, IsAdminOrHubManager]

    def patch(self, request, pk):
        """Mark a bottle return as RETURNED or LOST with strict role and hub authorization."""
        from apps.deliveries.models import BottleReturn

        user = request.user
        is_manager_or_admin = (
            user.is_staff
            or user.is_superuser
            or getattr(user, "role", "") in (User.Roles.ADMIN, User.Roles.HUB_MANAGER, "PROVIDER")
        )
        if not is_manager_or_admin:
            return Response(
                {"detail": "Only hub managers or platform administrators can verify and refund bottle returns."},
                status=status.HTTP_403_FORBIDDEN,
            )

        bottle = BottleReturn.objects.filter(pk=pk).first()
        if not bottle:
            return Response({"detail": "Bottle return record not found"}, status=status.HTTP_404_NOT_FOUND)

        # Hub Scoping: ensure hub manager can only refund bottles for their assigned hub
        if not (user.is_staff or user.is_superuser):
            if bottle.hub and user.assigned_hub and bottle.hub != user.assigned_hub:
                return Response(
                    {"detail": f"You are assigned to {user.assigned_hub.name} and cannot manage bottle returns for {bottle.hub.name}."},
                    status=status.HTTP_403_FORBIDDEN,
                )

        new_status = request.data.get("status")
        if new_status and new_status in dict(BottleReturn.Statuses.choices):
            # Prevent duplicate refund attacks
            if bottle.status == BottleReturn.Statuses.RETURNED:
                return Response(
                    {"detail": "This bottle deposit has already been refunded and finalized."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            bottle.status = new_status
            if new_status == BottleReturn.Statuses.RETURNED:
                bottle.returned_date = date.today()
                # Refund deposit to customer wallet (atomic to avoid lost updates)
                if bottle.deposit_amount > 0:
                    customer = bottle.customer
                    User.objects.filter(pk=customer.pk).update(
                        wallet_balance=F("wallet_balance") + bottle.deposit_amount
                    )
                    customer.refresh_from_db(fields=["wallet_balance"])

                    WalletTransaction.objects.create(
                        user=customer,
                        amount=bottle.deposit_amount,
                        transaction_type=WalletTransaction.Types.CREDIT,
                        description=f"🔄 Bottle deposit refund ({bottle.quantity}x returned)",
                    )
            bottle.save()
            return Response({
                "message": f"Bottle return record #{bottle.id} updated to {bottle.status}.",
                "id": bottle.id,
                "status": bottle.status,
            })
        return Response({"detail": "Invalid status"}, status=status.HTTP_400_BAD_REQUEST)


class ProviderEarningsSummaryView(APIView):
    """
    Dedicated endpoint for Hub Managers / Depot Operators to get live, real-time earnings,
    demand metrics, volume in litres, COD cash in hand, and withdrawable balance.
    """
    permission_classes = [permissions.IsAuthenticated, IsAdminOrHubManager]

    def get(self, request):
        from .models import LocationHub, ProviderPayout
        from .settlement_service import resolve_period_dates, calculate_hub_earnings

        user = request.user
        hub = getattr(user, "assigned_hub", None)
        if not hub and (user.is_staff or user.is_superuser):
            hub_code = request.query_params.get("hub_code") or request.query_params.get("hub_id")
            if hub_code:
                if str(hub_code).isdigit():
                    hub = LocationHub.objects.filter(pk=int(hub_code)).first()
                else:
                    hub = LocationHub.objects.filter(hub_code=hub_code).first()
            if not hub:
                hub = LocationHub.objects.first()

        if not hub:
            return Response({"detail": "Hub not found"}, status=status.HTTP_404_NOT_FOUND)

        period = request.query_params.get("period", "TODAY")
        start_date_str = request.query_params.get("start_date")
        end_date_str = request.query_params.get("end_date")

        s_date, e_date = resolve_period_dates(period, start_date_str, end_date_str)
        earnings = calculate_hub_earnings(hub=hub, start_date=s_date, end_date=e_date, unsettled_only=False)

        # All-time unsettled withdrawable balance
        unsettled_earnings = calculate_hub_earnings(hub=hub, unsettled_only=True)

        recent_payouts = ProviderPayout.objects.filter(hub=hub).order_by("-created_at")[:5]
        payouts_list = []
        for p in recent_payouts:
            b_name = p.bank_name or hub.bank_name or ""
            b_acc = p.bank_account_number or hub.bank_account_number or ""
            payouts_list.append({
                "id": p.payment_reference or f"PAY-KDD-{p.id:04d}",
                "raw_id": p.id,
                "amount": float(p.net_payout),
                "gross_revenue": float(p.total_revenue),
                "cash_collected": float(p.cash_collected),
                "prepaid_revenue": float(p.prepaid_revenue),
                "platform_commission": float(p.platform_commission),
                "status": p.status,
                "payment_reference": p.payment_reference,
                "bank": f"{b_name} (A/C •••• {b_acc[-4:]})" if len(b_acc) >= 4 else b_name,
                "bank_name": b_name,
                "bank_account_number": b_acc,
                "bank_account_masked": f"•••• {b_acc[-4:]}" if len(b_acc) >= 4 else b_acc,
                "bank_ifsc": p.bank_ifsc or hub.bank_ifsc or "",
                "upi_id": p.upi_id or hub.upi_id or "",
                "date": p.paid_at.strftime("%Y-%m-%d %H:%M") if p.paid_at else p.created_at.strftime("%Y-%m-%d"),
            })

        bank_acc = hub.bank_account_number or ""
        masked_acc = f"•••• {bank_acc[-4:]}" if len(bank_acc) >= 4 else bank_acc
        return Response({
            "period": period.upper(),
            "start_date": str(s_date),
            "end_date": str(e_date),
            "hub": {
                "id": hub.id,
                "hub_code": hub.hub_code,
                "name": hub.name,
                "manager_name": hub.manager_name,
                "manager_phone": hub.manager_phone,
                "bank_name": hub.bank_name or "",
                "bank_account_number": bank_acc,
                "bank_account_masked": masked_acc,
                "bank_ifsc": hub.bank_ifsc or "",
                "bank_account_holder": hub.bank_account_holder or (hub.manager_name or "Hub Manager"),
                "upi_id": hub.upi_id or "",
            },
            "metrics": {
                "total_deliveries": earnings["total_deliveries"],
                "completed_deliveries": earnings["completed_deliveries"],
                "pending_deliveries": earnings["pending_deliveries"],
                "gross_revenue": float(earnings["gross_revenue"]),
                "cash_collected": float(earnings["cash_collected"]),
                "prepaid_revenue": float(earnings["prepaid_revenue"]),
                "platform_commission": float(earnings["platform_commission"]),
                "total_litres": earnings["total_litres"],
                "net_withdrawable_amount": float(unsettled_earnings["net_withdrawable_amount"]),
                "period_net_withdrawable": float(earnings["net_withdrawable_amount"]),
                "already_settled_amount": float(earnings["already_settled_amount"]),
            },
            "product_breakdown": earnings["product_breakdown"],
            "recent_payouts": payouts_list,
        })


class ProviderPayoutListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminOrHubManager]

    def get(self, request):
        """List provider payouts for the user's hub."""
        from apps.deliveries.models import ProviderPayout, LocationHub

        user = request.user
        hub = getattr(user, "assigned_hub", None) or LocationHub.objects.first()

        qs = ProviderPayout.objects.all().select_related("hub", "manager").order_by("-created_at")
        if getattr(user, "role", "") in (User.Roles.HUB_MANAGER, "PROVIDER") and hub:
            qs = qs.filter(hub=hub)
        elif hub and not (user.is_staff or getattr(user, "role", "") in (User.Roles.ADMIN, "ADMIN")):
            qs = qs.filter(hub=hub)

        payouts_data = []
        for p in qs[:50]:
            h_obj = p.hub
            b_name = p.bank_name or (h_obj.bank_name if h_obj else "") or ""
            b_acc = p.bank_account_number or (h_obj.bank_account_number if h_obj else "") or ""
            b_ifsc = p.bank_ifsc or (h_obj.bank_ifsc if h_obj else "") or ""
            b_upi = p.upi_id or (h_obj.upi_id if h_obj else "") or ""

            payouts_data.append({
                "id": p.payment_reference or f"PAY-KDD-{p.id:04d}",
                "raw_id": p.id,
                "hub_id": p.hub_id,
                "hub_name": h_obj.name if h_obj else "Central Hub",
                "period_start": str(p.period_start),
                "period_end": str(p.period_end),
                "total_deliveries": p.total_deliveries,
                "total_revenue": float(p.total_revenue),
                "cash_collected": float(p.cash_collected),
                "prepaid_revenue": float(p.prepaid_revenue),
                "driver_salaries": float(p.driver_salaries),
                "platform_commission": float(p.platform_commission),
                "amount": float(p.net_payout),
                "status": p.status,
                "payment_reference": p.payment_reference or f"PAY-KDD-{p.id:04d}",
                "bank": f"{b_name} (A/C •••• {b_acc[-4:]})",
                "bank_name": b_name,
                "bank_account_number": b_acc,
                "bank_account_masked": f"•••• {b_acc[-4:]}",
                "bank_ifsc": b_ifsc,
                "upi_id": b_upi,
                "notes": p.notes,
                "date": p.paid_at.strftime("%Y-%m-%d %H:%M") if p.paid_at else p.created_at.strftime("%Y-%m-%d"),
            })

        return Response(payouts_data)

    def post(self, request):
        """Request / trigger instant payout settlement for hub manager with strict role and hub validation."""
        from apps.deliveries.models import LocationHub
        from apps.deliveries.settlement_service import execute_hub_payout_settlement

        user = request.user
        is_manager_or_admin = (
            user.is_staff
            or user.is_superuser
            or getattr(user, "role", "") in (User.Roles.ADMIN, User.Roles.HUB_MANAGER, "PROVIDER")
        )
        if not is_manager_or_admin:
            return Response(
                {"detail": "Only hub managers or platform administrators can request payout settlements."},
                status=status.HTTP_403_FORBIDDEN,
            )

        hub = getattr(user, "assigned_hub", None)
        if not hub and (user.is_staff or user.is_superuser):
            hub_id = request.data.get("hub_id") or request.data.get("hub")
            if hub_id:
                if str(hub_id).isdigit():
                    hub = LocationHub.objects.filter(pk=int(hub_id)).first()
                else:
                    hub = LocationHub.objects.filter(hub_code=hub_id).first()
            if not hub:
                hub = LocationHub.objects.first()

        if not hub:
            return Response(
                {"detail": "You must be assigned to an active location hub to generate a provider payout."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        amount_req = request.data.get("amount")
        parsed_amount = None
        if amount_req is not None:
            try:
                parsed_amount = Decimal(str(amount_req))
                if parsed_amount <= Decimal("0"):
                    return Response({"detail": "Payout amount must be greater than zero."}, status=status.HTTP_400_BAD_REQUEST)
            except Exception:
                return Response({"detail": "Invalid payout amount format."}, status=status.HTTP_400_BAD_REQUEST)

        notes = request.data.get("notes", "")

        try:
            payout = execute_hub_payout_settlement(
                hub=hub,
                manager_user=user,
                amount=parsed_amount,
                notes=notes,
            )
        except ValueError as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        b_name = payout.bank_name or hub.bank_name or ""
        b_acc = payout.bank_account_number or hub.bank_account_number or ""

        return Response({
            "message": f"Instant Payout of ₹{payout.net_payout:.2f} transferred successfully!",
            "payout": {
                "id": payout.payment_reference,
                "raw_id": payout.id,
                "amount": float(payout.net_payout),
                "gross_revenue": float(payout.total_revenue),
                "cash_collected": float(payout.cash_collected),
                "prepaid_revenue": float(payout.prepaid_revenue),
                "platform_commission": float(payout.platform_commission),
                "status": "SETTLED ✅",
                "payment_reference": payout.payment_reference,
                "bank": f"{b_name} (A/C •••• {b_acc[-4:]})",
                "bank_name": b_name,
                "bank_account_number": b_acc,
                "bank_account_masked": f"•••• {b_acc[-4:]}",
                "bank_ifsc": payout.bank_ifsc,
                "upi_id": payout.upi_id,
                "date": payout.paid_at.strftime("%Y-%m-%d %H:%M") if payout.paid_at else "",
            }
        }, status=status.HTTP_201_CREATED)


class GenerateTodayTasksView(APIView):
    """Admin / Hub Manager / Driver endpoint to trigger daily delivery task generation."""
    permission_classes = [IsAdminOrHubManager]

    def post(self, request):
        from datetime import timedelta
        from apps.subscriptions.models import VacationPause
        from apps.deliveries.models import LocationHub, DailyMilkBatch, DeliveryTask
        from apps.products.models import Product
        import random
        import logging

        logger = logging.getLogger(__name__)

        # 1. Parse target date safely
        target_date_str = request.data.get("date")
        if target_date_str:
            try:
                target_date = date.fromisoformat(str(target_date_str).split("T")[0].strip())
            except Exception:
                target_date = date.today()
        else:
            target_date = date.today()

        # 2. Resolve target hub (ALWAYS define hub_obj safely)
        hub_code = request.data.get("hub_code") or request.data.get("hub_id")
        hub_obj = None
        if hub_code and str(hub_code).lower() != "all":
            hub_qs = LocationHub.objects.filter(hub_code=hub_code)
            if not hub_qs.exists() and str(hub_code).isdigit():
                hub_qs = LocationHub.objects.filter(pk=int(hub_code))
            hub_obj = hub_qs.first()
        if not hub_obj and getattr(request.user, "assigned_hub", None):
            hub_obj = request.user.assigned_hub
        if not hub_obj:
            hub_obj = LocationHub.objects.first()

        # 3. Auto-resume expired vacation pauses
        resumed_count = 0
        expired_pauses = VacationPause.objects.filter(
            end_date__lt=target_date,
            subscription__status=Subscription.Statuses.PAUSED,
        ).select_related("subscription", "subscription__customer", "subscription__product")

        for pause in expired_pauses:
            sub = pause.subscription
            sub.status = Subscription.Statuses.ACTIVE
            sub.save(update_fields=["status"])
            try:
                Notification.objects.create(
                    user=sub.customer,
                    title="🔔 Subscription Resumed",
                    message=f"Your vacation pause has ended. Daily deliveries of {sub.product.name} resume from {target_date}.",
                    notification_type=Notification.Types.VACATION,
                )
            except Exception:
                pass
            resumed_count += 1

        # 4. Record & wire daily batch lab certification if provided
        product_name = request.data.get("product_name", "Pure Buffalo Milk")
        fat_val = request.data.get("fat_percentage")
        snf_val = request.data.get("snf_percentage")
        water_val = request.data.get("water_percentage", 0.0)
        price_val = request.data.get("price_per_litre")
        total_litres = request.data.get("total_litres", 450.0)
        temp_val = request.data.get("temperature_celsius", 3.8)

        created_batch_code = None
        if fat_val is not None and price_val is not None:
            try:
                batch_code = request.data.get("batch_code") or f"BATCH-{target_date.strftime('%Y%m%d')}-{random.randint(100, 999)}"
                # Find existing batch for this date, hub, and product
                batch_filter = {"batch_date": target_date, "product_name__iexact": product_name}
                if hub_obj:
                    batch_filter["hub"] = hub_obj
                batch = DailyMilkBatch.objects.filter(**batch_filter).first()
                if not batch:
                    batch = DailyMilkBatch(
                        batch_date=target_date,
                        hub=hub_obj,
                        product_name=product_name,
                        batch_code=batch_code,
                    )
                batch.fat_percentage = float(fat_val)
                batch.snf_percentage = float(snf_val or 9.0)
                batch.water_percentage = float(water_val or 0.0)
                batch.price_per_litre = float(price_val)
                batch.total_litres = float(total_litres or 450.0)
                batch.temperature_celsius = float(temp_val or 3.8)
                batch.status = "DISPATCHED"
                batch.dispatched_by = request.user if request.user.is_authenticated else None
                batch.save()
                created_batch_code = batch.batch_code

                # Update product unit price (Milk products only - protect ghee, honey, paneer)
                first_w = product_name.split()[0] if product_name else "Milk"
                Product.objects.filter(
                    Q(name__iexact=product_name) |
                    (Q(name__icontains=first_w) & Q(name__icontains="milk"))
                ).update(price_per_unit=float(price_val))
            except Exception as batch_err:
                logger.warning(f"Batch certification warning: {batch_err}")

        # 5. Query active subscriptions
        active_subs = (
            Subscription.objects
            .filter(status=Subscription.Statuses.ACTIVE)
            .select_related("customer", "product", "hub", "address", "customer__assigned_hub")
        )

        user = request.user
        if hub_code and str(hub_code).lower() != "all" and hub_obj:
            active_subs = active_subs.filter(
                Q(hub=hub_obj) | Q(customer__assigned_hub=hub_obj) | Q(hub__isnull=True)
            )
        elif not user.is_superuser and getattr(user, 'assigned_hub', None):
            active_subs = active_subs.filter(
                Q(hub=user.assigned_hub) | Q(customer__assigned_hub=user.assigned_hub) | Q(hub__isnull=True)
            )

        created_count = 0
        skipped_count = 0
        hub_drivers = {}
        hub_driver_indices = {}

        for sub in active_subs:
            # Check active vacation pause
            active_pause = VacationPause.objects.filter(
                subscription=sub,
                start_date__lte=target_date,
                end_date__gte=target_date,
            ).exists()
            if active_pause:
                skipped_count += 1
                continue

            # Check if task already exists for this subscription on this date
            existing_task = DeliveryTask.objects.filter(subscription=sub, delivery_date=target_date).first()
            if existing_task:
                skipped_count += 1
                continue

            # Don't generate tasks if subscription starts in the future
            if sub.start_date and sub.start_date > target_date:
                skipped_count += 1
                continue

            # Schedule eligibility (case-insensitive)
            sched = (sub.schedule_type or 'DAILY').upper()
            if sched == Subscription.Schedules.ALTERNATE:
                days_since = (target_date - sub.start_date).days
                if days_since % 2 != 0:
                    skipped_count += 1
                    continue
            elif sched == Subscription.Schedules.CUSTOM:
                if target_date.weekday() not in (0, 2, 4):
                    skipped_count += 1
                    continue
            elif sched == Subscription.Schedules.ONCE:
                if DeliveryTask.objects.filter(subscription=sub).exists():
                    skipped_count += 1
                    continue
            elif sched in ('WEEKDAYS', 'WEEKDAY') and target_date.weekday() >= 5:  # 5=Sat, 6=Sun
                skipped_count += 1
                continue

            # Resolve hub
            hub = sub.hub or getattr(sub.customer, "assigned_hub", None) or hub_obj
            if hub and not sub.hub:
                sub.hub = hub
                sub.save(update_fields=["hub"])

            # Resolve driver with multi-tier fallback
            driver = self._get_next_driver(hub, hub_drivers, hub_driver_indices)

            # Resolve customer address
            task_address = sub.address
            if not task_address and hasattr(sub.customer, "addresses"):
                task_address = sub.customer.addresses.filter(is_default=True).first() or sub.customer.addresses.first()

            slot = sub.delivery_slot or getattr(sub.customer, "delivery_slot_preference", None) or "05:30 AM - 07:00 AM"

            DeliveryTask.objects.create(
                subscription=sub,
                hub=hub,
                driver=driver,
                address=task_address,
                delivery_date=target_date,
                slot_time=slot,
                status=DeliveryTask.Statuses.PENDING,
            )
            created_count += 1

        # 6. Auto-link quality batch to generated tasks
        batches = DailyMilkBatch.objects.filter(batch_date=target_date)
        if batches.exists():
            for task in DeliveryTask.objects.filter(delivery_date=target_date, batch__isnull=True):
                matching_batch = batches.filter(hub=task.hub).first() or batches.first()
                if matching_batch:
                    task.batch = matching_batch
                    task.save(update_fields=['batch'])

        # 7. Total tasks count
        total_tasks = DeliveryTask.objects.filter(delivery_date=target_date).count()

        return Response({
            "status": "success",
            "message": f"Task generation complete for {target_date}.",
            "date": str(target_date),
            "tasks_created": created_count,
            "total_tasks": total_tasks,
            "subscriptions_skipped": skipped_count,
            "vacations_resumed": resumed_count,
            "active_subscriptions_found": active_subs.count() if hasattr(active_subs, 'count') else len(list(active_subs)),
            "hub_filter": str(hub_code or getattr(hub_obj, 'hub_code', 'ALL')),
            "batch_code": created_batch_code,
        }, status=status.HTTP_200_OK)

    def _get_next_driver(self, hub, hub_drivers, hub_driver_indices):
        if hub is None:
            return None

        hub_id = hub.id
        if hub_id not in hub_drivers:
            # 1. Try active drivers for this hub
            drivers = list(
                User.objects.filter(
                    role__in=[User.Roles.DELIVERY_PARTNER, "DRIVER", "DELIVERY_PARTNER"],
                    assigned_hub=hub,
                    driver_status="ACTIVE",
                ).order_by("id")
            )
            # 2. Fallback: Any drivers assigned to this hub
            if not drivers:
                drivers = list(
                    User.objects.filter(
                        role__in=[User.Roles.DELIVERY_PARTNER, "DRIVER", "DELIVERY_PARTNER"],
                        assigned_hub=hub,
                    ).order_by("id")
                )
            # 3. Fallback: Any driver in the system
            if not drivers:
                drivers = list(
                    User.objects.filter(
                        role__in=[User.Roles.DELIVERY_PARTNER, "DRIVER", "DELIVERY_PARTNER"],
                    ).order_by("id")
                )
            hub_drivers[hub_id] = drivers
            hub_driver_indices[hub_id] = 0

        drivers = hub_drivers[hub_id]
        if not drivers:
            return None

        idx = hub_driver_indices[hub_id]
        driver = drivers[idx % len(drivers)]
        hub_driver_indices[hub_id] = idx + 1
        return driver


class SlotAvailabilityView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        from .models import DeliverySlot, LocationHub
        from datetime import date as date_cls
        
        hub_id = request.query_params.get('hub_id')
        date_str = request.query_params.get('date')
        
        # Parse date or default to today
        if date_str:
            try:
                from datetime import datetime
                target_date = datetime.strptime(date_str, '%Y-%m-%d').date()
            except ValueError:
                target_date = date_cls.today()
        else:
            target_date = date_cls.today()
        
        # Get hub
        if hub_id:
            slots = DeliverySlot.objects.filter(hub_id=hub_id, is_active=True)
        else:
            slots = DeliverySlot.objects.filter(is_active=True)
        
        result = []
        for slot in slots:
            booked = slot.booked_count(target_date)
            result.append({
                'id': slot.id,
                'name': slot.name,
                'label': slot.label,
                'start_time': slot.start_time.strftime('%H:%M'),
                'end_time': slot.end_time.strftime('%H:%M'),
                'max_orders': slot.max_orders,
                'booked_count': booked,
                'available_count': max(0, slot.max_orders - booked),
                'is_full': booked >= slot.max_orders,
                'is_cutoff_passed': slot.is_cutoff_passed(),
                'hub_id': slot.hub_id,
                'hub_name': slot.hub.name if slot.hub else '',
            })
        
        return Response(result)


class DailyMilkBatchListCreateView(APIView):
    """
    Handles recording and querying daily milk batches submitted by the Hub Provider.
    Includes FAT %, SNF %, Water %, Litre Price, Total Volume, and temperature.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from django.db import models
        from .models import DailyMilkBatch, LocationHub
        from datetime import date as date_cls

        date_str = request.query_params.get("date")
        product_name = request.query_params.get("product")
        hub_code = request.query_params.get("hub_code") or request.query_params.get("hub_id")

        batches = DailyMilkBatch.objects.all()

        if date_str:
            try:
                from datetime import datetime
                target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
                batches = batches.filter(batch_date=target_date)
            except ValueError:
                pass
        
        if product_name:
            batches = batches.filter(product_name__icontains=product_name)

        if hub_code:
            batch_hub_qs = batches.filter(hub__hub_code=hub_code)
            if not batch_hub_qs.exists() and str(hub_code).isdigit():
                batch_hub_qs = batches.filter(hub__pk=int(hub_code))
            batches = batch_hub_qs
        elif not request.user.is_superuser and getattr(request.user, 'assigned_hub', None):
            batches = batches.filter(hub=request.user.assigned_hub)

        data = []
        for b in batches[:50]:
            data.append({
                "id": b.id,
                "batch_code": b.batch_code,
                "product_name": b.product_name,
                "batch_date": str(b.batch_date),
                "fat_percentage": float(b.fat_percentage),
                "snf_percentage": float(b.snf_percentage),
                "water_percentage": float(b.water_percentage),
                "price_per_litre": float(b.price_per_litre),
                "total_litres": float(b.total_litres),
                "temperature_celsius": float(b.temperature_celsius),
                "status": b.status,
                "quality_certificate_note": b.quality_certificate_note,
                "hub_id": b.hub_id,
                "hub_name": b.hub.name if b.hub else "",
                "created_at": b.created_at.isoformat(),
            })

        return Response({"count": len(data), "batches": data})

    def post(self, request):
        # Certifying a batch rewrites product pricing, so restrict to
        # drivers, hub managers/providers, and admins — never plain customers.
        role = getattr(request.user, "role", "")
        if not request.user.is_staff and role == User.Roles.CUSTOMER:
            return Response(
                {"detail": "You do not have permission to certify milk batches."},
                status=status.HTTP_403_FORBIDDEN,
            )

        from django.db import models
        from .models import DailyMilkBatch, LocationHub
        from apps.products.models import Product
        from datetime import date as date_cls
        import random

        payload = request.data
        product_name = payload.get("product_name", "Pure Buffalo Milk").strip()
        try:
            fat = float(payload.get("fat_percentage", 6.80))
        except (ValueError, TypeError):
            fat = 6.80
        try:
            snf = float(payload.get("snf_percentage", 9.00))
        except (ValueError, TypeError):
            snf = 9.00
        try:
            water = float(payload.get("water_percentage", 0.00))
        except (ValueError, TypeError):
            water = 0.00
        try:
            litre_price = float(payload.get("price_per_litre", 68.00))
        except (ValueError, TypeError):
            litre_price = 68.00
        try:
            total_litres = float(payload.get("total_litres", 450.00))
        except (ValueError, TypeError):
            total_litres = 450.00
        try:
            temperature = float(payload.get("temperature_celsius", 3.8))
        except (ValueError, TypeError):
            temperature = 3.8

        hub_code = payload.get("hub_code") or payload.get("hub_id")
        
        hub = None
        if hub_code:
            hub_qs = LocationHub.objects.filter(hub_code=hub_code)
            if not hub_qs.exists() and str(hub_code).isdigit():
                hub_qs = LocationHub.objects.filter(pk=int(hub_code))
            hub = hub_qs.first()
        if not hub:
            hub = LocationHub.objects.first()

        batch_date_val = date_cls.today()
        if payload.get("batch_date"):
            try:
                from datetime import datetime
                batch_date_val = datetime.strptime(str(payload.get("batch_date")).strip(), "%Y-%m-%d").date()
            except Exception:
                batch_date_val = date_cls.today()

        batch_code = payload.get("batch_code") or f"BATCH-{batch_date_val.strftime('%Y%m%d')}-{random.randint(100, 999)}"

        batch_filter = {
            "batch_date": batch_date_val,
            "product_name__iexact": product_name,
        }
        if hub:
            batch_filter["hub"] = hub

        batch = DailyMilkBatch.objects.filter(**batch_filter).first()
        created = False
        if not batch:
            batch = DailyMilkBatch(
                batch_code=batch_code,
                hub=hub,
                product_name=product_name,
                batch_date=batch_date_val,
            )
            created = True

        batch.fat_percentage = fat
        batch.snf_percentage = snf
        batch.water_percentage = water
        batch.price_per_litre = litre_price
        batch.total_litres = total_litres
        batch.temperature_celsius = temperature
        batch.status = payload.get("status", "DISPATCHED")
        batch.quality_certificate_note = payload.get("quality_certificate_note", "FSSAI Certified • Passed 24 Purity Checks")
        batch.save()

        # ── Cascade and link to matching DeliveryTasks & LiveOrders for this date ──
        try:
            from .models import DeliveryTask, LiveOrder
            task_qs = DeliveryTask.objects.filter(delivery_date=batch.batch_date)
            if batch.hub:
                task_qs = task_qs.filter(models.Q(hub=batch.hub) | models.Q(hub__isnull=True))
            first_word = product_name.split()[0] if product_name.split() else ""
            if first_word:
                matching_tasks = task_qs.filter(
                    models.Q(subscription__product__name__icontains=first_word) |
                    models.Q(order__items__product__name__icontains=first_word)
                )
                if matching_tasks.exists():
                    matching_tasks.update(batch=batch)
                else:
                    task_qs.update(batch=batch)
            else:
                task_qs.update(batch=batch)

            order_qs = LiveOrder.objects.filter(delivery_date=batch.batch_date)
            if batch.hub:
                order_qs = order_qs.filter(models.Q(hub=batch.hub) | models.Q(hub__isnull=True))
            order_qs.update(batch=batch)
        except Exception as e:
            pass

        # Sync/Update matching product's unit price in database (Milk products only!)
        try:
            first_word = product_name.split()[0] if product_name.split() else "Milk"
            matching_products = Product.objects.filter(
                models.Q(name__iexact=product_name) |
                (models.Q(name__icontains=first_word) & models.Q(name__icontains="milk"))
            )
            for p in matching_products:
                p.price_per_unit = litre_price
                p.save(update_fields=["price_per_unit"])
        except Exception:
            pass

        return Response({
            "status": "success",
            "message": f"Daily milk batch {batch.batch_code} certified and dispatched successfully!",
            "batch": {
                "id": batch.id,
                "batch_code": batch.batch_code,
                "product_name": batch.product_name,
                "batch_date": str(batch.batch_date),
                "fat_percentage": float(batch.fat_percentage),
                "snf_percentage": float(batch.snf_percentage),
                "water_percentage": float(batch.water_percentage),
                "price_per_litre": float(batch.price_per_litre),
                "total_litres": float(batch.total_litres),
                "temperature_celsius": float(batch.temperature_celsius),
                "status": batch.status,
                "quality_certificate_note": batch.quality_certificate_note,
                "hub_name": batch.hub.name if batch.hub else "",
            }
        }, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


class DailyMilkBatchDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        from .models import DailyMilkBatch
        try:
            b = DailyMilkBatch.objects.get(pk=pk)
        except DailyMilkBatch.DoesNotExist:
            return Response({"detail": "Batch not found."}, status=status.HTTP_404_NOT_FOUND)

        return Response({
            "id": b.id,
            "batch_code": b.batch_code,
            "product_name": b.product_name,
            "batch_date": str(b.batch_date),
            "fat_percentage": float(b.fat_percentage),
            "snf_percentage": float(b.snf_percentage),
            "water_percentage": float(b.water_percentage),
            "price_per_litre": float(b.price_per_litre),
            "total_litres": float(b.total_litres),
            "temperature_celsius": float(b.temperature_celsius),
            "status": b.status,
            "quality_certificate_note": b.quality_certificate_note,
            "hub_id": b.hub_id,
            "hub_name": b.hub.name if b.hub else "",
            "created_at": b.created_at.isoformat(),
        })

    def patch(self, request, pk):
        from .models import DailyMilkBatch, LocationHub
        from apps.products.models import Product
        try:
            b = DailyMilkBatch.objects.get(pk=pk)
        except DailyMilkBatch.DoesNotExist:
            return Response({"detail": "Batch not found."}, status=status.HTTP_404_NOT_FOUND)

        data = request.data
        if "fat_percentage" in data:
            b.fat_percentage = float(data["fat_percentage"])
        if "snf_percentage" in data:
            b.snf_percentage = float(data["snf_percentage"])
        if "water_percentage" in data:
            b.water_percentage = float(data["water_percentage"])
        if "price_per_litre" in data:
            b.price_per_litre = float(data["price_per_litre"])
        if "total_litres" in data:
            b.total_litres = float(data["total_litres"])
        if "temperature_celsius" in data:
            b.temperature_celsius = float(data["temperature_celsius"])
        if "status" in data:
            b.status = data["status"]
        if "quality_certificate_note" in data:
            b.quality_certificate_note = data["quality_certificate_note"]
        if "product_name" in data:
            b.product_name = data["product_name"]

        b.save()

        # Update product price (Milk products only!)
        try:
            first_word = b.product_name.split()[0] if b.product_name.split() else "Milk"
            Product.objects.filter(
                models.Q(name__iexact=b.product_name) |
                (models.Q(name__icontains=first_word) & models.Q(name__icontains="milk"))
            ).update(price_per_unit=b.price_per_litre)
        except Exception:
            pass

        return Response({
            "status": "success",
            "message": f"Daily milk batch {b.batch_code} updated successfully.",
            "batch": {
                "id": b.id,
                "batch_code": b.batch_code,
                "product_name": b.product_name,
                "batch_date": str(b.batch_date),
                "fat_percentage": float(b.fat_percentage),
                "snf_percentage": float(b.snf_percentage),
                "water_percentage": float(b.water_percentage),
                "price_per_litre": float(b.price_per_litre),
                "total_litres": float(b.total_litres),
                "temperature_celsius": float(b.temperature_celsius),
                "status": b.status,
                "quality_certificate_note": b.quality_certificate_note,
                "hub_name": b.hub.name if b.hub else "",
            }
        })

    def delete(self, request, pk):
        from .models import DailyMilkBatch
        try:
            b = DailyMilkBatch.objects.get(pk=pk)
            code = b.batch_code
            b.delete()
            return Response({"status": "success", "message": f"Batch {code} deleted successfully."})
        except DailyMilkBatch.DoesNotExist:
            return Response({"detail": "Batch not found."}, status=status.HTTP_404_NOT_FOUND)


class QualityHistoryView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from .models import DailyMilkBatch
        user = request.user
        # Get batches for user's hub or all batches
        hub = getattr(user, 'assigned_hub', None)
        if hub:
            batches = DailyMilkBatch.objects.filter(hub=hub).order_by('-batch_date')[:30]
        else:
            batches = DailyMilkBatch.objects.all().order_by('-batch_date')[:30]
        
        result = []
        for b in batches:
            result.append({
                'id': b.id,
                'batch_code': b.batch_code,
                'product_name': b.product_name,
                'batch_date': b.batch_date.isoformat() if b.batch_date else None,
                'fat_percentage': float(b.fat_percentage) if b.fat_percentage else None,
                'snf_percentage': float(b.snf_percentage) if b.snf_percentage else None,
                'water_percentage': float(b.water_percentage) if b.water_percentage else None,
                'price_per_litre': float(b.price_per_litre) if b.price_per_litre else None,
                'total_litres': float(b.total_litres) if b.total_litres else None,
                'temperature_celsius': float(b.temperature_celsius) if b.temperature_celsius else None,
                'status': b.status,
                'quality_certificate_note': b.quality_certificate_note or '',
                'hub_name': b.hub.name if b.hub else '',
                'dispatched_by': b.dispatched_by.username if b.dispatched_by else '',
            })
        return Response(result)


class DeliveryRatingSubmitView(APIView):
    """
    Submit customer delivery rating and feedback. Persists to DeliveryRating table.
    POST /api/deliveries/rate/
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        from apps.deliveries.models import DeliveryRating, LiveOrder, DeliveryTask
        order_id = request.data.get("order_id")
        task_id = request.data.get("task_id")
        rating = int(request.data.get("rating", 5))
        rating = max(1, min(5, rating))
        feedback = request.data.get("feedback", "").strip()
        tags = request.data.get("tags", [])
        if not isinstance(tags, list):
            tags = []

        user = request.user if request.user.is_authenticated else None
        order = LiveOrder.objects.filter(id=order_id).first() if order_id else None
        task = DeliveryTask.objects.filter(id=task_id).first() if task_id else None

        driver = None
        if order and order.driver:
            driver = order.driver
        elif task and task.driver:
            driver = task.driver

        rating_obj = DeliveryRating.objects.create(
            user=user,
            order=order,
            task=task,
            driver=driver,
            rating=rating,
            feedback=feedback,
            tags=tags,
        )

        return Response({
            "status": "success",
            "message": "Thank you! Delivery rating recorded successfully.",
            "id": rating_obj.id,
            "rating": rating_obj.rating,
            "driver": driver.username if driver else None,
        }, status=status.HTTP_201_CREATED)


class AutoDispatchDailyTasksView(APIView):
    """
    Idempotent automated nightly task generator.
    POST /api/deliveries/auto-dispatch-daily-tasks/
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        from apps.deliveries.task_generator import generate_daily_tasks_for_date
        target_date = request.data.get("date")
        shift = request.data.get("shift", "all")
        hub_code = request.data.get("hub_code")

        target_hub = None
        if hub_code:
            from apps.deliveries.models import LocationHub
            target_hub = LocationHub.objects.filter(hub_code=hub_code).first()

        result = generate_daily_tasks_for_date(target_date=target_date, target_hub=target_hub, shift=shift)
        return Response({
            "status": "success",
            "message": f"Generated {result['created']} tasks, skipped {result['skipped']}.",
            **result,
        }, status=status.HTTP_200_OK)


class CoverageExpansionRequestView(APIView):
    """
    Submit customer interest for delivery coverage expansion.
    POST /api/deliveries/coverage-request/
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        from apps.deliveries.models import CoverageExpansionRequest
        user = request.user if request.user.is_authenticated else None
        phone = request.data.get("phone", "").strip()
        city = request.data.get("city", "Kodad").strip()
        area_name = request.data.get("area_name", "").strip()
        lat = request.data.get("latitude")
        lon = request.data.get("longitude")

        if not phone and user and hasattr(user, "phone"):
            phone = user.phone or ""

        req = CoverageExpansionRequest.objects.create(
            user=user,
            phone=phone,
            city=city,
            area_name=area_name,
            latitude=float(lat) if lat is not None else None,
            longitude=float(lon) if lon is not None else None,
        )

        return Response({
            "status": "success",
            "message": f"Interest recorded for {area_name or city}! We will notify you when early morning milk delivery launches here.",
            "id": req.id,
            "city": req.city,
            "area_name": req.area_name,
        }, status=status.HTTP_201_CREATED)
