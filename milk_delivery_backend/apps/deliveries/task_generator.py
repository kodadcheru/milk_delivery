import logging
from datetime import date, timedelta
from django.db.models import Q
from apps.accounts.models import User, Notification
from apps.subscriptions.models import Subscription, VacationPause
from apps.deliveries.models import DeliveryTask, LocationHub, DailyMilkBatch
from apps.core.models import SiteConfig

logger = logging.getLogger(__name__)


def _get_next_driver(hub, hub_drivers, hub_driver_indices):
    if not hub:
        return None
    hub_id = hub.id
    if hub_id not in hub_drivers:
        # 1. Active drivers for this hub
        drivers = list(User.objects.filter(
            role__in=[User.Roles.DELIVERY_PARTNER, "DRIVER", "DELIVERY_PARTNER"],
            assigned_hub=hub,
            driver_status="ACTIVE",
        ).order_by("id"))
        # 2. Any drivers for this hub
        if not drivers:
            drivers = list(User.objects.filter(
                role__in=[User.Roles.DELIVERY_PARTNER, "DRIVER", "DELIVERY_PARTNER"],
                assigned_hub=hub,
            ).order_by("id"))
        # 3. System-wide fallback driver
        if not drivers:
            drivers = list(User.objects.filter(
                role__in=[User.Roles.DELIVERY_PARTNER, "DRIVER", "DELIVERY_PARTNER"],
            ).order_by("id"))
        hub_drivers[hub_id] = drivers
        hub_driver_indices[hub_id] = 0

    drivers = hub_drivers[hub_id]
    if not drivers:
        return None

    idx = hub_driver_indices[hub_id]
    driver = drivers[idx % len(drivers)]
    hub_driver_indices[hub_id] = idx + 1
    return driver


def generate_daily_tasks_for_date(target_date=None, target_hub=None, shift="all", force=False):
    """
    Idempotent automated task generator.
    Generates delivery tasks for target_date (defaults to tomorrow) for all eligible active subscriptions.
    - Handles DAILY, ALTERNATE, CUSTOM, WEEKDAYS, ONCE schedules.
    - Auto-resumes ended vacation pauses.
    - Skips active vacation pauses.
    - Round-robin assigns drivers per hub.
    - Automatically links quality batches.
    - If force=True, ignores time-of-day cutoffs to ensure tasks are generated for same-day delivery.
    Returns dict: {'created': int, 'skipped': int, 'target_date': str}
    """
    config = SiteConfig.get()
    
    if target_date is None:
        target_date = date.today()
    elif isinstance(target_date, str):
        try:
            target_date = date.fromisoformat(str(target_date).split("T")[0].strip())
        except Exception as e:
            logger.error(f"Failed to parse target_date '{target_date}', defaulting to today: {e}")
            target_date = date.today()

    # 1. Auto-resume expired vacation pauses
    today = date.today()
    expired_pauses = VacationPause.objects.filter(
        end_date__lt=today,
        subscription__status=Subscription.Statuses.PAUSED,
    )
    for p in expired_pauses:
        p.subscription.status = Subscription.Statuses.ACTIVE
        p.subscription.save(update_fields=["status"])

    # 2. Query active subscriptions
    active_subs = (
        Subscription.objects.filter(status=Subscription.Statuses.ACTIVE)
        .select_related("customer", "product", "hub", "customer__assigned_hub")
    )
    if target_hub:
        active_subs = active_subs.filter(
            Q(hub=target_hub) | Q(customer__assigned_hub=target_hub)
        )

    created_count = 0
    skipped_count = 0
    hub_drivers = {}
    hub_driver_indices = {}

    default_fallback_hub = LocationHub.objects.first()

    for sub in active_subs:
        # Check start date: don't generate tasks if subscription starts in the future
        if sub.start_date and sub.start_date > target_date:
            skipped_count += 1
            continue

        # Check active vacation pause
        active_pause = VacationPause.objects.filter(
            subscription=sub,
            start_date__lte=target_date,
            end_date__gte=target_date,
        ).exists()
        if active_pause:
            skipped_count += 1
            continue

        # Prevent duplicate tasks
        existing_task = DeliveryTask.objects.filter(subscription=sub, delivery_date=target_date).first()
        if existing_task:
            skipped_count += 1
            continue

        # Schedule eligibility
        if sub.schedule_type == Subscription.Schedules.ALTERNATE:
            days_since = (target_date - sub.start_date).days
            if days_since % 2 != 0:
                skipped_count += 1
                continue
        elif sub.schedule_type == Subscription.Schedules.CUSTOM:
            if target_date.weekday() not in sub.get_custom_days():
                skipped_count += 1
                continue
        elif sub.schedule_type == Subscription.Schedules.ONCE:
            if DeliveryTask.objects.filter(subscription=sub).exists():
                skipped_count += 1
                continue
        elif sub.schedule_type == 'WEEKDAYS' and target_date.weekday() >= 5:
            skipped_count += 1
            continue

        # Resolve hub & driver
        hub = sub.hub or getattr(sub.customer, "assigned_hub", None) or target_hub or default_fallback_hub
        if hub and not sub.hub:
            sub.hub = hub
            sub.save(update_fields=["hub"])

        driver = _get_next_driver(hub, hub_drivers, hub_driver_indices)
        slot = sub.delivery_slot or getattr(sub.customer, "delivery_slot_preference", None) or config.default_delivery_slot

        # Shift filtering if specified
        is_evening = any(x in slot.upper() for x in ["PM", "17:", "18:", "19:", "EVENING"])
        if shift == "morning" and is_evening:
            continue
        if shift == "evening" and not is_evening:
            continue

        # Cutoff check: if generating for today, respect shift cutoffs unless force=True
        if not force:
            from django.utils import timezone
            import datetime
            now_local = timezone.localtime()
            if target_date == now_local.date():
                if not is_evening and (now_local.hour >= config.afternoon_cutoff_hour or now_local.time() >= datetime.time(config.morning_cutoff_hour, config.morning_cutoff_minute)):
                    skipped_count += 1
                    continue
                if is_evening and now_local.hour >= config.afternoon_cutoff_hour:
                    skipped_count += 1
                    continue

        task_address = sub.address
        if not task_address and hasattr(sub.customer, "addresses"):
            task_address = sub.customer.addresses.filter(is_default=True).first() or sub.customer.addresses.first()

        task, created = DeliveryTask.objects.get_or_create(
            subscription=sub,
            delivery_date=target_date,
            defaults={
                "hub": hub,
                "driver": driver,
                "address": task_address,
                "slot_time": slot,
                "status": DeliveryTask.Statuses.PENDING,
            },
        )
        if created:
            created_count += 1
        else:
            skipped_count += 1

    # Auto-link active quality batch if present
    batches = DailyMilkBatch.objects.filter(batch_date=target_date)
    if batches.exists():
        for task in DeliveryTask.objects.filter(delivery_date=target_date, batch__isnull=True):
            matching_batch = batches.filter(hub=task.hub).first() or batches.first()
            if matching_batch:
                task.batch = matching_batch
                task.save(update_fields=["batch"])

    return {
        "created": created_count,
        "skipped": skipped_count,
        "target_date": target_date.isoformat(),
    }
