from decimal import Decimal
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from apps.accounts.models import CustomerAddress, User
from apps.accounts.serializers import CustomerAddressSerializer


def _clean_phone_digits(phone_str):
    if not phone_str:
        return ""
    digits = "".join(filter(str.isdigit, str(phone_str)))
    return digits[-10:] if len(digits) >= 10 else digits


def _find_user_by_phone(phone_str):
    last_10 = _clean_phone_digits(phone_str)
    if not last_10:
        return None
    return (
        User.objects.filter(phone__endswith=last_10).first()
        or User.objects.filter(phone__icontains=last_10).first()
        or User.objects.filter(username=phone_str).first()
    )


def _resolve_customer_user(request):
    user = request.user
    
    # 1. If staff/admin requesting specific customer, resolve that customer
    if user and user.is_authenticated and (user.is_staff or getattr(user, 'role', '') in ('ADMIN', 'PROVIDER', 'HUB_MANAGER')):
        customer_id = request.query_params.get('customer_id') or request.data.get('customer_id')
        phone = request.query_params.get('phone') or request.data.get('phone') or request.data.get('customer_phone')
        
        if customer_id:
            try:
                found_user = User.objects.filter(id=int(customer_id)).first()
                if found_user:
                    return found_user
            except (ValueError, TypeError):
                pass
                
        if phone:
            found_user = _find_user_by_phone(phone)
            if found_user:
                return found_user
    
    # 2. Authenticated user
    if user and user.is_authenticated:
        return user

    # 3. Fallback for unauthenticated / token-refresh gap
    phone = request.query_params.get("phone") or request.data.get("phone") or request.data.get("customer_phone")
    customer_id = request.query_params.get("customer_id") or request.data.get("customer_id")

    if phone:
        found_user = _find_user_by_phone(phone)
        if found_user:
            return found_user

    if customer_id:
        try:
            found_user = User.objects.filter(id=int(customer_id)).first()
            if found_user:
                return found_user
        except (ValueError, TypeError):
            pass

    return None


class CustomerAddressListCreateView(generics.ListCreateAPIView):
    serializer_class = CustomerAddressSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        user = _resolve_customer_user(self.request)
        if not user:
            return CustomerAddress.objects.none()

        from django.db.models import Q
        user_query = Q(user=user)
        clean_digits = _clean_phone_digits(user.phone or getattr(user, 'username', ''))
        if clean_digits:
            user_query |= Q(user__phone__endswith=clean_digits) | Q(user__username__icontains=clean_digits)
        return CustomerAddress.objects.filter(user_query).order_by("-is_default", "-id")

    def perform_create(self, serializer):
        user = _resolve_customer_user(self.request)
        if not user:
            from rest_framework.exceptions import NotAuthenticated
            raise NotAuthenticated("Authentication required to save address.")

        from django.db.models import Q
        clean_digits = _clean_phone_digits(user.phone or getattr(user, 'username', ''))
        user_query = Q(user=user)
        if clean_digits:
            user_query |= Q(user__phone__endswith=clean_digits) | Q(user__username__icontains=clean_digits)

        has_existing = CustomerAddress.objects.filter(user_query).exists()
        is_default = bool(self.request.data.get("is_default", not has_existing))

        if is_default:
            CustomerAddress.objects.filter(user_query).update(is_default=False)

        addr = serializer.save(user=user, is_default=is_default)

        # Update user's active delivery profile address
        formatted = addr.formatted_address or addr.street_address
        if is_default or not user.address:
            user.address = formatted or user.address
            user.latitude = addr.latitude
            user.longitude = addr.longitude
            user.save(update_fields=["address", "latitude", "longitude"])
            if clean_digits:
                User.objects.filter(phone__endswith=clean_digits).exclude(id=user.id).update(
                    address=user.address, latitude=user.latitude, longitude=user.longitude
                )


class CustomerAddressDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CustomerAddressSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        if self.request.user and self.request.user.is_authenticated and self.request.user.is_staff:
            return CustomerAddress.objects.all()
        user = _resolve_customer_user(self.request)
        if not user:
            return CustomerAddress.objects.none()
        return CustomerAddress.objects.filter(user=user)

    def perform_update(self, serializer):
        user = _resolve_customer_user(self.request)
        is_default = serializer.validated_data.get("is_default", False)

        if user and is_default:
            CustomerAddress.objects.filter(user=user).exclude(pk=serializer.instance.pk).update(is_default=False)

        addr = serializer.save(user=user if user else serializer.instance.user)
        target_user = user or addr.user

        if target_user and (addr.is_default or not target_user.address):
            target_user.address = addr.street_address or target_user.address
            target_user.latitude = addr.latitude
            target_user.longitude = addr.longitude
            target_user.save(update_fields=["address", "latitude", "longitude"])

    def perform_destroy(self, instance):
        user = instance.user
        was_default = instance.is_default
        instance.delete()
        if user:
            next_default = CustomerAddress.objects.filter(user=user).first()
            if next_default:
                if was_default:
                    next_default.is_default = True
                    next_default.save(update_fields=["is_default"])
                user.address = next_default.street_address or user.address
                user.latitude = next_default.latitude
                user.longitude = next_default.longitude
                user.save(update_fields=["address", "latitude", "longitude"])


class CustomerAddressSetDefaultView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request, pk):
        user = request.user if request.user and request.user.is_authenticated else _resolve_customer_user(request)
        if not user:
            return Response({"detail": "Authentication required"}, status=status.HTTP_401_UNAUTHORIZED)
            
        if request.user and request.user.is_authenticated and request.user.is_staff:
            try:
                addr = CustomerAddress.objects.get(pk=pk)
            except CustomerAddress.DoesNotExist:
                return Response({"detail": "Address not found"}, status=status.HTTP_404_NOT_FOUND)
        else:
            try:
                addr = CustomerAddress.objects.get(pk=pk, user=user)
            except CustomerAddress.DoesNotExist:
                return Response({"detail": "Address not found"}, status=status.HTTP_404_NOT_FOUND)

        CustomerAddress.objects.filter(user=addr.user).update(is_default=False)
        addr.is_default = True
        addr.save(update_fields=["is_default"])

        addr.user.address = addr.street_address or addr.user.address
        addr.user.latitude = addr.latitude
        addr.user.longitude = addr.longitude
        addr.user.save(update_fields=["address", "latitude", "longitude"])

        return Response({
            "message": f"'{addr.get_address_type_display()}' set as primary delivery address",
            "address": CustomerAddressSerializer(addr).data,
        }, status=status.HTTP_200_OK)
