import json
import logging
import urllib.request
import urllib.error
from apps.core.models import SiteConfig

import os

logger = logging.getLogger("pamba.sms")

NINZASMS_ENDPOINT = "https://ninzasms.in.net/auth/send_sms.php"


def send_otp_sms(phone_10_digits: str, otp_code: str) -> dict:
    """
    Sends a 6-digit OTP SMS to an Indian mobile number via NinzaSMS API.
    Returns: {"success": bool, "message": str, "balance": float or None}
    """
    try:
        cfg = SiteConfig.get()
        enabled = getattr(cfg, "ninzasms_enabled", True)
        api_key = (
            getattr(cfg, "ninzasms_api_key", "")
            or os.environ.get("NINZASMS_API_KEY")
            or ""
        )
        sender_id = (
            getattr(cfg, "ninzasms_sender_id", "")
            or os.environ.get("NINZASMS_SENDER_ID")
            or ""
        )
    except Exception as e:
        logger.warning(f"SiteConfig access error ({e}), falling back to environment variables.")
        enabled = os.environ.get("NINZASMS_ENABLED", "True").lower() in ("1", "true", "yes")
        api_key = os.environ.get("NINZASMS_API_KEY", "")
        sender_id = os.environ.get("NINZASMS_SENDER_ID", "")

    if not enabled:
        logger.info(f"SMS Gateway disabled. OTP for {phone_10_digits}: {otp_code}")
        return {"success": True, "message": "SMS gateway disabled (mock mode)", "mock": True}

    payload = {
        "sender_id": sender_id,
        "numbers": str(phone_10_digits).strip(),
        "rout": "sms",
        "variables_values": str(otp_code),
    }

    headers = {
        "Authorization": api_key,
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }

    try:
        data_bytes = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            NINZASMS_ENDPOINT,
            data=data_bytes,
            headers=headers,
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            resp_body = resp.read().decode("utf-8")
            res_json = json.loads(resp_body)

            # NinzaSMS returns status: 1 on success
            if res_json.get("status") == 1:
                logger.info(f"NinzaSMS: OTP sent to {phone_10_digits}. Balance: {res_json.get('balance')}")
                return {
                    "success": True,
                    "message": res_json.get("msg", "OTP Sent Successfully"),
                    "balance": res_json.get("balance"),
                }
            else:
                err_msg = res_json.get("msg", "Failed to dispatch SMS")
                logger.error(f"NinzaSMS error response for {phone_10_digits}: {err_msg}")
                return {"success": False, "message": err_msg}

    except urllib.error.HTTPError as e:
        err_text = e.read().decode("utf-8") if e.fp else str(e)
        logger.error(f"NinzaSMS HTTP error {e.code}: {err_text}")
        return {"success": False, "message": f"Gateway HTTP {e.code}"}
    except Exception as e:
        logger.error(f"NinzaSMS unexpected error: {str(e)}")
        return {"success": False, "message": str(e)}
