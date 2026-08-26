from rest_framework import generics, permissions, status
from rest_framework.authentication import BasicAuthentication, SessionAuthentication
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Q
from apps.core.pagination import StandardResultsSetPagination
from apps.core.permissions import IsAdminOrStaff, IsAdminOrReadOnly
from apps.products.models import Category, Product
from apps.products.serializers import CategorySerializer, ProductSerializer


class CategoryListCreateView(generics.ListCreateAPIView):
    queryset = Category.objects.filter(is_active=True).order_by("display_order", "id")
    serializer_class = CategorySerializer
    authentication_classes = [JWTAuthentication, SessionAuthentication, BasicAuthentication]
    permission_classes = [IsAdminOrReadOnly]

    def get_queryset(self):
        include_inactive = self.request.query_params.get("all")
        if include_inactive == "true":
            return Category.objects.all().order_by("display_order", "id")
        return Category.objects.filter(is_active=True).order_by("display_order", "id")


class CategoryDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    authentication_classes = [JWTAuthentication, SessionAuthentication, BasicAuthentication]
    permission_classes = [IsAdminOrReadOnly]


class ProductListView(generics.ListCreateAPIView):
    serializer_class = ProductSerializer
    authentication_classes = [JWTAuthentication, SessionAuthentication, BasicAuthentication]
    permission_classes = [IsAdminOrReadOnly]
    pagination_class = StandardResultsSetPagination

    def get_queryset(self):
        show_all = self.request.query_params.get("all") == "true"
        base_qs = Product.objects.select_related("category_ref")
        queryset = base_qs.all() if show_all else base_qs.filter(is_available=True)
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
            try:
                cat_obj = Category.objects.filter(id=int(cat_id)).first()
            except (ValueError, TypeError):
                pass
        if not cat_obj and cat_name:
            cat_obj = Category.objects.filter(Q(name__iexact=str(cat_name).strip()) | Q(slug__iexact=str(cat_name).strip())).first()

        serializer.save(
            category=cat_obj.name if cat_obj else str(cat_name).strip(),
            category_ref=cat_obj
        )


class ProductDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer
    authentication_classes = [JWTAuthentication, SessionAuthentication, BasicAuthentication]
    permission_classes = [IsAdminOrReadOnly]

    def perform_update(self, serializer):
        from apps.products.pricing import update_sibling_product_prices
        cat_id = self.request.data.get("category_id") or self.request.data.get("category_ref")
        cat_name = self.request.data.get("category")
        cat_obj = None
        if cat_id:
            try:
                cat_obj = Category.objects.filter(id=int(cat_id)).first()
            except (ValueError, TypeError):
                pass
        if not cat_obj and cat_name:
            cat_obj = Category.objects.filter(Q(name__iexact=str(cat_name).strip()) | Q(slug__iexact=str(cat_name).strip())).first()

        updated_instance = serializer.save(
            category=cat_obj.name if cat_obj else (cat_name or serializer.instance.category),
            category_ref=cat_obj if cat_obj else serializer.instance.category_ref
        )
        update_sibling_product_prices(updated_instance)


