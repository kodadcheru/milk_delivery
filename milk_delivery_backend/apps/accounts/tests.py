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
        self.user = User.objects.create_user(
            username="testcustomer",
            password="password123",
            role=User.Roles.CUSTOMER,
            phone="+91 9999999999",
            wallet_balance=Decimal("500.00"),
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
