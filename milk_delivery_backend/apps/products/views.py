from rest_framework import generics, permissions
from apps.products.models import Product
from apps.products.serializers import ProductSerializer


class ProductListView(generics.ListCreateAPIView):
    serializer_class = ProductSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        queryset = Product.objects.filter(is_available=True)
        category = self.request.query_params.get("category")
        search = self.request.query_params.get("search")

        if category and category != "ALL":
            queryset = queryset.filter(category=category)
        if search:
            queryset = queryset.filter(name__icontains=search)

        return queryset.order_by("-id")


class ProductDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
