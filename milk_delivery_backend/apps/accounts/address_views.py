from decimal import Decimal
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from apps.accounts.models import CustomerAddress, User
from apps.accounts.serializers import CustomerAddressSerializer


def _resolve_customer_user(request):
    user = request.user
    if user and user.is_authenticated:
        return user

    phone = request.query_params.get("phone") or request.data.get("phone") or request.data.get("customer_phone")
    customer_id = request.query_params.get("customer_id") or request.data.get("customer_id")

    if phone:
        clean_phone = str(phone).replace("+91", "").replace(" ", "").strip()
        user = User.objects.filter(phone_number__icontains=clean_phone).first()
        if user:
            return user

    if customer_id:
        try:
            user = User.objects.filter(id=int(customer_id)).first()
            if user:
                return user
        except (ValueError, TypeError):
            pass

    return User.objects.filter(role=User.Roles.CUSTOMER).first()


class CustomerAddressListCreateView(generics.ListCreateAPIView):
    serializer_class = CustomerAddressSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        user = _resolve_customer_user(self.request)
        if not user:
            return CustomerAddress.objects.all()

        # If user has an address on profile but no CustomerAddress rows, create primary Home address
        if not CustomerAddress.objects.filter(user=user).exists() and user.address:
            CustomerAddress.objects.create(
                user=user,
                address_type="HOME",
                flat_house_no="2X27+P3X",
                street_address=user.address,
                city=user.city or "Kodad",
                pincode="508206",
                latitude=user.latitude or Decimal("16.9947"),
                longitude=user.longitude or Decimal("79.9750"),
                is_default=True,
            )

        return CustomerAddress.objects.filter(user=user).order_by("-is_default", "-created_at")

    def perform_create(self, serializer):
        user = _resolve_customer_user(self.request)

        # If user has no addresses yet, make this one default
        has_existing = CustomerAddress.objects.filter(user=user).exists() if user else False
        is_default = self.request.data.get("is_default", not has_existing)

        addr = serializer.save(user=user, is_default=is_default)
        
        # Also update user's active delivery profile address
        if user and (is_default or not user.address):
            user.address = addr.street_address or user.address
            user.latitude = addr.latitude
            user.longitude = addr.longitude
            user.save(update_fields=["address", "latitude", "longitude"])


class CustomerAddressDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CustomerAddressSerializer
    permission_classes = [permissions.AllowAny]
    queryset = CustomerAddress.objects.all()

    def perform_update(self, serializer):
        addr = serializer.save()
        user = addr.user
        if user and (addr.is_default or not user.address):
            user.address = addr.street_address or user.address
            user.latitude = addr.latitude
            user.longitude = addr.longitude
            user.save(update_fields=["address", "latitude", "longitude"])

    def perform_destroy(self, instance):
        user = instance.user
        was_default = instance.is_default
        instance.delete()
        if user:
            next_default = CustomerAddress.objects.filter(user=user).first()
            if next_default:
                if was_default:
                    next_default.is_default = True
                    next_default.save()
                user.address = next_default.street_address or user.address
                user.latitude = next_default.latitude
                user.longitude = next_default.longitude
            else:
                user.address = ""
            user.save(update_fields=["address", "latitude", "longitude"])


class CustomerAddressSetDefaultView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request, pk):
        user = _resolve_customer_user(request)
        if not user:
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
