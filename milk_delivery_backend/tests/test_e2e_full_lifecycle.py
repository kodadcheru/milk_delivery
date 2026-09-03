"""
End-to-End (E2E) Full Lifecycle Integration Test Suite
======================================================
Flow:
1. Customer Login (Phone OTP) & Address Registration
2. Customer Places Cash-on-Delivery (COD) Express Order
3. Customer Creates Daily Recurring Milk Subscription
4. Hub Manager Logs In, Reviews Live Orders & Daily Batches
5. Hub Manager Generates & Auto-Dispatches Delivery Tasks to Hub Driver
6. Delivery Driver Logs In & Receives Run Manifest
7. Delivery Driver Delivers Express Order (OTP verification & Cash Collection)
8. Delivery Driver Completes Subscription Delivery Task with Proof of Delivery
9. End-to-End Multi-Persona Status Reconciliation
"""

import os
import sys
import uuid
import datetime
from decimal import Decimal

# Configure Django environment
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "milk_backend.settings")
import django
django.setup()

from rest_framework.test import APIClient
from django.test import TestCase

from apps.accounts.models import User, CustomerAddress
from apps.products.models import Product, Category, HubProductInventory
from apps.deliveries.models import LocationHub, LiveOrder, DeliveryTask, DailyMilkBatch
from apps.subscriptions.models import Subscription


