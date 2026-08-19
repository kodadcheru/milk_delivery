from django.db import migrations


def create_default_users(apps, schema_editor):
    User = apps.get_model("accounts", "User")
    from django.contrib.auth.hashers import make_password

    # Helper function to safely get or update a user without phone collision
    def safe_upsert_user(uname, defaults):
        user = User.objects.filter(username=uname).first()
        if not user:
            # Check if phone already taken
            ph = defaults.get("phone")
            if ph:
                user = User.objects.filter(phone=ph).first()

        if not user:
            user = User.objects.create(
                username=uname,
                **defaults
            )
        else:
            for k, v in defaults.items():
                setattr(user, k, v)
            user.save()
        return user

    # Admin / Superuser
    safe_upsert_user("admin", {
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
    })

    # Hub Manager
    safe_upsert_user("hub_manager", {
        "password": make_password("pass123"),
        "email": "hubmanager@milkdrop.in",
        "first_name": "Sanjay",
        "last_name": "Rao",
        "role": "ADMIN",
        "phone": "+91 97654 32100",
        "address": "Madhapur Tech Enclave Depot #3",
        "is_staff": True,
        "wallet_balance": 5000.0,
    })

    # Driver
    safe_upsert_user("driver", {
        "password": make_password("pass123"),
        "email": "driver@milkdrop.in",
        "first_name": "Suresh",
        "last_name": "Rao",
        "role": "DRIVER",
        "phone": "+91 9123456789",
        "address": "Jubilee Hills Central Depot #1",
        "wallet_balance": 0.0,
    })

    # Customer
    safe_upsert_user("customer", {
        "password": make_password("pass123"),
        "email": "customer@milkdrop.in",
        "first_name": "Ramesh",
        "last_name": "Kumar",
        "role": "CUSTOMER",
        "phone": "+91 98765 43210",
        "address": "Flat 402, Road No. 36, Jubilee Hills, Hyderabad",
        "wallet_balance": 1500.0,
    })


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0003_user_latitude_user_longitude"),
    ]

    operations = [
        migrations.RunPython(create_default_users),
    ]
