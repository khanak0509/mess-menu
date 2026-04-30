# IITJ Mess Menu

A full-stack mess menu system with:

- FastAPI backend (Firebase Firestore)
- Flutter mobile app (Android/iOS)
- Admin dashboard for uploading menus and updating timings

This project supports separate Veg and Non-Veg menus, first-time preference selection in app, configurable mess timings, and date-based special dinner highlights.

## Highlights

- Upload Veg and Non-Veg monthly CSV menus from dashboard
- User selects Veg/Non-Veg on first launch (stored locally)
- Preference can be changed anytime from app top bar toggle
- Meal timings are configurable from dashboard and reflected in app
- Special dinner can be set separately for Veg/Non-Veg with a specific date
- Daily API fetch with local cache fallback in app

## Project Structure

```text
mess/
├── backend/              # FastAPI API + admin dashboard
│   ├── api.py
│   ├── requirements.txt
│   └── admin.json        # Firebase service account (local only, keep secret)
├── frontend/             # Flutter mobile app
│   ├── lib/
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
└── README.md
```

## Tech Stack

- Backend: FastAPI, Uvicorn, Pandas, Firebase Admin SDK, Firestore
- Frontend: Flutter, SharedPreferences, HTTP, Workmanager, Local Notifications
- Hosting: Render (backend)

## Backend Setup (Local)

### 1) Create Python environment

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 2) Firebase credentials

Place your Firebase service account JSON at:

```text
backend/admin.json
```

### 3) Run backend

```bash
python3 -m uvicorn api:app --reload --port 8000
```

### 4) Open admin dashboard

```text
http://127.0.0.1:8000/admin
```

## Frontend Setup (Local)

```bash
cd frontend
flutter pub get
flutter run
```

## Build APK

Debug APK:

```bash
cd frontend
flutter build apk --debug
```

Release APK:

```bash
cd frontend
flutter build apk --release
```

Output path:

```text
frontend/build/app/outputs/flutter-apk/
```

## API Overview

Base URL examples:

- Local: `http://127.0.0.1:8000`
- Render: `https://<your-service>.onrender.com`

Important endpoints:

- `GET /menu?preference=veg|nonveg`
- `GET /menu/{day}?preference=veg|nonveg`
- `GET /config`
- `GET /admin`
- `POST /upload-csv/veg`
- `POST /upload-csv/nonveg`
- `POST /update-config`

## CSV Upload Notes

The parser supports typical mess CSV layouts and also handles Non-Veg column variants:

- `NON-VEG`
- `NON VEG`
- `Non-Veg`
- `Non Veg`
- `NONVEG`

## Render Deploy (Backend)

Create a new Web Service with:

- Branch: `main`
- Root Directory: `backend`
- Build Command: `pip install -r requirements.txt`
- Start Command: `uvicorn api:app --host 0.0.0.0 --port $PORT`

Add secret file:

- Filename: `admin.json`
- Contents: Firebase service account JSON

## Current App Behavior

- If live API fails temporarily, app shows warning and uses cached menu
- Veg and Non-Veg caches are stored separately
- Special dinner is shown only for selected date and current day
- After special date passes, normal dinner menu is shown automatically

## Security Notes

- Never commit `backend/admin.json` to git
- Use Render Secret Files or environment-driven credential management

## Future Improvements

- Add admin auth for `/admin`
- Add API health endpoint (`/health`)
- Add CI checks for Flutter analyze + backend lint/tests
- Add tests for CSV parser edge cases

---

Built for IITJ mess operations with quick updates and student-friendly UX.
