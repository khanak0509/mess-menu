# Mess Menu App

A simple full-stack menu management app with:

- Flutter mobile app
- FastAPI backend
- Web admin dashboard for uploads and settings

## About

This app lets users view daily meal menus with a Veg/Non-Veg preference.  
Admins can upload menu CSV files, manage meal timings, and set special dinner notes.

## Live Links

- APK Download: [app-debug.apk]([https://github.com/khanak0509/mess-menu/releases/download/v1/app-debug.apk](https://github.com/khanak0509/mess-menu/releases/download/v1/IITJ.menu))
## Tech Stack

- **Frontend:** Flutter
- **Backend:** FastAPI, Uvicorn
- **Database:** Firebase Firestore (via Firebase Admin SDK)
- **Hosting:** Render

## Key Features

- Separate Veg and Non-Veg menu support
- First-time preference selection in app
- Preference toggle in app bar
- Dashboard-based timing updates
- Date-based special dinner support
- Local cache fallback when API is unavailable

## Local Setup

### Backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 -m uvicorn api:app --reload --port 8000
```

Add Firebase credentials file at:

```text
backend/admin.json
```

Admin dashboard:

```text
http://127.0.0.1:8000/admin
```

### Frontend

```bash
cd frontend
flutter pub get
flutter run
```

## Build APK

```bash
cd frontend
flutter build apk --release
```

Generated file:

```text
frontend/build/app/outputs/flutter-apk/app-release.apk
```

## Main API Endpoints

- `GET /menu?preference=veg|nonveg`
- `GET /menu/{day}?preference=veg|nonveg`
- `GET /config`
- `POST /upload-csv/veg`
- `POST /upload-csv/nonveg`
- `POST /update-config`

## Deployment Notes

For Render backend service:

- Root Directory: `backend`
- Build Command: `pip install -r requirements.txt`
- Start Command: `uvicorn api:app --host 0.0.0.0 --port $PORT`

Built for IITJ mess operations with quick updates and student-friendly UX.
