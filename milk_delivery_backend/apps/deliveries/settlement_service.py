"""
Settlement and Financial Calculation Service.

Handles:
- Hub earnings calculations (Gross Revenue, COD cash collected in hand, Prepaid Online Revenue, Platform Commission)
- Double-settlement prevention by linking completed DeliveryTask records to ProviderPayout
- Instant payout settlement generation with dynamic Hub banking details
"""

from decimal import Decimal
from datetime import date, datetime, timedelta
import random
import logging
from django.db import transaction
from django.utils import timezone
from apps.deliveries.models import DeliveryTask, LocationHub, ProviderPayout, LiveOrder
from apps.accounts.models import User, Notification

logger = logging.getLogger(__name__)

PLATFORM_COMMISSION_RATE = Decimal("0.05")  # 5% platform fee


def resolve_period_dates(period: str, start_date_str=None, end_date_str=None):
    """
    Resolves human-readable or custom period string into (start_date, end_date).
    """
    today = date.today()
    period = (period or "TODAY").upper().strip()

    if period == "TODAY":
        return today, today
    elif period == "YESTERDAY":
        yest = today - timedelta(days=1)
        return yest, yest
    elif period in ("7DAYS", "WEEK", "LAST_7_DAYS"):
        return today - timedelta(days=6), today
    elif period in ("MONTH", "THIS_MONTH"):
        return today.replace(day=1), today
    elif period == "CUSTOM" and start_date_str and end_date_str:
        try:
            s = datetime.strptime(str(start_date_str).split("T")[0].strip(), "%Y-%m-%d").date()
            e = datetime.strptime(str(end_date_str).split("T")[0].strip(), "%Y-%m-%d").date()
            return min(s, e), max(s, e)
        except Exception:
            return today, today

    return today, today


