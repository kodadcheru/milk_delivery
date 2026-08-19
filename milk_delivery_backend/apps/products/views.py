from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Q
from apps.products.models import Category, Product
from apps.products.serializers import CategorySerializer, ProductSerializer


class CategoryListCreateView(generics.ListCreateAPIView):
    queryset = Category.objects.filter(is_active=True).order_by("display_order", "id")
    serializer_class = CategorySerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        include_inactive = self.request.query_params.get("all")
        if include_inactive == "true":
            return Category.objects.all().order_by("display_order", "id")
        return Category.objects.filter(is_active=True).order_by("display_order", "id")


class CategoryDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    permission_classes = [permissions.AllowAny]


class ProductListView(generics.ListCreateAPIView):
    serializer_class = ProductSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        show_all = self.request.query_params.get("all") == "true"
        queryset = Product.objects.all() if show_all else Product.objects.filter(is_available=True)
        category = self.request.query_params.get("category")
        search = self.request.query_params.get("search")

        if category and category != "ALL":
            queryset = queryset.filter(
                Q(category__iexact=category) | 
                Q(category_ref__slug__iexact=category) | 
                Q(category_ref__name__iexact=category)
            )
        if search:
            queryset = queryset.filter(
                Q(name__icontains=search) | 
                Q(description__icontains=search)
            )

        return queryset.order_by("-id")

    def perform_create(self, serializer):
        cat_id = self.request.data.get("category_id") or self.request.data.get("category_ref")
        cat_name = self.request.data.get("category", "MILK")
        cat_obj = None
        if cat_id:
            cat_obj = Category.objects.filter(id=cat_id).first()
        elif cat_name:
            cat_obj = Category.objects.filter(Q(name__iexact=cat_name) | Q(slug__iexact=cat_name)).first()
            if not cat_obj:
                cat_obj = Category.objects.create(name=cat_name)

        serializer.save(
            category=cat_obj.name if cat_obj else cat_name,
            category_ref=cat_obj
        )


class ProductDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer
    permission_classes = [permissions.AllowAny]

    def perform_update(self, serializer):
        cat_id = self.request.data.get("category_id") or self.request.data.get("category_ref")
        cat_name = self.request.data.get("category")
        cat_obj = None
        if cat_id:
            cat_obj = Category.objects.filter(id=cat_id).first()
        elif cat_name:
            cat_obj = Category.objects.filter(Q(name__iexact=cat_name) | Q(slug__iexact=cat_name)).first()

        if cat_obj:
            serializer.save(category=cat_obj.name, category_ref=cat_obj)
        else:
            serializer.save()
