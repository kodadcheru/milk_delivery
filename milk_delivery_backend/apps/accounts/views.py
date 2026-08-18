from decimal import Decimal
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import Notification, User, WalletTransaction
from apps.accounts.serializers import (
    NotificationSerializer,
    RegisterSerializer,
    UserSerializer,
    WalletTopUpSerializer,
    WalletTransactionSerializer,
)


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]


class UserProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user


class WalletBalanceView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response(
            {
                "wallet_balance": str(request.user.wallet_balance),
                "currency": "INR",
            }
        )


class WalletTopUpView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = WalletTopUpSerializer(data=request.data)
        if serializer.is_valid():
            amount = serializer.validated_data["amount"]
            desc = serializer.validated_data["description"]

            user = request.user
            user.wallet_balance += amount
            user.save()

            tx = WalletTransaction.objects.create(
                user=user,
                amount=amount,
                transaction_type=WalletTransaction.Types.CREDIT,
                description=desc,
            )

            # Auto-generate Notification for Wallet Top Up
            Notification.objects.create(
                user=user,
                title="⚡ Wallet Recharged",
                message=f"₹{amount} credited to your prepaid wallet via {desc}. New balance: ₹{user.wallet_balance}",
                notification_type=Notification.Types.WALLET,
            )

            return Response(
                {
                    "message": "Top-up successful",
                    "new_balance": str(user.wallet_balance),
                    "transaction": WalletTransactionSerializer(tx).data,
                },
                status=status.HTTP_200_OK,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class WalletTransactionListView(generics.ListAPIView):
    serializer_class = WalletTransactionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return WalletTransaction.objects.filter(user=self.request.user)


class NotificationListView(generics.ListAPIView):
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user)


class NotificationMarkReadView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk=None):
        if pk:
            try:
                notif = Notification.objects.get(pk=pk, user=request.user)
                notif.is_read = True
                notif.save()
                return Response({"message": "Marked as read"})
            except Notification.DoesNotExist:
                return Response({"detail": "Notification not found"}, status=status.HTTP_404_NOT_FOUND)
        else:
            Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
            return Response({"message": "All notifications marked as read"})
