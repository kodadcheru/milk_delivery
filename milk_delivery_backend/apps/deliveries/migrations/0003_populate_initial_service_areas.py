from django.db import migrations


def populate_service_areas(apps, schema_editor):
    # No-op: Do not insert mock hubs or service areas.
    # Hubs and service areas are managed exclusively by the Administrator.
    pass


class Migration(migrations.Migration):
    dependencies = [
        ("deliveries", "0002_locationhub_servicearea"),
    ]

    operations = [
        migrations.RunPython(populate_service_areas, migrations.RunPython.noop),
    ]
