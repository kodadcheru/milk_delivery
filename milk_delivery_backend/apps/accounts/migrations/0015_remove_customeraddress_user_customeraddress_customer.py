from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


def migrate_address_customer_column(apps, schema_editor):
    if schema_editor.connection.vendor == 'postgresql':
        with schema_editor.connection.cursor() as cursor:
            cursor.execute("""
                DO $$ 
                BEGIN
                    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='accounts_customeraddress' AND column_name='user_id') THEN
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='accounts_customeraddress' AND column_name='customer_id') THEN
                            ALTER TABLE accounts_customeraddress RENAME COLUMN user_id TO customer_id;
                        ELSE
                            ALTER TABLE accounts_customeraddress DROP COLUMN user_id;
                        END IF;
                    END IF;
                    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='accounts_customeraddress' AND column_name='customer_id') THEN
                        ALTER TABLE accounts_customeraddress ADD COLUMN customer_id bigint NOT NULL DEFAULT 1 REFERENCES accounts_user(id) ON DELETE CASCADE;
                    END IF;
                END $$;
            """)
    elif schema_editor.connection.vendor == 'sqlite':
        with schema_editor.connection.cursor() as cursor:
            cursor.execute("PRAGMA table_info(accounts_customeraddress)")
            cols = [c[1] for c in cursor.fetchall()]
            if 'customer_id' not in cols:
                if 'user_id' in cols:
                    cursor.execute("ALTER TABLE accounts_customeraddress RENAME COLUMN user_id TO customer_id")
                else:
                    cursor.execute("ALTER TABLE accounts_customeraddress ADD COLUMN customer_id integer NOT NULL DEFAULT 1 REFERENCES accounts_user(id) ON DELETE CASCADE")


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0014_user_driving_license_user_vehicle_number'),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            state_operations=[
                migrations.RemoveField(
                    model_name='customeraddress',
                    name='user',
                ),
                migrations.AddField(
                    model_name='customeraddress',
                    name='customer',
                    field=models.ForeignKey(
                        db_column='customer_id',
                        default=1,
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='saved_addresses',
                        to=settings.AUTH_USER_MODEL,
                    ),
                    preserve_default=False,
                ),
            ],
            database_operations=[
                migrations.RunPython(
                    migrate_address_customer_column,
                    reverse_code=migrations.RunPython.noop,
                )
            ]
        ),
    ]

