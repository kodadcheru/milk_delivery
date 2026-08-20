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

        qs = Subscription.objects.all().select_related("customer", "product", "hub")

        if user and user.is_authenticated:
            if getattr(user, "role", "") == User.Roles.CUSTOMER:
                return qs.filter(customer=user)
            elif getattr(user, "role", "") == User.Roles.ADMIN:
                return qs

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
            )
            # Persist hub assignment on the customer for future subscriptions
            if hub and hasattr(user, "assigned_hub"):
                user.assigned_hub = hub
                user.save(update_fields=["assigned_hub"])

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

        # Only create immediate task if subscription starts today or earlier
        # Future subscriptions will be handled by generate_daily_tasks command
        if sub.start_date <= date.today():
            driver = hub.delivery_partners.first() if hub else None
            DeliveryTask.objects.get_or_create(
                subscription=sub,
                delivery_date=date.today(),
                defaults={
                    "hub": hub,
                    "driver": driver,
                    "slot_time": deliv_slot,
                    "status": DeliveryTask.Statuses.PENDING,
                },
            )


class SubscriptionDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = SubscriptionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        if self.request.user.is_staff:
            return Subscription.objects.all()
        return Subscription.objects.filter(customer=self.request.user)


class SubscriptionPauseView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        sub = Subscription.objects.filter(pk=pk).first()
        if not sub:
            return Response({"detail": "Subscription not found"}, status=status.HTTP_404_NOT_FOUND)

        if sub.customer != request.user and not request.user.is_staff:
            return Response({"detail": "You can only pause your own subscriptions."}, status=status.HTTP_403_FORBIDDEN)

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
        sub = Subscription.objects.filter(pk=pk).first()
        if not sub:
            return Response({"detail": "Subscription not found"}, status=status.HTTP_404_NOT_FOUND)

        if sub.customer != request.user and not request.user.is_staff:
            return Response({"detail": "You can only resume your own subscriptions."}, status=status.HTTP_403_FORBIDDEN)

        sub.status = Subscription.Statuses.ACTIVE
        sub.save()

        return Response(
            {
                "message": "Subscription resumed to active status.",
                "subscription": SubscriptionSerializer(sub).data,
            },
            status=status.HTTP_200_OK,
        )
