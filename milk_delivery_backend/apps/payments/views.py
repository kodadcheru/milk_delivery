import logging
from decimal import Decimal
from django.conf import settings
from django.db import transaction
from django.db.models import F, Q, Sum
from django.utils.decorators import method_decorator
from apps.core.permissions import IsAdminOrStaff, IsAdminOrHubManager
from django.views.decorators.csrf import csrf_exempt
from rest_framework import permissions, status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import Notification, User, WalletTransaction
from apps.core.services.push_service import send_push_to_user
from apps.deliveries.models import LiveOrder
from apps.products.models import StorefrontConfig
from apps.core.models import SiteConfig

from .models import RazorpayPayment
from .serializers import (
    CreateRazorpayOrderSerializer,
    RazorpayPaymentSerializer,
    VerifyRazorpayPaymentSerializer,
)
from .services.razorpay_service import RazorpayService

logger = logging.getLogger(__name__)


class RazorpayConfigView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        store_cfg = StorefrontConfig.get_active()
        is_enabled = getattr(store_cfg, "is_online_payment_enabled", True)
        return Response({
            "key_id": RazorpayService.get_key_id(),
            "is_enabled": is_enabled,
            "currency": "INR",
        })


class RazorpayCreateOrderView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        store_cfg = StorefrontConfig.get_active()
        if not getattr(store_cfg, "is_online_payment_enabled", True):
            return Response(
                {"detail": "Online payment via Razorpay is currently disabled by store admin."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = CreateRazorpayOrderSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        amount = serializer.validated_data["amount"]
        purpose = serializer.validated_data["purpose"]
        order_id = serializer.validated_data.get("order_id")
        notes = serializer.validated_data.get("notes", {})

        target_order = None
        if purpose == RazorpayPayment.Purpose.WALLET_TOPUP:
            if amount > SiteConfig.get().max_wallet_topup:
                return Response(
                    {"detail": f"Maximum single top-up limit is ₹{SiteConfig.get().max_wallet_topup}."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            notes["purpose"] = "WALLET_TOPUP"
            notes["user_id"] = str(request.user.id)
            notes["phone"] = str(request.user.phone)
        elif purpose == RazorpayPayment.Purpose.ORDER_PAYMENT:
            if order_id:
                target_order = LiveOrder.objects.filter(id=order_id, customer=request.user).first()
                if not target_order:
                    return Response(
                        {"detail": f"Order #{order_id} not found for this customer."},
                        status=status.HTTP_404_NOT_FOUND,
                    )
            notes["purpose"] = "ORDER_PAYMENT"
            notes["order_id"] = str(order_id) if order_id else ""

        user_name = request.user.get_full_name() or request.user.username or "Pamba Customer"
        receipt_ref = f"rcpt_{request.user.id}_{purpose[:3]}_{int(amount)}"

        amount_paise = int(Decimal(str(amount)) * 100)

        error_detail = None
        try:
            rzp_order = RazorpayService.create_order(
                amount=amount,
                currency="INR",
                receipt=receipt_ref,
                notes=notes,
            )
            rzp_order_id = rzp_order["id"]
            amount_paise = rzp_order.get("amount", amount_paise)
        except Exception as e:
            logger.error("Razorpay order creation failed: %s", e, exc_info=True)
            return Response(
                {"success": False, "detail": "Payment gateway is temporarily unavailable. Please try again later."},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        payment_record = RazorpayPayment.objects.create(
            user=request.user,
            purpose=purpose,
            order=target_order,
            amount=amount,
            currency="INR",
            razorpay_order_id=rzp_order_id,
            status=RazorpayPayment.Status.PENDING,
            metadata=rzp_order,
        )

        return Response(
            {
                "success": True,
                "razorpay_order_id": rzp_order_id,
                "amount": str(amount),
                "amount_paise": amount_paise,
                "currency": rzp_order.get("currency", "INR"),
                "key_id": RazorpayService.get_key_id(),
                "error_detail": error_detail,
                "purpose": purpose,
                "user": {
                    "name": user_name,
                    "email": request.user.email or "customer@pamba.in",
                    "phone": str(request.user.phone or ""),
                },
                "payment_id": payment_record.id,
            },
            status=status.HTTP_201_CREATED,
        )


class RazorpayVerifyPaymentView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = VerifyRazorpayPaymentSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        rzp_order_id = serializer.validated_data["razorpay_order_id"]
        rzp_payment_id = serializer.validated_data["razorpay_payment_id"]
        rzp_signature = serializer.validated_data["razorpay_signature"]

        with transaction.atomic():
            payment = RazorpayPayment.objects.select_for_update().filter(
                razorpay_order_id=rzp_order_id,
                user=request.user,
            ).first()

            if not payment:
                return Response(
                    {"detail": "Payment order record not found."},
                    status=status.HTTP_404_NOT_FOUND,
                )

            if payment.status == RazorpayPayment.Status.SUCCESS:
                user = request.user
                user.refresh_from_db()
                return Response(
                    {
                        "success": True,
                        "message": "Payment already verified.",
                        "new_wallet_balance": str(user.wallet_balance),
                        "payment": RazorpayPaymentSerializer(payment).data,
                    },
                    status=status.HTTP_200_OK,
                )

            is_valid = RazorpayService.verify_payment_signature(
                razorpay_order_id=rzp_order_id,
                razorpay_payment_id=rzp_payment_id,
                razorpay_signature=rzp_signature,
            )

            if not is_valid:
                payment.status = RazorpayPayment.Status.FAILED
                payment.razorpay_payment_id = rzp_payment_id
                payment.razorpay_signature = rzp_signature
                payment.error_description = "Cryptographic signature verification failed"
                payment.save(update_fields=["status", "razorpay_payment_id", "razorpay_signature", "error_description", "updated_at"])
                return Response(
                    {"detail": "Payment signature verification failed. Untrusted payment."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            user = request.user

            payment.status = RazorpayPayment.Status.SUCCESS
            payment.razorpay_payment_id = rzp_payment_id
            payment.razorpay_signature = rzp_signature
            payment.save(update_fields=["status", "razorpay_payment_id", "razorpay_signature", "updated_at"])

            if payment.purpose == RazorpayPayment.Purpose.WALLET_TOPUP:
                User.objects.filter(pk=user.pk).update(wallet_balance=F("wallet_balance") + payment.amount)
                user.refresh_from_db()

                tx = WalletTransaction.objects.create(
                    user=user,
                    amount=payment.amount,
                    transaction_type=WalletTransaction.Types.CREDIT,
                    description=f"Recharge via Razorpay Online Pay (Ref: {rzp_payment_id})",
                )

                Notification.objects.create(
                    user=user,
                    title="⚡ Wallet Recharged via Razorpay",
                    message=f"₹{payment.amount} credited to your prepaid wallet. New balance: ₹{user.wallet_balance}",
                    notification_type=Notification.Types.WALLET,
                    target_screen="WALLET",
                )

                try:
                    send_push_to_user(
                        user=user,
                        title="⚡ Wallet Recharged via Razorpay",
                        body=f"₹{payment.amount} credited to your prepaid wallet. New balance: ₹{user.wallet_balance}",
                        target_screen="WALLET",
                    )
                except Exception as e:
                    logger.warning(f"Notification failed: {e}")

            elif payment.purpose == RazorpayPayment.Purpose.ORDER_PAYMENT and payment.order:
                payment.order.payment_method = "RAZORPAY"
                payment.order.payment_status = "PAID"
                payment.order.save(update_fields=["payment_method", "payment_status", "updated_at"])

        return Response(
            {
                "success": True,
                "message": "Payment verified and processed successfully.",
                "new_wallet_balance": str(user.wallet_balance),
                "payment": RazorpayPaymentSerializer(payment).data,
            },
            status=status.HTTP_200_OK,
        )


@method_decorator(csrf_exempt, name='dispatch')
class RazorpayWebhookView(APIView):
    permission_classes = [AllowAny]  # Razorpay sends webhooks without auth
    authentication_classes = []  # No auth needed

    def post(self, request):
        import hmac
        import hashlib

        webhook_secret = getattr(settings, 'RAZORPAY_WEBHOOK_SECRET', settings.RAZORPAY_KEY_SECRET)
        signature = request.headers.get('X-Razorpay-Signature', '')
        body = request.body

        # Verify webhook signature
        expected = hmac.new(
            webhook_secret.encode('utf-8'),
            body,
            hashlib.sha256
        ).hexdigest()

        if not hmac.compare_digest(expected, signature):
            return Response({'status': 'invalid_signature'}, status=200)

        payload = request.data
        event = payload.get('event', '')

        try:
            if event == 'payment.captured':
                payment_entity = payload.get('payload', {}).get('payment', {}).get('entity', {})
                order_id = payment_entity.get('order_id')
                payment_id = payment_entity.get('id')

                if order_id:
                    from apps.payments.models import RazorpayPayment
                    from django.db import transaction
                    from django.db.models import F

                    try:
                        with transaction.atomic():
                            rp = RazorpayPayment.objects.select_for_update().get(razorpay_order_id=order_id)
                            if rp.status != 'SUCCESS':  # Idempotent
                                rp.razorpay_payment_id = payment_id
                                rp.status = 'SUCCESS'
                                rp.save(update_fields=['razorpay_payment_id', 'status', 'updated_at'])

                                if rp.purpose == RazorpayPayment.Purpose.WALLET_TOPUP:
                                    # Credit wallet for wallet recharge
                                    from django.contrib.auth import get_user_model
                                    User = get_user_model()
                                    User.objects.filter(pk=rp.user_id).update(
                                        wallet_balance=F('wallet_balance') + rp.amount
                                    )

                                    # Create wallet transaction
                                    from apps.accounts.models import WalletTransaction
                                    WalletTransaction.objects.create(
                                        user=rp.user,
                                        transaction_type=WalletTransaction.Types.CREDIT,
                                        amount=rp.amount,
                                        description=f'Razorpay payment {payment_id} (webhook)',
                                    )
                                elif rp.purpose == RazorpayPayment.Purpose.ORDER_PAYMENT and rp.order:
                                    rp.order.payment_method = "RAZORPAY"
                                    rp.order.payment_status = "PAID"
                                    rp.order.save(update_fields=["payment_method", "payment_status", "updated_at"])
                    except RazorpayPayment.DoesNotExist:
                        logger.warning(f"RazorpayPayment not found for order {order_id} in webhook")
                        pass

            elif event == 'payment.failed':
                payment_entity = payload.get('payload', {}).get('payment', {}).get('entity', {})
                order_id = payment_entity.get('order_id')
                if order_id:
                    from apps.payments.models import RazorpayPayment
                    RazorpayPayment.objects.filter(
                        razorpay_order_id=order_id,
                        status='PENDING'
                    ).update(status='FAILED')
        except Exception as e:
            logger.error(f"Error processing Razorpay webhook: {e}", exc_info=True)
            # Always return 200 to Razorpay to acknowledge webhook receipt

        return Response({'status': 'ok'}, status=200)


class AdminRazorpayPaymentsListView(APIView):
    permission_classes = [IsAdminOrHubManager]

    def get(self, request):
        qs = RazorpayPayment.objects.select_related("user", "order").all()

        # Status filter
        status_filter = request.query_params.get("status", "").strip().upper()
        if status_filter and status_filter != "ALL":
            qs = qs.filter(status=status_filter)

        # Purpose filter
        purpose_filter = request.query_params.get("purpose", "").strip().upper()
        if purpose_filter and purpose_filter != "ALL":
            qs = qs.filter(purpose=purpose_filter)

        # Search query
        q = request.query_params.get("q", "").strip()
        if q:
            qs = qs.filter(
                Q(razorpay_payment_id__icontains=q)
                | Q(razorpay_order_id__icontains=q)
                | Q(user__username__icontains=q)
                | Q(user__phone__icontains=q)
                | Q(user__first_name__icontains=q)
                | Q(user__last_name__icontains=q)
                | Q(order__id__icontains=q)
            )

        # Global aggregate stats
        all_payments = RazorpayPayment.objects.all()
        success_qs = all_payments.filter(status=RazorpayPayment.Status.SUCCESS)
        total_collected = success_qs.aggregate(total=Sum("amount"))["total"] or Decimal("0.00")
        success_count = success_qs.count()
        pending_count = all_payments.filter(status=RazorpayPayment.Status.PENDING).count()
        failed_count = all_payments.filter(status=RazorpayPayment.Status.FAILED).count()
        wallet_topup_total = success_qs.filter(purpose=RazorpayPayment.Purpose.WALLET_TOPUP).aggregate(total=Sum("amount"))["total"] or Decimal("0.00")
        order_payment_total = success_qs.filter(purpose=RazorpayPayment.Purpose.ORDER_PAYMENT).aggregate(total=Sum("amount"))["total"] or Decimal("0.00")

        # Latest 300 transactions
        payments = qs.order_by("-created_at")[:300]

        results = []
        for p in payments:
            user_data = None
            if p.user:
                user_data = {
                    "id": p.user.id,
                    "name": p.user.get_full_name() or p.user.username or "Customer",
                    "phone": str(p.user.phone or ""),
                    "email": p.user.email or "",
                    "customer_code": getattr(p.user, "customer_code", f"CUST-{p.user.id}"),
                }

            order_info = None
            if p.order:
                order_info = {
                    "id": p.order.id,
                    "total_amount": str(p.order.total_amount),
                    "status": p.order.status,
                }

            meta = p.metadata or {}
            method = meta.get("method") or meta.get("payment_method")
            if not method and isinstance(meta.get("notes"), dict):
                method = meta["notes"].get("method")

            results.append({
                "id": p.id,
                "razorpay_order_id": p.razorpay_order_id,
                "razorpay_payment_id": p.razorpay_payment_id or "",
                "amount": str(p.amount),
                "currency": p.currency,
                "status": p.status,
                "purpose": p.purpose,
                "purpose_display": p.get_purpose_display(),
                "payment_method": (method or "Online").upper(),
                "user": user_data,
                "order": order_info,
                "error_description": p.error_description or "",
                "created_at": p.created_at.isoformat() if p.created_at else None,
                "metadata": meta,
            })

        return Response({
            "stats": {
                "total_collected": str(total_collected),
                "success_count": success_count,
                "pending_count": pending_count,
                "failed_count": failed_count,
                "wallet_topup_total": str(wallet_topup_total),
                "order_payment_total": str(order_payment_total),
            },
            "count": len(results),
            "results": results,
        })

