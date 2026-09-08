from django.db import migrations, models


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
                migrations.RunSQL(
                    sql="""
                    DO $$ 
                    BEGIN
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='accounts_user' AND column_name='gender') THEN
                            ALTER TABLE accounts_user ADD COLUMN gender varchar(10) NOT NULL DEFAULT 'Male';
                        END IF;
                    END $$;
                    """,
                    reverse_sql=migrations.RunSQL.noop,
                )
            ]
        ),
    ]
