from django.db import migrations

def clear_all_subscriptions(apps, schema_editor):
    try:
        DeliveryTask = apps.get_model('deliveries', 'DeliveryTask')
        DeliveryTask.objects.filter(subscription__isnull=False).delete()
    except Exception:
        pass
    try:
        VacationPause = apps.get_model('subscriptions', 'VacationPause')
        VacationPause.objects.all().delete()
    except Exception:
        pass
    try:
        Subscription = apps.get_model('subscriptions', 'Subscription')
        Subscription.objects.all().delete()
    except Exception:
        pass

class Migration(migrations.Migration):
    dependencies = [
        ('subscriptions', '0007_alter_subscription_schedule_type'),
    ]

    operations = [
        migrations.RunPython(clear_all_subscriptions, reverse_code=migrations.RunPython.noop),
    ]
