"""
Management command to generate monthly provider/hub payout records.
Calculates revenue from completed deliveries, deducts driver salaries and platform commission,
and creates a ProviderPayout settlement record for each hub.
"""
from datetime import date, timedelta
from decimal import Decimal
from django.core.management.base import BaseCommand
from django.db.models import Sum, Count, Q

from apps.accounts.models import User
from apps.deliveries.models import DeliveryTask, LocationHub, ProviderPayout


class Command(BaseCommand):
    help = "Generate monthly provider payout settlement records for each hub."

    def add_arguments(self, parser):
        parser.add_argument(
            "--month",
            type=str,
            default=None,
            help="Target month in YYYY-MM format. Defaults to previous month.",
        )
        parser.add_argument(
            "--commission-rate",
            type=float,
            default=10.0,
            help="Platform commission percentage (default: 10%%).",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            default=False,
            help="Preview payouts without creating records.",
        )

    def handle(self, *args, **options):
        month_str = options["month"]
        commission_rate = Decimal(str(options["commission_rate"])) / Decimal("100")
        dry_run = options["dry_run"]

        if month_str:
            year, month = map(int, month_str.split("-"))
            period_start = date(year, month, 1)
        else:
            # Default to previous month
            today = date.today()
            first_of_this_month = date(today.year, today.month, 1)
            period_start = (first_of_this_month - timedelta(days=1)).replace(day=1)

        # Calculate period end (last day of the month)
        if period_start.month == 12:
            period_end = date(period_start.year + 1, 1, 1) - timedelta(days=1)
        else:
            period_end = date(period_start.year, period_start.month + 1, 1) - timedelta(days=1)

        self.stdout.write(f"\n{'='*60}")
        self.stdout.write(f"💰 MilkDrop Provider Payout Generator")
        self.stdout.write(f"   Period: {period_start} to {period_end}")
        self.stdout.write(f"   Platform Commission: {commission_rate * 100}%")
        self.stdout.write(f"   Mode: {'DRY RUN' if dry_run else 'LIVE'}")
        self.stdout.write(f"{'='*60}\n")

        hubs = LocationHub.objects.all()
        total_payouts = Decimal("0")

        for hub in hubs:
            # Check if payout already exists for this period
            if ProviderPayout.objects.filter(hub=hub, period_start=period_start, period_end=period_end).exists():
                self.stdout.write(f"  ⏭️  Skip: {hub.name} — payout already exists")
                continue

            # Calculate completed deliveries for this hub in the period
            completed_tasks = DeliveryTask.objects.filter(
                hub=hub,
                delivery_date__gte=period_start,
                delivery_date__lte=period_end,
                status=DeliveryTask.Statuses.DELIVERED,
            )

            total_deliveries = completed_tasks.count()
            if total_deliveries == 0:
                self.stdout.write(f"  📭 Skip: {hub.name} — no deliveries in period")
                continue

            # Calculate revenue from completed deliveries
            total_revenue = Decimal("0")
            for task in completed_tasks.select_related("subscription__product"):
                if task.subscription:
                    total_revenue += task.subscription.product.price_per_unit * task.subscription.quantity

            # Calculate driver salaries for the hub
            hub_drivers = User.objects.filter(
                role=User.Roles.DELIVERY_PARTNER,
                assigned_hub=hub,
            )
            driver_salaries = sum(d.monthly_salary for d in hub_drivers)

            # Platform commission
            platform_commission = total_revenue * commission_rate

            # Net payout to provider
            net_payout = total_revenue - driver_salaries - platform_commission

            # Find hub manager
            manager = User.objects.filter(
                Q(role=User.Roles.HUB_MANAGER) | Q(role="PROVIDER"),
                assigned_hub=hub,
            ).first()

            if not dry_run:
                ProviderPayout.objects.create(
                    hub=hub,
                    manager=manager,
                    period_start=period_start,
                    period_end=period_end,
                    total_deliveries=total_deliveries,
                    total_revenue=total_revenue,
                    driver_salaries=driver_salaries,
                    platform_commission=platform_commission,
                    net_payout=net_payout,
                    status=ProviderPayout.Statuses.PENDING,
                )

            total_payouts += net_payout
            self.stdout.write(
                self.style.SUCCESS(
                    f"  ✅ {hub.name}: {total_deliveries} deliveries | "
                    f"Revenue: ₹{total_revenue:,.2f} | Salaries: ₹{driver_salaries:,.2f} | "
                    f"Commission: ₹{platform_commission:,.2f} | Net: ₹{net_payout:,.2f}"
                )
            )

        self.stdout.write(f"\n{'='*60}")
        self.stdout.write(f"📊 Total payouts generated: ₹{total_payouts:,.2f}")
        self.stdout.write(f"{'='*60}\n")
