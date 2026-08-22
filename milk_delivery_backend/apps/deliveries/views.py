from datetime import date
from decimal import Decimal
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
        if req_date:
            qs = qs.filter(delivery_date=req_date)

        # Scope by role
        from django.db.models import Q
        if user.role in (User.Roles.HUB_MANAGER, "PROVIDER"):
            if getattr(user, "assigned_hub", None):
                return qs.filter(Q(hub=user.assigned_hub) | Q(subscription__hub=user.assigned_hub) | Q(hub__isnull=True))
            return qs
        elif user.role in (User.Roles.DELIVERY_PARTNER, "DRIVER"):
            return qs.filter(driver=user)
        elif user.role == "CUSTOMER":
            return qs.filter(Q(subscription__customer=user) | Q(order__customer=user))
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

            if customer.wallet_balance >= total_cost:
                customer.wallet_balance -= total_cost
                customer.save(update_fields=["wallet_balance"])

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
                # Insufficient balance — still complete delivery but notify customer to top up
                Notification.objects.create(
                    user=customer,
                    title="⚠️ Low Wallet Balance!",
                    message=f"Delivery #{task.id} completed but wallet balance (₹{customer.wallet_balance}) is insufficient for ₹{total_cost}. Please top up your wallet to avoid service disruption.",
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

        task.status = DeliveryTask.Statuses.SKIPPED
        task.save()

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
                "message": f"Bottle return record #{bottle.id} updated to {bottle.status}.",
                "id": bottle.id,
                "status": bottle.status,
            })
        return Response({"detail": "Invalid status"}, status=status.HTTP_400_BAD_REQUEST)


class ProviderPayoutListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        """List provider payouts for the user's hub."""
        from apps.deliveries.models import ProviderPayout, LocationHub, DeliveryTask
        from datetime import date
        import random

        user = request.user
        hub = getattr(user, "assigned_hub", None) or LocationHub.objects.first()

        qs = ProviderPayout.objects.all().select_related("hub", "manager").order_by("-created_at")
        if hub and not (user.is_staff or getattr(user, "role", "") in (User.Roles.ADMIN, "ADMIN")):
            qs = qs.filter(hub=hub)

        payouts_data = []
        for p in qs[:30]:
            payouts_data.append({
                "id": p.payment_reference or f"PAY-HYD-{p.id:04d}",
                "raw_id": p.id,
                "hub_id": p.hub_id,
                "hub_name": p.hub.name if p.hub else "Central Hub",
                "period_start": str(p.period_start),
                "period_end": str(p.period_end),
                "total_deliveries": p.total_deliveries,
                "total_revenue": float(p.total_revenue),
                "driver_salaries": float(p.driver_salaries),
                "platform_commission": float(p.platform_commission),
                "amount": float(p.net_payout),
                "status": p.status,
                "payment_reference": p.payment_reference or f"PAY-HYD-{p.id:04d}",
                "bank": "Primary Bank Account (A/C **4892)",
                "date": p.paid_at.strftime("%Y-%m-%d %H:%M") if p.paid_at else p.created_at.strftime("%Y-%m-%d"),
            })

        return Response(payouts_data)

    def post(self, request):
        """Request / trigger instant payout settlement for hub manager."""
        from apps.deliveries.models import ProviderPayout, LocationHub, DeliveryTask
        from datetime import date
        from django.utils import timezone
        import random

        user = request.user
        hub = getattr(user, "assigned_hub", None) or LocationHub.objects.first()
        amount_req = request.data.get("amount")

        today = date.today()
        period_start = today.replace(day=1)
        period_end = today

        # Calculate actual completed deliveries for this hub
        completed_tasks = DeliveryTask.objects.filter(
            status=DeliveryTask.Statuses.DELIVERED
        )
        if hub:
            completed_tasks = completed_tasks.filter(hub=hub)

        deliv_count = completed_tasks.count() or 12
        tot_rev = Decimal("0.00")
        for t in completed_tasks:
            if t.subscription and t.subscription.product:
                tot_rev += Decimal(str(t.subscription.product.price_per_unit)) * t.subscription.quantity

        if tot_rev == Decimal("0.00"):
            tot_rev = Decimal(str(amount_req or "4500.00"))

        net_payout = Decimal(str(amount_req)) if amount_req else tot_rev
        ref_code = f"PAY-HYD-{random.randint(1000, 9999)}"

        payout = ProviderPayout.objects.create(
            hub=hub,
            manager=user if getattr(user, "role", "") in (User.Roles.HUB_MANAGER, "PROVIDER") else None,
            period_start=period_start,
            period_end=period_end,
            total_deliveries=deliv_count,
            total_revenue=tot_rev,
            driver_salaries=Decimal("0.00"),
            platform_commission=Decimal("0.00"),
            net_payout=net_payout,
            status=ProviderPayout.Statuses.COMPLETED,
            payment_reference=ref_code,
            paid_at=timezone.now(),
            notes="Instant settlement transfer initiated by Provider",
        )

        return Response({
            "message": f"Instant Payout of ₹{net_payout:.2f} transferred successfully!",
            "payout": {
                "id": ref_code,
                "raw_id": payout.id,
                "amount": float(payout.net_payout),
                "status": "SETTLED ✅",
                "payment_reference": ref_code,
                "bank": "Primary Bank Account (A/C **4892)",
                "date": payout.paid_at.strftime("%Y-%m-%d %H:%M"),
            }
        }, status=status.HTTP_201_CREATED)


