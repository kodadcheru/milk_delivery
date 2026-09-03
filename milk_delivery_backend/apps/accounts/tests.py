from decimal import Decimal
from django.test import TestCase
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APIClient

from apps.accounts.models import User, WalletTransaction
from apps.products.models import Product
from apps.subscriptions.models import Subscription
from apps.deliveries.models import DeliveryTask


class MilkBackendAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        from apps.deliveries.models import LocationHub
        self.hub = LocationHub.objects.create(
            hub_code="HUB-KODAD",
            name="Kodad Main Hub",
            address="Main Bazaar, Kodad",
            latitude=Decimal("17.00173400"),
            longitude=Decimal("79.96250000"),
            coverage_radius_km=25.0,
        )
        self.user = User.objects.create_user(
            username="testcustomer",
            password="password123",
            role=User.Roles.CUSTOMER,
            phone="+91 9999999999",
            wallet_balance=Decimal("500.00"),
            assigned_hub=self.hub,
            latitude=Decimal("17.00173400"),
            longitude=Decimal("79.96250000"),
        )
        self.client.force_authenticate(user=self.user)

        self.product = Product.objects.create(
            name="A2 Organic Cow Milk",
            price_per_unit=Decimal("70.00"),
            unit=Product.Units.PACKET,
            unit_quantity="1 Liter Pouch",
        )

    def test_phone_send_and_verify_otp(self):
        # 1. Send OTP
        res = self.client.post(reverse("auth_send_otp"), {"phone": "9999999999"}, format="json")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data["is_existing_user"])

        # 2. Verify with valid OTP 1234
        res = self.client.post(reverse("auth_verify_otp"), {"phone": "+91 9999999999", "otp": "1234"}, format="json")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertFalse(res.data["is_new_user"])
        self.assertIn("access", res.data)

        # 3. Verify with invalid OTP
        res = self.client.post(reverse("auth_verify_otp"), {"phone": "+91 9999999999", "otp": "9999"}, format="json")
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_mobile_new_user_registration(self):
        data = {
            "phone": "9888877777",
            "first_name": "NewCustomer",
            "email": "newcust@example.com",
            "address": "Villa 12, Palm Meadows",
            "delivery_instructions": "Leave near doorstep box",
        }
        res = self.client.post(reverse("auth_register_mobile"), data, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertIn("access", res.data)

        new_user = User.objects.get(phone="+91 9888877777")
        self.assertEqual(new_user.first_name, "NewCustomer")
        self.assertEqual(new_user.wallet_balance, Decimal("500.00"))

    def test_product_list(self):
        res = self.client.get(reverse("product_list"))
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(len(res.data), 1)

    def test_wallet_topup(self):
        url = reverse("wallet_topup")
        res = self.client.post(url, {"amount": "250.00", "description": "Test Topup"}, format="json")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertEqual(self.user.wallet_balance, Decimal("750.00"))

    def test_subscription_creation(self):
        url = reverse("subscription_list")
        data = {
            "product": self.product.id,
            "quantity": 2,
            "schedule_type": Subscription.Schedules.DAILY,
            "start_date": "2026-08-18",
        }
        res = self.client.post(url, data, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Subscription.objects.count(), 1)

    def test_delivery_completion_and_wallet_debit(self):
        sub = Subscription.objects.create(
            customer=self.user,
            product=self.product,
            quantity=1,
            schedule_type=Subscription.Schedules.DAILY,
            start_date="2026-08-18",
        )
        task = DeliveryTask.objects.create(
            subscription=sub,
            delivery_date="2026-08-18",
            slot_time="05:30 AM",
        )

        url = reverse("delivery_complete", kwargs={"pk": task.id})
        res = self.client.post(url, {"proof_image_url": "https://example.com/doorstep.jpg"}, format="json")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        task.refresh_from_db()
        self.assertEqual(task.status, DeliveryTask.Statuses.DELIVERED)

        self.user.refresh_from_db()
        self.assertEqual(self.user.wallet_balance, Decimal("430.00"))  # 500 - 70

    def test_gps_coordinates_update_and_delivery_serialization(self):
        # 1. Update user GPS coordinates
        res = self.client.patch(
            reverse("auth_me"),
            {
                "latitude": "17.43250000",
                "longitude": "78.40890000",
                "address": "Road 45, Jubilee Hills",
            },
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertEqual(self.user.latitude, Decimal("17.43250000"))
        self.assertEqual(self.user.longitude, Decimal("78.40890000"))

        # 2. Check that delivery task returns the customer's coordinates
        sub = Subscription.objects.create(
            customer=self.user,
            product=self.product,
            quantity=1,
            schedule_type=Subscription.Schedules.DAILY,
            start_date="2026-08-18",
        )
        task = DeliveryTask.objects.create(
            subscription=sub,
            delivery_date="2026-08-25",
        )
        res = self.client.get(reverse("delivery_list"))
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        tasks_data = res.data.get("results", res.data) if isinstance(res.data, dict) else res.data
        self.assertGreaterEqual(len(tasks_data), 1)
        target_task = next((t for t in tasks_data if t["id"] == task.id), tasks_data[0])
        self.assertAlmostEqual(target_task["customer_latitude"], 17.4325, places=3)
        self.assertAlmostEqual(target_task["customer_longitude"], 78.4089, places=3)

    def test_admin_fixed_number_role(self):
        # Fixed Admin number 8919548905
        res = self.client.post(reverse("auth_verify_otp"), {"phone": "8919548905", "otp": "1234"}, format="json")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["user"]["role"], User.Roles.ADMIN)

    def test_catalog_write_permission_lockdown(self):
        # Customer trying to create product -> HTTP 403 Forbidden
        res = self.client.post(reverse("product_list"), {"name": "Hacker Milk", "price_per_unit": "10.00"}, format="json")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        # Admin user creating product -> HTTP 201 Created
        admin_user = User.objects.create_user(username="admin_test", password="pass", role=User.Roles.ADMIN, is_staff=True)
        self.client.force_authenticate(user=admin_user)
        res = self.client.post(reverse("product_list"), {"name": "Admin Milk", "price_per_unit": "80.00"}, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)

    def test_address_idor_protection(self):
        from apps.accounts.models import CustomerAddress
        user_a = User.objects.create_user(username="usera", password="pass", phone="+91 9111111111")
        user_b = User.objects.create_user(username="userb", password="pass", phone="+91 9222222222")
        addr_a = CustomerAddress.objects.create(user=user_a, street_address="User A House", is_default=True)

        # User B trying to set User A's address as default -> HTTP 404 Not Found
        self.client.force_authenticate(user=user_b)
        res = self.client.post(reverse("address_set_default", kwargs={"pk": addr_a.pk}))
        self.assertEqual(res.status_code, status.HTTP_404_NOT_FOUND)

    def test_strict_hub_resolver_out_of_service(self):
        from apps.deliveries.hub_resolver import find_hub_for_location
        # Location far outside coverage (lat=1.0, lon=1.0)
        hub = find_hub_for_location(latitude=1.0, longitude=1.0, strict=True)
        self.assertIsNone(hub)

    def test_phone_validation_rejects_invalid(self):
        # 1. Too short
        res = self.client.post(reverse("auth_send_otp"), {"phone": "12345"}, format="json")
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

        # 2. Starts with invalid prefix (e.g. 5)
        res = self.client.post(reverse("auth_send_otp"), {"phone": "5888877777"}, format="json")
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

        # 3. Letters/non-digits
        res = self.client.post(reverse("auth_send_otp"), {"phone": "abcdefghij"}, format="json")
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_email_validation_rejects_malformed(self):
        data = {
            "phone": "9777766666",
            "first_name": "EmailTester",
            "email": "not-a-valid-email",
        }
        res = self.client.post(reverse("auth_register_mobile"), data, format="json")
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("valid email address", res.data.get("detail", ""))

    def test_email_validation_rejects_duplicates(self):
        data1 = {
            "phone": "9666655555",
            "first_name": "FirstUser",
            "email": "unique@example.com",
        }
        res1 = self.client.post(reverse("auth_register_mobile"), data1, format="json")
        self.assertEqual(res1.status_code, status.HTTP_201_CREATED)

        data2 = {
            "phone": "9555544444",
            "first_name": "SecondUser",
            "email": "unique@example.com",
        }
        res2 = self.client.post(reverse("auth_register_mobile"), data2, format="json")
        self.assertEqual(res2.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("already exists", res2.data.get("detail", ""))

    def test_customer_sees_past_delivered_daily_orders(self):
        from datetime import date, timedelta
        from apps.subscriptions.models import Subscription
        from apps.deliveries.models import DeliveryTask

        cust = User.objects.create_user(
            username="past_order_cust",
            password="pass",
            role=User.Roles.CUSTOMER,
            phone="+91 9777711111",
        )
        self.client.force_authenticate(user=cust)

        # Create past delivered drops
        two_days_ago = date.today() - timedelta(days=2)
        yesterday = date.today() - timedelta(days=1)
        today = date.today()

        sub = Subscription.objects.create(
            customer=cust,
            product=self.product,
            quantity=1,
            schedule_type="DAILY",
            delivery_slot="05:30 AM - 07:00 AM",
            delivery_address="1-23 Main Road, Kodad",
            status=Subscription.Statuses.ACTIVE,
            start_date=two_days_ago,
        )

        t_past2 = DeliveryTask.objects.create(
            subscription=sub,
            delivery_date=two_days_ago,
            slot_time="06:00 AM",
            status=DeliveryTask.Statuses.DELIVERED,
        )
        t_past1 = DeliveryTask.objects.create(
            subscription=sub,
            delivery_date=yesterday,
            slot_time="06:00 AM",
            status=DeliveryTask.Statuses.DELIVERED,
        )
        t_today = DeliveryTask.objects.create(
            subscription=sub,
            delivery_date=today,
            slot_time="06:00 AM",
            status=DeliveryTask.Statuses.PENDING,
        )

        # Customer calls delivery list without date filter
        res = self.client.get(reverse("delivery_list"))
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        tasks_data = res.data.get("results", res.data) if isinstance(res.data, dict) else res.data
        task_ids = [t["id"] for t in tasks_data]

        # Customer must receive ALL tasks including past delivered orders
        self.assertIn(t_past2.id, task_ids)
        self.assertIn(t_past1.id, task_ids)
        self.assertIn(t_today.id, task_ids)

        # Check latest-first ordering
        self.assertEqual(tasks_data[0]["id"], t_today.id)
        self.assertEqual(tasks_data[1]["id"], t_past1.id)
        self.assertEqual(tasks_data[2]["id"], t_past2.id)
