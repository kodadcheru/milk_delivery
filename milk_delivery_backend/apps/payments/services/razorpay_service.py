import logging
import hmac
import hashlib
from decimal import Decimal
from django.conf import settings
import razorpay

logger = logging.getLogger(__name__)


class RazorpayService:
    @classmethod
    def get_key_id(cls):
        return getattr(settings, "RAZORPAY_KEY_ID", "") or ""

    @classmethod
    def get_key_secret(cls):
        return getattr(settings, "RAZORPAY_KEY_SECRET", "") or ""

    @classmethod
    def get_client(cls):
        key_id = cls.get_key_id()
        key_secret = cls.get_key_secret()
        if not key_id or not key_secret:
            logger.warning("Razorpay credentials not fully configured in settings.")
        return razorpay.Client(auth=(key_id, key_secret))

    @classmethod
    def create_order(cls, amount, currency="INR", receipt=None, notes=None):
        """
        Creates a Razorpay order. Amount should be a Decimal or float in INR.
        Converts to paise for Razorpay API.
        """
        client = cls.get_client()
        amount_in_paise = int(Decimal(str(amount)) * 100)
        payload = {
            "amount": amount_in_paise,
            "currency": currency,
            "receipt": str(receipt or f"rcpt_{amount_in_paise}"),
            "payment_capture": 1,
        }
        if notes:
            payload["notes"] = notes

        try:
            order = client.order.create(data=payload)
            logger.info("Razorpay order created successfully: %s", order.get("id"))
            return order
        except Exception as e:
            logger.error("Failed to create Razorpay order: %s", e)
            raise

    @classmethod
    def verify_payment_signature(cls, razorpay_order_id, razorpay_payment_id, razorpay_signature):
        """
        Verifies HMAC-SHA256 signature returned by Razorpay Checkout.
        """
        client = cls.get_client()
        params_dict = {
            "razorpay_order_id": razorpay_order_id,
            "razorpay_payment_id": razorpay_payment_id,
            "razorpay_signature": razorpay_signature,
        }
        try:
            client.utility.verify_payment_signature(params_dict)
            return True
        except razorpay.errors.SignatureVerificationError:
            logger.warning("Signature verification failed for Razorpay order %s", razorpay_order_id)
            return False
        except Exception as e:
            logger.error("Unexpected error during signature verification: %s", e)
            # Fallback manual HMAC SHA256 check
            key_secret = cls.get_key_secret().encode("utf-8")
            msg = f"{razorpay_order_id}|{razorpay_payment_id}".encode("utf-8")
            expected_sig = hmac.new(key_secret, msg, hashlib.sha256).hexdigest()
            return hmac.compare_digest(expected_sig, razorpay_signature)