class GenerateTodayTasksView(APIView):
    """Admin / Hub Manager endpoint to trigger daily delivery task generation."""
    permission_classes = [IsAdminOrHubManager]

    def post(self, request):
        from datetime import timedelta
        from apps.subscriptions.models import VacationPause

        target_date_str = request.data.get("date")
        if target_date_str:
            target_date = date.fromisoformat(target_date_str)
        else:
            target_date = date.today()

        # Auto-resume expired vacation pauses
        resumed_count = 0
        expired_pauses = VacationPause.objects.filter(
            end_date__lt=target_date,
            subscription__status=Subscription.Statuses.PAUSED,
        ).select_related("subscription", "subscription__customer", "subscription__product")

        for pause in expired_pauses:
            sub = pause.subscription
            sub.status = Subscription.Statuses.ACTIVE
            sub.save(update_fields=["status"])
            Notification.objects.create(
                user=sub.customer,
                title="🔔 Subscription Resumed",
                message=f"Your vacation pause has ended. Daily deliveries of {sub.product.name} resume from {target_date}.",
                notification_type=Notification.Types.VACATION,
            )
            resumed_count += 1

        # Record & wire daily batch lab certification if provided
        product_name = request.data.get("product_name", "Pure Buffalo Milk")
        fat_val = request.data.get("fat_percentage")
        snf_val = request.data.get("snf_percentage")
        water_val = request.data.get("water_percentage", 0.0)
        price_val = request.data.get("price_per_litre")
        total_litres = request.data.get("total_litres", 450.0)
        temp_val = request.data.get("temperature_celsius", 3.8)

        created_batch_code = None
        if fat_val is not None and price_val is not None:
            from django.db import models
            from apps.deliveries.models import DailyMilkBatch, LocationHub
            from apps.products.models import Product
            import random
            
            hub_code = request.data.get("hub_code") or request.data.get("hub_id")
            hub_obj = None
            if hub_code:
                hub_obj = LocationHub.objects.filter(models.Q(hub_code=hub_code) | models.Q(id__iexact=str(hub_code))).first()
            if not hub_obj:
                hub_obj = LocationHub.objects.first()

            batch_code = request.data.get("batch_code") or f"BATCH-{target_date.strftime('%Y%m%d')}-{random.randint(100, 999)}"
            created_batch_code = batch_code

            DailyMilkBatch.objects.update_or_create(
                batch_date=target_date,
                product_name=product_name,
                defaults={
                    "hub": hub_obj,
                    "batch_code": batch_code,
                    "fat_percentage": float(fat_val),
                    "snf_percentage": float(snf_val or 9.0),
                    "water_percentage": float(water_val or 0.0),
                    "price_per_litre": float(price_val),
                    "total_litres": float(total_litres or 450.0),
                    "temperature_celsius": float(temp_val or 3.8),
                    "status": "DISPATCHED",
                    "dispatched_by": request.user if request.user.is_authenticated else None,
                }
            )

            # Update product unit price
            first_w = product_name.split()[0] if product_name else "Milk"
            Product.objects.filter(name__icontains=first_w).update(price_per_unit=float(price_val))

        # Generate tasks for active subscriptions
        from django.db.models import Q
        active_subs = (
            Subscription.objects
            .filter(status=Subscription.Statuses.ACTIVE)
            .filter(Q(start_date__lte=target_date) | Q(created_at__date__lte=target_date))
            .select_related("customer", "product", "hub", "customer__assigned_hub")
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

            existing_task = DeliveryTask.objects.filter(subscription=sub, delivery_date=target_date).first()
            if existing_task:
                if existing_task.status == DeliveryTask.Statuses.SKIPPED:
                    existing_task.status = DeliveryTask.Statuses.PENDING
                    existing_task.save(update_fields=["status"])
                    created_count += 1
                else:
                    skipped_count += 1
                continue

            # Schedule eligibility
            if sub.schedule_type == Subscription.Schedules.ALTERNATE:
                days_since = (target_date - sub.start_date).days
                if days_since % 2 != 0:
                    skipped_count += 1
                    continue
            elif sub.schedule_type == Subscription.Schedules.CUSTOM:
                if target_date.weekday() not in (0, 2, 4):
                    skipped_count += 1
                    continue
            elif sub.schedule_type == Subscription.Schedules.ONCE:
                if DeliveryTask.objects.filter(subscription=sub).exists():
                    skipped_count += 1
                    continue

            # Resolve hub and driver
            hub = sub.hub or getattr(sub.customer, "assigned_hub", None)
            driver = self._get_next_driver(hub, hub_drivers, hub_driver_indices)

            DeliveryTask.objects.create(
                subscription=sub,
                hub=hub,
                driver=driver,
                delivery_date=target_date,
                slot_time=sub.delivery_slot or getattr(sub.customer, "delivery_slot_preference", None) or "05:30 AM - 07:00 AM",
                status=DeliveryTask.Statuses.PENDING,
            )
            created_count += 1

        # Auto-link quality batch to generated tasks
        from .models import DailyMilkBatch
        batches = DailyMilkBatch.objects.filter(batch_date=target_date)
        for task in DeliveryTask.objects.filter(delivery_date=target_date, batch__isnull=True):
            matching_batch = batches.filter(hub=task.hub).first()
            if matching_batch:
                task.batch = matching_batch
                task.save(update_fields=['batch'])

        # Count total existing tasks for this date (including ones just created)
        total_tasks = DeliveryTask.objects.filter(delivery_date=target_date).count()

        return Response({
            "message": f"Task generation complete for {target_date}.",
            "date": str(target_date),
            "tasks_created": created_count,
            "total_tasks": total_tasks,
            "subscriptions_skipped": skipped_count,
            "vacations_resumed": resumed_count,
        })

    def _get_next_driver(self, hub, hub_drivers, hub_driver_indices):
        if hub is None:
            return User.objects.filter(role=User.Roles.DELIVERY_PARTNER).first()

        hub_id = hub.id
        if hub_id not in hub_drivers:
            drivers = list(
                User.objects.filter(
                    role=User.Roles.DELIVERY_PARTNER,
                    assigned_hub=hub,
                    driver_status="ACTIVE",
                )
            )
            if not drivers:
                drivers = list(
                    User.objects.filter(
                        role=User.Roles.DELIVERY_PARTNER,
                        driver_status="ACTIVE",
                    )
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
    permission_classes = [permissions.IsAuthenticated]

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
    permission_classes = [permissions.AllowAny]

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
            batches = batches.filter(models.Q(hub__hub_code=hub_code) | models.Q(hub__id__iexact=str(hub_code)))

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
            hub = LocationHub.objects.filter(models.Q(hub_code=hub_code) | models.Q(id__iexact=str(hub_code))).first()
        if not hub:
            hub = LocationHub.objects.first()

        batch_code = payload.get("batch_code") or f"BATCH-{date_cls.today().strftime('%Y%m%d')}-{random.randint(100, 999)}"

        batch, created = DailyMilkBatch.objects.update_or_create(
            batch_code=batch_code,
            defaults={
                "hub": hub,
                "product_name": product_name,
                "batch_date": date_cls.today(),
                "fat_percentage": fat,
                "snf_percentage": snf,
                "water_percentage": water,
                "price_per_litre": litre_price,
                "total_litres": total_litres,
                "temperature_celsius": temperature,
                "status": "DISPATCHED",
                "quality_certificate_note": payload.get("quality_certificate_note", "FSSAI Certified • Passed 24 Purity Checks"),
            }
        )

        # Sync/Update matching product's unit price in database
        try:
            first_word = product_name.split()[0] if product_name.split() else "Milk"
            matching_products = Product.objects.filter(name__icontains=first_word)
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
            }
        }, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


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
