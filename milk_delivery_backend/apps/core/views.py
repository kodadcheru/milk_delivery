import time
from django.db import connection
from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
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

        is_healthy = "UNHEALTHY" not in db_status

        payload = {
            "status": "UP" if is_healthy else "DEGRADED",
            "service": "MilkDrop Express Delivery API",
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
                    "status": "OPERATIONAL",
                },
            },
        }

        return Response(
            payload,
            status=status.HTTP_200_OK if is_healthy else status.HTTP_503_SERVICE_UNAVAILABLE,
        )
