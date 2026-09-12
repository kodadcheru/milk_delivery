from rest_framework import generics, permissions, status
from rest_framework.authentication import BasicAuthentication
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Q
from apps.core.pagination import StandardResultsSetPagination
from apps.core.permissions import IsAdminOrStaff, IsAdminOrReadOnly
from apps.core.authentication import CsrfExemptSessionAuthentication
from apps.products.models import Category, Product
from apps.products.serializers import CategorySerializer, ProductSerializer


class CategoryListCreateView(generics.ListCreateAPIView):
    serializer_class = CategorySerializer
    authentication_classes = [JWTAuthentication, CsrfExemptSessionAuthentication, BasicAuthentication]
    permission_classes = [IsAdminOrReadOnly]

    def get_queryset(self):
        from django.db.models import Count
        include_inactive = self.request.query_params.get("all")
        qs = Category.objects.all() if include_inactive == "true" else Category.objects.filter(is_active=True)
        return qs.annotate(items_count_annotated=Count("products")).order_by("display_order", "id")


class CategoryDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    authentication_classes = [JWTAuthentication, CsrfExemptSessionAuthentication, BasicAuthentication]
    permission_classes = [IsAdminOrReadOnly]


class ProductListView(generics.ListCreateAPIView):
    serializer_class = ProductSerializer
    authentication_classes = [JWTAuthentication, CsrfExemptSessionAuthentication, BasicAuthentication]
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
    authentication_classes = [JWTAuthentication, CsrfExemptSessionAuthentication, BasicAuthentication]
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

        save_kwargs = {}
        if cat_obj:
            save_kwargs["category"] = cat_obj.name
            save_kwargs["category_ref"] = cat_obj
        elif cat_name is not None and str(cat_name).strip():
            save_kwargs["category"] = str(cat_name).strip()

        serializer.save(**save_kwargs)


class ProductToggleSubscriptionView(APIView):
    authentication_classes = [JWTAuthentication, CsrfExemptSessionAuthentication, BasicAuthentication]
    permission_classes = [IsAdminOrReadOnly]

    def post(self, request, pk):
        try:
            prod = Product.objects.get(pk=pk)
        except Product.DoesNotExist:
            return Response({"detail": "Product not found."}, status=status.HTTP_404_NOT_FOUND)

        prod.is_subscription_enabled = not prod.is_subscription_enabled
        prod.save(update_fields=["is_subscription_enabled"])
        return Response({
            "id": prod.id,
            "name": prod.name,
            "is_subscription_enabled": prod.is_subscription_enabled,
            "message": f"Subscriptions {'enabled' if prod.is_subscription_enabled else 'disabled'} for {prod.name}."
        })


class HubInventoryListUpdateView(APIView):
    authentication_classes = [JWTAuthentication, CsrfExemptSessionAuthentication, BasicAuthentication]
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
    authentication_classes = [JWTAuthentication, CsrfExemptSessionAuthentication, BasicAuthentication]
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
            if hasattr(request, "_request") and hasattr(request._request, "user") and request._request.user.is_authenticated:
                user = request._request.user
        if not (user and user.is_authenticated):
            try:
                auth_res = JWTAuthentication().authenticate(request)
                if auth_res:
                    user = auth_res[0]
            except Exception:
                pass

        # Allow if authenticated staff/admin, superuser, or hub manager
        is_authorized = bool(
            user and user.is_authenticated and (
                user.is_staff or 
                user.is_superuser or 
                getattr(user, "role", "") in ["ADMIN", "HUB_MANAGER", "PROVIDER"]
            )
        )

        if not is_authorized:
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
            
        from decimal import Decimal
        from apps.core.models import SiteConfig
        site_cfg = SiteConfig.get()
        has_site_cfg_changes = False

        def _parse_decimal(val, default="0.00"):
            if val is None or str(val).strip() == "":
                return Decimal(default)
            try:
                return Decimal(str(val).strip())
            except Exception:
                return Decimal(default)

        if "platform_fee" in request.data:
            config.platform_fee = _parse_decimal(request.data.get("platform_fee"), "0.00")
            site_cfg.customer_platform_fee = config.platform_fee
            has_site_cfg_changes = True
        if "tax_percentage" in request.data:
            config.tax_percentage = _parse_decimal(request.data.get("tax_percentage"), "0.00")
            site_cfg.tax_percentage = config.tax_percentage
            has_site_cfg_changes = True
        if "delivery_fee" in request.data:
            config.delivery_fee = _parse_decimal(request.data.get("delivery_fee"), "0.00")
            site_cfg.delivery_fee = config.delivery_fee
            has_site_cfg_changes = True
        if "free_delivery_threshold" in request.data:
            config.free_delivery_threshold = _parse_decimal(request.data.get("free_delivery_threshold"), "0.00")
            site_cfg.free_delivery_threshold = config.free_delivery_threshold
            has_site_cfg_changes = True
        if has_site_cfg_changes:
            site_cfg.save()

        is_cod_enabled = request.data.get("is_cod_enabled")
        if is_cod_enabled is not None:
            if isinstance(is_cod_enabled, str):
                config.is_cod_enabled = is_cod_enabled.strip().lower() in ("true", "1", "yes", "t")
            else:
                config.is_cod_enabled = bool(is_cod_enabled)

        is_wallet_enabled = request.data.get("is_wallet_enabled")
        if is_wallet_enabled is not None:
            if isinstance(is_wallet_enabled, str):
                config.is_wallet_enabled = is_wallet_enabled.strip().lower() in ("true", "1", "yes", "t")
            else:
                config.is_wallet_enabled = bool(is_wallet_enabled)

        is_online_payment_enabled = request.data.get("is_online_payment_enabled")
        if is_online_payment_enabled is not None:
            if isinstance(is_online_payment_enabled, str):
                config.is_online_payment_enabled = is_online_payment_enabled.strip().lower() in ("true", "1", "yes", "t")
            else:
                config.is_online_payment_enabled = bool(is_online_payment_enabled)

        config.save()
        serializer = StorefrontConfigSerializer(config, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)


from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def cross_sell_products(request):
    """
    Returns 6-8 complementary products based on cart contents.
    Query params: cart_ids=1,5,12 (comma-separated product IDs in cart)
    """
    cart_ids_str = request.query_params.get('cart_ids', '')
    cart_ids = [int(x) for x in cart_ids_str.split(',') if x.strip().isdigit()]
    
    # Get categories of products in cart
    cart_products = Product.objects.filter(id__in=cart_ids)
    cart_categories = set(cart_products.values_list('category_ref_id', flat=True))
    # Also get text categories for fallback
    cart_text_categories = set(cart_products.values_list('category', flat=True))
    
    # Strategy:
    # 1. Products from same categories (different items) - highest priority
    # 2. Products from adjacent/complementary categories
    # 3. Popular available products as fallback
    
    suggestions = Product.objects.filter(
        is_available=True
    ).exclude(
        id__in=cart_ids
    ).order_by('?')  # Random ordering for variety
    
    # Prioritize same-category products first
    same_category = suggestions.filter(
        category_ref_id__in=cart_categories
    )[:4]
    
    # Then other categories
    other_category = suggestions.exclude(
        category_ref_id__in=cart_categories
    )[:4]
    
    # Combine, limit to 8
    combined_ids = list(same_category.values_list('id', flat=True)) + list(other_category.values_list('id', flat=True))
    result = Product.objects.filter(id__in=combined_ids[:8], is_available=True)
    
    serializer = ProductSerializer(result, many=True)
    return Response(serializer.data)
