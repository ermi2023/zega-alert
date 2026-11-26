# Deploying ZEGA-ALERT

The backend ships as a Docker image (`backend/Dockerfile`) and runs its own
migrations on boot, so it works on Render, Railway, Fly.io, or any container
host. `render.yaml` is a ready-to-use Render blueprint for the API, a Postgres
database, and the static admin web app.

## 1. Push to GitHub

```bash
# from the repo root (C:\Users\hp g7\ZEGA-ALERT)
git add -A
git commit -m "Deployment config"
git push origin main
```

> `.env`, Firebase service-account JSON, and `google-services.json` are
> git-ignored — never commit secrets.

## 2. Deploy on Render (one click)

1. Render dashboard -> **New -> Blueprint** -> pick this repo.
2. Render reads `render.yaml` and creates:
   - `zega-alert-db` (Postgres)
   - `zega-alert-api` (Docker web service)
   - `zega-alert-admin` (static admin site)
3. When prompted, fill the `sync: false` values (see below).
4. Wait for the deploy; the health check is `GET /health`.

### Environment variables to provide

| Key | Value |
| --- | --- |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | The **entire** contents of `backend/zega-alert-firebase-adminsdk-*.json` as one line |
| `AT_USERNAME` / `AT_API_KEY` / `AT_SENDER_ID` | Africa's Talking credentials |
| `OTP_SCREEN_FALLBACK` | Set to `true` only for a controlled demo to show an undelivered OTP in the app; keep `false` for public production |
| `VITE_API_URL` (admin site) | `https://zega-alert-api.onrender.com` |

> Maps use OpenStreetMap tiles via Leaflet — **no API key or billing**, so
> there is nothing to add for the live map.

Citizen registration sends phone OTPs by SMS. In development, when SMS is not
delivered, the code is shown in the app instead of being logged. For a
controlled hosted demo only, set `OTP_SCREEN_FALLBACK=true`; turn it off when
SMS delivery is configured. Do not enable this fallback for a public
production service because showing the code in the same app does not prove
ownership of the phone number. Email OTP delivery is not configured.

`JWT_SECRET`, `ENCRYPTION_KEY`, `DATABASE_URL`, `CORS_ORIGINS`, and
`FIREBASE_STORAGE_BUCKET` are set automatically by the blueprint.

Identity verification currently uses mock FAN records managed by a
System Admin under **Admin → FAN Identity Verification**. Add the mock name,
phone number, and 16-digit FAN. Citizens access
verification in **Settings → Security** and can enter the FAN or scan the QR
code on their original ID. Only a matching active FAN verifies them; the app
shows the saved mock record, not personal data from the scanned QR.

> **Free DB caveat:** Render's free Postgres expires after ~30 days. For a
> permanent free database use [Neon](https://neon.tech) (or Supabase), then set
> the API's `DATABASE_URL` to the Neon connection string and remove the
> `fromDatabase` block for that variable.

## 3. Build the mobile app for Android

Either
- open the app, tap **Server** on the login screen and paste
  `https://zega-alert-api.onrender.com`, **or**
- build a multi-architecture release with the URL baked in.

For Google Play, build one Android App Bundle containing all supported
architectures. Google Play then delivers only the native libraries needed by
each device:

```powershell
$env:ANDROID_HOME="C:\Users\hp g7\Android\Sdk"; $env:ANDROID_SDK_ROOT=$env:ANDROID_HOME
Set-Location mobile
& "C:\flutter\bin\flutter.bat" build appbundle --release --target-platform=android-arm,android-arm64,android-x64 --dart-define=ZEGA_API_BASE=https://zega-alert-api.onrender.com
```

For direct installation or sharing one APK file, build a universal APK:

```powershell
& "C:\flutter\bin\flutter.bat" build apk --release --target-platform=android-arm,android-arm64,android-x64 --dart-define=ZEGA_API_BASE=https://zega-alert-api.onrender.com
```

This creates one `build/app/outputs/flutter-apk/app-release.apk` containing
`armeabi-v7a` (32-bit ARM), `arm64-v8a` (64-bit ARM), and `x86_64` libraries.
Install or share this same file for all supported devices; Android uses the
matching native libraries. Since it includes every architecture, this APK is
larger than an architecture-specific APK. For smaller per-device downloads,
use the App Bundle with Google Play, which selects the needed libraries for
each device. The app prefers an in-app saved server URL over the build-time
URL, so users can override it.

> Free Render web services sleep after ~15 min idle; the first request after a
> sleep can take ~30-60s. The mobile app's request timeout should accommodate
> this, or upgrade to a paid instance for an always-on service.

## 4. Railway alternative

1. New Project -> Deploy from GitHub.
2. In the service **Settings -> Source**, set **Root Directory** = `backend`.
   Railway auto-detects the `Dockerfile`.
3. Add a Postgres plugin; Railway injects `DATABASE_URL` automatically.
4. Add the same env vars from the table above (plus `JWT_SECRET`,
   `ENCRYPTION_KEY`, `CORS_ORIGINS=*`).

## 5. Verify

```bash
curl https://zega-alert-api.onrender.com/health        # {"ok":true}
curl https://zega-alert-api.onrender.com/api/admin/stats # needs admin token
```

Boot logs should show:
`[DB] Migrations complete`, `[DB] PostgreSQL connected`, `[SERVER] ZEGA-ALERT running`, `[SOCKET] real-time events attached`.
