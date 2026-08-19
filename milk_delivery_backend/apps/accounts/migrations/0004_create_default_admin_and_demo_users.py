from django.db import migrations


def create_default_users(apps, schema_editor):
    # No-op: Do not insert mock users. Admin and real users are managed via seed_railway and registrations.
    pass


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0003_user_latitude_user_longitude"),
    ]

    operations = [
        migrations.RunPython(create_default_users, migrations.RunPython.noop),
    ]