class HubInventoryListUpdateView(APIView):
    authentication_classes = [JWTAuthentication, SessionAuthentication, BasicAuthentication]
    permission_classes = [IsAdminOrReadOnly]

    def get(self, request):
        from apps.accounts.models import User
        from apps.deliveries.models import LocationHub
        from apps.products.models import HubProductInventory
        from apps.products.serializers import HubProductInventorySerializer

        user = getattr(request, "user", None)
        if not (user and user.is_authenticated) and hasattr(request, "_request") and getattr(request._request, "user", None) and request._request.user.is_authenticated:
            user = request._request.user

        hub_id = request.query_params.get("hub_id")
        target_hub = None
        if hub_id:
            try:
                target_hub = LocationHub.objects.filter(pk=int(hub_id)).first()
            except (ValueError, TypeError):
                pass
        if not target_hub and user and user.is_authenticated:
            target_hub = getattr(user, "assigned_hub", None)

        if target_hub:
            products = Product.objects.all()
            for p in products:
                HubProductInventory.objects.get_or_create(
                    hub=target_hub,
                    product=p,
                    defaults={"daily_capacity_slots": 100, "booked_slots": 0, "is_available": True},
                )
            inventories = HubProductInventory.objects.filter(hub=target_hub).select_related("hub", "product")
        elif user and user.is_authenticated and (user.is_staff or getattr(user, "role", "") in (User.Roles.ADMIN, "ADMIN")):
            inventories = HubProductInventory.objects.all().select_related("hub", "product")
        else:
            inventories = HubProductInventory.objects.none()

        serializer = HubProductInventorySerializer(inventories, many=True)
        return Response(serializer.data)

    def post(self, request):
        from apps.accounts.models import User
        from apps.deliveries.models import LocationHub
        from apps.products.models import HubProductInventory
        from apps.products.serializers import HubProductInventorySerializer

        user = getattr(request, "user", None)
        if not (user and user.is_authenticated) and hasattr(request, "_request") and getattr(request._request, "user", None) and request._request.user.is_authenticated:
            user = request._request.user

        product_id = request.data.get("product_id")
        hub_id = request.data.get("hub_id")
        daily_slots = request.data.get("daily_capacity_slots")
        is_avail = request.data.get("is_available")

        hub = None
        if hub_id:
            try:
                hub = LocationHub.objects.filter(pk=int(hub_id)).first()
            except (ValueError, TypeError):
                pass
        if not hub and user and user.is_authenticated and getattr(user, "assigned_hub", None):
            hub = user.assigned_hub

        if not hub:
            return Response({"detail": "Valid hub required to manage capacity slots."}, status=status.HTTP_400_BAD_REQUEST)

        if not product_id or daily_slots is None:
            return Response({"detail": "product_id and daily_capacity_slots are required."}, status=status.HTTP_400_BAD_REQUEST)

        product = Product.objects.filter(id=product_id).first()
        if not product:
            return Response({"detail": "Product not found."}, status=status.HTTP_404_NOT_FOUND)

        inv, _ = HubProductInventory.objects.get_or_create(
            hub=hub,
            product=product,
            defaults={"daily_capacity_slots": int(daily_slots), "booked_slots": 0},
        )
        inv.daily_capacity_slots = int(daily_slots)
        if is_avail is not None:
            inv.is_available = bool(is_avail)
        inv.save()

        return Response(HubProductInventorySerializer(inv).data, status=status.HTTP_200_OK)


class StorefrontConfigView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        from apps.products.models import StorefrontConfig
        from apps.products.serializers import StorefrontConfigSerializer
        config = StorefrontConfig.get_active()
        serializer = StorefrontConfigSerializer(config, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        return self._update_config(request)

    def patch(self, request):
        return self._update_config(request)

    def _update_config(self, request):
        from apps.products.models import StorefrontConfig
        from apps.products.serializers import StorefrontConfigSerializer
        from rest_framework_simplejwt.authentication import JWTAuthentication

        user = request.user
        if not (user and user.is_authenticated):
            try:
                auth_res = JWTAuthentication().authenticate(request)
                if auth_res:
                    user = auth_res[0]
            except Exception:
                pass

        # Allow if authenticated staff/admin or superuser, or if valid admin session exists
        is_authorized = bool(
            user and user.is_authenticated and (
                user.is_staff or 
                user.is_superuser or 
                getattr(user, "role", "") in ["ADMIN", "HUB_MANAGER", "PROVIDER"]
            )
        )

        if not is_authorized:
            # Check if superuser token or session
            if not (request.user and request.user.is_staff):
                return Response({"detail": "Admin authorization required to update storefront settings."}, status=status.HTTP_403_FORBIDDEN)

        config = StorefrontConfig.get_active()
        banner_url = request.data.get("banner_image_url") or request.data.get("raw_banner_image_url")
        headline = request.data.get("headline")
        subtitle = request.data.get("subtitle")
        dispatch_tag = request.data.get("dispatch_tag")
        promo_chip = request.data.get("promo_chip")
        cta_text = request.data.get("cta_text")
        banner_file = request.FILES.get("banner_image")

        if banner_url is not None:
            config.banner_image_url = banner_url.strip()
        if headline is not None:
            config.headline = headline.strip()
        if subtitle is not None:
            config.subtitle = subtitle.strip()
        if dispatch_tag is not None:
            config.dispatch_tag = dispatch_tag.strip()
        if promo_chip is not None:
            config.promo_chip = promo_chip.strip()
        if cta_text is not None:
            config.cta_text = cta_text.strip()
        if banner_file:
            config.banner_image = banner_file

        config.save()
        serializer = StorefrontConfigSerializer(config, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)

