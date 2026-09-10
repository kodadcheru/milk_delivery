import logging
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

logger = logging.getLogger(__name__)

from apps.core.pagination import StandardResultsSetPagination
from apps.accounts.models import Notification, User, WalletTransaction
from apps.core.services.push_service import send_push_to_user
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
        orders = LiveOrder.objects.all().prefetch_related("items__product__category_ref").select_related("customer", "hub", "driver", "batch").order_by("-created_at")

        if user and user.is_authenticated and user.role == User.Roles.CUSTOMER:
            customer_orders = orders.filter(customer=user)
            if not customer_orders.exists() and getattr(user, "phone", None):
                customer_orders = orders.filter(customer__phone=user.phone)
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
        # Safely resolve coordinates without blindly defaulting out-of-area locations
        raw_lat = data.get("delivery_latitude") or getattr(user, "latitude", None)
        raw_lon = data.get("delivery_longitude") or getattr(user, "longitude", None)
        delivery_lat = None
        delivery_lon = None
        if raw_lat is not None and str(raw_lat).strip() not in ("", "0", "0.0"):
            try:
                delivery_lat = float(raw_lat)
            except (ValueError, TypeError):
                delivery_lat = None
        if raw_lon is not None and str(raw_lon).strip() not in ("", "0", "0.0"):
            try:
                delivery_lon = float(raw_lon)
            except (ValueError, TypeError):
                delivery_lon = None

        pincode = data.get("pincode", "")

        # Auto-resolve hub based on delivery location with strict geofencing
        from apps.deliveries.hub_resolver import find_hub_for_location, _haversine_km
        active_hub = find_hub_for_location(
            pincode=pincode,
            latitude=delivery_lat,
            longitude=delivery_lon,
            address=delivery_address,
            strict=True,
        )

        # If strict resolution failed, try user's assigned_hub BUT only if
        # the delivery coordinates are within that hub's coverage radius.
        # This closes the loophole where a Jubilee Hills user with
        # assigned_hub=Kodad could bypass geofencing.
        if not active_hub:
            fallback_hub = getattr(user, "assigned_hub", None)
            if fallback_hub and delivery_lat is not None and delivery_lon is not None:
                try:
                    dist = _haversine_km(
                        float(delivery_lat), float(delivery_lon),
                        float(fallback_hub.latitude), float(fallback_hub.longitude),
                    )
                    if dist <= fallback_hub.coverage_radius_km:
                        active_hub = fallback_hub
                except (ValueError, TypeError):
                    pass
            elif fallback_hub and delivery_lat is None and delivery_lon is None:
                # No GPS at all – only allow if address/pincode matched via
                # text strategies (already handled above). Do NOT silently
                # default to assigned_hub for unknown locations.
                pass

        # Strict Geo-Fence Validation: reject if coordinates exceed hub's coverage radius
        if active_hub and delivery_lat is not None and delivery_lon is not None:
            try:
                dist = _haversine_km(float(delivery_lat), float(delivery_lon), float(active_hub.latitude), float(active_hub.longitude))
                if dist > active_hub.coverage_radius_km:
                    return Response(
                        {
                            "error": "Your delivery address is outside our serviceable area. We cannot deliver to this address.",
                            "detail": "OUT_OF_SERVICE_AREA",
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )
            except (ValueError, TypeError):
                pass

        if not active_hub:
            return Response(
                {
                    "error": "Your delivery address is outside our serviceable range. We do not currently deliver to this area.",
                    "detail": "OUT_OF_SERVICE_AREA",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

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
                except Exception as e:
                    logger.warning(f"Failed to parse item JSON string '{item_entry}': {e}")
                    continue
            if not isinstance(item_entry, dict):
                continue
            
            prod = None
            raw_id = item_entry.get("product_id") or (item_entry.get("product", {}).get("id") if isinstance(item_entry.get("product"), dict) else None)
            prod_name = item_entry.get("name") or item_entry.get("product_name") or (item_entry.get("product", {}).get("name") if isinstance(item_entry.get("product"), dict) else None)
            pack_size = item_entry.get("pack_size") or ""
            category = item_entry.get("category") or ""
            qty = int(item_entry.get("quantity", 1))

            # 1. Direct PK lookup
            if raw_id is not None:
                try:
                    clean_id = int(re.sub(r'\D', '', str(raw_id))) if any(c.isdigit() for c in str(raw_id)) else None
                    if clean_id:
                        prod = Product.objects.filter(pk=clean_id).first()
                except Exception as e:
                    logger.debug(f"Failed to resolve product by raw_id {raw_id}: {e}")
                    prod = None

            # 2. Try match by product name keywords
            if not prod and prod_name:
                p_name_clean = str(prod_name).strip()
                prod = Product.objects.filter(name__iexact=p_name_clean).first()
                if not prod:
                    prod = Product.objects.filter(name__icontains=p_name_clean).first()
                if not prod:
                    # Token-level match
                    tokens = [t for t in p_name_clean.split() if len(t) > 3]
                    for token in tokens:
                        prod = Product.objects.filter(name__icontains=token).first()
                        if prod:
                            break

            # 3. Match by pack size hints (e.g. eggs, 20L can, curd, ghee)
            p_size_lower = str(pack_size).lower()
            if not prod and p_size_lower:
                if "egg" in p_size_lower:
                    prod = Product.objects.filter(name__icontains="egg").first()
                elif "can" in p_size_lower or "water" in p_size_lower:
                    prod = Product.objects.filter(name__icontains="water").first() or Product.objects.filter(name__icontains="can").first()
                elif "curd" in p_size_lower or "dahi" in p_size_lower:
                    prod = Product.objects.filter(name__icontains="curd").first() or Product.objects.filter(name__icontains="dahi").first()
                elif "ghee" in p_size_lower or "butter" in p_size_lower or "makkhan" in p_size_lower:
                    prod = Product.objects.filter(name__icontains="ghee").first() or Product.objects.filter(name__icontains="butter").first()
                elif "chicken" in p_size_lower or "meat" in p_size_lower or "mutton" in p_size_lower:
                    prod = Product.objects.filter(name__icontains="meat").first() or Product.objects.filter(name__icontains="chicken").first() or Product.objects.filter(name__icontains="mutton").first()
                elif "buffalo" in p_size_lower:
                    prod = Product.objects.filter(name__icontains="buffalo").first()

            # 4. Match by category hint
            if not prod and category:
                cat_upper = str(category).upper()
                if "EGG" in cat_upper:
                    prod = Product.objects.filter(name__icontains="egg").first()
                elif "WATER" in cat_upper:
                    prod = Product.objects.filter(name__icontains="water").first()
                elif "MEAT" in cat_upper:
                    prod = Product.objects.filter(name__icontains="meat").first() or Product.objects.filter(name__icontains="chicken").first()
                elif "GHEE" in cat_upper:
                    prod = Product.objects.filter(name__icontains="ghee").first() or Product.objects.filter(name__icontains="butter").first()
                elif "CURD" in cat_upper:
                    prod = Product.objects.filter(name__icontains="curd").first()

            # 5. Fallback only as absolute last resort
            if not prod:
                prod = Product.objects.filter(is_available=True).first() or Product.objects.first()

            if not prod:
                continue

            if not pack_size:
                pack_size = getattr(prod, "unit_quantity", "1 Litre")

            # Always use server-side product price
            unit_price = prod.price_per_unit

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

        # 2. Payment Method Handling (Wallet vs COD vs Razorpay Online)
        from apps.products.models import StorefrontConfig
        store_cfg = StorefrontConfig.get_active()

        raw_payment_method = str(request.data.get("payment_method", "WALLET")).upper()
        if "COD" in raw_payment_method or "CASH" in raw_payment_method:
            payment_method = "COD"
        elif "RAZORPAY" in raw_payment_method or "ONLINE" in raw_payment_method:
            payment_method = "RAZORPAY"
        elif "UPI" in raw_payment_method:
            payment_method = "UPI"
        else:
            payment_method = "WALLET"
        is_cod = (payment_method == "COD")

        # Admin controls enforcement
        if payment_method == "COD" and not store_cfg.is_cod_enabled:
            return Response(
                {"detail": "Cash on Delivery (COD) is temporarily disabled by admin. Please pay using Pamba Wallet or Online Pay."},
                status=status.HTTP_400_BAD_REQUEST
            )
        if payment_method == "WALLET" and not store_cfg.is_wallet_enabled:
            return Response(
                {"detail": "Pamba Wallet payment is temporarily disabled by store admin. Please choose Cash on Delivery (COD) or Online Pay."},
                status=status.HTTP_400_BAD_REQUEST
            )
        if payment_method == "RAZORPAY" and not getattr(store_cfg, "is_online_payment_enabled", True):
            return Response(
                {"detail": "Online payment via Razorpay is temporarily disabled by store admin."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if payment_method == "WALLET" and user.wallet_balance < total_amount:
            return Response(
                {"detail": f"Insufficient wallet balance (₹{user.wallet_balance:.2f}). Required: ₹{total_amount:.2f}. Please top up your wallet or select Cash on Delivery."},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            with transaction.atomic():
                if payment_method == "COD":
                    initial_payment_status = "PENDING (Cash on Delivery)"
                elif payment_method == "RAZORPAY":
                    initial_payment_status = "PENDING_PAYMENT"
                else:
                    initial_payment_status = "PAID (Prepaid Wallet)"

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
                    payment_status=initial_payment_status,
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
                    except Exception as e:
                        logger.debug(f"LiveOrderItem create with pack_size failed, falling back: {e}")
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
                    except Exception as e:
                        logger.warning(f"Failed to update HubProductInventory booked_slots: {e}")

                if payment_method == "WALLET":
                    try:
                        User.objects.filter(pk=user.pk).update(wallet_balance=F("wallet_balance") - total_amount)
                        user.refresh_from_db(fields=["wallet_balance"])

                        WalletTransaction.objects.create(
                            user=user,
                            amount=total_amount,
                            transaction_type=WalletTransaction.Types.DEBIT,
                            description=f"Express Order {order_id} ({len(parsed_items)} items)",
                        )
                    except Exception as e:
                        order.delete()
                        return Response(
                            {"error": f"Wallet debit failed: {str(e)}"},
                            status=status.HTTP_400_BAD_REQUEST,
                        )
                elif payment_method == "RAZORPAY":
                    rzp_order_id = request.data.get("razorpay_order_id")
                    if rzp_order_id:
                        try:
                            from apps.payments.models import RazorpayPayment
                            RazorpayPayment.objects.filter(
                                razorpay_order_id=rzp_order_id,
                                user=user,
                            ).update(order=order)
                        except Exception as e:
                            logger.error(f"Failed to link RazorpayPayment {rzp_order_id} to order {order.id}: {e}")

                try:
                    notif_title = f"⚡ Express Order {order_id} Confirmed!"
                    pay_label = 'Payment: Cash on Delivery (₹' + str(total_amount) + ')' if is_cod else ('Payment: Razorpay Online' if payment_method == 'RAZORPAY' else 'Payment: Prepaid Wallet')
                    notif_msg = f"Your order with {len(parsed_items)} item(s) is scheduled for {delivery_slot}. {pay_label}."
                    Notification.objects.create(
                        user=user,
                        title=notif_title,
                        message=notif_msg,
                        notification_type=Notification.Types.DELIVERY,
                        target_screen="DELIVERIES",
                        target_param=order_id,
                    )
                    send_push_to_user(
                        user=user,
                        title=notif_title,
                        body=notif_msg,
                        target_screen="DELIVERIES",
                        target_param=order_id,
                    )
                except Exception as e:
                    logger.warning(f"Notification failed for order confirmation: {e}")

                hub_driver = None
                try:
                    hub_driver = auto_assign_hub_driver(order, active_hub=active_hub)
                except Exception as e:
                    logger.warning(f"Driver auto-assignment failed for order {order_id}: {e}")

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
                except Exception as e:
                    logger.warning(f"Failed to create full DeliveryTask, trying minimal schema: {e}")
                    try:
                        DeliveryTask.objects.create(
                            order=order,
                            hub=active_hub,
                            driver=hub_driver,
                            delivery_date=delivery_date,
                            slot_time=delivery_slot,
                            status=DeliveryTask.Statuses.PENDING,
                        )
                    except Exception as inner_e:
                        logger.error(f"Failed to create DeliveryTask for order {order.id}: {inner_e}", exc_info=True)

                if hub_driver:
                    try:
                        driver_title = '🚚 New Express Order Assigned!'
                        driver_msg = f'Express order {order.id} has been assigned to you. Deliver to: {delivery_address[:50]}'
                        Notification.objects.create(
                            user=hub_driver,
                            title=driver_title,
                            message=driver_msg,
                            notification_type=Notification.Types.DELIVERY,
                            target_screen="DRIVER_ROUTE",
                            target_param=order.id,
                        )
                        send_push_to_user(
                            user=hub_driver,
                            title=driver_title,
                            body=driver_msg,
                            target_screen="DRIVER_ROUTE",
                            target_param=order.id,
                        )
                    except Exception as e:
                        logger.warning(f"Notification failed for driver assignment: {e}")

            try:
                from apps.core.consumers import broadcast_hub_event
                hub_code = getattr(active_hub, "hub_code", "HUB-KDD-01") if active_hub else "HUB-KDD-01"
                broadcast_hub_event(hub_code, "order_created", {
                    "order_id": order.id,
                    "customer": user.username,
                    "amount": float(total_amount),
                })
            except Exception as e:
                logger.warning(f"Failed to broadcast order_created event: {e}")

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
            order = LiveOrder.objects.prefetch_related("items__product").select_related("customer", "hub", "driver", "batch").get(id=order_id)
        except LiveOrder.DoesNotExist:
            return Response({"detail": "Express order not found"}, status=status.HTTP_404_NOT_FOUND)

        is_staff = request.user.is_staff or getattr(request.user, 'role', '') in ('ADMIN', 'HUB_MANAGER', 'PROVIDER')
        is_assigned_driver = (order.driver == request.user) or \
            DeliveryTask.objects.filter(order=order, driver=request.user).exists()
        is_hub_driver = (
            getattr(request.user, 'role', '') in ('DRIVER', 'DELIVERY_PARTNER')
            and getattr(request.user, 'assigned_hub', None) is not None
            and order.hub == request.user.assigned_hub
        )

        if order.customer != request.user and not (is_staff or is_assigned_driver or is_hub_driver):
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
        is_staff = request.user.is_staff or getattr(request.user, 'role', '') in ('ADMIN', 'HUB_MANAGER', 'PROVIDER')
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
            delivered_lat = request.data.get("delivered_latitude")
            delivered_lng = request.data.get("delivered_longitude")
            if new_status == LiveOrder.Statuses.DELIVERED:
                order.delivered_at = timezone.now()
                if proof_url:
                    order.proof_image_url = proof_url
                if delivered_lat is not None:
                    try:
                        order.delivered_latitude = float(delivered_lat)
                    except (ValueError, TypeError):
                        pass
                if delivered_lng is not None:
                    try:
                        order.delivered_longitude = float(delivered_lng)
                    except (ValueError, TypeError):
                        pass
                # Bug 8: Update COD status & cash collected flag
                if order.is_cod:
                    cash_collected = request.data.get("cash_collected", True)
                    order.cash_collected = bool(cash_collected)
                    if cash_collected:
                        order.payment_status = "PAID (Cash Collected)"

            # Send customer real-time notification on status change
            try:
                if new_status == LiveOrder.Statuses.PICKED_UP and order.customer:
                    t = "📦 Order Picked Up"
                    m = f"Your order #{order.id} has been packed and picked up at the hub."
                    Notification.objects.create(
                        user=order.customer,
                        title=t,
                        message=m,
                        notification_type=Notification.Types.DELIVERY,
                        target_screen="DELIVERIES",
                        target_param=order.id,
                    )
                    send_push_to_user(order.customer, t, m, target_screen="DELIVERIES", target_param=order.id)
                elif new_status == LiveOrder.Statuses.OUT_FOR_DELIVERY and order.customer:
                    t = "🛵 Delivery Partner is On The Way!"
                    m = f"Your delivery partner is en route to your doorstep with order #{order.id}!"
                    Notification.objects.create(
                        user=order.customer,
                        title=t,
                        message=m,
                        notification_type=Notification.Types.DELIVERY,
                        target_screen="DELIVERIES",
                        target_param=order.id,
                    )
                    send_push_to_user(order.customer, t, m, target_screen="DELIVERIES", target_param=order.id)
                elif new_status == LiveOrder.Statuses.DELIVERED and order.customer:
                    t = "🎉 Order Delivered!"
                    m = f"Your fresh order #{order.id} has been delivered to your doorstep. Enjoy!"
                    Notification.objects.create(
                        user=order.customer,
                        title=t,
                        message=m,
                        notification_type=Notification.Types.DELIVERY,
                        target_screen="DELIVERIES",
                        target_param=order.id,
                    )
                    send_push_to_user(order.customer, t, m, target_screen="DELIVERIES", target_param=order.id)
            except Exception as e:
                logger.warning(f"Notification failed for order status change: {e}")

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

                ref_t = f"💰 Order {order.id} Refunded"
                ref_m = f"₹{refund_amount} has been refunded to your wallet for cancelled order {order.id}. New balance: ₹{customer.wallet_balance}"
                Notification.objects.create(
                    user=customer,
                    title=ref_t,
                    message=ref_m,
                    notification_type=Notification.Types.WALLET,
                    target_screen="WALLET",
                )
                try:
                    send_push_to_user(customer, ref_t, ref_m, target_screen="WALLET")
                except Exception as e:
                    logger.warning(f"Notification failed for order refund push: {e}")

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
            task_update_kwargs = {
                "status": task_status,
                "driver": order.driver,
                "proof_image_url": proof_url if proof_url else "",
                "cash_collected": order.cash_collected if order.is_cod else False,
                "delivered_at": timezone.now() if new_status == LiveOrder.Statuses.DELIVERED else None,
            }
            if new_status == LiveOrder.Statuses.DELIVERED:
                if order.delivered_latitude is not None:
                    task_update_kwargs["delivered_latitude"] = order.delivered_latitude
                if order.delivered_longitude is not None:
                    task_update_kwargs["delivered_longitude"] = order.delivered_longitude
            DeliveryTask.objects.filter(order=order).update(**task_update_kwargs)

        try:
            from apps.core.consumers import broadcast_hub_event
            hub_code = getattr(order.hub, "hub_code", "HUB-KDD-01") if order.hub else "HUB-KDD-01"
            broadcast_hub_event(hub_code, "order_updated", {
                "order_id": order.id,
                "status": new_status,
            })
        except Exception as e:
            logger.warning(f"Failed to broadcast order_updated event: {e}")

        return Response(LiveOrderSerializer(order).data)
