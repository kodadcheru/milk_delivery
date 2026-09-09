import logging
from django.core.management.base import BaseCommand
from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.triggers.cron import CronTrigger
from django.core.management import call_command

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Run the APScheduler for periodic tasks (daily task generation, payouts)'

    def handle(self, *args, **options):
        scheduler = BlockingScheduler()

        # 1. Evening generation for tomorrow at 9:00 PM IST
        scheduler.add_job(
            self._generate_tomorrow_tasks,
            trigger=CronTrigger(hour=21, minute=0, timezone='Asia/Kolkata'),
            id='generate_tomorrow_tasks',
            name='Generate tomorrow delivery tasks',
            replace_existing=True,
        )

        # 2. Morning reconciliation at 4:00 AM IST
        scheduler.add_job(
            self._generate_today_tasks,
            trigger=CronTrigger(hour=4, minute=0, timezone='Asia/Kolkata'),
            id='generate_today_tasks',
            name='Reconcile today morning delivery tasks',
            replace_existing=True,
        )

        # 3. Generate payouts at 11:00 PM IST daily
        scheduler.add_job(
            self._generate_payouts,
            trigger=CronTrigger(hour=23, minute=0, timezone='Asia/Kolkata'),
            id='generate_payouts',
            name='Generate driver payouts',
            replace_existing=True,
        )

        self.stdout.write(self.style.SUCCESS('\n🕐 Scheduler started. Registered jobs:'))
        for job in scheduler.get_jobs():
            self.stdout.write(f'  - {job.name}: {job.trigger}')

        try:
            scheduler.start()
        except KeyboardInterrupt:
            scheduler.shutdown()
            self.stdout.write(self.style.SUCCESS('Scheduler stopped.'))

    def _generate_tomorrow_tasks(self):
        logger.info('⏰ Running scheduled: generate_tomorrow_tasks')
        try:
            call_command('generate_daily_tasks')
            logger.info('✅ Tomorrow delivery tasks generated successfully')
        except Exception as e:
            logger.error(f'❌ Tomorrow delivery task generation failed: {e}')

    def _generate_today_tasks(self):
        logger.info('⏰ Running scheduled: generate_today_tasks (morning reconciliation)')
        try:
            from datetime import date
            today_str = date.today().isoformat()
            call_command('generate_daily_tasks', date=today_str, force=True)
            logger.info('✅ Today morning delivery tasks reconciled successfully')
        except Exception as e:
            logger.error(f'❌ Today morning delivery task generation failed: {e}')

    def _generate_payouts(self):
        logger.info('⏰ Running scheduled: generate_payouts')
        try:
            call_command('generate_payouts')
            logger.info('✅ Payouts generated successfully')
        except Exception as e:
            logger.error(f'❌ Payout generation failed: {e}')
