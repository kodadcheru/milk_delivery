import os
import django

if __name__ == "__main__":
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "milk_backend.settings")
    django.setup()

from apps.subscriptions.models import Subscription, VacationPause
from apps.deliveries.models import DeliveryTask, LiveOrder, LiveOrderItem, BottleReturn, DailyMilkBatch
from apps.products.models import Product, Category, HubProductInventory

def cleanup():
    print("🧹 [Cleanup Script] Cleaning up all products, categories, subscriptions, orders, and delivery tasks...")

    # 1. Clean up Subscriptions & Tasks
    tasks_count, _ = DeliveryTask.objects.all().delete()
    pauses_count, _ = VacationPause.objects.all().delete()
    subs_count, _ = Subscription.objects.all().delete()
    print(f"🗑️ Deleted {subs_count} subscriptions, {pauses_count} pauses, and {tasks_count} delivery tasks.")

    # 2. Clean up Live Orders & Bottle Returns
    items_count, _ = LiveOrderItem.objects.all().delete()
    orders_count, _ = LiveOrder.objects.all().delete()
    returns_count, _ = BottleReturn.objects.all().delete()
    batches_count, _ = DailyMilkBatch.objects.all().delete()
    print(f"🗑️ Deleted {orders_count} live orders, {items_count} order items, {returns_count} bottle returns, and {batches_count} batches.")

    # 3. Clean up Inventory, Products, and Categories
    inv_count, _ = HubProductInventory.objects.all().delete()
    prod_count, _ = Product.objects.all().delete()
    cat_count, _ = Category.objects.all().delete()
    print(f"🗑️ Deleted {inv_count} hub inventories, {prod_count} products, and {cat_count} categories.")

    print("✨ [Cleanup Finished] Database catalog & subscriptions are completely clean! Now ready for fresh creation via Admin Console.")

if __name__ == "__main__":
    cleanup()
