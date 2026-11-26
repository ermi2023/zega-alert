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
- Official, staff-managed safety areas (schools, hospitals, police stations, events)
- Announcements (news, warnings, legal, events)
- Real-time chat between citizens and staff (Socket.io)
- Legal/rights content with multi-language support (Amharic/English)
- PoD accessibility mode
- JWT auth + OTP phone verification, role-based access control, full audit log
- Admin-managed mock FAN identity verification for demonstration

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
| Verification | `/api/verification/status`, `/fan`                 |

## Safety zones (geofences)

A safety zone is a mapped area officially published by authorized staff. Publishing, changing, pausing, or removing a zone adds a notice to the inbox of active citizens in its region/sub-city/Woreda; an SOS inside an active zone also creates an incident notice for citizens in the matching area. Push alerts are sent when Firebase Messaging is configured and device notifications are enabled. The app does not track citizens continuously, and a zone does not guarantee that an area is safe.

- **Citizens:** Open the bottom **Zones** tab and tap an area to view its map and boundary. Open the notification bell to read safety-zone notices.
- **Authorized staff:** Open **Geofences** in the admin portal to publish, pause, or update an area.
- **Boundary logic:** A zone is either a circle (center point plus radius of at least 50 m) or a drawn boundary with at least three points. If a drawn boundary is saved, it alone defines the zone; the map and SOS checks use that same boundary. Paused areas are not used for SOS context or warnings.

## FAN identity verification

This demonstration uses mock data instead of connecting to the national Fayda
service. A System Admin adds the mock name, phone number, and 16-digit FAN in
the separate **Admin → FAN Identity Verification** dashboard. From
**Settings → Security → FAN identity verification**, a citizen can enter the
FAN or scan the QR code on the original ID. The server checks only the FAN
against an active record and returns the saved mock name and phone; it never
displays the other data from the QR code. A non-matching FAN remains
unverified. Phone/OTP verification is separate.

## Tech notes

- Passwords hashed with bcryptjs; auth via short-lived JWT access tokens + refresh token.
- If SMS is unavailable in development, registration displays a temporary OTP in the app; codes are not printed to the backend console. Production requires SMS delivery, except for a controlled demo using `OTP_SCREEN_FALLBACK=true`.
- SOS auto-dispatch matches police/dispatcher users by region and creates `dispatch_assignments`.
- Push notifications use FCM in `services/notification.service.js`. Without Firebase credentials, development mode logs simulated pushes; notification inbox entries are still stored in the database.
