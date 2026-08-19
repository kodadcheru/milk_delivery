from decimal import Decimal
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from apps.accounts.models import CustomerAddress, User
from apps.accounts.serializers import CustomerAddressSerializer


class CustomerAddressListCreateView(generics.ListCreateAPIView):
    serializer_class = CustomerAddressSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        user = self.request.user
        if not user or not user.is_authenticated:
            return CustomerAddress.objects.none()
        return CustomerAddress.objects.filter(user=user).order_by("-is_default", "-created_at")

    def perform_create(self, serializer):
        user = self.request.user
        if not user or not user.is_authenticated:
            user = User.objects.filter(role=User.Roles.CUSTOMER).first()

        # If user has no addresses yet, make this one default
        has_existing = CustomerAddress.objects.filter(user=user).exists()
        is_default = self.request.data.get("is_default", not has_existing)

        addr = serializer.save(user=user, is_default=is_default)
        
        # Also update user's active delivery profile address
        if is_default or not user.address:
            user.address = addr.street_address or user.address
            user.latitude = addr.latitude
            user.longitude = addr.longitude
            user.save(update_fields=["address", "latitude", "longitude"])


class CustomerAddressDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CustomerAddressSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        user = self.request.user
        if not user or not user.is_authenticated:
            user = User.objects.filter(role=User.Roles.CUSTOMER).first()
        if not user:
            return CustomerAddress.objects.all()
        return CustomerAddress.objects.filter(user=user)


class CustomerAddressSetDefaultView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request, pk):
        user = request.user
        if not user or not user.is_authenticated:
            user = User.objects.filter(role=User.Roles.CUSTOMER).first()

        addr = CustomerAddress.objects.filter(pk=pk, user=user).first()
        if not addr:
            return Response({"detail": "Address not found"}, status=status.HTTP_404_NOT_FOUND)

        addr.is_default = True
        addr.save()

        # Update user active profile
        user.address = addr.street_address or user.address
        user.latitude = addr.latitude
        user.longitude = addr.longitude
        user.save(update_fields=["address", "latitude", "longitude"])

        return Response({
            "message": f"'{addr.get_address_type_display()}' set as primary delivery address",
            "address": CustomerAddressSerializer(addr).data,
        })
