from datetime import date
from decimal import Decimal
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import WalletTransaction
from apps.deliveries.models import DeliveryTask
from apps.deliveries.serializers import DeliveryTaskSerializer


class DeliveryTaskListView(generics.ListAPIView):
    serializer_class = DeliveryTaskSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        req_date = self.request.query_params.get("date", date.today().isoformat())

        qs = DeliveryTask.objects.filter(delivery_date=req_date)
        if user.role == "CUSTOMER":
            return qs.filter(subscription__customer=user)
        elif user.role == "DRIVER":
            # Return driver assigned tasks or unassigned
            return qs
        return qs


class DeliveryTaskCompleteView(APIView):
    permission_classes = [permissions.IsAuthenticated]

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

        # Deduct wallet balance for customer
        sub = task.subscription
        customer = sub.customer
        total_cost = sub.product.price_per_unit * sub.quantity

        customer.wallet_balance -= total_cost
        customer.save()

        WalletTransaction.objects.create(
            user=customer,
            amount=total_cost,
            transaction_type=WalletTransaction.Types.DEBIT,
            description=f"Daily Delivery #{task.id}: {sub.quantity}x {sub.product.name}",
        )

        from apps.accounts.models import Notification

        Notification.objects.create(
            user=customer,
            title="🥛 Morning Delivery Complete!",
            message=f"Your {sub.quantity}x {sub.product.name} was delivered at doorstep. Photo proof attached. ₹{total_cost} debited from wallet.",
            notification_type=Notification.Types.DELIVERY,
        )

        if customer.wallet_balance < Decimal("150.00"):
            Notification.objects.create(
                user=customer,
                title="⚠️ Low Wallet Balance Warning",
                message=f"Your wallet balance is ₹{customer.wallet_balance}. Top up now to avoid delivery interruptions tomorrow!",
                notification_type=Notification.Types.WALLET,
            )

        return Response(
            {
                "message": "Delivery completed successfully and customer wallet debited.",
                "task": DeliveryTaskSerializer(task).data,
                "remaining_balance": str(customer.wallet_balance),
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
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        """Admin / Operations summary of today's total milk demand."""
        today = date.today().isoformat()
        tasks = DeliveryTask.objects.filter(delivery_date=today)

        total_deliveries = tasks.count()
        completed = tasks.filter(status=DeliveryTask.Statuses.DELIVERED).count()
        pending = tasks.filter(status=DeliveryTask.Statuses.PENDING).count()

        product_demand = {}
        for t in tasks:
            p_name = t.subscription.product.name
            product_demand[p_name] = product_demand.get(p_name, 0) + t.subscription.quantity

        return Response(
            {
                "date": today,
                "total_deliveries": total_deliveries,
                "completed": completed,
                "pending": pending,
                "product_demand": product_demand,
            }
        )
