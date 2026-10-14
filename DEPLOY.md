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
| `FAYDA_API_URL` / `FAYDA_API_KEY` | Your Fayda/NIDP credentials (leave blank for dev auto-approve) |
| `AT_USERNAME` / `AT_API_KEY` / `AT_SENDER_ID` | Africa's Talking credentials |
| `VITE_API_URL` (admin site) | `https://zega-alert-api.onrender.com` |
| `VITE_GOOGLE_MAPS_API_KEY` (admin site) | Your Google Maps JS API key |

`JWT_SECRET`, `ENCRYPTION_KEY`, `DATABASE_URL`, `CORS_ORIGINS`, and
`FIREBASE_STORAGE_BUCKET` are set automatically by the blueprint.

> **Free DB caveat:** Render's free Postgres expires after ~30 days. For a
> permanent free database use [Neon](https://neon.tech) (or Supabase), then set
> the API's `DATABASE_URL` to the Neon connection string and remove the
> `fromDatabase` block for that variable.

## 3. Point the mobile app at the public URL

Either
- open the app, tap **Server** on the login screen and paste
  `https://zega-alert-api.onrender.com`, **or**
- build the APK with the URL baked in:

```powershell
$env:ANDROID_HOME="C:\Users\hp g7\Android\Sdk"; $env:ANDROID_SDK_ROOT=$env:ANDROID_HOME
& "C:\flutter\bin\flutter.bat" build apk --release --dart-define=ZEGA_API_BASE=https://zega-alert-api.onrender.com
```

The app prefers the in-app saved value over the `--dart-define` value, so users
can always override it at runtime.

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
