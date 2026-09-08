import os
import json
import logging
from typing import Optional, Dict, Any, List

logger = logging.getLogger("pamba.push")

_firebase_initialized = False
_firebase_app = None


def get_firebase_app():
    """
    Safely initialize and retrieve the Firebase Admin App instance.
    Supports either:
      1. FIREBASE_CREDENTIALS_JSON (raw JSON string in env var)
      2. FIREBASE_SERVICE_ACCOUNT_PATH (file path in env var)
      3. Default credentials (ADC) if available
    Returns None if unconfigured, allowing safe fallback without crashing.
    """
    global _firebase_initialized, _firebase_app
    if _firebase_initialized:
        return _firebase_app

    try:
        import firebase_admin
        from firebase_admin import credentials

        # Check existing apps
        if firebase_admin._apps:
            _firebase_app = firebase_admin.get_app()
            _firebase_initialized = True
            logger.info("FCM: Using existing Firebase App")
            return _firebase_app

        cred_json = os.getenv("FIREBASE_CREDENTIALS_JSON")
        cred_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH")
        if not cred_path:
            try:
                from django.conf import settings
                candidate = os.path.join(getattr(settings, "BASE_DIR", ""), "firebase_credentials.json")
                if os.path.exists(candidate):
                    cred_path = candidate
            except Exception:
                pass

        if cred_json:
            try:
                cred_dict = json.loads(cred_json)
                cred = credentials.Certificate(cred_dict)
                _firebase_app = firebase_admin.initialize_app(cred)
                _firebase_initialized = True
                logger.info("FCM: Initialized Firebase via FIREBASE_CREDENTIALS_JSON")
                return _firebase_app
            except Exception as e:
                logger.error(f"FCM: Failed to parse FIREBASE_CREDENTIALS_JSON: {e}")

        elif cred_path and os.path.exists(cred_path):
            try:
                cred = credentials.Certificate(cred_path)
                _firebase_app = firebase_admin.initialize_app(cred)
                _firebase_initialized = True
                logger.info(f"FCM: Initialized Firebase via path {cred_path}")
                return _firebase_app
            except Exception as e:
                logger.error(f"FCM: Failed to load service account file at {cred_path}: {e}")

        logger.info("FCM: No Firebase credentials configured. Push notifications will run in mock/log mode.")
    except ImportError:
        logger.warning("FCM: firebase-admin package is not installed. Push notifications disabled.")
    except Exception as e:
        logger.error(f"FCM: Unexpected error initializing Firebase: {e}")

    _firebase_initialized = True
    return None


def send_push_to_tokens(
    tokens: List[str],
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None,
    badge: Optional[int] = None
) -> Dict[str, Any]:
    """
    Sends a multicast push notification to a list of device tokens.
    Deactivates tokens that are reported as unregistered/invalid by FCM.
    """
    if not tokens:
        return {"success_count": 0, "failure_count": 0, "status": "no_tokens"}

    app = get_firebase_app()
    if not app:
        logger.info(f"[FCM Mock] Push to {len(tokens)} token(s) | Title: '{title}' | Body: '{body}'")
        return {"success_count": len(tokens), "failure_count": 0, "status": "mocked"}

    try:
        from firebase_admin import messaging
        from apps.accounts.models import DeviceToken

        # Prepare stringified data dictionary for FCM
        str_data = {}
        if data:
            for k, v in data.items():
                str_data[str(k)] = str(v)

        # iOS APNs specific payload (sound, badge, critical headers)
        apns_alert = messaging.ApsAlert(title=title, body=body)
        aps_payload = messaging.Aps(
            alert=apns_alert,
            sound="default",
            badge=badge or 1,
            content_available=True
        )
        apns_config = messaging.APNSConfig(
            payload=messaging.APNSPayload(aps=aps_payload),
            headers={"apns-priority": "10"}
        )

        # Android specific config
        android_config = messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                title=title,
                body=body,
                sound="default",
                channel_id="pamba_milk_delivery"
            )
        )

        # Standard notification payload
        notification = messaging.Notification(title=title, body=body)

        # Send in chunks of 500 (FCM multicast limit)
        success_total = 0
        failure_total = 0
        tokens_to_deactivate = []

        for i in range(0, len(tokens), 500):
            batch_tokens = tokens[i:i + 500]
            multicast_message = messaging.MulticastMessage(
                tokens=batch_tokens,
                notification=notification,
                data=str_data,
                android=android_config,
                apns=apns_config
            )

            response = messaging.send_each_for_multicast(multicast_message)
            success_total += response.success_count
            failure_total += response.failure_count

            if response.failure_count > 0:
                for idx, resp in enumerate(response.responses):
                    if not resp.success:
                        err = resp.exception
                        # If token is invalid or app was uninstalled, mark for deactivation
                        if isinstance(err, (messaging.UnregisteredError, messaging.SenderIdMismatchError)):
                            tokens_to_deactivate.append(batch_tokens[idx])
                        else:
                            logger.warning(f"FCM: Failed send to token {batch_tokens[idx][:15]}...: {err}")

        # Bulk deactivate dead tokens
        if tokens_to_deactivate:
            DeviceToken.objects.filter(token__in=tokens_to_deactivate).update(is_active=False)
            logger.info(f"FCM: Deactivated {len(tokens_to_deactivate)} invalid/expired device tokens")

        return {
            "success_count": success_total,
            "failure_count": failure_total,
            "status": "sent"
        }

    except Exception as e:
        logger.error(f"FCM: Error dispatching push notification: {e}", exc_info=True)
        return {"success_count": 0, "failure_count": len(tokens), "error": str(e), "status": "error"}


def send_push_to_user(
    user,
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None,
    target_screen: str = "",
    target_param: str = ""
) -> Dict[str, Any]:
    """
    Send push notification to all active devices registered for a specific user.
    """
    if not user:
        return {"status": "no_user"}

    from apps.accounts.models import DeviceToken

    active_tokens = list(
        DeviceToken.objects.filter(user=user, is_active=True).values_list("token", flat=True)
    )

    if not active_tokens:
        logger.debug(f"FCM: No active device tokens found for user {user.phone or user.username}")
        return {"status": "no_devices", "user": user.username}

    payload_data = dict(data or {})
    if target_screen:
        payload_data["target_screen"] = target_screen
    if target_param:
        payload_data["target_param"] = target_param

    return send_push_to_tokens(
        tokens=active_tokens,
        title=title,
        body=body,
        data=payload_data
    )


def send_push_broadcast(
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None,
    role: Optional[str] = None
) -> Dict[str, Any]:
    """
    Send a broadcast push notification to all active devices (or filtered by user role).
    """
    from apps.accounts.models import DeviceToken

    qs = DeviceToken.objects.filter(is_active=True)
    if role:
        qs = qs.filter(user__role=role.upper())

    tokens = list(qs.values_list("token", flat=True).distinct())
    return send_push_to_tokens(tokens=tokens, title=title, body=body, data=data)
