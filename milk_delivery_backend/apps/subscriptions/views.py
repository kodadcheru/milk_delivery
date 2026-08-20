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
            elif getattr(user, "role", "") in (User.Roles.HUB_MANAGER, "PROVIDER") and getattr(user, "assigned_hub", None):
                return qs.filter(hub=user.assigned_hub)

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

        # Auto-resolve hub: use customer's existing hub, or find the best one
        hub = getattr(user, "assigned_hub", None)
        if not hub:
            hub = find_hub_for_location(
                pincode=pincode,
                latitude=deliv_lat,
                longitude=deliv_lon,
                address=deliv_addr,
                strict=True,
            )
            # If strict matching failed, try general resolution before rejecting
            if not hub:
                hub = find_hub_for_location(
                    pincode=pincode,
                    latitude=deliv_lat,
                    longitude=deliv_lon,
                    address=deliv_addr,
                )
            if hub and hasattr(user, "assigned_hub"):
                user.assigned_hub = hub
                user.save(update_fields=["assigned_hub"])

        # Capacity slot enforcement check for hub & product
        if hub:
            from apps.products.models import HubProductInventory
            prod_obj = serializer.validated_data.get("product")
            req_qty = serializer.validated_data.get("quantity", 1)
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
            inv.booked_slots += req_qty
            inv.save(update_fields=["booked_slots"])

        sub = serializer.save(
            customer=user,
            hub=hub,
            delivery_address=deliv_addr or "Doorstep Delivery",
            delivery_slot=deliv_slot,
            delivery_latitude=deliv_lat or 16.9950,
            delivery_longitude=deliv_lon or 79.9670,
            delivery_instructions=deliv_inst,
            pack_size=pack_size,
            status=Subscription.Statuses.ACTIVE,
        )

        # Delivery tasks are NOT auto-created here.
        # Hub manager triggers task generation via "Generate Today's Delivery Tasks" button
        # which calls POST /api/admin/generate-tasks/


class SubscriptionDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = SubscriptionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        from apps.accounts.models import User
        user = self.request.user
        if not user or not user.is_authenticated:
            return Subscription.objects.none()
        if user.is_staff or getattr(user, "role", "") in (User.Roles.ADMIN, "ADMIN"):
            return Subscription.objects.all()
        if getattr(user, "role", "") in (User.Roles.HUB_MANAGER, "PROVIDER") and getattr(user, "assigned_hub", None):
            return Subscription.objects.filter(hub=user.assigned_hub)
        return Subscription.objects.filter(customer=user)


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
        if hub:
            from apps.accounts.models import Notification
            hub_manager = hub.manager
            if hub_manager:
                Notification.objects.create(
                    user=hub_manager,
                    title="⏸️ Subscription Paused",
                    message=f"{sub.customer.first_name} {sub.customer.last_name} paused their "
                            f"{sub.product.name if sub.product else 'subscription'} from {start_date} to {end_date}. "
                            f"Reason: {reason}",
                    notif_type=Notification.Types.VACATION,
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