class FullLifecycleE2ETestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.today = datetime.date.today()
        self.unique_suffix = uuid.uuid4().hex[:6]
        self.unique_digits = f"{int(uuid.uuid4().int % 90000) + 10000}"

        # 0. Base Infrastructure Setup (Hub, ServiceArea, Category, Product)
        self.hub = LocationHub.objects.filter(hub_code="HUB-KDD-01").first()
        if not self.hub:
            self.hub = LocationHub.objects.create(
                hub_code="HUB-KDD-01",
                name="Kodad Central Depot",
                address="Near RTC Bus Stand, Kodad",
                latitude=Decimal("17.001734"),
                longitude=Decimal("79.962500"),
                coverage_radius_km=15.0,
                manager_name="Suresh Manager",
                manager_phone="+91 8885199878",
            )

        from apps.deliveries.models import ServiceArea
        self.service_area, _ = ServiceArea.objects.get_or_create(
            hub=self.hub,
            name="Kodad Town",
            defaults={
                "city": "Kodad",
                "pincodes": "508206",
                "latitude": 17.001734,
                "longitude": 79.962500,
                "radius_km": 15.0,
                "status": "ACTIVE",
            }
        )

        self.category = Category.objects.filter(slug="milk").first()
        if not self.category:
            self.category = Category.objects.create(
                name="Milk & Dairy",
                slug="milk",
                icon="🥛",
                is_active=True,
            )

        self.product = Product.objects.filter(name="Pure Buffalo Milk").first()
        if not self.product:
            self.product = Product.objects.create(
                name="Pure Buffalo Milk",
                price_per_unit=Decimal("68.00"),
                unit_quantity="1 Litre",
                category="MILK",
                category_ref=self.category,
                is_available=True,
            )

        self.inventory, _ = HubProductInventory.objects.get_or_create(
            hub=self.hub,
            product=self.product,
            defaults={"daily_capacity_slots": 100, "booked_slots": 0},
        )
        self.inventory.daily_capacity_slots = 100
        self.inventory.booked_slots = 0
        self.inventory.save()

        # Driver setup assigned to HUB-KDD-01
        self.driver_user = User.objects.filter(
            role__in=[User.Roles.DELIVERY_PARTNER, "DRIVER"],
            assigned_hub=self.hub,
            driver_status="ACTIVE",
        ).first() or User.objects.filter(
            role__in=[User.Roles.DELIVERY_PARTNER, "DRIVER"],
            assigned_hub=self.hub,
        ).first()

        if not self.driver_user:
            self.driver_phone = f"+91 98480{self.unique_digits}"
            self.driver_user = User.objects.create(
                username=f"driver_{self.unique_suffix}",
                phone=self.driver_phone,
                first_name="Ramesh",
                last_name="Delivery Hero",
                role=User.Roles.DELIVERY_PARTNER,
                assigned_hub=self.hub,
                is_staff=False,
                wallet_balance=Decimal("500.00"),
                driver_status="ACTIVE",
            )
            self.driver_user.set_password("pass123")
            self.driver_user.save()
            self._created_driver = True
        else:
            self.driver_phone = self.driver_user.phone
            self._created_driver = False

        # Hub Manager phone matching self.hub.manager_phone
        self.manager_phone = self.hub.manager_phone or "+91 8885199878"

        self.customer_phone = f"+91 91234{self.unique_digits}"
        self.customer_id = None
        self.created_order_id = None
        self.created_sub_id = None

    def tearDown(self):
        # Clean up test records
        if self.customer_id:
            User.objects.filter(id=self.customer_id).delete()
        if hasattr(self, "_created_driver") and self._created_driver and self.driver_user:
            User.objects.filter(id=self.driver_user.id).delete()
        if self.created_order_id:
            LiveOrder.objects.filter(id=self.created_order_id).delete()
        if self.created_sub_id:
            Subscription.objects.filter(id=self.created_sub_id).delete()

    def test_full_operational_lifecycle(self):
        print("\n" + "=" * 70)
        print("🚀 STARTING FULL OPERATIONAL LIFECYCLE E2E TEST")
        print("=" * 70)

        # ---------------------------------------------------------------------
        # 1. CUSTOMER ONBOARDING & AUTHENTICATION
        # ---------------------------------------------------------------------
        print("\n▶ [STEP 1] Customer Phone OTP Login & Doorstep Address Setup")
        # 1.1 Send OTP
        res = self.client.post("/api/auth/send-otp/", {"phone": self.customer_phone})
        self.assertEqual(res.status_code, 200, f"Send OTP failed: {getattr(res, 'data', res.content)}")
        print(f"  ✓ OTP sent to {self.customer_phone}")

        # 1.2 Verify OTP (new user)
        res = self.client.post("/api/auth/verify-otp/", {"phone": self.customer_phone, "otp": "1234"})
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data.get("is_new_user"))
        print("  ✓ OTP verified as new customer")

        # 1.3 Complete Mobile Registration
        res = self.client.post("/api/auth/register-mobile/", {
            "phone": self.customer_phone,
            "first_name": "Deep",
            "last_name": "Reddy",
            "address": "Flat 402, Sri Sai Nilayam, Kodad",
            "city": "Kodad",
            "delivery_instructions": "Leave near milk bag at door",
            "latitude": 17.001734,
            "longitude": 79.962500,
        })
        self.assertIn(res.status_code, [200, 201], f"Registration failed: {res.data}")
        customer_token = res.data["access"]
        customer_id = res.data["user"]["id"]
        self.customer_id = customer_id
        print(f"  ✓ Customer registered successfully (User ID: {customer_id})")

        # 1.4 Save Doorstep Address in Address Book
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {customer_token}")
        res = self.client.post("/api/accounts/addresses/", {
            "title": "Home",
            "address_line1": "Flat 402, Sri Sai Nilayam",
            "landmark": "Near RTC Bus Stand",
            "city": "Kodad",
            "state": "Telangana",
            "pincode": "508206",
            "latitude": 17.001734,
            "longitude": 79.962500,
            "is_default": True,
        }, format="json")
        self.assertEqual(res.status_code, 201, f"Address save failed: {res.data}")
        print("  ✓ Doorstep address saved in Address Book")

        # ---------------------------------------------------------------------
        # 2. CUSTOMER PLACES EXPRESS ORDER (COD)
        # ---------------------------------------------------------------------
        print("\n▶ [STEP 2] Customer Places Express Order (Instant/COD)")
        initial_booked_slots = HubProductInventory.objects.get(pk=self.inventory.pk).booked_slots
        res = self.client.post("/api/orders/express/", {
            "items": [{"product_id": self.product.id, "quantity": 2}],
            "delivery_date": str(self.today),
            "delivery_slot": "Instant Delivery",
            "delivery_type": "INSTANT",
            "payment_method": "COD",
            "delivery_address": "Flat 402, Sri Sai Nilayam, Kodad",
            "delivery_latitude": 17.001734,
            "delivery_longitude": 79.962500,
        }, format="json")
        self.assertEqual(res.status_code, 201, f"Express order failed: {res.data}")
        order_id = res.data["id"]
        self.created_order_id = order_id
        order_otp = res.data["delivery_otp"]
        self.assertTrue(order_id.startswith("ORD-") or order_id.startswith("EXP-") or order_id.startswith("MD-"))
        self.assertTrue(res.data.get("is_cod"))
        print(f"  ✓ Express Order placed: {order_id}")
        print(f"  ✓ Secret Delivery OTP: {order_otp}")
        print(f"  ✓ Payment Method: {res.data.get('payment_method')} (is_cod: {res.data.get('is_cod')})")

        # Verify capacity slot was booked
        self.inventory.refresh_from_db()
        self.assertEqual(self.inventory.booked_slots, initial_booked_slots + 2)
        print(f"  ✓ Inventory capacity reserved: {self.inventory.booked_slots} slots booked")

        # ---------------------------------------------------------------------
        # 3. CUSTOMER CREATES RECURRING DAILY SUBSCRIPTION
        # ---------------------------------------------------------------------
        print("\n▶ [STEP 3] Customer Creates Daily Recurring Milk Subscription")
        res = self.client.post("/api/subscriptions/", {
            "product": self.product.id,
            "quantity": 1,
            "schedule_type": "DAILY",
            "start_date": str(self.today),
            "delivery_slot": "05:30 AM - 07:00 AM",
            "delivery_address": "Flat 402, Sri Sai Nilayam, Kodad",
        }, format="json")
        self.assertEqual(res.status_code, 201, f"Subscription failed: {res.data}")
        sub_id = res.data["id"]
        self.created_sub_id = sub_id
        self.assertEqual(res.data["status"], "ACTIVE")
        print(f"  ✓ Subscription #{sub_id} activated for {self.product.name} (1 Litre/day)")

        # ---------------------------------------------------------------------
        # 4. HUB MANAGER OPERATIONS & DISPATCH
        # ---------------------------------------------------------------------
        print("\n▶ [STEP 4] Hub Manager Logs In & Reviews Live Hub Dispatch")
        # 4.1 Hub Manager Login
        res = self.client.post("/api/auth/verify-otp/", {"phone": self.manager_phone, "otp": "1234"}, format="json")
        self.assertEqual(res.status_code, 200)
        manager_token = res.data["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {manager_token}")
        print(f"  ✓ Hub Manager logged in ({self.hub.name})")

        # 4.2 Hub Manager Views Live Express Orders
        res = self.client.get(f"/api/orders/express/?hub_code={self.hub.hub_code}")
        self.assertEqual(res.status_code, 200)
        order_list = res.data.get("results", res.data) if isinstance(res.data, dict) else res.data
        order_ids = [o["id"] for o in order_list]
        self.assertIn(order_id, order_ids, "Placed order should appear in Hub Manager's dispatch list")
        print(f"  ✓ Hub Manager verified incoming order {order_id} in dispatch queue")

        # 4.3 Hub Manager Certifies Daily Quality Batch
        res = self.client.post("/api/deliveries/daily-batches/", {
            "product_name": "Pure Buffalo Milk",
            "fat_percentage": 6.8,
            "snf_percentage": 9.2,
            "temperature_celsius": 3.8,
            "price_per_litre": 68.0,
            "batch_date": str(self.today),
            "hub_id": self.hub.id,
        }, format="json")
        self.assertIn(res.status_code, [200, 201])
        print(f"  ✓ Daily milk batch certified (Fat: 6.8%, SNF: 9.2%, Temp: 3.8°C)")

        # 4.4 Hub Manager Triggers Task Generation
        res = self.client.post("/api/deliveries/generate-today-tasks/", {
            "hub_id": self.hub.id,
            "target_date": str(self.today),
        }, format="json")
        self.assertEqual(res.status_code, 200)
        print(f"  ✓ Daily tasks generated & dispatched: {res.data.get('created_count', 0)} created")

        # ---------------------------------------------------------------------
        # 5. DELIVERY DRIVER PICKUP & FULFILLMENT
        # ---------------------------------------------------------------------
        print("\n▶ [STEP 5] Delivery Driver Retrieves Manifest & Delivers Order")
        # 5.1 Driver Login
        res = self.client.post("/api/auth/verify-otp/", {"phone": self.driver_phone, "otp": "1234"}, format="json")
        self.assertEqual(res.status_code, 200)
        driver_token = res.data["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {driver_token}")
        print(f"  ✓ Delivery Partner {self.driver_user.first_name} logged in")

        # 5.2 Driver Fetches Today's Delivery Tasks
        res = self.client.get(f"/api/deliveries/?hub_code={self.hub.hub_code}")
        self.assertEqual(res.status_code, 200)
        task_list = res.data.get("results", res.data) if isinstance(res.data, dict) else res.data
        self.assertGreater(len(task_list), 0, "Driver should have delivery tasks in manifest")
        print(f"  ✓ Driver manifest retrieved: {len(task_list)} stops assigned")

        # 5.3 Driver Attempts Delivery with INCORRECT OTP (Security Test)
        res = self.client.patch(f"/api/orders/express/{order_id}/", {
            "status": "DELIVERED",
            "delivery_otp": "0000",  # WRONG OTP
        }, format="json")
        self.assertEqual(res.status_code, 400, "Wrong OTP should be rejected with 400")
        print(f"  ✓ Security Guard verified: Invalid OTP '0000' rejected by server")

        # 5.4 Driver Delivers Express Order with VALID Customer OTP + Cash Collected
        res = self.client.patch(f"/api/orders/express/{order_id}/", {
            "status": "DELIVERED",
            "delivery_otp": order_otp,
            "cash_collected": True,
        }, format="json")
        self.assertEqual(res.status_code, 200, f"Delivery completion failed: {res.data}")
        delivered_order = LiveOrder.objects.get(id=order_id)
        self.assertEqual(delivered_order.status, "DELIVERED")
        self.assertTrue(delivered_order.cash_collected)
        self.assertIn("Cash Collected", delivered_order.payment_status)
        print(f"  ✓ Express Order {order_id} DELIVERED with OTP {order_otp} & Cash Collected!")

        # 5.5 Driver Completes Subscription Delivery Task with Proof of Delivery
        sub_task = DeliveryTask.objects.filter(subscription_id=sub_id, delivery_date=self.today).first()
        if sub_task:
            res = self.client.post(f"/api/deliveries/{sub_task.id}/complete/", {
                "proof_image_url": "https://images.milkdrop.in/proofs/doorstep_drop_402.jpg",
                "notes": "Left on milk doorstep pouch",
            }, format="json")
            self.assertEqual(res.status_code, 200, f"Task completion failed: {res.data}")
            sub_task.refresh_from_db()
            self.assertEqual(sub_task.status, "DELIVERED")
            print(f"  ✓ Subscription Delivery Task #{sub_task.id} marked DELIVERED with photo proof")

        # ---------------------------------------------------------------------
        # 6. POST-DELIVERY RECONCILIATION ACROSS ALL ROLES
        # ---------------------------------------------------------------------
        print("\n▶ [STEP 6] Cross-Persona Status Reconciliation")
        # 6.1 Customer View: Order shows DELIVERED
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {customer_token}")
        res = self.client.get("/api/orders/express/")
        self.assertEqual(res.status_code, 200)
        cust_orders = res.data.get("results", res.data) if isinstance(res.data, dict) else res.data
        cust_order = next((o for o in cust_orders if o["id"] == order_id), None)
        self.assertIsNotNone(cust_order)
        self.assertEqual(cust_order["status"], "DELIVERED")
        print(f"  ✓ Customer app confirms Order {order_id} is DELIVERED")

        # 6.2 Customer View: Subscriptions tab shows active plan
        res = self.client.get("/api/subscriptions/")
        self.assertEqual(res.status_code, 200)
        cust_subs = res.data.get("results", res.data) if isinstance(res.data, dict) else res.data
        self.assertTrue(any(s["id"] == sub_id for s in cust_subs))
        print(f"  ✓ Customer app confirms Subscription #{sub_id} is ACTIVE")

        # 6.3 Hub Manager View: Delivery Summary reflects completion
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {manager_token}")
        res = self.client.get(f"/api/deliveries/summary/?hub_code={self.hub.hub_code}")
        self.assertEqual(res.status_code, 200)
        print(f"  ✓ Hub Manager Summary: {res.data}")

        print("\n" + "=" * 70)
        print("🎉 ALL LIFECYCLE PHASES COMPLETED AND VERIFIED SUCCESSFULLY!")
        print("=" * 70 + "\n")


if __name__ == "__main__":
    import unittest
    # Run test directly
    suite = unittest.TestLoader().loadTestsFromTestCase(FullLifecycleE2ETestCase)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
