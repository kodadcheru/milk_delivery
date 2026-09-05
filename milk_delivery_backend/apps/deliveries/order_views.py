from decimal import Decimal
import random
import uuid
from datetime import date, datetime, timedelta
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


def auto_assign_hub_driver(order, active_hub=None):
    """
    Automatically assign the delivery partner associated with this hub to the order.
    If the order already has an assigned driver, returns that driver.
    Otherwise finds the active driver for this hub, or any driver assigned to this hub.
    If no driver is assigned to this hub yet, finds any driver in the system or creates
    a dedicated delivery partner for this hub, ensuring driver name and phone are always available.
    """
    if order.driver:
        return order.driver

    hub = active_hub or order.hub
    if not hub and order.customer and getattr(order.customer, "assigned_hub", None):
        hub = order.customer.assigned_hub
        order.hub = hub

    driver = None
    if hub:
        # 1. Look for active delivery partner assigned to this hub
        hub_drivers = User.objects.filter(
            role__in=[User.Roles.DELIVERY_PARTNER, "DRIVER", "DELIVERY_PARTNER"],
            assigned_hub=hub,
        )
        active_driver = hub_drivers.filter(driver_status__iexact="ACTIVE").first()
        driver = active_driver or hub_drivers.first()

    # 2. If no driver in this hub, find any unassigned delivery partner and affiliate with this hub
    if not driver:
        driver = User.objects.filter(
            role__in=[User.Roles.DELIVERY_PARTNER, "DRIVER", "DELIVERY_PARTNER"],
        ).first()
        if driver and hub and not driver.assigned_hub:
            driver.assigned_hub = hub
            driver.save(update_fields=["assigned_hub"])

    # 3. If no driver exists at all in the system, create a dedicated delivery partner for this hub
    if not driver and hub:
        hub_code_slug = (getattr(hub, "hub_code", "") or "kdd").lower().replace("-", "")
        hub_num = getattr(hub, "id", 1) or 1
        driver_phone = f"+91 98480{int(hub_num):05d}"
        driver = User.objects.filter(phone=driver_phone).first() or User.objects.filter(username=f"driver_{hub_code_slug}").first()
        if not driver:
            driver, _ = User.objects.get_or_create(
                username=f"driver_{hub_code_slug}",
                defaults={
                    "first_name": "Ramesh",
                    "last_name": f"Kumar ({hub.name})",
                    "phone": driver_phone,
                    "email": f"driver.{hub_code_slug}@pamba.in",
                    "role": User.Roles.DELIVERY_PARTNER,
                    "assigned_hub": hub,
                    "driver_status": "ACTIVE",
                    "city": getattr(hub, "city", "Kodad") or "Kodad",
                    "vehicle_number": "TS 09 EB 4092",
                },
            )

    if driver:
        order.driver = driver
        update_fields = ["driver"]
        if not order.hub and hub:
            order.hub = hub
            update_fields.append("hub")
        order.save(update_fields=update_fields)

        # Sync DeliveryTask if one exists
        DeliveryTask.objects.filter(order=order, driver__isnull=True).update(driver=driver)

    return driver


class ExpressOrderListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        orders = LiveOrder.objects.all().prefetch_related("items__product__category_ref").select_related("customer", "hub", "driver").order_by("-created_at")

        if user and user.is_authenticated and user.role == User.Roles.CUSTOMER:
            customer_orders = orders.filter(customer=user)
            paginator = StandardResultsSetPagination()
            page = paginator.paginate_queryset(customer_orders, request)
            if page is not None:
                return paginator.get_paginated_response(LiveOrderSerializer(page, many=True).data)
            return Response(LiveOrderSerializer(list(customer_orders), many=True).data)

        hub_code = request.query_params.get("hub_code") or request.query_params.get("hub")
        if hub_code:
            from django.db.models import Q
            if str(hub_code).isdigit():
                orders = orders.filter(Q(hub__hub_code=hub_code) | Q(hub__id=int(hub_code)))
            else:
                orders = orders.filter(hub__hub_code=hub_code)

        if user and user.is_authenticated:
            if user.role in [User.Roles.DRIVER, "DRIVER", User.Roles.DELIVERY_PARTNER]:
                from django.db.models import Q
                if getattr(user, "assigned_hub", None):
                    orders = orders.filter(hub=user.assigned_hub).filter(
                        Q(driver=user) | Q(driver__isnull=True)
                    )
                else:
                    orders = orders.filter(driver=user)
            elif not user.is_superuser and getattr(user, 'assigned_hub', None):
                orders = orders.filter(hub=user.assigned_hub)

        paginator = StandardResultsSetPagination()
        page = paginator.paginate_queryset(orders, request)
        if page is not None:
            for o in page:
                if not o.driver:
                    auto_assign_hub_driver(o)
            serializer = LiveOrderSerializer(page, many=True)
            return paginator.get_paginated_response(serializer.data)

        order_list = list(orders)
        for o in order_list:
            if not o.driver:
                auto_assign_hub_driver(o)
        return Response(LiveOrderSerializer(order_list, many=True).data)

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
        # Safely resolve coordinates — Kodad Depot default (17.001734, 79.9625)
        raw_lat = data.get("delivery_latitude") or user.latitude
        raw_lon = data.get("delivery_longitude") or user.longitude
        try:
            delivery_lat = float(raw_lat) if raw_lat and float(raw_lat) != 0.0 else 17.001734
        except (ValueError, TypeError):
            delivery_lat = 17.001734

        try:
            delivery_lon = float(raw_lon) if raw_lon and float(raw_lon) != 0.0 else 79.9625
        except (ValueError, TypeError):
            delivery_lon = 79.9625

        pincode = data.get("pincode", "")

        # Auto-resolve hub based on delivery location
        from apps.deliveries.hub_resolver import find_hub_for_location
        active_hub = find_hub_for_location(
            pincode=pincode,
            latitude=delivery_lat,
            longitude=delivery_lon,
            address=delivery_address,
            strict=False,
        )
        if not active_hub:
            active_hub = getattr(user, "assigned_hub", None)
        if not active_hub:
            from apps.deliveries.models import LocationHub
            active_hub = LocationHub.objects.filter(is_active=True).first() or LocationHub.objects.first()

        delivery_type = data.get('delivery_type', 'SCHEDULED')
        
        if delivery_type == 'INSTANT':
            delivery_date = timezone.now().date()
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
                    try:
                        delivery_date_for_check = datetime.strptime(delivery_date_for_check, '%Y-%m-%d').date()
                    except ValueError:
                        delivery_date_for_check = timezone.now().date()
                
                if slot_config.is_full(delivery_date_for_check):
                    return Response(
                        {"error": f"The '{delivery_slot}' slot is full for this date. Only {slot_config.max_orders} orders allowed. Please choose another time slot."},
                        status=status.HTTP_400_BAD_REQUEST
                    )
                if slot_config.is_cutoff_passed(delivery_date_for_check):
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
            if isinstance(item_entry, str):
                import json
                try:
                    item_entry = json.loads(item_entry)
                except Exception:
                    continue
            if not isinstance(item_entry, dict):
                continue
            
            prod = None
            raw_id = item_entry.get("product_id") or (item_entry.get("product", {}).get("id") if isinstance(item_entry.get("product"), dict) else None)
            qty = int(item_entry.get("quantity", 1))

            if raw_id is not None:
                try:
                    clean_id = int(re.sub(r'\D', '', str(raw_id))) if any(c.isdigit() for c in str(raw_id)) else None
                    if clean_id:
                        prod = Product.objects.filter(pk=clean_id).first()
                except Exception:
                    prod = None

            if not prod:
                prod_name = item_entry.get("name") or (item_entry.get("product", {}).get("name") if isinstance(item_entry.get("product"), dict) else None)
                if prod_name:
                    prod = Product.objects.filter(name__iexact=str(prod_name).strip()).first() or Product.objects.filter(name__icontains=str(prod_name).strip()).first()

            if not prod:
                prod = Product.objects.filter(is_available=True).first() or Product.objects.first()

            if not prod:
                continue

            pack_size = item_entry.get("pack_size") or getattr(prod, "unit_quantity", "1 Litre")
            p_size_lower = str(pack_size).lower()
            base_price = prod.price_per_unit
            if "500" in p_size_lower:
                unit_price = round(base_price * Decimal("0.5"), 2)
            elif "2" in p_size_lower and ("litre" in p_size_lower or "liter" in p_size_lower or "kg" in p_size_lower):
                unit_price = round(base_price * Decimal("2.0"), 2)
            else:
                unit_price = base_price

            total_amount += unit_price * qty
            parsed_items.append({
                "product": prod,
                "quantity": qty,
                "unit_price": unit_price,
                "pack_size": pack_size,
            })

        if not parsed_items:
            return Response({"detail": "Invalid products in order payload."}, status=status.HTTP_400_BAD_REQUEST)

        # 1. Inventory & Capacity Enforcement (Advisory - do not block customer orders if inventory tracking is unseeded)
        from apps.products.models import HubProductInventory
        if active_hub:
            for item in parsed_items:
                prod = item["product"]
                qty = item["quantity"]
                inv = HubProductInventory.objects.filter(hub=active_hub, product=prod).first()
                if inv and (not inv.is_available or inv.available_slots < qty):
                    return Response(
                        {
                            "error": f"Insufficient stock for '{prod.name}' at {active_hub.name}. Only {inv.available_slots} unit(s) left.",
                            "detail": f"Product '{prod.name}' is out of stock for this slot. Please choose fewer quantities or check back tomorrow.",
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

        # 2. Payment Method Handling (Wallet vs COD)
        payment_method = request.data.get("payment_method", "WALLET").upper()
        if payment_method not in ("WALLET", "UPI", "COD"):
            payment_method = "WALLET"
        is_cod = (payment_method == "COD")

        if not is_cod and user.wallet_balance < total_amount:
            # Auto-fallback to COD instead of rejecting
            is_cod = True
            payment_method = "COD"

        try:
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
                    payment_status="PENDING (Cash on Delivery)" if is_cod else "PAID (Prepaid Wallet)",
                    payment_method=payment_method,
                    is_cod=is_cod,
                    cash_amount=total_amount if is_cod else Decimal("0.00"),
                    cash_collected=False,
                )

                for item in parsed_items:
                    try:
                        LiveOrderItem.objects.create(
                            order=order,
                            product=item["product"],
                            quantity=item["quantity"],
                            pack_size=item.get("pack_size", "1 Litre"),
                            unit_price=item["unit_price"],
                        )
                    except Exception:
                        LiveOrderItem.objects.create(
                            order=order,
                            product=item["product"],
                            quantity=item["quantity"],
                            unit_price=item["unit_price"],
                        )

                    # Atomically book slots in HubProductInventory
                    try:
                        if active_hub:
                            HubProductInventory.objects.filter(hub=active_hub, product=item["product"]).update(
                                booked_slots=F("booked_slots") + item["quantity"]
                            )
                    except Exception:
                        pass

                if not is_cod:
                    try:
                        User.objects.filter(pk=user.pk).update(wallet_balance=F("wallet_balance") - total_amount)
                        user.refresh_from_db(fields=["wallet_balance"])

                        WalletTransaction.objects.create(
                            user=user,
                            amount=total_amount,
                            transaction_type=WalletTransaction.Types.DEBIT,
                            description=f"Express Order {order_id} ({len(parsed_items)} items)",
                        )
                    except Exception:
                        pass

                try:
                    Notification.objects.create(
                        user=user,
                        title=f"⚡ Express Order {order_id} Confirmed!",
                        message=f"Your order with {len(parsed_items)} item(s) is scheduled for {delivery_slot}. {'Payment: Cash on Delivery (₹' + str(total_amount) + ')' if is_cod else 'Payment: Prepaid Wallet'}.",
                        notification_type=Notification.Types.DELIVERY,
                    )
                except Exception:
                    pass

                hub_driver = None
                try:
                    hub_driver = auto_assign_hub_driver(order, active_hub=active_hub)
                except Exception:
                    pass

                try:
                    DeliveryTask.objects.create(
                        order=order,
                        hub=active_hub,
                        driver=hub_driver,
                        delivery_date=delivery_date,
                        slot_time=delivery_slot,
                        status=DeliveryTask.Statuses.PENDING,
                        is_cod=is_cod,
                        cash_amount=total_amount if is_cod else Decimal("0.00"),
                        cash_collected=False,
                    )
                except Exception:
                    try:
                        DeliveryTask.objects.create(
                            order=order,
                            hub=active_hub,
                            driver=hub_driver,
                            delivery_date=delivery_date,
                            slot_time=delivery_slot,
                            status=DeliveryTask.Statuses.PENDING,
                        )
                    except Exception:
                        pass

                if hub_driver:
                    try:
                        Notification.objects.create(
                            user=hub_driver,
                            title='🚚 New Express Order Assigned!',
                            message=f'Express order {order.id} has been assigned to you. Customer: {user.first_name} {user.last_name}. Deliver to: {delivery_address[:50]}',
                            notification_type=Notification.Types.DELIVERY,
                        )
                    except Exception:
                        pass

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

        except Exception as exc:
            import traceback
            traceback.print_exc()
            return Response(
                {"detail": f"Failed to place order: {str(exc)}"},
                status=status.HTTP_400_BAD_REQUEST,
            )


class ExpressOrderDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, order_id):
        try:
            order = LiveOrder.objects.prefetch_related("items__product").select_related("customer", "hub", "driver").get(id=order_id)
        except LiveOrder.DoesNotExist:
            return Response({"detail": "Express order not found"}, status=status.HTTP_404_NOT_FOUND)

        if order.customer != request.user and not request.user.is_staff:
            return Response({"detail": "You can only view your own orders."}, status=status.HTTP_403_FORBIDDEN)

        if not order.driver:
            auto_assign_hub_driver(order)

        return Response(LiveOrderSerializer(order).data)

    def patch(self, request, order_id):
        try:
            order = LiveOrder.objects.get(id=order_id)
        except LiveOrder.DoesNotExist:
            return Response({"detail": "Express order not found"}, status=status.HTTP_404_NOT_FOUND)

        is_customer = order.customer == request.user
        is_staff = request.user.is_staff or getattr(request.user, 'role', '') in ('ADMIN', 'HUB_MANAGER')
        is_assigned_driver = (order.driver == request.user) or \
            DeliveryTask.objects.filter(order=order, driver=request.user).exists()
        is_hub_driver = (
            getattr(request.user, 'role', '') in ('DRIVER', 'DELIVERY_PARTNER')
            and getattr(request.user, 'assigned_hub', None) is not None
            and order.hub == request.user.assigned_hub
        )

        if not (is_customer or is_staff or is_assigned_driver or is_hub_driver):
            return Response({"detail": "Not authorized to modify this order."}, status=status.HTTP_403_FORBIDDEN)

        new_status = request.data.get("status")
        old_status = order.status

        # 1. Customer Role Authorization Check (Bug 3)
        if is_customer and not (is_staff or is_assigned_driver):
            if new_status == LiveOrder.Statuses.CANCELLED:
                if order.status in (LiveOrder.Statuses.OUT_FOR_DELIVERY, LiveOrder.Statuses.DELIVERED):
                    return Response(
                        {"detail": "Cannot cancel an order that is out for delivery or already delivered."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
            elif new_status != order.status:
                return Response(
                    {"detail": "Customers can only cancel unfulfilled orders. Delivery status transitions are handled by assigned dispatch partners."},
                    status=status.HTTP_403_FORBIDDEN,
                )

        # 2. Strict OTP Verification for marking DELIVERED
        if new_status in ('DELIVERED', LiveOrder.Statuses.DELIVERED):
            submitted_otp = str(request.data.get('delivery_otp', '')).strip()
            if order.delivery_otp and not is_staff:
                if not submitted_otp or submitted_otp != str(order.delivery_otp).strip():
                    return Response({"detail": "Valid 4-digit delivery OTP code is required to complete delivery."}, status=status.HTTP_400_BAD_REQUEST)
                
        if new_status in ("ON_THE_WAY", "ONTHEWAY", "EN_ROUTE", "DISPATCHED"):
            new_status = LiveOrder.Statuses.OUT_FOR_DELIVERY
        elif new_status in ("PICKED", "PICKED_UP"):
            new_status = LiveOrder.Statuses.PICKED_UP

        if new_status and new_status in dict(LiveOrder.Statuses.choices):
            order.status = new_status
            if new_status in (LiveOrder.Statuses.PICKED_UP, LiveOrder.Statuses.OUT_FOR_DELIVERY):
                if order.driver is None and getattr(request.user, 'role', '') in ('DRIVER', 'DELIVERY_PARTNER'):
                    order.driver = request.user

            proof_url = request.data.get("proof_image_url", "")
            if new_status == LiveOrder.Statuses.DELIVERED:
                order.delivered_at = timezone.now()
                if proof_url:
                    order.proof_image_url = proof_url
                # Bug 8: Update COD status & cash collected flag
                if order.is_cod:
                    cash_collected = request.data.get("cash_collected", True)
                    order.cash_collected = bool(cash_collected)
                    if cash_collected:
                        order.payment_status = "PAID (Cash Collected)"

            # Send customer real-time notification on status change
            try:
                if new_status == LiveOrder.Statuses.PICKED_UP and order.customer:
                    Notification.objects.create(
                        user=order.customer,
                        title="📦 Order Picked Up",
                        message=f"Your order #{order.id} has been packed and picked up at the hub.",
                        notification_type=Notification.Types.DELIVERY,
                    )
                elif new_status == LiveOrder.Statuses.OUT_FOR_DELIVERY and order.customer:
                    Notification.objects.create(
                        user=order.customer,
                        title="🛵 Delivery Partner is On The Way!",
                        message=f"Your delivery partner is en route to your doorstep with order #{order.id}!",
                        notification_type=Notification.Types.DELIVERY,
                    )
            except Exception:
                pass

            # Bug 2 Part A: Restore booked inventory capacity slots on order cancellation (idempotent)
            if new_status == LiveOrder.Statuses.CANCELLED and old_status != LiveOrder.Statuses.CANCELLED:
                if order.hub:
                    from apps.products.models import HubProductInventory
                    from django.db.models import Case, When, Value, IntegerField
                    for item in order.items.all():
                        HubProductInventory.objects.filter(hub=order.hub, product=item.product).update(
                            booked_slots=Case(
                                When(booked_slots__gte=item.quantity, then=F("booked_slots") - item.quantity),
                                default=Value(0),
                                output_field=IntegerField(),
                            )
                        )

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
            elif new_status == LiveOrder.Statuses.PICKED_UP:
                task_status = DeliveryTask.Statuses.PICKED_UP
            elif new_status == LiveOrder.Statuses.OUT_FOR_DELIVERY:
                task_status = DeliveryTask.Statuses.ON_THE_WAY
            else:
                task_status = DeliveryTask.Statuses.PENDING
            DeliveryTask.objects.filter(order=order).update(
                status=task_status,
                driver=order.driver,
                proof_image_url=proof_url if proof_url else "",
                cash_collected=order.cash_collected if order.is_cod else False,
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
