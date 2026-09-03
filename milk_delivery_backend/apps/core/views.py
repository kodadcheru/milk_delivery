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
                if connection.vendor == "postgresql":
                    cursor.execute("""
                        ALTER TABLE accounts_user ADD COLUMN IF NOT EXISTS gender varchar(10) DEFAULT 'Male';
                        ALTER TABLE products_category ADD COLUMN IF NOT EXISTS subtitle varchar(150) DEFAULT '';
                        ALTER TABLE products_category ADD COLUMN IF NOT EXISTS quality_badge_title varchar(150) DEFAULT '';
                        ALTER TABLE products_category ADD COLUMN IF NOT EXISTS quality_specs jsonb DEFAULT '{}'::jsonb;
                        ALTER TABLE products_category ADD COLUMN IF NOT EXISTS tracking_badges jsonb DEFAULT '[]'::jsonb;
                        ALTER TABLE products_category ADD COLUMN IF NOT EXISTS image_url varchar(500) DEFAULT '';
                        ALTER TABLE products_product ADD COLUMN IF NOT EXISTS subtitle varchar(150) DEFAULT '';
                        ALTER TABLE products_product ADD COLUMN IF NOT EXISTS quality_badge_title varchar(150) DEFAULT '';
                        ALTER TABLE products_product ADD COLUMN IF NOT EXISTS quality_specs jsonb DEFAULT '{}'::jsonb;
                        ALTER TABLE products_product ADD COLUMN IF NOT EXISTS tracking_badges jsonb DEFAULT '[]'::jsonb;
                        CREATE TABLE IF NOT EXISTS deliveries_deliverychatmessage (
                            id BIGSERIAL PRIMARY KEY,
                            channel_key VARCHAR(100) NOT NULL,
                            task_id BIGINT REFERENCES deliveries_deliverytask(id) ON DELETE SET NULL,
                            order_id VARCHAR(50) REFERENCES deliveries_liveorder(id) ON DELETE SET NULL,
                            sender_role VARCHAR(20) NOT NULL DEFAULT 'DRIVER',
                            sender_name VARCHAR(150) NOT NULL DEFAULT '',
                            sender_phone VARCHAR(30) NOT NULL DEFAULT '',
                            text TEXT NOT NULL,
                            is_read BOOLEAN NOT NULL DEFAULT FALSE,
                            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                        );
                        CREATE INDEX IF NOT EXISTS deliv_chat_chan_idx ON deliveries_deliverychatmessage (channel_key, created_at);
                    """)
            try:
                from django.core.management import call_command
                call_command("migrate", interactive=False)
            except Exception as mig_err:
                print("HealthCheck migration notice:", mig_err)
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
            "service": "Pamba Fresh Delivery API",
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
