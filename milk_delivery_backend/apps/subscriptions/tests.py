from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from apps.accounts.models import User
from apps.products.models import Product
from apps.subscriptions.models import Subscription

class SubscriptionAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username="9876543210",
            phone="9876543210",
            first_name="Ramesh",
            role=User.Roles.CUSTOMER,
        )
        self.product = Product.objects.create(
            name="Farm Fresh A2 Desi Cow Milk",
            category="MILK",
            price_per_unit=85.0,
            unit_quantity="1 Litre",
            is_available=True,
        )
        self.client.force_authenticate(user=self.user)

    def test_create_subscription(self):
        payload = {
            "product": self.product.id,
            "quantity": 2,
            "schedule_type": Subscription.Schedules.DAILY,
            "start_date": "2026-08-19",
        }
        response = self.client.post("/api/subscriptions/", payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Subscription.objects.count(), 1)
        sub = Subscription.objects.first()
        self.assertEqual(sub.quantity, 2)
        self.assertEqual(sub.status, Subscription.Statuses.ACTIVE)

    def test_pause_and_resume_subscription(self):
        sub = Subscription.objects.create(
            customer=self.user,
            product=self.product,
            quantity=1,
            schedule_type=Subscription.Schedules.DAILY,
            start_date="2026-08-19",
            status=Subscription.Statuses.ACTIVE,
        )

        # Pause
        response = self.client.post(f"/api/subscriptions/{sub.id}/pause/", {
            "start_date": "2026-08-20",
            "end_date": "2026-08-25",
            "reason": "Family trip",
        }, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        sub.refresh_from_db()
        self.assertEqual(sub.status, Subscription.Statuses.PAUSED)

        # Resume
        response = self.client.post(f"/api/subscriptions/{sub.id}/resume/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        sub.refresh_from_db()
        self.assertEqual(sub.status, Subscription.Statuses.ACTIVE)
