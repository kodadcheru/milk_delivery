from decimal import Decimal
import random
import uuid
from datetime import date
from django.db import transaction
from django.db.models import F
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.pagination import StandardResultsSetPagination
from apps.accounts.models import Notification, User, WalletTransaction
from apps.deliveries.models import DeliveryTask, LiveOrder, LiveOrderItem, LocationHub
from apps.deliveries.serializers import LiveOrderSerializer
from apps.products.models import Product


class ExpressOrderListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        orders = LiveOrder.objects.all().prefetch_related("items__product__category_ref").select_related("customer", "hub", "driver").order_by("-created_at")
        if user and user.is_authenticated:
            if user.role == User.Roles.CUSTOMER:
                orders = orders.filter(customer=user)
            elif user.role in [User.Roles.DRIVER, "DRIVER"]:
                orders = orders.filter(driver=user)
            elif user.role in [User.Roles.HUB_MANAGER, "PROVIDER"] and user.assigned_hub:
                orders = orders.filter(hub=user.assigned_hub)

        paginator = StandardResultsSetPagination()
        page = paginator.paginate_queryset(orders, request)
        if page is not None:
            serializer = LiveOrderSerializer(page, many=True)
            return paginator.get_paginated_response(serializer.data)

        return Response(LiveOrderSerializer(orders, many=True).data)

    def post(self, request):
        user = request.user
        if not user or not user.is_authenticated:
            return Response({"error": "Authentication required"}, status=status.HTTP_401_UNAUTHORIZED)

        data = request.data
        items_data = data.get("items", [])
        if not items_data:
            return Response({"detail": "Order must contain at least one item."}, status=status.HTTP_400_BAD_REQUEST)

        delivery_date = data.get("delivery_date", "Tomorrow")
        delivery_slot = data.get("delivery_slot", "05:30 AM - 07:00 AM")
        delivery_address = data.get("delivery_address") or user.address or "Doorstep Delivery"
        delivery_lat = float(data.get("delivery_latitude") or user.latitude or 17.4319)
        delivery_lon = float(data.get("delivery_longitude") or user.longitude or 78.4073)
        pincode = data.get("pincode", "")

        # Auto-resolve hub based on delivery location
        from apps.deliveries.hub_resolver import find_hub_for_location
        active_hub = getattr(user, "assigned_hub", None)
        if not active_hub:
            active_hub = find_hub_for_location(
                pincode=pincode,
                latitude=delivery_lat,
                longitude=delivery_lon,
                address=delivery_address,
            )

        order_id = f"MD-{uuid.uuid4().hex[:6].upper()}"
        while LiveOrder.objects.filter(id=order_id).exists():
            order_id = f"MD-{uuid.uuid4().hex[:6].upper()}"

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

        if user.wallet_balance < total_amount:
            shortfall = total_amount - user.wallet_balance
            return Response(
                {"detail": f"Insufficient wallet balance (Current: ₹{user.wallet_balance}). Please top up ₹{shortfall:.2f} to confirm order."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        with transaction.atomic():
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
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, order_id):
        try:
            order = LiveOrder.objects.prefetch_related("items__product").select_related("customer", "hub", "driver").get(id=order_id)
        except LiveOrder.DoesNotExist:
            return Response({"detail": "Express order not found"}, status=status.HTTP_404_NOT_FOUND)

        if order.customer != request.user and not request.user.is_staff:
            return Response({"detail": "You can only view your own orders."}, status=status.HTTP_403_FORBIDDEN)

        return Response(LiveOrderSerializer(order).data)

    def patch(self, request, order_id):
        try:
            order = LiveOrder.objects.get(id=order_id)
        except LiveOrder.DoesNotExist:
            return Response({"detail": "Express order not found"}, status=status.HTTP_404_NOT_FOUND)

        if order.customer != request.user and not request.user.is_staff:
            return Response({"detail": "You can only modify your own orders."}, status=status.HTTP_403_FORBIDDEN)

        new_status = request.data.get("status")
        if new_status and new_status in dict(LiveOrder.Statuses.choices):
            order.status = new_status
            proof_url = request.data.get("proof_image_url", "")
            if new_status == LiveOrder.Statuses.DELIVERED:
                order.delivered_at = timezone.now()
                if proof_url:
                    order.proof_image_url = proof_url

            # Refund wallet on cancellation (only if not already refunded)
            if new_status == LiveOrder.Statuses.CANCELLED and order.payment_status == "PAID":
                customer = order.customer
                refund_amount = order.total_amount

                with transaction.atomic():
                    User.objects.filter(pk=customer.pk).update(
                        wallet_balance=F("wallet_balance") + refund_amount
                    )
                    customer.refresh_from_db()

                WalletTransaction.objects.create(
                    user=customer,
                    amount=refund_amount,
                    transaction_type=WalletTransaction.Types.CREDIT,
                    description=f"💰 Refund for cancelled order {order.id}",
                )

                Notification.objects.create(
                    user=customer,
                    title=f"💰 Order {order.id} Refunded",
                    message=f"₹{refund_amount} has been refunded to your wallet for cancelled order {order.id}. New balance: ₹{customer.wallet_balance}",
                    notification_type=Notification.Types.WALLET,
                )

                order.payment_status = "REFUNDED"

            order.save()

            # Also update linked DeliveryTask
            if new_status == LiveOrder.Statuses.DELIVERED:
                task_status = DeliveryTask.Statuses.DELIVERED
            elif new_status == LiveOrder.Statuses.CANCELLED:
                task_status = DeliveryTask.Statuses.SKIPPED
            else:
                task_status = DeliveryTask.Statuses.PENDING
            DeliveryTask.objects.filter(order=order).update(
                status=task_status,
                proof_image_url=proof_url if proof_url else "",
                delivered_at=timezone.now() if new_status == LiveOrder.Statuses.DELIVERED else None,
            )
        return Response(LiveOrderSerializer(order).data)
