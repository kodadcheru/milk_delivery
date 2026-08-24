"""
Management command to generate tomorrow's delivery tasks for all active subscriptions.

Handles:
- DAILY subscriptions: task every day
- ALTERNATE subscriptions: task every other day (based on days since start_date)
- CUSTOM subscriptions: task on Mon/Wed/Fri by default
- ONCE subscriptions: only if no task has been created yet
- Vacation auto-resume: resumes subscriptions whose VacationPause.end_date has passed
- Skips subscriptions that are within an active vacation pause window
- Round-robin driver assignment per hub
"""
from datetime import date, timedelta
from django.core.management.base import BaseCommand
from django.db.models import Q

from apps.accounts.models import User, Notification
from apps.subscriptions.models import Subscription, VacationPause
from apps.deliveries.models import DeliveryTask, LocationHub


class Command(BaseCommand):
    help = "Generate delivery tasks for tomorrow (or specified date) for all active subscriptions."

    def add_arguments(self, parser):
        parser.add_argument(
            "--date",
            type=str,
            default=None,
            help="Target date in YYYY-MM-DD format. Defaults to tomorrow.",
        )
        parser.add_argument(
            "--shift",
            type=str,
            default="all",
            choices=["all", "morning", "evening"],
            help="Filter which shift to generate tasks for ('morning', 'evening', or 'all').",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            default=False,
            help="Preview tasks without creating them.",
        )

    def handle(self, *args, **options):
        target_date_str = options["date"]
        shift_opt = options.get("shift", "all").lower()
        dry_run = options["dry_run"]

        if target_date_str:
            target_date = date.fromisoformat(target_date_str)
        else:
            target_date = date.today() + timedelta(days=1)

        self.stdout.write(f"\n{'='*60}")
        self.stdout.write(f"🥛 MilkDrop Daily Task Generator")
        self.stdout.write(f"   Target Date: {target_date}")
        self.stdout.write(f"   Shift: {shift_opt.upper()}")
        self.stdout.write(f"   Mode: {'DRY RUN (preview only)' if dry_run else 'LIVE'}")
        self.stdout.write(f"{'='*60}\n")

        # Step 1: Auto-resume paused subscriptions whose vacation has ended
        resumed_count = self._auto_resume_vacations(target_date, dry_run)

        # Step 2: Generate tasks for active subscriptions
        created_count, skipped_count = self._generate_tasks(target_date, dry_run, shift_filter=shift_opt)

        self.stdout.write(f"\n{'='*60}")
        self.stdout.write(f"📊 Summary:")
        self.stdout.write(f"   Vacations auto-resumed: {resumed_count}")
        self.stdout.write(f"   Tasks created: {created_count}")
        self.stdout.write(f"   Subscriptions skipped: {skipped_count}")
        self.stdout.write(f"{'='*60}\n")

    def _auto_resume_vacations(self, target_date, dry_run):
        """Find paused subscriptions whose vacation pause ended on or before target_date."""
        expired_pauses = VacationPause.objects.filter(
            end_date__lt=target_date,
            subscription__status=Subscription.Statuses.PAUSED,
        ).select_related("subscription", "subscription__customer")

        resumed_count = 0
        for pause in expired_pauses:
            sub = pause.subscription
            if not dry_run:
                sub.status = Subscription.Statuses.ACTIVE
                sub.save()

                Notification.objects.create(
                    user=sub.customer,
                    title="🥛 Vacation Ended — Deliveries Resumed!",
                    message=(
                        f"Your vacation mode ended on {pause.end_date}. "
                        f"Your daily delivery of {sub.quantity}x {sub.product.name} resumes tomorrow."
                    ),
                    notification_type=Notification.Types.SUBSCRIPTION,
                )

            self.stdout.write(
                self.style.WARNING(
                    f"  🔄 Resumed: Sub #{sub.id} for {sub.customer.username} (vacation ended {pause.end_date})"
                )
            )
            resumed_count += 1

        return resumed_count

    def _generate_tasks(self, target_date, dry_run, shift_filter="all"):
        """Generate DeliveryTask entries for each eligible active subscription."""
        active_subs = (
            Subscription.objects
            .filter(status=Subscription.Statuses.ACTIVE, start_date__lte=target_date)
            .select_related("customer", "product", "hub", "customer__assigned_hub")
        )

        # Pre-load hub drivers for round-robin assignment
        hub_drivers = {}
        hub_driver_indices = {}

        created_count = 0
        skipped_count = 0

        for sub in active_subs:
            slot_str = (sub.delivery_slot or sub.customer.delivery_slot_preference or "05:30 AM - 07:00 AM").upper()
            is_evening = "PM" in slot_str or "17:" in slot_str or "18:" in slot_str or "19:" in slot_str

            if shift_filter == "morning" and is_evening:
                continue
            if shift_filter == "evening" and not is_evening:
                continue

            # Check if task already exists for this date
            if DeliveryTask.objects.filter(subscription=sub, delivery_date=target_date).exists():
                self.stdout.write(f"  ⏭️  Skip (exists): Sub #{sub.id} for {sub.customer.username}")
                skipped_count += 1
                continue

            # Check if subscription is within an active vacation pause
            active_pause = VacationPause.objects.filter(
                subscription=sub,
                start_date__lte=target_date,
                end_date__gte=target_date,
            ).exists()
            if active_pause:
                self.stdout.write(f"  🏖️  Skip (vacation): Sub #{sub.id} for {sub.customer.username}")
                skipped_count += 1
                continue

            # Check schedule eligibility
            if not self._is_scheduled_for_date(sub, target_date):
                self.stdout.write(f"  📅 Skip (schedule): Sub #{sub.id} ({sub.schedule_type})")
                skipped_count += 1
                continue

            # Determine hub and driver
            hub = sub.hub or sub.customer.assigned_hub
            driver = self._get_next_driver(hub, hub_drivers, hub_driver_indices)

            if not dry_run:
                DeliveryTask.objects.create(
                    subscription=sub,
                    hub=hub,
                    driver=driver,
                    delivery_date=target_date,
                    slot_time=sub.delivery_slot or sub.customer.delivery_slot_preference or "05:30 AM - 07:00 AM",
                    status=DeliveryTask.Statuses.PENDING,
                )

            driver_name = f"{driver.first_name} {driver.last_name}".strip() if driver else "Unassigned"
            shift_tag = "🌙 Evening" if is_evening else "☀️ Morning"
            self.stdout.write(
                self.style.SUCCESS(
                    f"  ✅ Created ({shift_tag}): Sub #{sub.id} | {sub.customer.username} | "
                    f"{sub.quantity}x {sub.product.name} | Slot: {slot_str} | Driver: {driver_name}"
                )
            )
            created_count += 1

        return created_count, skipped_count

    def _is_scheduled_for_date(self, sub, target_date):
        """Determine if a subscription should have a delivery on the given date."""
        if sub.schedule_type == Subscription.Schedules.DAILY:
            return True

        if sub.schedule_type == Subscription.Schedules.ALTERNATE:
            days_since_start = (target_date - sub.start_date).days
            return days_since_start % 2 == 0  # Deliver on even days (0, 2, 4, ...)

        if sub.schedule_type == Subscription.Schedules.CUSTOM:
            # Default custom schedule: Mon, Wed, Fri (0=Mon, 2=Wed, 4=Fri)
            return target_date.weekday() in (0, 2, 4)

        if sub.schedule_type == Subscription.Schedules.ONCE:
            # Only create task if none has been created yet
            return not DeliveryTask.objects.filter(subscription=sub).exists()

        return True  # Default: treat as DAILY

    def _get_next_driver(self, hub, hub_drivers, hub_driver_indices):
        """Round-robin driver assignment per hub."""
        if hub is None:
            # Fallback to any available driver
            return User.objects.filter(role=User.Roles.DELIVERY_PARTNER).first()

        hub_id = hub.id
        if hub_id not in hub_drivers:
            drivers = list(
                User.objects.filter(
                    role=User.Roles.DELIVERY_PARTNER,
                    assigned_hub=hub,
                    driver_status="ACTIVE",
                )
            )
            if not drivers:
                drivers = list(
                    User.objects.filter(
                        role=User.Roles.DELIVERY_PARTNER,
                        driver_status="ACTIVE",
                    )
                )
            hub_drivers[hub_id] = drivers
            hub_driver_indices[hub_id] = 0

        drivers = hub_drivers[hub_id]
        if not drivers:
            return None

        idx = hub_driver_indices[hub_id]
        driver = drivers[idx % len(drivers)]
        hub_driver_indices[hub_id] = idx + 1
        return driver
