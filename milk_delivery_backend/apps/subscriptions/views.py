from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from apps.subscriptions.models import Subscription, VacationPause
from apps.subscriptions.serializers import SubscriptionSerializer, VacationPauseSerializer


class SubscriptionListCreateView(generics.ListCreateAPIView):
    serializer_class = SubscriptionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == "ADMIN":
            return Subscription.objects.all()
        return Subscription.objects.filter(customer=user)

    def perform_create(self, serializer):
        user = self.request.user
        hub = user.assigned_hub
        if not hub:
            from apps.deliveries.models import LocationHub
            hub = LocationHub.objects.first()
            
        deliv_addr = self.request.data.get("delivery_address") or user.address or "Doorstep Drop"
        deliv_slot = self.request.data.get("delivery_slot") or user.delivery_slot_preference or "05:30 AM - 07:00 AM"
        deliv_lat = self.request.data.get("delivery_latitude") or user.latitude or 17.4319
        deliv_lon = self.request.data.get("delivery_longitude") or user.longitude or 78.4073
        deliv_inst = self.request.data.get("delivery_instructions") or user.delivery_instructions or ""
        pack_size = self.request.data.get("pack_size") or "1 Litre"

        sub = serializer.save(
            customer=user,
            hub=hub,
            delivery_address=deliv_addr,
            delivery_slot=deliv_slot,
            delivery_latitude=deliv_lat,
            delivery_longitude=deliv_lon,
            delivery_instructions=deliv_inst,
            pack_size=pack_size,
        )

        from datetime import date
        from apps.deliveries.models import DeliveryTask
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
        user = self.request.user
        if user.role == "ADMIN":
            return Subscription.objects.all()
        return Subscription.objects.filter(customer=user)


class SubscriptionPauseView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            sub = Subscription.objects.get(pk=pk, customer=request.user)
        except Subscription.DoesNotExist:
            return Response({"detail": "Subscription not found"}, status=status.HTTP_404_NOT_FOUND)

        start_date = request.data.get("start_date")
        end_date = request.data.get("end_date")
        reason = request.data.get("reason", "Vacation")

        if not start_date or not end_date:
            return Response({"detail": "start_date and end_date are required"}, status=status.HTTP_400_BAD_REQUEST)

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
        try:
            sub = Subscription.objects.get(pk=pk, customer=request.user)
        except Subscription.DoesNotExist:
            return Response({"detail": "Subscription not found"}, status=status.HTTP_404_NOT_FOUND)

        sub.status = Subscription.Statuses.ACTIVE
        sub.save()

        return Response(
            {
                "message": "Subscription resumed to active status.",
                "subscription": SubscriptionSerializer(sub).data,
            },
            status=status.HTTP_200_OK,
        )
