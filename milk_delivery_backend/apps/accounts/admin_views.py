from decimal import Decimal
from django.shortcuts import render
from django.utils import timezone
from django.views import View
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import Notification, User, WalletTransaction
from apps.accounts.serializers import UserSerializer, WalletTransactionSerializer
from apps.deliveries.models import DeliveryTask
from apps.deliveries.serializers import DeliveryTaskSerializer
from apps.products.models import Product
from apps.products.serializers import ProductSerializer
from apps.subscriptions.models import Subscription, VacationPause
from apps.subscriptions.serializers import SubscriptionSerializer


class AdminConsoleHTMLView(View):
    def get(self, request):
        return render(request, "admin_console.html")


class AdminCustomerListView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        customers = User.objects.filter(role=User.Roles.CUSTOMER)
        return Response(UserSerializer(customers, many=True).data)


class AdminCreditWalletView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        user_id = request.data.get("user_id")
        amount_str = request.data.get("amount", "100.00")
        desc = request.data.get("description", "Admin Manual Wallet Bonus")

        try:
            amount = Decimal(str(amount_str))
            user = User.objects.get(pk=user_id)
        except (User.DoesNotExist, Exception) as e:
            return Response({"detail": f"User not found or invalid amount: {e}"}, status=status.HTTP_400_BAD_REQUEST)

        user.wallet_balance += amount
        user.save()

        tx = WalletTransaction.objects.create(
            user=user,
            amount=amount,
            transaction_type=WalletTransaction.Types.CREDIT,
            description=f"🎁 {desc}",
        )

        Notification.objects.create(
            user=user,
            title="🎁 Wallet Credit Adjustment",
            message=f"₹{amount} credited to your wallet by Admin. Reason: {desc}. New Balance: ₹{user.wallet_balance}",
            notification_type=Notification.Types.WALLET,
        )

        return Response(
            {
                "message": f"Successfully credited ₹{amount} to {user.username}'s wallet",
                "new_balance": str(user.wallet_balance),
                "transaction": WalletTransactionSerializer(tx).data,
            },
            status=status.HTTP_200_OK,
        )


class AdminBroadcastNotificationView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        title = request.data.get("title", "MilkDrop Announcement")
        message = request.data.get("message", "Important update regarding morning deliveries.")
        target_role = request.data.get("target_role", "ALL")

        users = User.objects.all()
        if target_role == "CUSTOMER":
            users = users.filter(role=User.Roles.CUSTOMER)
        elif target_role == "DRIVER":
            users = users.filter(role=User.Roles.DELIVERY_PARTNER)

        created_count = 0
        for u in users:
            Notification.objects.create(
                user=u,
                title=title,
                message=message,
                notification_type=Notification.Types.OFFER,
            )
            created_count += 1

        return Response(
            {
                "message": f"Broadcast sent successfully to {created_count} user(s).",
                "count": created_count,
            },
            status=status.HTTP_200_OK,
        )


class AdminHubsView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        hubs = [
            {
                "id": "HUB-HYD-01",
                "name": "Jubilee Hills Central Depot #1",
                "address": "Plot 42, Road #36, Jubilee Hills, Hyderabad",
                "manager": "Rajesh Varma (+91 98888 77777)",
                "subscribers_count": 128,
                "daily_volume_liters": 310.0,
                "active_delivery_boys": 4,
                "salary_per_boy": 15000,
                "status": "OPERATIONAL",
                "fssai_license": "13621014000342",
            },
            {
                "id": "HUB-HYD-02",
                "name": "Banjara Hills Micro-Depot #2",
                "address": "Road #12, Banjara Hills, Hyderabad",
                "manager": "Kavitha Reddy (+91 98765 43211)",
                "subscribers_count": 94,
                "daily_volume_liters": 225.0,
                "active_delivery_boys": 3,
                "salary_per_boy": 15000,
                "status": "OPERATIONAL",
                "fssai_license": "13621014000889",
            },
            {
                "id": "HUB-HYD-03",
                "name": "Madhapur Tech Enclave Depot #3",
                "address": "Hitec City Main Road, Madhapur, Hyderabad",
                "manager": "Sanjay Rao (+91 97654 32100)",
                "subscribers_count": 160,
                "daily_volume_liters": 390.0,
                "active_delivery_boys": 5,
                "salary_per_boy": 15000,
                "status": "OPERATIONAL",
                "fssai_license": "13621014000912",
            },
        ]
        return Response(hubs)