def calculate_hub_earnings(hub: LocationHub, start_date: date = None, end_date: date = None, unsettled_only: bool = False):
    """
    Computes grounded financial metrics for a specific Hub within a date range.
    Includes both Subscription tasks and LiveOrders (Express Deliveries).
    Distinguishes Cash-on-Delivery (COD in hand) from Prepaid Online Revenue.
    """
    if not hub:
        return {
            "total_deliveries": 0,
            "completed_deliveries": 0,
            "pending_deliveries": 0,
            "gross_revenue": Decimal("0.00"),
            "cash_collected": Decimal("0.00"),
            "prepaid_revenue": Decimal("0.00"),
            "platform_commission": Decimal("0.00"),
            "net_withdrawable_amount": Decimal("0.00"),
            "already_settled_amount": Decimal("0.00"),
            "total_litres": 0.0,
            "product_breakdown": {},
        }

    tasks_qs = DeliveryTask.objects.filter(hub=hub).select_related(
        "subscription",
        "subscription__product",
        "subscription__customer",
        "order",
        "order__customer",
        "driver",
        "payout",
    ).prefetch_related("order__items", "order__items__product")

    if start_date and end_date:
        tasks_qs = tasks_qs.filter(delivery_date__gte=start_date, delivery_date__lte=end_date)

    if unsettled_only:
        tasks_qs = tasks_qs.filter(payout__isnull=True)

    total_tasks_count = tasks_qs.count()
    completed_tasks = [t for t in tasks_qs if t.status == DeliveryTask.Statuses.DELIVERED]
    pending_tasks_count = sum(1 for t in tasks_qs if t.status == DeliveryTask.Statuses.PENDING)
    completed_tasks_count = len(completed_tasks)

    gross_revenue = Decimal("0.00")
    cash_collected = Decimal("0.00")
    prepaid_revenue = Decimal("0.00")
    total_litres = 0.0
    product_stats = {}

    for task in completed_tasks:
        task_rev = Decimal("0.00")
        p_name = "Farm Fresh Milk"
        item_qty = 1.0
        pack_size_str = "1 Litre"

        # 1. Evaluate Subscription Task Revenue
        if task.subscription:
            sub = task.subscription
            prod = sub.product
            p_name = prod.name if prod else "Fresh Milk"
            price = sub.effective_unit_price or (prod.price_per_unit if prod else Decimal("68.00"))
            item_qty = float(sub.quantity)
            pack_size_str = sub.pack_size or (prod.unit_quantity if prod else "1 Litre")
            task_rev = Decimal(str(price)) * Decimal(str(item_qty))

        # 2. Evaluate Live Express Order Revenue
        elif task.order:
            order = task.order
            task_rev = order.total_amount
            order_items = list(order.items.all())
            if order_items:
                p_name = order_items[0].product.name
                pack_size_str = order_items[0].product.unit_quantity or "1 Litre"
                item_qty = sum(item.quantity for item in order_items)
            else:
                p_name = "Express Grocery & Dairy"
                item_qty = 1.0

        # 3. Fallback task cash or price fields
        elif task.cash_amount > Decimal("0.00"):
            task_rev = task.cash_amount

        # Calculate volume in Litres for liquid dairy / water
        litres = 0.0
        ps_lower = pack_size_str.lower()
        if "500" in ps_lower or "half" in ps_lower or "0.5" in ps_lower:
            litres = 0.5 * item_qty
        elif "2" in ps_lower or "2l" in ps_lower:
            litres = 2.0 * item_qty
        elif "can" in ps_lower or "20" in ps_lower:
            litres = 20.0 * item_qty
        else:
            litres = 1.0 * item_qty

        is_liquid = any(w in p_name.lower() for w in ["milk", "dairy", "water", "buttermilk", "curd"])
        if is_liquid:
            total_litres += litres

        # Track product-wise metrics
        if p_name not in product_stats:
            product_stats[p_name] = {"count": 0, "quantity": 0, "litres": 0.0, "revenue": Decimal("0.00")}
        product_stats[p_name]["count"] += 1
        product_stats[p_name]["quantity"] += int(item_qty)
        product_stats[p_name]["litres"] += litres
        product_stats[p_name]["revenue"] += task_rev

        # Segregate COD Cash-in-Hand vs Prepaid Online
        is_cod_task = task.is_cod or (task.order and task.order.is_cod)
        if is_cod_task and (task.cash_collected or (task.order and task.order.cash_collected)):
            cash_collected += (task.cash_amount if task.cash_amount > 0 else task_rev)
        else:
            prepaid_revenue += task_rev

        gross_revenue += task_rev

    # Platform commission on gross revenue
    platform_commission = (gross_revenue * PLATFORM_COMMISSION_RATE).quantize(Decimal("0.01"))

    # Net withdrawable online amount (Prepaid revenue minus platform commission)
    net_withdrawable = max(Decimal("0.00"), prepaid_revenue - platform_commission)

    # Compute already settled amount in this period
    payouts_in_period = ProviderPayout.objects.filter(hub=hub)
    if start_date and end_date:
        payouts_in_period = payouts_in_period.filter(
            period_start__lte=end_date,
            period_end__gte=start_date,
        )
    already_settled_amount = sum((p.net_payout for p in payouts_in_period), Decimal("0.00"))
    if not unsettled_only:
        net_withdrawable = max(Decimal("0.00"), net_withdrawable - already_settled_amount)

    # Format product stats for JSON serialization
    serialized_product_stats = {}
    for k, v in product_stats.items():
        serialized_product_stats[k] = {
            "count": v["count"],
            "quantity": v["quantity"],
            "litres": round(v["litres"], 1),
            "revenue": float(v["revenue"]),
        }

    return {
        "total_deliveries": total_tasks_count,
        "completed_deliveries": completed_tasks_count,
        "pending_deliveries": pending_tasks_count,
        "gross_revenue": gross_revenue,
        "cash_collected": cash_collected,
        "prepaid_revenue": prepaid_revenue,
        "platform_commission": platform_commission,
        "net_withdrawable_amount": net_withdrawable,
        "already_settled_amount": already_settled_amount,
        "total_litres": round(total_litres, 1),
        "product_breakdown": serialized_product_stats,
    }


