from django.core.management.base import BaseCommand
from apps.deliveries.models import DeliverySlot, LocationHub
from datetime import time


class Command(BaseCommand):
    help = 'Seed default delivery slots for all hubs'

    def handle(self, *args, **options):
        default_slots = [
            {'name': '05:30 AM - 07:00 AM', 'label': '⚡ Peak Morning', 'start_time': time(5, 30), 'end_time': time(7, 0), 'max_orders': 50, 'cutoff_minutes_before': 30},
            {'name': '07:00 AM - 08:30 AM', 'label': '🌅 Standard Morning', 'start_time': time(7, 0), 'end_time': time(8, 30), 'max_orders': 40, 'cutoff_minutes_before': 30},
            {'name': '05:00 PM - 07:00 PM', 'label': '🌇 Evening', 'start_time': time(17, 0), 'end_time': time(19, 0), 'max_orders': 30, 'cutoff_minutes_before': 60},
        ]

        hubs = LocationHub.objects.all()
        if not hubs.exists():
            self.stdout.write(self.style.WARNING('No hubs found. Slots will be created when hubs exist.'))
            return

        created = 0
        for hub in hubs:
            for slot_data in default_slots:
                _, was_created = DeliverySlot.objects.get_or_create(
                    hub=hub,
                    name=slot_data['name'],
                    defaults=slot_data,
                )
                if was_created:
                    created += 1

        self.stdout.write(self.style.SUCCESS(f'Created {created} delivery slots across {hubs.count()} hub(s).'))