class AdminSubscriptionsListView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        subs = Subscription.objects.all().select_related("customer", "product")
        data = []
        for s in subs:
            data.append({
                "id": s.id,
                "customer_name": f"{s.customer.first_name or s.customer.username} {s.customer.last_name or ''}".strip(),
                "customer_phone": s.customer.phone or "+91 9876543210",
                "customer_address": s.customer.address or "Jubilee Hills, Hyderabad",
                "product_name": s.product.name,
                "quantity": s.quantity,
                "frequency": s.frequency,
                "status": s.status,
                "start_date": str(s.start_date),
                "created_at": s.created_at.strftime("%d %b %Y"),
                "estimated_monthly_value": float(s.product.price_per_unit * s.quantity * 30),
            })
        return Response(data)


class AdminSubscriptionToggleView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request, pk):
        try:
            sub = Subscription.objects.get(pk=pk)
        except Subscription.DoesNotExist:
            return Response({"detail": "Subscription not found"}, status=status.HTTP_404_NOT_FOUND)

        action = request.data.get("action", "toggle")
        if action == "pause":
            sub.status = Subscription.Statuses.PAUSED
        elif action == "resume":
            sub.status = Subscription.Statuses.ACTIVE
        elif action == "cancel":
            sub.status = Subscription.Statuses.CANCELLED
        else:
            sub.status = Subscription.Statuses.PAUSED if sub.status == Subscription.Statuses.ACTIVE else Subscription.Statuses.ACTIVE
        sub.save()

        return Response({
            "message": f"Subscription #{sub.id} status updated to {sub.status}",
            "status": sub.status,
        })


class AdminFleetListView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        fleet = [
            {
                "id": 1,
                "name": "Suresh Rao",
                "phone": "+91 9123456789",
                "hub": "Jubilee Hills Depot #1",
                "route": "Route #4 (Sector A & B)",
                "assigned_stops": 12,
                "completed_stops": 12,
                "on_time_rate": "100%",
                "status": "🟢 Shift Active & GPS Live",
                "employment": "Fixed Salaried Staff",
                "salary": "₹15,000 / month",
                "bottles_collected": 14,
            },
            {
                "id": 2,
                "name": "Vikram Sharma",
                "phone": "+91 9876501234",
                "hub": "Jubilee Hills Depot #1",
                "route": "Route #2 (Film Nagar)",
                "assigned_stops": 14,
                "completed_stops": 14,
                "on_time_rate": "99.1%",
                "status": "🟢 Shift Active & GPS Live",
                "employment": "Fixed Salaried Staff",
                "salary": "₹15,000 / month",
                "bottles_collected": 18,
            },
            {
                "id": 3,
                "name": "Anil Kumar",
                "phone": "+91 9765432109",
                "hub": "Jubilee Hills Depot #1",
                "route": "Route #1 (Madhapur Enclave)",
                "assigned_stops": 10,
                "completed_stops": 10,
                "on_time_rate": "100%",
                "status": "🟢 Completed Morning Shift",
                "employment": "Fixed Salaried Staff",
                "salary": "₹15,000 / month",
                "bottles_collected": 11,
            },
            {
                "id": 4,
                "name": "Raju Patel",
                "phone": "+91 9654321098",
                "hub": "Jubilee Hills Depot #1",
                "route": "Route #3 (Banjara Hills)",
                "assigned_stops": 15,
                "completed_stops": 15,
                "on_time_rate": "98.5%",
                "status": "🔴 Shift Reconciled at Depot",
                "employment": "Fixed Salaried Staff",
                "salary": "₹15,000 / month",
                "bottles_collected": 20,
            },
        ]
        return Response(fleet)
