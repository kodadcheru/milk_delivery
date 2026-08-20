#!/bin/sh
set -e

echo "🚀 [1/4] Running database migrations..."
python manage.py migrate --noinput || true

echo "🌱 [2/4] Seeding default superusers and hub catalogs..."
python seed_railway.py || true

echo "📦 [3/4] Collecting static assets..."
python manage.py collectstatic --noinput --clear || true

# Ensure persistent media directories exist
mkdir -p "${MEDIA_ROOT:-/app/media}/proofs" || true

APP_PORT="${PORT:-8000}"
echo "🌟 [4/4] Starting ASGI production server (WebSockets + HTTP) on port $APP_PORT..."
exec gunicorn milk_backend.asgi:application \
    -k uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:$APP_PORT \
    --workers 2 \
    --timeout 120 \
    --access-logfile - \
    --error-logfile -
