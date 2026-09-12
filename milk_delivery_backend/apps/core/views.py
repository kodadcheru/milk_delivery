import time
from django.db import connection
from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework import status

START_TIME = time.time()

class HealthCheckView(APIView):
    """
    Production health check and system diagnostics endpoint.
    GET /api/health/
    """
    permission_classes = [AllowAny]

    def get(self, request):
        db_status = "HEALTHY"
        db_latency_ms = None

        try:
            t0 = time.time()
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1;")
                cursor.fetchone()
            db_latency_ms = round((time.time() - t0) * 1000, 2)
        except Exception as e:
            db_status = f"UNHEALTHY: {str(e)}"

        uptime_seconds = int(time.time() - START_TIME)
        days = uptime_seconds // 86400
        hours = (uptime_seconds % 86400) // 3600
        minutes = (uptime_seconds % 3600) // 60
        seconds = uptime_seconds % 60
        uptime_human = f"{days}d {hours}h {minutes}m {seconds}s"

        # Check Cache / Redis status
        cache_status = "HEALTHY"
        cache_latency_ms = None
        cache_backend = "LocMemCache"
        try:
            from django.core.cache import cache
            cache_backend = cache.__class__.__name__
            t_c0 = time.time()
            cache.set("__health_check_test__", "ok", timeout=10)
            val = cache.get("__health_check_test__")
            cache_latency_ms = round((time.time() - t_c0) * 1000, 2)
            if val != "ok":
                cache_status = "DEGRADED: Key verification mismatch"
        except Exception as e:
            cache_status = f"UNHEALTHY: {str(e)}"

        is_healthy = "UNHEALTHY" not in db_status and "UNHEALTHY" not in cache_status

        payload = {
            "status": "UP" if is_healthy else "DEGRADED",
            "service": "Pamba Delivery API",
            "version": "1.0.0-production",
            "timestamp": timezone.now().isoformat(),
            "uptime": uptime_human,
            "uptime_seconds": uptime_seconds,
            "checks": {
                "database": {
                    "status": db_status,
                    "engine": connection.settings_dict.get("ENGINE", "unknown").split(".")[-1],
                    "latency_ms": db_latency_ms,
                },
                "cache": {
                    "status": cache_status,
                    "backend": cache_backend,
                    "latency_ms": cache_latency_ms,
                },
            },
        }

        return Response(
            payload,
            status=status.HTTP_200_OK if is_healthy else status.HTTP_503_SERVICE_UNAVAILABLE,
        )

class AppConfigView(APIView):
    """
    Returns app configuration including the dynamic Google Maps API key.
    Requires authentication.
    GET /api/app-config/
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from .models import SiteConfig
        cfg = SiteConfig.get()
        import os
        from apps.products.models import StorefrontConfig
        store_cfg = StorefrontConfig.get_active()
        return Response({
            "google_maps_api_key": cfg.google_maps_api_key or os.environ.get("GOOGLE_MAPS_API_KEY", ""),
            "support_phone": cfg.support_phone,
            "support_whatsapp": cfg.support_whatsapp,
            "support_email": cfg.support_email,
            "default_city": cfg.default_city,
            "welcome_bonus": int(cfg.welcome_bonus_amount),
            "platform_fee": getattr(store_cfg, "platform_fee", 0),
            "tax_percentage": getattr(store_cfg, "tax_percentage", 0),
            "delivery_fee": getattr(store_cfg, "delivery_fee", 0),
            "free_delivery_threshold": getattr(store_cfg, "free_delivery_threshold", 0),
        })


def privacy_policy_view(request):
    from django.http import HttpResponse
    html = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy - Pamba</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 760px; margin: 40px auto; padding: 0 20px; line-height: 1.6; color: #1e293b; }
        h1 { color: #059669; }
        h2 { color: #0f172a; margin-top: 24px; }
    </style>
</head>
<body>
    <h1>Privacy Policy</h1>
    <p><em>Last updated: September 2026</em></p>
    <p>Welcome to <strong>Pamba</strong> ("we", "our", or "us"). We provide daily morning fresh milk and dairy doorstep delivery services. This Privacy Policy explains how we collect, use, and protect your information when you use our mobile application and services.</p>
    
    <h2>1. Information We Collect</h2>
    <ul>
        <li><strong>Phone Number:</strong> Used strictly for secure authentication via SMS OTP verification.</li>
        <li><strong>Delivery Address & GPS:</strong> Used to assign your delivery to the nearest local hub and enable our delivery drivers to drop off your daily milk bottle at your doorstep.</li>
        <li><strong>Name & Contact Information:</strong> Used to identify your household subscription and provide order updates.</li>
    </ul>

    <h2>2. How We Use Your Information</h2>
    <p>Your information is used solely to provide doorstep delivery, process prepaid wallet debits, and deliver customer support. We do not sell, rent, or trade your personal data to any third parties for marketing purposes.</p>

    <h2>3. Data Protection & Security</h2>
    <p>All authentication tokens, wallet transactions, and customer details are transmitted securely over HTTPS using industry-standard encryption protocols.</p>

    <h2>4. Account Deletion & Contact</h2>
    <p>You may request account deletion or data removal at any time directly through the app profile or by contacting us at:</p>
    <p><strong>Email:</strong> support@pamba.in<br><strong>Phone:</strong> +91 8919548905<br><strong>Address:</strong> Kodad, Telangana, India</p>
</body>
</html>"""
    return HttpResponse(html, content_type="text/html")


def terms_of_service_view(request):
    from django.http import HttpResponse
    html = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Terms of Service - Pamba</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 760px; margin: 40px auto; padding: 0 20px; line-height: 1.6; color: #1e293b; }
        h1 { color: #059669; }
        h2 { color: #0f172a; margin-top: 24px; }
    </style>
</head>
<body>
    <h1>Terms of Service</h1>
    <p><em>Last updated: September 2026</em></p>
    <p>Welcome to <strong>Pamba</strong>. By using our application, you agree to these Terms of Service.</p>

    <h2>1. Subscriptions & Morning Delivery</h2>
    <p>Daily farm-fresh milk deliveries are carried out between 5:30 AM and 7:00 AM. Any vacation pause or subscription change must be made prior to the evening cutoff time.</p>

    <h2>2. Prepaid Wallet</h2>
    <p>Deliveries are fulfilled against your prepaid wallet balance. Unused balances remain in your account and skipped deliveries are automatically refunded to your wallet.</p>

    <h2>3. Contact Information</h2>
    <p>Email: support@pamba.in | Phone: +91 8919548905</p>
</body>
</html>"""
    return HttpResponse(html, content_type="text/html")