def execute_hub_payout_settlement(hub: LocationHub, manager_user: User, amount: Decimal = None, notes: str = ""):
    """
    Executes an atomic payout settlement for a Hub.
    Marks unsettled delivered tasks as settled with this payout reference.
    Records the Hub's registered bank details and returns the created payout.
    """
    if not hub:
        raise ValueError("A valid LocationHub is required for settlement.")

    today = date.today()

    with transaction.atomic():
        # 1. Fetch all unsettled completed delivery tasks for this hub
        unsettled_tasks = DeliveryTask.objects.select_for_update().filter(
            hub=hub,
            status=DeliveryTask.Statuses.DELIVERED,
            payout__isnull=True,
        ).select_related("subscription__product", "order")

        task_count = unsettled_tasks.count()
        earnings = calculate_hub_earnings(hub=hub, unsettled_only=True)

        available_withdrawable = earnings["net_withdrawable_amount"]
        gross_rev = earnings["gross_revenue"]
        cash_cod = earnings["cash_collected"]
        prepaid_rev = earnings["prepaid_revenue"]
        commission = earnings["platform_commission"]

        # 2. Validate Settlement Amount
        if amount is not None:
            payout_amount = Decimal(str(amount))
            if payout_amount <= Decimal("0.00"):
                raise ValueError("Payout amount must be greater than zero.")
        else:
            payout_amount = available_withdrawable

        if payout_amount <= Decimal("0.00") and task_count == 0:
            raise ValueError("No unsettled completed deliveries found to settle.")

        if payout_amount <= Decimal("0.00") and gross_rev > Decimal("0.00"):
            # If all earnings were collected in cash via COD, the cash in hand is already retained
            payout_amount = Decimal("0.00")

        # 3. Determine Period Start / End
        dates = [t.delivery_date for t in unsettled_tasks if t.delivery_date]
        period_start = min(dates) if dates else today.replace(day=1)
        period_end = max(dates) if dates else today

        # 4. Generate Unique Reference Code
        hub_code_slug = (hub.hub_code or "HUB").replace("-", "")
        ref_code = f"PAY-{hub_code_slug}-{random.randint(10000, 99999)}"
        while ProviderPayout.objects.filter(payment_reference=ref_code).exists():
            ref_code = f"PAY-{hub_code_slug}-{random.randint(10000, 99999)}"

        # 5. Create the Provider Payout record with real Hub banking snapshot
        payout = ProviderPayout.objects.create(
            hub=hub,
            manager=manager_user,
            period_start=period_start,
            period_end=period_end,
            total_deliveries=task_count,
            total_revenue=gross_rev,
            cash_collected=cash_cod,
            prepaid_revenue=prepaid_rev,
            driver_salaries=Decimal("0.00"),
            platform_commission=commission,
            net_payout=payout_amount,
            status=ProviderPayout.Statuses.COMPLETED,
            payment_reference=ref_code,
            bank_name=hub.bank_name or "",
            bank_account_number=hub.bank_account_number or "",
            bank_ifsc=hub.bank_ifsc or "",
            upi_id=hub.upi_id or "",
            notes=notes or f"Instant IMPS settlement to {hub.bank_name or 'Registered Bank'} A/C ending in {(hub.bank_account_number or '0000')[-4:]}",
            paid_at=timezone.now(),
        )

        # 6. Stamp settled tasks with this payout FK to prevent double-settlement
        if amount is not None and payout_amount < available_withdrawable:
            # Greedily stamp only tasks covered by this partial payout
            stamped_ids = []
            running_total = Decimal("0.00")
            for t in unsettled_tasks:
                stamped_ids.append(t.id)
                t_rev = Decimal("0.00")
                if t.subscription:
                    pr = t.subscription.effective_unit_price or (t.subscription.product.price_per_unit if t.subscription.product else Decimal("0.00"))
                    t_rev = Decimal(str(pr)) * t.subscription.quantity
                elif t.order:
                    t_rev = t.order.total_amount
                t_net = t_rev * (Decimal("1.00") - PLATFORM_COMMISSION_RATE)
                running_total += t_net
                if running_total >= payout_amount:
                    break
            DeliveryTask.objects.filter(id__in=stamped_ids).update(payout=payout)
        else:
            unsettled_tasks.update(payout=payout)

        # 7. Notify Hub Manager
        if manager_user:
            try:
                Notification.objects.create(
                    user=manager_user,
                    title="💸 Hub Payout Settled Successfully!",
                    message=(
                        f"Settlement of ₹{payout_amount:.2f} (Ref: {ref_code}) has been transferred to "
                        f"{payout.bank_name} A/C ending in {payout.bank_account_number[-4:]}."
                    ),
                    notification_type=Notification.Types.WALLET,
                )
            except Exception as e:
                logger.warning(f"Could not send payout notification: {e}")

        return payout
