from django.db import migrations


def create_initial_data(apps, schema_editor):
    # No-op: Do not auto-seed mock products during database migration.
    # Products are managed dynamically via Admin Web Console.
    pass


def remove_initial_data(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('products', '0003_alter_product_category_alter_product_farm_origin_and_more'),
        ('accounts', '0003_user_latitude_user_longitude'),
    ]

    operations = [
        migrations.RunPython(create_initial_data, remove_initial_data),
    ]
