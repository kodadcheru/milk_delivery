#!/bin/sh
set -e

echo "🚀 Running database migrations on Railway PostgreSQL..."
python manage.py migrate --noinput || true

echo "📦 Collecting static files..."
python manage.py collectstatic --noinput || true

PORT_VAL="${PORT:-8000}"
echo "🌟 Starting Gunicorn on port $PORT_VAL..."
exec gunicorn milk_backend.wsgi:application --bind "0.0.0.0:$PORT_VAL" --workers 3 --timeout 120
