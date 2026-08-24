from django.core.management.base import BaseCommand
from decimal import Decimal
from apps.products.models import Category, Product
from apps.subscriptions.models import Subscription, VacationPause
from apps.deliveries.models import DeliveryTask, LiveOrder, LiveOrderItem, DailyMilkBatch
from apps.accounts.models import User, CustomerAddress, Notification, WalletTransaction


class Command(BaseCommand):
    help = "Deletes all transactional data (orders, tasks, subscriptions, addresses, notifications, transactions) while preserving products and categories."

    def handle(self, *args, **options):
        self.stdout.write("🧹 Starting clean database reset (Preserving Products & Categories)...")

        # 1. Delete Deliveries and Orders
        del_tasks_count = DeliveryTask.objects.all().delete()[0]
        self.stdout.write(f"  - Deleted {del_tasks_count} DeliveryTask records.")

        del_items_count = LiveOrderItem.objects.all().delete()[0]
        del_orders_count = LiveOrder.objects.all().delete()[0]
        self.stdout.write(f"  - Deleted {del_orders_count} LiveOrder records ({del_items_count} items).")

        del_batches_count = DailyMilkBatch.objects.all().delete()[0]
        self.stdout.write(f"  - Deleted {del_batches_count} DailyMilkBatch records.")

        # 2. Delete Subscriptions
        del_pauses_count = VacationPause.objects.all().delete()[0]
        del_subs_count = Subscription.objects.all().delete()[0]
        self.stdout.write(f"  - Deleted {del_subs_count} Subscription records ({del_pauses_count} vacation pauses).")

        # 3. Delete Address Book
        del_addrs_count = CustomerAddress.objects.all().delete()[0]
        self.stdout.write(f"  - Deleted {del_addrs_count} CustomerAddress records.")

        # 4. Delete Notifications & Wallet Transactions
        del_notifs_count = Notification.objects.all().delete()[0]
        del_txs_count = WalletTransaction.objects.all().delete()[0]
        self.stdout.write(f"  - Deleted {del_notifs_count} Notification records.")
        self.stdout.write(f"  - Deleted {del_txs_count} WalletTransaction records.")

        # 5. Reset Users (Reset wallet balances, clear temporary profiles)
        users = User.objects.all()
        for u in users:
            if u.role == User.Roles.CUSTOMER:
                u.wallet_balance = Decimal("1000.00")  # Fresh test balance
                u.address = ""
                u.latitude = Decimal("16.9947")
                u.longitude = Decimal("79.9750")
                u.delivery_instructions = ""
                u.save(update_fields=["wallet_balance", "address", "latitude", "longitude", "delivery_instructions"])
            elif u.role in [User.Roles.DELIVERY_PARTNER, "DRIVER"]:
                u.wallet_balance = Decimal("0.00")
                u.save(update_fields=["wallet_balance"])

        self.stdout.write("  - Reset user wallets and delivery profiles.")

        # 6. Verify Products & Categories are Intact
        prod_count = Product.objects.count()
        cat_count = Category.objects.count()
        self.stdout.write(self.style.SUCCESS(
            f"✨ Clean Reset Complete! Products ({prod_count}) & Categories ({cat_count}) preserved 100%."
        ))
