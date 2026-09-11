from django.db import migrations, models


def add_gender_column(apps, schema_editor):
    if schema_editor.connection.vendor == 'postgresql':
        with schema_editor.connection.cursor() as cursor:
            cursor.execute("""
                DO $$ 
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='accounts_user' AND column_name='gender') THEN
                        ALTER TABLE accounts_user ADD COLUMN gender varchar(10) NOT NULL DEFAULT 'Male';
                    END IF;
                END $$;
            """)
    elif schema_editor.connection.vendor == 'sqlite':
        with schema_editor.connection.cursor() as cursor:
            cursor.execute("PRAGMA table_info(accounts_user)")
            cols = [c[1] for c in cursor.fetchall()]
            if 'gender' not in cols:
                cursor.execute("ALTER TABLE accounts_user ADD COLUMN gender varchar(10) NOT NULL DEFAULT 'Male'")


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0017_alter_customeraddress_latitude_and_more'),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            state_operations=[
                migrations.AddField(
                    model_name='user',
                    name='gender',
                    field=models.CharField(choices=[('Male', 'Male 👨'), ('Female', 'Female 👩'), ('Other', 'Other 👤')], default='Male', max_length=10),
                ),
            ],
            database_operations=[
                migrations.RunPython(
                    add_gender_column,
                    reverse_code=migrations.RunPython.noop,
                )
            ]
        ),
    ]

