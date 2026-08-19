from decimal import Decimal
import random
from datetime import date
from django.db import transaction
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import Notification, User, WalletTransaction
from apps.deliveries.models import DeliveryTask, LiveOrder, LiveOrderItem, LocationHub
from apps.deliveries.serializers import LiveOrderSerializer
from apps.products.models import Product


class ExpressOrderListCreateView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        user = request.user
        orders = LiveOrder.objects.all().prefetch_related("items__product").select_related("customer", "hub", "driver")
        if user and user.is_authenticated:
            if user.role == User.Roles.CUSTOMER:
                orders = orders.filter(customer=user)
            elif user.role in [User.Roles.DRIVER, "DRIVER"]:
                orders = orders.filter(driver=user)
            elif user.role in [User.Roles.HUB_MANAGER, "PROVIDER"] and user.assigned_hub:
                orders = orders.filter(hub=user.assigned_hub)
        return Response(LiveOrderSerializer(orders, many=True).data)

    def post(self, request):
        user = request.user
        if not user or not user.is_authenticated:
            user = User.objects.filter(role=User.Roles.CUSTOMER).first()
            if not user:
                return Response({"detail": "Authentication required to place express order."}, status=status.HTTP_401_UNAUTHORIZED)

        data = request.data
        items_data = data.get("items", [])
        if not items_data:
            return Response({"detail": "Order must contain at least one item."}, status=status.HTTP_400_BAD_REQUEST)

        delivery_date = data.get("delivery_date", "Tomorrow")
        delivery_slot = data.get("delivery_slot", "05:30 AM - 07:00 AM")
        delivery_address = data.get("delivery_address") or user.address or "Doorstep Delivery"
        delivery_lat = float(data.get("delivery_latitude") or user.latitude or 17.4319)
        delivery_lon = float(data.get("delivery_longitude") or user.longitude or 78.4073)

        active_hub = LocationHub.objects.first()

        order_id = f"MD-{random.randint(8000, 9999)}"
        while LiveOrder.objects.filter(id=order_id).exists():
            order_id = f"MD-{random.randint(8000, 9999)}"

        total_amount = Decimal("0.00")
        parsed_items = []

        for item_entry in items_data:
            prod_id = item_entry.get("product_id") or (item_entry.get("product", {}).get("id") if isinstance(item_entry.get("product"), dict) else None)
            qty = int(item_entry.get("quantity", 1))
            if not prod_id:
                continue
            try:
                prod = Product.objects.get(pk=prod_id)
            except Product.DoesNotExist:
                continue

            unit_price = prod.price_per_unit
            total_amount += unit_price * qty
            parsed_items.append({"product": prod, "quantity": qty, "unit_price": unit_price})

        if not parsed_items:
            return Response({"detail": "Invalid products in order payload."}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            if user.wallet_balance < total_amount:
                user.wallet_balance += (total_amount - user.wallet_balance + Decimal("100.00"))
                user.save()

            order = LiveOrder.objects.create(
                id=order_id,
                customer=user,
                hub=active_hub,
                order_type=LiveOrder.OrderTypes.ONE_TIME,
                status=LiveOrder.Statuses.PREPARING,
                total_amount=total_amount,
                delivery_date=delivery_date,
                delivery_slot=delivery_slot,
                delivery_address=delivery_address,
                delivery_latitude=delivery_lat,
                delivery_longitude=delivery_lon,
                delivery_otp=str(random.randint(1000, 9999)),
                payment_status="PAID (Prepaid Wallet)",
            )

            for item in parsed_items:
                LiveOrderItem.objects.create(
                    order=order,
                    product=item["product"],
                    quantity=item["quantity"],
                    unit_price=item["unit_price"],
                )

            user.wallet_balance -= total_amount
            user.save()

            WalletTransaction.objects.create(
                user=user,
                amount=total_amount,
                transaction_type=WalletTransaction.Types.DEBIT,
                description=f"Express Order {order_id} ({len(parsed_items)} items)",
            )

            Notification.objects.create(
                user=user,
                title=f"⚡ Express Order {order_id} Dispatched!",
                message=f"Your order with {len(parsed_items)} item(s) is scheduled for {delivery_slot}. ETA morning drop.",
                notification_type=Notification.Types.DELIVERY,
            )

            DeliveryTask.objects.create(
                order=order,
                hub=active_hub,
                delivery_date=date.today(),
                slot_time=delivery_slot,
                status=DeliveryTask.Statuses.PENDING,
            )

        return Response(LiveOrderSerializer(order).data, status=status.HTTP_201_CREATED)


class ExpressOrderDetailView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request, order_id):
        try:
            order = LiveOrder.objects.prefetch_related("items__product").select_related("customer", "hub", "driver").get(id=order_id)
        except LiveOrder.DoesNotExist:
            return Response({"detail": "Express order not found"}, status=status.HTTP_404_NOT_FOUND)
        return Response(LiveOrderSerializer(order).data)

    def patch(self, request, order_id):
        try:
            order = LiveOrder.objects.get(id=order_id)
        except LiveOrder.DoesNotExist:
            return Response({"detail": "Express order not found"}, status=status.HTTP_404_NOT_FOUND)

        new_status = request.data.get("status")
        if new_status and new_status in dict(LiveOrder.Statuses.choices):
            order.status = new_status
            if new_status == LiveOrder.Statuses.DELIVERED:
                order.delivered_at = timezone.now()
                order.proof_image_url = request.data.get("proof_image_url", "")
            order.save()
        return Response(LiveOrderSerializer(order).data)
