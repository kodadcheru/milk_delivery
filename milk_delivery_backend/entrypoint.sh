#!/bin/sh
set -e

echo "🚀 Running database migrations on Railway PostgreSQL..."
python manage.py migrate --noinput

echo "📦 Collecting static files..."
python manage.py collectstatic --noinput

echo "🌟 Starting Gunicorn on port ${PORT:-8000}..."
exec gunicorn milk_backend.wsgi:application --bind 0.0.0.0:${PORT:-8000} --workers 3 --timeout 120
