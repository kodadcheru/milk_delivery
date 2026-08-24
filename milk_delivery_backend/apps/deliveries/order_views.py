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
            elif user.role in [User.Roles.DRIVER, "DRIVER", User.Roles.DELIVERY_PARTNER]:
                from django.db.models import Q
                if getattr(user, "assigned_hub", None):
                    orders = orders.filter(
                        Q(driver=user) |
                        Q(driver__isnull=True, hub=user.assigned_hub) |
                        Q(driver__isnull=True, hub__isnull=True)
                    )
                else:
                    orders = orders.filter(Q(driver=user) | Q(driver__isnull=True))
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

        # Normalize delivery_date: the frontend may send an ISO date, a label
        # like "Tomorrow", or a slot string. Only a real date can be stored in
        # the DateField, so parse it defensively and fall back to today.
        raw_delivery_date = data.get("delivery_date", "")
        if isinstance(raw_delivery_date, str):
            from datetime import datetime as _dt
            for fmt in ("%Y-%m-%d", "%d %b %Y"):
                try:
                    delivery_date = _dt.strptime(raw_delivery_date.strip(), fmt).date()
                    break
                except (ValueError, TypeError):
                    continue
            else:
                delivery_date = date.today()
        else:
            delivery_date = raw_delivery_date or date.today()
        delivery_slot = data.get("delivery_slot", "05:30 AM - 07:00 AM")
        delivery_address = data.get("delivery_address") or user.address or "Doorstep Delivery"
        delivery_lat = float(data.get("delivery_latitude") or user.latitude or 17.4319)
        delivery_lon = float(data.get("delivery_longitude") or user.longitude or 78.4073)
        pincode = data.get("pincode", "")

        # Auto-resolve hub based on delivery location
        from apps.deliveries.hub_resolver import find_hub_for_location
        active_hub = find_hub_for_location(
            pincode=pincode,
            latitude=delivery_lat,
            longitude=delivery_lon,
            address=delivery_address,
            strict=True,
        )
        if not active_hub:
            active_hub = getattr(user, "assigned_hub", None)

        if active_hub and delivery_lat and delivery_lon:
            from apps.deliveries.hub_resolver import _haversine_km
            try:
                dist = _haversine_km(float(delivery_lat), float(delivery_lon), float(active_hub.latitude), float(active_hub.longitude))
                if dist > active_hub.coverage_radius_km:
                    return Response(
                        {"detail": f"Delivery location is outside {active_hub.name} service coverage ({dist:.1f} km away, max radius is {active_hub.coverage_radius_km} km)."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
            except (ValueError, TypeError):
                pass

        if not active_hub:
            return Response({"detail": "Delivery location is outside our operational service area."}, status=status.HTTP_400_BAD_REQUEST)

        delivery_type = data.get('delivery_type', 'SCHEDULED')
        from datetime import timedelta
        
        if delivery_type == 'INSTANT':
            delivery_date = date.today()
            eta_minutes = 25
            estimated_delivery_time = timezone.now() + timedelta(minutes=25)
            delivery_slot = 'Instant Delivery'
            order_type = LiveOrder.OrderTypes.EXPRESS
            order_status = LiveOrder.Statuses.PREPARING
        else:
            eta_minutes = 0
            estimated_delivery_time = None
            order_type = LiveOrder.OrderTypes.ONE_TIME
            order_status = LiveOrder.Statuses.PREPARING

            # Validate slot capacity
            from .models import DeliverySlot
            slot_config = DeliverySlot.objects.filter(hub=active_hub, name=delivery_slot, is_active=True).first()
            if slot_config:
                delivery_date_for_check = delivery_date
                if isinstance(delivery_date_for_check, str):
                    from datetime import datetime as dt
                    try:
                        delivery_date_for_check = dt.strptime(delivery_date_for_check, '%Y-%m-%d').date()
                    except ValueError:
                        from django.utils import timezone
                        delivery_date_for_check = timezone.now().date()
                
                if slot_config.is_full(delivery_date_for_check):
                    return Response(
                        {"error": f"The '{delivery_slot}' slot is full for this date. Only {slot_config.max_orders} orders allowed. Please choose another time slot."},
                        status=status.HTTP_400_BAD_REQUEST
                    )
                if slot_config.is_cutoff_passed():
                    return Response(
                        {"error": f"The '{delivery_slot}' slot has passed its cutoff time. Please choose a later slot or order for tomorrow."},
                        status=status.HTTP_400_BAD_REQUEST
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
                order_type=order_type,
                status=order_status,
                delivery_type=delivery_type,
                eta_minutes=eta_minutes,
                estimated_delivery_time=estimated_delivery_time,
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

            User.objects.filter(pk=user.pk).update(wallet_balance=F("wallet_balance") - total_amount)
            user.refresh_from_db(fields=["wallet_balance"])

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

            hub_driver = User.objects.filter(
                role__in=[User.Roles.DELIVERY_PARTNER, "DRIVER"],
                assigned_hub=active_hub,
            ).first() or User.objects.filter(
                role__in=[User.Roles.DELIVERY_PARTNER, "DRIVER"]
            ).first()
            
            order.driver = hub_driver
            order.save(update_fields=['driver'])

            DeliveryTask.objects.create(
                order=order,
                hub=active_hub,
                driver=hub_driver,
                delivery_date=delivery_date,
                slot_time=delivery_slot,
                status=DeliveryTask.Statuses.PENDING,
            )

            if hub_driver:
                Notification.objects.create(
                    user=hub_driver,
                    title='🚚 New Express Order Assigned!',
                    message=f'Express order {order.id} has been assigned to you. Customer: {user.first_name} {user.last_name}. Deliver to: {delivery_address[:50]}',
                    notification_type=Notification.Types.DELIVERY,
                )

        try:
            from apps.core.consumers import broadcast_hub_event
            hub_code = getattr(active_hub, "hub_code", "HUB-KDD-01") if active_hub else "HUB-KDD-01"
            broadcast_hub_event(hub_code, "order_created", {
                "order_id": order.id,
                "customer": user.username,
                "amount": float(total_amount),
            })
        except Exception:
            pass

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

        is_customer = order.customer == request.user
        is_staff = request.user.is_staff
        is_assigned_driver = (order.driver == request.user) or \
            DeliveryTask.objects.filter(order=order, driver=request.user).exists()
        is_driver_role = getattr(request.user, 'role', '') in ('DRIVER', 'DELIVERY_PARTNER')

        if not (is_customer or is_staff or is_assigned_driver or is_driver_role):
            return Response({"detail": "Not authorized to modify this order."}, status=status.HTTP_403_FORBIDDEN)

        new_status = request.data.get("status")
        if new_status == 'DELIVERED' and getattr(request.user, 'role', '') in ('DRIVER', 'DELIVERY_PARTNER'):
            submitted_otp = request.data.get('delivery_otp', '')
            if submitted_otp and submitted_otp != order.delivery_otp:
                return Response({"detail": "Invalid delivery OTP."}, status=status.HTTP_400_BAD_REQUEST)
                
        if new_status == "DISPATCHED":
            new_status = LiveOrder.Statuses.OUT_FOR_DELIVERY

        if new_status and new_status in dict(LiveOrder.Statuses.choices):
            order.status = new_status
            proof_url = request.data.get("proof_image_url", "")
            if new_status == LiveOrder.Statuses.DELIVERED:
                order.delivered_at = timezone.now()
                if proof_url:
                    order.proof_image_url = proof_url

            # Refund wallet on cancellation (only if paid and not already refunded)
            if new_status == LiveOrder.Statuses.CANCELLED and order.payment_status.startswith("PAID"):
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

        try:
            from apps.core.consumers import broadcast_hub_event
            hub_code = getattr(order.hub, "hub_code", "HUB-KDD-01") if order.hub else "HUB-KDD-01"
            broadcast_hub_event(hub_code, "order_updated", {
                "order_id": order.id,
                "status": new_status,
            })
        except Exception:
            pass

        return Response(LiveOrderSerializer(order).data)
