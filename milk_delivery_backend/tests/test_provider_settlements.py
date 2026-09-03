import os
import django
from decimal import Decimal
from datetime import date, timedelta

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "milk_backend.settings")
django.setup()

from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from apps.accounts.models import User, CustomerAddress
from apps.products.models import Product, Category
from apps.subscriptions.models import Subscription
from apps.deliveries.models import LocationHub, DeliveryTask, ProviderPayout, LiveOrder, LiveOrderItem
from apps.deliveries.settlement_service import (
    calculate_hub_earnings,
    execute_hub_payout_settlement,
    resolve_period_dates,
)


class ProviderSettlementsTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()

        # 1. Create Hub with Banking details
        self.hub = LocationHub.objects.create(
            hub_code="HUB-KDD-01",
            name="Kodad Main Depot",
            address="Near Bus Stand, Kodad",
            manager_name="Srinuvasa Reddy",
            manager_phone="9848022338",
            bank_name="State Bank of India",
            bank_account_number="389201948210",
            bank_ifsc="SBIN0004892",
            bank_account_holder="Srinuvasa Reddy",
            upi_id="8885199878@upi",
        )

        # 2. Users
        self.manager = User.objects.create_user(
            username="manager_srinu",
            phone="+919848022338",
            first_name="Srinuvasa",
            last_name="Reddy",
            role=User.Roles.HUB_MANAGER,
            assigned_hub=self.hub,
        )

        self.admin = User.objects.create_superuser(
            username="admin_test",
            phone="+919999900000",
            first_name="Super",
            last_name="Admin",
            role=User.Roles.ADMIN,
        )

        self.customer = User.objects.create_user(
            username="customer_test",
            phone="+919123456780",
            first_name="Deep",
            last_name="Reddy",
            role=User.Roles.CUSTOMER,
        )

        self.driver = User.objects.create_user(
            username="driver_test",
            phone="+919876543210",
            first_name="Ravi",
            last_name="Kumar",
            role=User.Roles.DELIVERY_PARTNER,
            assigned_hub=self.hub,
        )

        # 3. Product & Category
        self.category = Category.objects.create(name="Farm Fresh Milk", slug="farm-fresh-milk")
        self.product = Product.objects.create(
            name="A2 Desi Cow Milk",
            category_ref=self.category,
            price_per_unit=Decimal("68.00"),
            unit_quantity="1 Litre",
            is_available=True,
        )

        # 4. Customer Address
        self.address = CustomerAddress.objects.create(
            customer=self.customer,
            flat_house_no="Door 4-12",
            street_address="Gandhi Nagar",
            city="Kodad",
            pincode="508206",
        )

    def test_resolve_period_dates(self):
        today = date.today()
        s, e = resolve_period_dates("TODAY")
        self.assertEqual(s, today)
        self.assertEqual(e, today)

        s_yest, e_yest = resolve_period_dates("YESTERDAY")
        self.assertEqual(s_yest, today - timedelta(days=1))

        s_7d, e_7d = resolve_period_dates("7DAYS")
        self.assertEqual(s_7d, today - timedelta(days=6))
        self.assertEqual(e_7d, today)

    def test_hub_earnings_calculation_and_cod_separation(self):
        today = date.today()

        # A. Subscription Prepaid Task: 2 units of A2 Milk = 2 * 68 = ₹136.00
        sub = Subscription.objects.create(
            customer=self.customer,
            product=self.product,
            hub=self.hub,
            quantity=2,
            effective_unit_price=Decimal("68.00"),
            schedule_type=Subscription.Schedules.DAILY,
            status=Subscription.Statuses.ACTIVE,
            start_date=today,
        )

        task_prepaid = DeliveryTask.objects.create(
            subscription=sub,
            hub=self.hub,
            driver=self.driver,
            address=self.address,
            delivery_date=today,
            status=DeliveryTask.Statuses.DELIVERED,
            is_cod=False,
            cash_collected=False,
        )

        # B. Express COD Order Task: Total ₹200.00 cash collected at doorstep
        order = LiveOrder.objects.create(
            id="EXP-TEST-9999",
            customer=self.customer,
            hub=self.hub,
            status=LiveOrder.Statuses.DELIVERED,
            total_amount=Decimal("200.00"),
            is_cod=True,
            cash_collected=True,
            delivery_address="Door 4-12, Gandhi Nagar",
        )
        LiveOrderItem.objects.create(order=order, product=self.product, quantity=2, unit_price=Decimal("100.00"))

        task_cod = DeliveryTask.objects.create(
            order=order,
            hub=self.hub,
            driver=self.driver,
            address=self.address,
            delivery_date=today,
            status=DeliveryTask.Statuses.DELIVERED,
            is_cod=True,
            cash_collected=True,
            cash_amount=Decimal("200.00"),
        )

        # C. Compute Earnings
        earnings = calculate_hub_earnings(hub=self.hub, start_date=today, end_date=today)

        # Gross Revenue: 136.00 + 200.00 = 336.00
        self.assertEqual(earnings["gross_revenue"], Decimal("336.00"))
        # Cash Collected via COD: 200.00
        self.assertEqual(earnings["cash_collected"], Decimal("200.00"))
        # Online / Prepaid Revenue: 136.00
        self.assertEqual(earnings["prepaid_revenue"], Decimal("136.00"))
        # Commission (5% of 336.00): 16.80
        self.assertEqual(earnings["platform_commission"], Decimal("16.80"))
        # Net withdrawable online amount: 136.00 - 16.80 = 119.20
        self.assertEqual(earnings["net_withdrawable_amount"], Decimal("119.20"))
        self.assertEqual(earnings["completed_deliveries"], 2)

    def test_provider_earnings_summary_api(self):
        today = date.today()
        # Create a delivered task
        sub = Subscription.objects.create(
            customer=self.customer,
            product=self.product,
            hub=self.hub,
            quantity=1,
            effective_unit_price=Decimal("68.00"),
            schedule_type=Subscription.Schedules.DAILY,
            status=Subscription.Statuses.ACTIVE,
            start_date=today,
        )
        DeliveryTask.objects.create(
            subscription=sub,
            hub=self.hub,
            driver=self.driver,
            address=self.address,
            delivery_date=today,
            status=DeliveryTask.Statuses.DELIVERED,
        )

        self.client.force_authenticate(user=self.manager)
        response = self.client.get("/api/payouts/summary/?period=TODAY")
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        data = response.json()
        self.assertIn("metrics", data)
        self.assertEqual(data["metrics"]["completed_deliveries"], 1)
        self.assertEqual(data["metrics"]["gross_revenue"], 68.0)
        self.assertEqual(data["hub"]["bank_name"], "State Bank of India")
        self.assertEqual(data["hub"]["bank_account_masked"], "•••• 8210")
        self.assertEqual(data["hub"]["upi_id"], "8885199878@upi")

    def test_instant_payout_settlement_and_anti_double_count(self):
        today = date.today()

        # Create 2 delivered tasks
        sub = Subscription.objects.create(
            customer=self.customer,
            product=self.product,
            hub=self.hub,
            quantity=1,
            effective_unit_price=Decimal("68.00"),
            schedule_type=Subscription.Schedules.DAILY,
            status=Subscription.Statuses.ACTIVE,
            start_date=today,
        )
        t1 = DeliveryTask.objects.create(
            subscription=sub,
            hub=self.hub,
            driver=self.driver,
            address=self.address,
            delivery_date=today,
            status=DeliveryTask.Statuses.DELIVERED,
        )
        t2 = DeliveryTask.objects.create(
            subscription=sub,
            hub=self.hub,
            driver=self.driver,
            address=self.address,
            delivery_date=today,
            status=DeliveryTask.Statuses.DELIVERED,
        )

        # Verify initial unsettled balance
        initial_unsettled = calculate_hub_earnings(hub=self.hub, unsettled_only=True)
        self.assertEqual(initial_unsettled["completed_deliveries"], 2)
        self.assertGreater(initial_unsettled["net_withdrawable_amount"], Decimal("0.00"))

        # Trigger Instant Payout via API
        self.client.force_authenticate(user=self.manager)
        response = self.client.post("/api/payouts/", data={}, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        res_data = response.json()
        payout_info = res_data["payout"]
        self.assertIn("PAY-HUBKDD01-", payout_info["id"])
        self.assertEqual(payout_info["status"], "SETTLED ✅")
        self.assertEqual(payout_info["bank_name"], "State Bank of India")
        self.assertEqual(payout_info["bank_account_masked"], "•••• 8210")

        # 1. Verify tasks are stamped with payout_id
        t1.refresh_from_db()
        t2.refresh_from_db()
        self.assertIsNotNone(t1.payout)
        self.assertIsNotNone(t2.payout)
        self.assertEqual(t1.payout.id, t2.payout.id)

        # 2. Verify ANTI-DOUBLE COUNT: subsequent unsettled balance is now ZERO
        after_settlement = calculate_hub_earnings(hub=self.hub, unsettled_only=True)
        self.assertEqual(after_settlement["completed_deliveries"], 0)
        self.assertEqual(after_settlement["net_withdrawable_amount"], Decimal("0.00"))

        # 3. Subsequent payout request without new deliveries returns 400
        repeat_response = self.client.post("/api/payouts/", data={}, format="json")
        self.assertEqual(repeat_response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("No unsettled completed deliveries found", repeat_response.json()["detail"])

    def test_admin_payouts_view(self):
        today = date.today()
        sub = Subscription.objects.create(
            customer=self.customer,
            product=self.product,
            hub=self.hub,
            quantity=1,
            effective_unit_price=Decimal("68.00"),
            schedule_type=Subscription.Schedules.DAILY,
            status=Subscription.Statuses.ACTIVE,
            start_date=today,
        )
        DeliveryTask.objects.create(
            subscription=sub,
            hub=self.hub,
            driver=self.driver,
            address=self.address,
            delivery_date=today,
            status=DeliveryTask.Statuses.DELIVERED,
        )
        payout = execute_hub_payout_settlement(hub=self.hub, manager_user=self.manager)

        self.client.force_authenticate(user=self.admin)
        response = self.client.get("/api/admin/payouts/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertTrue(any(p["id"] == payout.id for p in data))

        # Test Admin Settle Action
        settle_res = self.client.post("/api/admin/payouts/", data={
            "action": "settle",
            "payout_id": payout.id,
            "payment_reference": "NEFT-TEST-778899",
        }, format="json")
        self.assertEqual(settle_res.status_code, status.HTTP_200_OK)
        payout.refresh_from_db()
        self.assertEqual(payout.payment_reference, "NEFT-TEST-778899")
        self.assertEqual(payout.status, ProviderPayout.Statuses.COMPLETED)


if __name__ == "__main__":
    import unittest
    unittest.main()
