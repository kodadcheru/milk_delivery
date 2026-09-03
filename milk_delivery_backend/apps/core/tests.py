from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status

class HealthCheckTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_health_check_endpoint(self):
        response = self.client.get("/api/health/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertEqual(data["status"], "UP")
        self.assertEqual(data["service"], "Pamba Fresh Delivery API")
        self.assertEqual(data["checks"]["database"]["status"], "HEALTHY")
        self.assertIn("uptime", data)
