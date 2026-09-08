from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


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
                migrations.RunSQL(
                    sql="""
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
                    """,
                    reverse_sql=migrations.RunSQL.noop,
                )
            ]
        ),
    ]
