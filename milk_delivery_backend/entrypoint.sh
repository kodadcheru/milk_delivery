#!/bin/sh
set -e

echo "🚀 [1/4] Running database migrations..."
python manage.py migrate token_blacklist --noinput || true

# If deliveries legacy columns already exist in Postgres, fake-apply up to 0027 so 0028 applies cleanly
python manage.py shell -c "
from django.db import connection
try:
    with connection.cursor() as cursor:
        cursor.execute(\"SELECT 1 FROM information_schema.columns WHERE table_name='deliveries_deliverytask' AND column_name='payout_id'\")
        if cursor.fetchone():
            from django.core.management import call_command
            call_command('migrate', 'deliveries', '0027', fake=True)
            print('✅ Automatically fake-applied deliveries up to 0027 because legacy schema already exists.')
except Exception as e:
    print('Notice during legacy schema check:', e)
" 2>/dev/null || true

python manage.py migrate --noinput

echo "🌱 [2/4] Seeding default superusers and hub catalogs..."
python manage.py shell -c "from apps.core.models import SiteConfig; exit(0 if SiteConfig.objects.exists() else 1)" 2>/dev/null && echo '✅ Seed data already exists, skipping.' || (python seed_railway.py || true)

echo "📦 [3/4] Collecting static assets..."
python manage.py collectstatic --noinput --clear || true

# Ensure persistent media directories exist
mkdir -p "${MEDIA_ROOT:-/app/media}/proofs" || true

APP_PORT="${PORT:-8000}"
if [ "${RUN_SCHEDULER}" = "true" ]; then
    echo "⏰ Starting background APScheduler worker (Task generation & Payouts)..."
    python manage.py run_scheduler &
fi

echo "🌟 [4/4] Starting ASGI production server (WebSockets + HTTP) on port $APP_PORT..."
exec gunicorn -c gunicorn.conf.py milk_backend.asgi:application \
    --bind 0.0.0.0:$APP_PORT \
    --workers 2 \
    --timeout 120 \
    --access-logfile - \
    --error-logfile -
