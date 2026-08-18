from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from apps.products.models import Product

class ProductAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.milk = Product.objects.create(
            name="Farm Fresh A2 Desi Cow Milk",
            category=Product.Categories.MILK,
            price_per_unit=85.0,
            unit_quantity="1 Litre",
            is_available=True,
        )
        self.meat = Product.objects.create(
            name="Tender Curry-Cut Chicken",
            category=Product.Categories.MEAT,
            price_per_unit=240.0,
            unit_quantity="500 gm",
            is_available=True,
        )
        self.eggs = Product.objects.create(
            name="Country Free-Range Desi Eggs",
            category=Product.Categories.EGGS,
            price_per_unit=90.0,
            unit_quantity="Pack of 6",
            is_available=True,
        )
        self.water = Product.objects.create(
            name="20L Mineral RO Water Can",
            category=Product.Categories.WATER_CAN,
            price_per_unit=60.0,
            unit_quantity="20 Litres",
            is_available=True,
        )

    def test_list_all_products(self):
        response = self.client.get("/api/products/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertEqual(len(data), 4)

    def test_filter_products_by_category(self):
        response = self.client.get("/api/products/?category=MILK")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]["name"], "Farm Fresh A2 Desi Cow Milk")

        response = self.client.get("/api/products/?category=WATER_CAN")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]["name"], "20L Mineral RO Water Can")
