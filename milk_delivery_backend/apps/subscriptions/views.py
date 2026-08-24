from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from apps.subscriptions.models import Subscription, VacationPause
from apps.subscriptions.serializers import SubscriptionSerializer, VacationPauseSerializer


class SubscriptionListCreateView(generics.ListCreateAPIView):
    serializer_class = SubscriptionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        from apps.accounts.models import User
        user = self.request.user
        customer_id = self.request.query_params.get("customer_id")
        phone = self.request.query_params.get("phone")

        qs = Subscription.objects.all().select_related("customer", "product", "hub", "product__category_ref").order_by("-created_at")

        if user and user.is_authenticated:
            if getattr(user, "role", "") == User.Roles.CUSTOMER:
                return qs.filter(customer=user)
            elif getattr(user, "role", "") in (User.Roles.ADMIN, "ADMIN"):
                return qs
            elif getattr(user, "role", "") in (User.Roles.HUB_MANAGER, "PROVIDER"):
                if getattr(user, "assigned_hub", None):
                    return qs.filter(hub=user.assigned_hub)
                return qs
            elif getattr(user, "role", "") in (User.Roles.DELIVERY_PARTNER, "DRIVER"):
                if getattr(user, "assigned_hub", None):
                    return qs.filter(hub=user.assigned_hub)
                return qs.none()

        if customer_id:
            return qs.filter(customer_id=customer_id)
        if phone:
            digits = "".join(filter(str.isdigit, str(phone)))
            if digits:
                return qs.filter(customer__phone__endswith=digits[-10:])

        return qs

    def perform_create(self, serializer):
        from apps.accounts.models import User
        from apps.deliveries.models import LocationHub, DeliveryTask
        from apps.deliveries.hub_resolver import find_hub_for_location
        from datetime import date

        user = self.request.user
        if not user or not user.is_authenticated:
            from rest_framework.exceptions import NotAuthenticated
            raise NotAuthenticated("Authentication required")

        deliv_addr = self.request.data.get("delivery_address") or getattr(user, "address", None) or ""
        deliv_slot = self.request.data.get("delivery_slot") or getattr(user, "delivery_slot_preference", None) or "05:30 AM - 07:00 AM"
        deliv_lat = self.request.data.get("delivery_latitude") or getattr(user, "latitude", None)
        deliv_lon = self.request.data.get("delivery_longitude") or getattr(user, "longitude", None)
        deliv_inst = self.request.data.get("delivery_instructions") or getattr(user, "delivery_instructions", None) or ""
        pack_size = self.request.data.get("pack_size") or "1 Litre"
        pincode = self.request.data.get("pincode") or ""

        # Auto-resolve hub: match against location
        hub = find_hub_for_location(
            pincode=pincode,
            latitude=deliv_lat,
            longitude=deliv_lon,
            address=deliv_addr,
            strict=True,
        )
        if not hub:
            hub = getattr(user, "assigned_hub", None)

        # Strict Geo-Fence Validation
        if hub and deliv_lat is not None and deliv_lon is not None:
            from apps.deliveries.hub_resolver import _haversine_km
            try:
                dist = _haversine_km(float(deliv_lat), float(deliv_lon), float(hub.latitude), float(hub.longitude))
                if dist > hub.coverage_radius_km:
                    from rest_framework.exceptions import ValidationError
                    raise ValidationError(
                        f"Delivery address is outside the operational service zone of {hub.name} "
                        f"({dist:.1f} km away, max coverage radius is {hub.coverage_radius_km} km). "
                        f"Please choose an address within the Kodad service area."
                    )
            except (ValueError, TypeError):
                pass

        if not hub:
            from rest_framework.exceptions import ValidationError
            raise ValidationError("Delivery location is outside our operational service area. No active hub covers this location.")

        if hub and hasattr(user, "assigned_hub") and user.assigned_hub != hub:
            user.assigned_hub = hub
            user.save(update_fields=["assigned_hub"])

        from apps.deliveries.models import DeliverySlot
        slot_config = DeliverySlot.objects.filter(hub=hub, name=deliv_slot, is_active=True).first()
        if slot_config:
            from datetime import date as date_cls
            check_date = date_cls.today()
            if slot_config.is_full(check_date):
                from rest_framework.exceptions import ValidationError
                raise ValidationError(
                    {"error": f"The '{deliv_slot}' slot is full. Max {slot_config.max_orders} orders per slot. Please choose another time."}
                )

        # Capacity slot enforcement check for hub & product
        prod_obj = serializer.validated_data.get("product")
        req_qty = serializer.validated_data.get("quantity", 1)
        
        # Calculate effective unit price based on pack_size
        base_price = float(prod_obj.price_per_unit)
        pack_size_val = self.request.data.get('pack_size', '1 Litre') or '1 Litre'
        if '500' in pack_size_val.lower():
            effective_price = round(base_price * 0.55, 2)
            volume_multiplier = 0.5
        elif '2' in pack_size_val.lower() and ('litre' in pack_size_val.lower() or 'liter' in pack_size_val.lower() or 'kg' in pack_size_val.lower()):
            effective_price = round(base_price * 1.95, 2)
            volume_multiplier = 2
        else:
            effective_price = base_price
            volume_multiplier = 1

        if hub:
            from apps.products.models import HubProductInventory
            inv, _ = HubProductInventory.objects.get_or_create(
                hub=hub,
                product=prod_obj,
                defaults={"daily_capacity_slots": 100, "booked_slots": 0, "is_available": True},
            )
            if not inv.is_available or inv.available_slots < req_qty:
                from rest_framework.exceptions import ValidationError
                raise ValidationError(
                    f"Hub daily capacity limit reached for {prod_obj.name}. "
                    f"Only {inv.available_slots} slot(s) available at {hub.name}."
                )
            inv.booked_slots += int(req_qty * volume_multiplier)
            inv.save(update_fields=["booked_slots"])

        sub = serializer.save(
            customer=user,
            hub=hub,
            delivery_address=deliv_addr or "Doorstep Delivery",
            delivery_slot=deliv_slot,
            delivery_latitude=deliv_lat or 16.9950,
            delivery_longitude=deliv_lon or 79.9670,
            delivery_instructions=deliv_inst,
            pack_size=pack_size_val,
            effective_unit_price=effective_price,
            status=Subscription.Statuses.ACTIVE,
        )

        # Auto-create initial DeliveryTask so customer & driver immediately see morning delivery
        try:
            hub_driver = User.objects.filter(
                role__in=[User.Roles.DELIVERY_PARTNER, "DRIVER"],
                assigned_hub=hub,
            ).first() or User.objects.filter(
                role__in=[User.Roles.DELIVERY_PARTNER, "DRIVER"]
            ).first()

            DeliveryTask.objects.get_or_create(
                subscription=sub,
                delivery_date=date.today(),
                defaults={
                    "hub": hub,
                    "driver": hub_driver,
                    "slot_time": deliv_slot,
                    "status": DeliveryTask.Statuses.PENDING,
                }
            )
        except Exception:
            pass

        # Broadcast real-time Redis event to Hub and Driver portals
        try:
            from apps.core.consumers import broadcast_hub_event
            hub_code = getattr(hub, "hub_code", "HUB-KDD-01") if hub else "HUB-KDD-01"
            broadcast_hub_event(hub_code, "subscription_created", {
                "subscription_id": sub.id,
                "customer": user.username,
                "product": prod_obj.name if 'prod_obj' in locals() and prod_obj else "Milk",
                "slot": deliv_slot,
            })
        except Exception:
            pass


class SubscriptionDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = SubscriptionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        from apps.accounts.models import User
        user = self.request.user
        if not user or not user.is_authenticated:
            return Subscription.objects.none()
        if user.is_superuser:
            return Subscription.objects.all()
        if getattr(user, "assigned_hub", None):
            return Subscription.objects.filter(hub=user.assigned_hub)
        if user.is_staff or getattr(user, "role", "") in (User.Roles.ADMIN, "ADMIN"):
            return Subscription.objects.all()
        return Subscription.objects.filter(customer=user)

    def perform_update(self, serializer):
        from apps.deliveries.models import DeliveryTask
        from datetime import date, timedelta
        prev_status = serializer.instance.status
        instance = serializer.save()
        if prev_status == Subscription.Statuses.CANCELLED and instance.status == Subscription.Statuses.ACTIVE:
            tomorrow = date.today() + timedelta(days=1)
            if not DeliveryTask.objects.filter(subscription=instance, delivery_date=tomorrow).exists():
                DeliveryTask.objects.create(
                    subscription=instance,
                    hub=instance.hub,
                    delivery_date=tomorrow,
                    slot_time=instance.delivery_slot or '06:00 AM',
                    status=DeliveryTask.Statuses.PENDING,
                )

    def perform_destroy(self, instance):
        from apps.deliveries.models import DeliveryTask

        # Soft-cancel the subscription to preserve past delivery and financial audit history
        instance.status = Subscription.Statuses.CANCELLED
        instance.save(update_fields=["status"])

        # Only cancel future PENDING delivery tasks; keep all past DELIVERED tasks intact
        DeliveryTask.objects.filter(
            subscription=instance,
            status=DeliveryTask.Statuses.PENDING,
        ).update(status=DeliveryTask.Statuses.SKIPPED)


