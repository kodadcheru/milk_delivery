#!/bin/sh
set -e

echo "🚀 [1/4] Running database migrations..."
python manage.py migrate token_blacklist --noinput || true
python manage.py migrate --noinput || echo "⚠️ Warning: Database migrations completed with warnings."

echo "🌱 [2/4] Seeding default superusers and hub catalogs..."
python seed_railway.py || true

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
