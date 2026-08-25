from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('deliveries', '0019_deliverytask_address_liveorder_address'),
    ]

    operations = [
        migrations.CreateModel(
            name='DeliveryChatMessage',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('channel_key', models.CharField(db_index=True, max_length=100)),
                ('sender_role', models.CharField(choices=[('DRIVER', 'Delivery Driver'), ('CUSTOMER', 'Customer'), ('SYSTEM', 'System Update')], default='DRIVER', max_length=20)),
                ('sender_name', models.CharField(default='', max_length=150)),
                ('sender_phone', models.CharField(blank=True, default='', max_length=30)),
                ('text', models.TextField()),
                ('is_read', models.BooleanField(default=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('order', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='chat_messages', to='deliveries.liveorder')),
                ('task', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='chat_messages', to='deliveries.deliverytask')),
            ],
            options={
                'ordering': ['created_at'],
                'indexes': [models.Index(fields=['channel_key', 'created_at'], name='deliv_chat_chan_idx')],
            },
        ),
    ]