class SubscriptionPauseView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        from apps.accounts.models import User
        from apps.deliveries.models import DeliveryTask

        sub = Subscription.objects.filter(pk=pk).first()
        if not sub:
            return Response({"detail": "Subscription not found"}, status=status.HTTP_404_NOT_FOUND)

        is_allowed = (
            sub.customer == request.user
            or request.user.is_staff
            or getattr(request.user, "role", "") in (User.Roles.ADMIN, User.Roles.HUB_MANAGER, "PROVIDER", "ADMIN")
        )
        if not is_allowed:
            return Response({"detail": "Permission denied for pausing subscription."}, status=status.HTTP_403_FORBIDDEN)

        start_date = request.data.get("start_date")
        end_date = request.data.get("end_date")
        reason = request.data.get("reason", "Vacation")

        if not start_date or not end_date:
            return Response({"detail": "start_date and end_date are required"}, status=status.HTTP_400_BAD_REQUEST)

        if str(end_date) < str(start_date):
            return Response({"detail": "end_date cannot be earlier than start_date"}, status=status.HTTP_400_BAD_REQUEST)

        pause = VacationPause.objects.create(
            subscription=sub,
            start_date=start_date,
            end_date=end_date,
            reason=reason,
        )
        sub.status = Subscription.Statuses.PAUSED
        sub.save()

        # Update pending delivery tasks within pause window to SKIPPED
        DeliveryTask.objects.filter(
            subscription=sub,
            delivery_date__gte=start_date,
            delivery_date__lte=end_date,
            status=DeliveryTask.Statuses.PENDING,
        ).update(status=DeliveryTask.Statuses.SKIPPED)

        # Notify hub manager about the pause
        hub = sub.hub
        if hub and hub.manager_phone:
            from apps.accounts.models import Notification, User
            hub_manager = User.objects.filter(phone__endswith=hub.manager_phone[-10:]).first()
            if hub_manager:
                Notification.objects.create(
                    user=hub_manager,
                    title="⏸️ Subscription Paused",
                    message=f"{sub.customer.first_name} {sub.customer.last_name} paused their "
                            f"{sub.product.name if sub.product else 'subscription'} from {start_date} to {end_date}. "
                            f"Reason: {reason}",
                    notification_type=Notification.Types.VACATION,
                )

        return Response(
            {
                "message": "Vacation pause created and subscription paused.",
                "pause": VacationPauseSerializer(pause).data,
                "subscription": SubscriptionSerializer(sub).data,
            },
            status=status.HTTP_201_CREATED,
        )


class SubscriptionResumeView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        from apps.accounts.models import User
        from apps.deliveries.models import DeliveryTask
        from datetime import date

        sub = Subscription.objects.filter(pk=pk).first()
        if not sub:
            return Response({"detail": "Subscription not found"}, status=status.HTTP_404_NOT_FOUND)

        is_allowed = (
            sub.customer == request.user
            or request.user.is_staff
            or getattr(request.user, "role", "") in (User.Roles.ADMIN, User.Roles.HUB_MANAGER, "PROVIDER", "ADMIN")
        )
        if not is_allowed:
            return Response({"detail": "Permission denied for resuming subscription."}, status=status.HTTP_403_FORBIDDEN)

        sub.status = Subscription.Statuses.ACTIVE
        sub.save()

        # Resume skipped tasks for today or in the future back to PENDING
        DeliveryTask.objects.filter(
            subscription=sub,
            delivery_date__gte=date.today(),
            status=DeliveryTask.Statuses.SKIPPED,
        ).update(status=DeliveryTask.Statuses.PENDING)

        return Response(
            {
                "message": "Subscription resumed to active status.",
                "subscription": SubscriptionSerializer(sub).data,
            },
            status=status.HTTP_200_OK,
        )
