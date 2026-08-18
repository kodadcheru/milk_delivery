# 🥛 MilkDrop Express — Next-Gen Milk & Fresh Essentials Delivery Platform

A production-grade, full-stack morning milk and daily essentials subscription & instant delivery platform.

---

## 🏗️ Architecture

- **Backend**: Python 3.14 + Django REST Framework + PostgreSQL / SQLite + JWT Authentication + Gunicorn + WhiteNoise.
- **Frontend**: Flutter 3.x (iOS, Android, Web) + Material 3 + Interactive OpenStreetMap/Google Maps Picker + State Management with dynamic real-time sync.
- **Features**:
  - 🗺️ **Interactive Doorstep Pin & Map Picker** (`flutter_map` + `latlong2` + Google Maps / OSM Geocoding).
  - 📍 **1-Click High-Precision GPS Auto-Fill**.
  - ⚡ **Live Express Orders (30 Mins)** with security OTP & live driver dialer.
  - 🥛 **Daily 06:00 AM Dawn Delivery Subscriptions** (Vacation pause, quantity steppers, doorstep proof photo).
  - 💳 **Prepaid Wallet & Instant Top-Ups**.
  - 📱 **Swipe-Right-for-Back** gesture across the entire app.
  - 🎠 **Auto-Sliding Promotional Banners** with animated indicators.
  - 🔒 **100% Real Live PostgreSQL / REST API Data** (Zero hardcoded mocks).

---

## 🚀 Deploy to Railway.app (1-Click Ready)

### 1. Backend Service (Django + PostgreSQL)
1. Link your GitHub repository to [Railway.app](https://railway.app).
2. Add a **PostgreSQL Database** plugin in your Railway project.
3. In your Backend service settings:
   - **Root Directory**: `milk_delivery_backend`
   - **Start Command**: `python manage.py migrate && python manage.py collectstatic --noinput && gunicorn milk_backend.wsgi:application --bind 0.0.0.0:$PORT --workers 3`
4. Set Environment Variables:
   - `DATABASE_URL`: Automatically linked from Railway PostgreSQL.
   - `SECRET_KEY`: `your-secure-production-key`
   - `DEBUG`: `False`
   - `ALLOWED_HOSTS`: `*`

---

## 🧪 Testing

### Backend Test Suite
```bash
cd milk_delivery_backend
./venv/bin/python manage.py test apps.accounts apps.products apps.subscriptions apps.deliveries apps.core
```

### Frontend Test Suite & Static Analysis
```bash
cd milk_delivery_frontend
flutter test
flutter analyze
```
