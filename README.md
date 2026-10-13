# ZEGA-ALERT

**Crime Reporting, Missing Person Finder & Emergency Assistance** — a hybrid system for Debark University's 4th-year project.

- **Mobile app** (citizens) — Flutter, 5-tab UI: Home, Report, News, Messages, Settings
- **Admin portal** (staff) — React.js, 4 role dashboards: System Admin, Regional Admin, Emergency Dispatcher, Regional Police
- **Backend** — Node.js/Express REST API + Socket.io real-time chat & dispatch
- **Database** — PostgreSQL

## Features

- Citizen crime reports (anonymous option, GPS location, evidence)
- SOS emergency dispatch with GPS + auto-assignment to nearest police/dispatchers
- Missing / wanted persons with citizen sightings
- Geofenced safety zones (schools, hospitals, police stations, events)
- Announcements (news, warnings, legal, events)
- Real-time chat between citizens and staff (Socket.io)
- Legal/rights content with multi-language support (Amharic/English)
- PoD accessibility mode
- JWT auth + OTP phone verification, role-based access control, full audit log

## Project layout

```
ZEGA-ALERT/
├── backend/          # Node/Express API + Socket.io
│   ├── src/
│   │   ├── config/   # env, pg pool
│   │   ├── controllers/
│   │   ├── db/       # schema.sql, seed.sql
│   │   ├── middleware/ (auth, roles, errors)
│   │   ├── routes/
│   │   ├── services/ # dispatch engine, notifications
│   │   ├── socket/
│   │   └── utils/
│   └── scripts/      # run-sql.js, seed.js
├── admin-web/        # React admin portal (Vite)
└── mobile/           # Flutter citizen app
```

## Prerequisites

- Node.js 18+
- PostgreSQL 15+ (18 recommended)
- Flutter SDK (for the mobile app) + Android Studio / emulator

## Setup — Database

```bash
psql -U postgres -c "CREATE ROLE zega LOGIN PASSWORD 'zega_dev_2026';"
psql -U postgres -c "CREATE DATABASE zega_alert OWNER zega;"
```

## Setup — Backend

```bash
cd backend
cp .env.example .env      # edit if needed
npm install
npm run db:schema         # apply schema.sql
npm run db:seed           # insert demo data + staff accounts
npm start                 # http://localhost:5000
```

Demo logins (password for all: `password123`):

| Role            | Phone         |
|-----------------|---------------|
| System Admin    | 0911000001    |
| Regional Admin  | 0911000002    |
| Dispatcher      | 0911000003    |
| Police          | 0911000004    |
| Citizen         | 0911000005    |

## Setup — Admin Web Portal

```bash
cd admin-web
npm install
npm run dev        # http://localhost:5173 (proxies /api to :5000)
```

## Setup — Mobile App

The app code is in `mobile/`. Flutter SDK is required:

```bash
cd mobile
flutter create .          # generates android/ios/etc scaffolding
flutter pub get
flutter run               # on an emulator/device
```

The API base URL is `http://10.0.2.2:5000` (Android emulator → host). Change it in
`mobile/lib/services/api.dart` for a physical device.

## API overview

| Area         | Endpoints                                            |
|--------------|------------------------------------------------------|
| Auth         | `/api/auth/register`, `/login`, `/login-otp`, `/request-otp`, `/verify-otp`, `/refresh`, `/me` |
| Reports      | `/api/reports` (CRUD + status workflow)              |
| SOS          | `/api/sos` (create, list, status, assign)            |
| Persons      | `/api/persons/missing`, `/wanted`, `/sightings`      |
| Announcements| `/api/announcements`                                 |
| Chat         | `/api/chat/conversations`, `/messages` + Socket.io   |
| Legal        | `/api/legal`                                         |
| Geofences    | `/api/geofences`                                     |
| Admin        | `/api/admin/stats`, `/users`, `/audit`, `/dispatches`|

## Tech notes

- Passwords hashed with bcryptjs; auth via short-lived JWT access tokens + refresh token.
- OTP codes are printed to the backend console in dev mode (no SMS provider wired yet).
- SOS auto-dispatch matches police/dispatcher users by region and creates `dispatch_assignments`.
- Push notifications (FCM) are stubbed in `services/notification.service.js`.
