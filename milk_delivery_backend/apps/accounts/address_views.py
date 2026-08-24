from decimal import Decimal
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from apps.accounts.models import CustomerAddress, User
from apps.accounts.serializers import CustomerAddressSerializer


def _resolve_customer_user(request):
    user = request.user
    
    # If staff/admin requesting specific customer, resolve that customer
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
            clean_phone = str(phone).replace("+91", "").replace(" ", "").strip()
            found_user = User.objects.filter(phone__icontains=clean_phone).first()
            if found_user:
                return found_user
    
    # Default: return the authenticated user
    if user and user.is_authenticated:
        return user

    # Fallback for unauthenticated
    phone = request.query_params.get("phone") or request.data.get("phone") or request.data.get("customer_phone")
    customer_id = request.query_params.get("customer_id") or request.data.get("customer_id")

    if phone:
        clean_phone = str(phone).replace("+91", "").replace(" ", "").strip()
        found_user = User.objects.filter(phone__icontains=clean_phone).first()
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
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = _resolve_customer_user(self.request)
        if not user:
            return CustomerAddress.objects.none() if self.request.user.is_authenticated else CustomerAddress.objects.all()

        return CustomerAddress.objects.filter(user=user).order_by("-is_default", "-id")

    def perform_create(self, serializer):
        user = _resolve_customer_user(self.request)
        if not user:
            raise permissions.exceptions.NotAuthenticated("Authentication required to save address.")

        has_existing = CustomerAddress.objects.filter(user=user).exists()
        is_default = self.request.data.get("is_default", not has_existing)

        if is_default:
            CustomerAddress.objects.filter(user=user).update(is_default=False)

        addr = serializer.save(user=user, is_default=is_default)

        # Update user's active delivery profile address
        if is_default or not user.address:
            user.address = addr.street_address or user.address
            user.latitude = addr.latitude
            user.longitude = addr.longitude
            user.save(update_fields=["address", "latitude", "longitude"])


class CustomerAddressDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CustomerAddressSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        if self.request.user.is_staff:
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
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        user = request.user if request.user and request.user.is_authenticated else _resolve_customer_user(request)
        if not user:
            return Response({"detail": "Authentication required"}, status=status.HTTP_401_UNAUTHORIZED)
            
        if request.user.is_staff:
            addr = CustomerAddress.objects.filter(pk=pk).first()
        else:
            addr = CustomerAddress.objects.filter(pk=pk, user=user).first()

        if not addr:
            return Response({"detail": "Address not found"}, status=status.HTTP_404_NOT_FOUND)

        if user:
            CustomerAddress.objects.filter(user=user).exclude(pk=addr.pk).update(is_default=False)
        addr.is_default = True
        addr.save()

        # Update user active profile
        if user:
            user.address = addr.street_address or user.address
            user.latitude = addr.latitude
            user.longitude = addr.longitude
            user.save(update_fields=["address", "latitude", "longitude"])

        return Response({
            "message": f"'{addr.get_address_type_display()}' set as primary delivery address",
            "address": CustomerAddressSerializer(addr).data,
        })
