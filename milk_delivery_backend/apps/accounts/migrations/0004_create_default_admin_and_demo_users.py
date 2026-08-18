from django.db import migrations


def create_default_users(apps, schema_editor):
    User = apps.get_model("accounts", "User")
    from django.contrib.auth.hashers import make_password

    # Admin / Superuser
    admin, created = User.objects.get_or_create(
        username="admin",
        defaults={
            "password": make_password("admin123"),
            "email": "admin@milkdrop.in",
            "first_name": "Rajesh",
            "last_name": "Varma",
            "role": "ADMIN",
            "phone": "+91 98888 77777",
            "address": "Plot 42, Road #36, Jubilee Hills, Hyderabad",
            "is_staff": True,
            "is_superuser": True,
            "wallet_balance": 10000.0,
        },
    )
    if not created:
        admin.password = make_password("admin123")
        admin.is_staff = True
        admin.is_superuser = True
        admin.role = "ADMIN"
        admin.save()

    # Hub Manager
    hub_mgr, created = User.objects.get_or_create(
        username="hub_manager",
        defaults={
            "password": make_password("pass123"),
            "email": "hubmanager@milkdrop.in",
            "first_name": "Sanjay",
            "last_name": "Rao",
            "role": "ADMIN",
            "phone": "+91 97654 32100",
            "address": "Madhapur Tech Enclave Depot #3",
            "is_staff": True,
            "wallet_balance": 5000.0,
        },
    )
    if not created:
        hub_mgr.password = make_password("pass123")
        hub_mgr.is_staff = True
        hub_mgr.save()

    # Driver
    driver, created = User.objects.get_or_create(
        username="driver",
        defaults={
            "password": make_password("pass123"),
            "email": "driver@milkdrop.in",
            "first_name": "Suresh",
            "last_name": "Rao",
            "role": "DRIVER",
            "phone": "+91 9123456789",
            "address": "Jubilee Hills Central Depot #1",
            "wallet_balance": 0.0,
        },
    )
    if not created:
        driver.password = make_password("pass123")
        driver.save()

    # Customer
    cust, created = User.objects.get_or_create(
        username="customer",
        defaults={
            "password": make_password("pass123"),
            "email": "customer@milkdrop.in",
            "first_name": "Ramesh",
            "last_name": "Kumar",
            "role": "CUSTOMER",
            "phone": "+91 98765 43210",
            "address": "Flat 402, Road No. 36, Jubilee Hills, Hyderabad",
            "wallet_balance": 1500.0,
        },
    )
    if not created:
        cust.password = make_password("pass123")
        cust.save()


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0003_user_latitude_user_longitude"),
    ]

    operations = [
        migrations.RunPython(create_default_users),
    ]
