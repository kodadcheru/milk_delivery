#!/bin/sh
set -e

echo "🚀 [1/4] Running database migrations..."
python manage.py shell -c "
from django.db import connection
try:
    with connection.cursor() as cursor:
        if connection.vendor == 'postgresql':
            cursor.execute('''
                ALTER TABLE products_category ADD COLUMN IF NOT EXISTS quality_badge_title varchar(150) DEFAULT '';
                ALTER TABLE products_category ADD COLUMN IF NOT EXISTS quality_specs jsonb DEFAULT '{}';
                ALTER TABLE products_category ADD COLUMN IF NOT EXISTS subtitle varchar(150) DEFAULT '';
                ALTER TABLE products_category ADD COLUMN IF NOT EXISTS tracking_badges jsonb DEFAULT '[]';

                ALTER TABLE products_product ADD COLUMN IF NOT EXISTS quality_badge_title varchar(150) DEFAULT '';
                ALTER TABLE products_product ADD COLUMN IF NOT EXISTS quality_specs jsonb DEFAULT '{}';
                ALTER TABLE products_product ADD COLUMN IF NOT EXISTS subtitle varchar(150) DEFAULT '';
                ALTER TABLE products_product ADD COLUMN IF NOT EXISTS tracking_badges jsonb DEFAULT '[]';

                ALTER TABLE products_storefrontconfig ADD COLUMN IF NOT EXISTS is_cod_enabled boolean DEFAULT true;
                ALTER TABLE products_storefrontconfig ADD COLUMN IF NOT EXISTS is_wallet_enabled boolean DEFAULT true;
                ALTER TABLE products_storefrontconfig ADD COLUMN IF NOT EXISTS is_online_payment_enabled boolean DEFAULT true;
                ALTER TABLE products_storefrontconfig ADD COLUMN IF NOT EXISTS platform_fee numeric(6,2) DEFAULT 0.00;
                ALTER TABLE products_storefrontconfig ADD COLUMN IF NOT EXISTS tax_percentage numeric(5,2) DEFAULT 0.00;
                ALTER TABLE products_storefrontconfig ADD COLUMN IF NOT EXISTS delivery_fee numeric(6,2) DEFAULT 0.00;
                ALTER TABLE products_storefrontconfig ADD COLUMN IF NOT EXISTS free_delivery_threshold numeric(8,2) DEFAULT 0.00;

                ALTER TABLE core_siteconfig ADD COLUMN IF NOT EXISTS customer_platform_fee numeric(6,2) DEFAULT 0.00;
                ALTER TABLE core_siteconfig ADD COLUMN IF NOT EXISTS tax_percentage numeric(5,2) DEFAULT 0.00;
                ALTER TABLE core_siteconfig ADD COLUMN IF NOT EXISTS delivery_fee numeric(6,2) DEFAULT 0.00;
                ALTER TABLE core_siteconfig ADD COLUMN IF NOT EXISTS free_delivery_threshold numeric(8,2) DEFAULT 0.00;

                ALTER TABLE deliveries_deliverytask ADD COLUMN IF NOT EXISTS delivered_latitude numeric(15,8);
                ALTER TABLE deliveries_deliverytask ADD COLUMN IF NOT EXISTS delivered_longitude numeric(15,8);

                ALTER TABLE deliveries_liveorder ADD COLUMN IF NOT EXISTS delivered_latitude numeric(15,8);
                ALTER TABLE deliveries_liveorder ADD COLUMN IF NOT EXISTS delivered_longitude numeric(15,8);
                ALTER TABLE deliveries_liveorder ADD COLUMN IF NOT EXISTS delivery_fee numeric(6,2) DEFAULT 0.00;
                ALTER TABLE deliveries_liveorder ADD COLUMN IF NOT EXISTS platform_fee numeric(6,2) DEFAULT 0.00;
                ALTER TABLE deliveries_liveorder ADD COLUMN IF NOT EXISTS subtotal numeric(10,2) DEFAULT 0.00;
                ALTER TABLE deliveries_liveorder ADD COLUMN IF NOT EXISTS tax_amount numeric(8,2) DEFAULT 0.00;
            ''')
            print('✅ PostgreSQL schema verified and columns ensured.')
except Exception as e:
    print('Schema check notice:', e)
" 2>/dev/null || true

python manage.py migrate token_blacklist --noinput || true
python manage.py migrate --noinput || true

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
