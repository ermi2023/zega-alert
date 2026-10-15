# ZEGA-ALERT — RESUME / HANDOFF

Paste this to continue me:
> read C:\Users\hp g7\ZEGA-ALERT\RESUME.md and continue where we stopped

---

## STATUS RIGHT NOW
- All app code (backend / admin-web / mobile) is **complete and verified**.
- **RELEASE APK IS BUILT** at `mobile\build\app\outputs\flutter-apk\app-release.apk` (101.7 MB).
- Region is now **nationwide / user-selected** per the spec (regional offices across Ethiopia): no hardcoded region. Users pick region + sub-city at registration and in Settings; report/SOS/missing submissions use the signed-in user's profile region (`Api.region` / `Api.subCity`).
- Backend on `http://localhost:5000/health` -> `{"ok":true}` (restart it after reboot with the command below).
- **PDF spec cross-check + gap-fill DONE** (backend / admin-web / mobile all aligned to the spec PDF). See section below.
- **GAP-FILL ROUND 2 DONE** (framework alignment + "work everywhere in Ethiopia"): Google Maps replaces Leaflet in admin-web; Fayda National ID API integration in backend; mobile can target any public backend URL (Settings + `--dart-define`); `scripts\start-public.ps1` exposes the backend via a Cloudflare tunnel. See the ROUND 2 section below.

## PDF SPEC GAP-FILL (after 3-way cross-check)
Backend (all `node --check` OK):
1. Logout invalidates the refresh token server-side: `users.token_version`; `utils/jwt.js` adds `ver` claim; `middleware/auth.js` rejects stale; `auth.controller.js` `refresh` version-checks + new `logout` (bumps version, audit_log); `POST /auth/logout`.
2. People of Determination (UC-4/UC-5): `pod.controller.js` + `pod.routes.js` — `POST/GET/PATCH /pod/direct-call` (GPS -> nearest station via haversine -> notify+SMS), `POST/GET /pod/sign-language`, `GET/POST /pod/stations`; `police_stations` table + seed.
3. Announcements: 8 categories incl. `wanted`/`missing`; auto-translation into en/am/om/ti (`services/translation.service.js`, LibreTranslate-compatible, placeholder fallback offline); `POST /announcements/:id/retranslate`; list attaches `translations`.
4. Legal: `review_status` (draft/under_review/published), reviewer + `legal_review_history`; `GET /legal/:id/history`, `PATCH /legal/:id/review`.
5. Admin: `DELETE /users/:id` (`deleteUser`, blocks self/last-admin, `confirm_active_cases` guard); report_status enum gains draft/submitted/assigned/in_progress.
6. Social share analytics (UC-11): `share.controller.js` + `share.routes.js` — `GET /share/platforms`, `POST /share`, `GET /share/stats`; `share_events` table.
7. `migration_gaps.sql` (idempotent) + mirrored `schema.sql`; `config/env.js` adds `TRANSLATE_API_URL`/`TRANSLATE_API_KEY`.

Admin-web (`npm run build` passes):
- `client.js`: `REFRESH_KEY`, `del(path,body)`, 401 clears refresh. `AuthContext.jsx`: calls `POST /auth/logout`.
- `Users.jsx`: edit + delete (with `confirm_active_cases` retry). `Legal.jsx`: review column + review/history modal.
- `Reports.jsx`: region filter + assign (officer dropdown -> `PATCH /reports/:id/status {status,assigned_to}`; backend confirmed to accept `assigned_to`).
- `Sos.jsx`: per-unit ETA. `RoleDashboards.jsx`: dispatcher live officer map (`/position/officers` + socket `officer:position`).
- `Chat.jsx`: media attach (`/upload/single`), wait-time (`/chat/wait-time`), post-chat rating (`/chat/conversations/:id/rating`).
- `Announcements.jsx`: wanted/missing categories, translation chips, Re-translate button.
- New `PeopleOfDetermination.jsx` (direct calls + sign-language, live via socket) + `Layout.jsx` nav `/pod` + `main.jsx` route + i18n `nav.pod` (en/am/om/ti).

Mobile (`flutter analyze` = 0 errors; APK rebuilt 101.7 MB):
- `Api.recordShare` + `platformFromRaw`; 4 share buttons (home x3, news) now record analytics via `POST /share`.
- `settings_screen.dart`: `_logout` calls `POST /auth/logout` then clears; `_requestCall` posts GPS to `/pod/direct-call` then dials station; `_recordSignLanguage` uploads video then `POST /pod/sign-language`.
- `news_screen.dart`: legal items show "Under Review" chip.

## IF YOU NEED TO REBUILD THE APK
```powershell
$new="C:\Users\hp g7\Android\Sdk"; $env:ANDROID_HOME=$new; $env:ANDROID_SDK_ROOT=$new
& "C:\flutter\bin\flutter.bat" build apk --release
```
(intended workdir: `C:\Users\hp g7\ZEGA-ALERT\mobile`)

To bake in a public backend at build time (works nationwide, no per-phone setup):
```powershell
& "C:\flutter\bin\flutter.bat" build apk --release --dart-define=ZEGA_API_BASE=https://your-tunnel.trycloudflare.com
```
Precedence for the backend URL: saved override in Settings > `ZEGA_API_BASE` dart-define > LAN auto-detect > localhost.

## GAP-FILL ROUND 2 (framework alignment + nationwide access)
1. **Google Maps (spec §4.4) replaces Leaflet (admin-web).** Installed `@react-google-maps/api@2.20.8`, removed `leaflet`+`react-leaflet`.
   - New `admin-web/src/components/LiveMap.jsx` (GoogleMap/Marker/InfoWindow/Circle) with graceful "no key" fallback.
   - `RoleDashboards.jsx` dispatcher live map now uses `LiveMap`; `Geofences.jsx` gained a zone map.
   - Key env var `VITE_GOOGLE_MAPS_API_KEY` (see `admin-web/.env.example`). `npm run build` passes.
2. **Fayda National ID (spec §4.4) integration (backend).** New `services/fayda.service.js` (`verifyFin`).
   - `verification.controller.js` verifies the FIN against the Fayda API when `FAYDA_API_URL` is set; otherwise dev auto-approve (unchanged behaviour). `/verification/status` also reports `fayda_configured`.
   - `config/env.js` + `.env.example` add `FAYDA_API_URL` / `FAYDA_API_KEY`.
3. **App reachable everywhere in Ethiopia (mobile).** `Api` base URL is now resolvable:
   - `Api.setBaseUrl(url)` persists an override (SharedPreferences `apiBaseUrl`); `Api.resolveHost()` loads it; `Api.baseUrl` prefers override > `String.fromEnvironment('ZEGA_API_BASE')` > localhost (web/windows) > LAN probe.
   - Settings screen: new "Backend server" card shows the current URL and lets the user paste a public URL (or reset to auto-detect).
   - `scripts/start-public.ps1` starts the backend and a Cloudflare quick tunnel, printing the public `https://*.trycloudflare.com` URL. Paste it into Settings (or build with `--dart-define=ZEGA_API_BASE=<url>`). `cloudflared.exe` is at `%TEMP%\opencode\cloudflared.exe`.
   - `flutter analyze` = 23 info, 0 errors (unchanged baseline).
4. **CRITICAL: DB migration had never been applied.** `migration_gaps.sql` (token_version, police_stations, direct_call_requests, sign_language_messages, share_events, legal_review_history, new enum values) was missing from the live DB, so auth (`token_version` lookup) and all POD/share/legal endpoints returned 401/500. Now applied.
   - `scripts/run-sql.js` now strips comments before splitting on `;` and runs each statement separately (enum `ADD VALUE` can't run in a transaction). New script: `npm run db:migrate`.
   - APK rebuilt with all of the above: `mobile\build\app\outputs\flutter-apk\app-release.apk` (101.8 MB).
5. **Mobile Firebase is now fully configured (push notifications work).**
   - The project `zega-alert` had **no apps registered**, so there was no `google-services.json`. Registered the Android app `com.example.zega_alert_mobile` via the Firebase Management API using the admin service account, then downloaded the config.
   - Added `mobile/android/app/google-services.json`; real `mobile/lib/firebase_options.dart` (apiKey/appId/senderId/projectId/storageBucket).
   - `main.dart`: `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` + `FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler)`.
   - `notification_service.dart`: background handler, foreground SnackBar, tap navigation to Callbacks, token registration via `PUT /auth/me {device_token}` (backend already allows it, `auth.controller.js:135`).
   - `AndroidManifest.xml`: FCM default channel meta-data; `MainActivity.kt` creates the `zega_alert_channel` (Android 8+).
   - Gradle: `com.google.gms.google-services` v4.4.2 added to `settings.gradle.kts` + `app/build.gradle.kts`. Release APK builds clean.
   - Backend `.env`: `FIREBASE_STORAGE_BUCKET=zega-alert.firebasestorage.app`.

## FIRST THING TO DO AFTER REBOOT
Confirm the APK still exists:
```powershell
Get-ChildItem "C:\Users\hp g7\ZEGA-ALERT\mobile\build" -Recurse -Filter *.apk
```
If missing, rebuild with the command in the STATUS section above. Expected output:
`mobile\build\app\outputs\flutter-apk\app-release.apk` (build takes ~2-10 min; deps cached).

## FIXES ALREADY APPLIED (do NOT undo)
1. Old SDK `cmdline-tools` (v12) is locked by TrustedInstaller -> could not write/upgrade.
   Solution: **writable mirror SDK** at `C:\Users\hp g7\Android\Sdk`:
   - `cmdline-tools\latest` = newly downloaded tools (real copy)
   - `platforms`, `build-tools`, `platform-tools`, `licenses`, `cmake`, `sources` = junctions to old SDK
   - `ndk` = REAL folder with: `25.1.8937393`, `25.2.9519653`, `27.0.12077973`,
     and `28.2.13676358` (junctions to 27.0's subdirs + patched `source.properties` revision -> no download needed)
2. `flutter config --android-sdk "C:\Users\hp g7\Android\Sdk"` (persisted; survives reboot).
3. `mobile/android/app/build.gradle.kts`: `ndkVersion = "28.2.13676358"` (plugins like flutter_webrtc/firebase require 28.2; 27.0 caused an AAR failsafe).
4. `mobile/android/build.gradle.kts`: added a `subprojects { afterEvaluate { ... } }` block that force-sets every Android plugin's `compileSdk` to **36** (flutter_webrtc hardcodes `compileSdkVersion 31`, which its AndroidX deps reject). Must NOT use `plugins.withId` (fires too early) or bare `afterEvaluate` (throws when project already evaluated) — the current try/afterEvaluate fallback is the working form.
5. `build-tools\36.0.0` in the mirror SDK is now complete/valid (was the earlier `Failed to install build-tools;36.0.0` blocker).
6. Region handling is nationwide: `mobile/lib/config/constants.dart` lists all 13 regions (Dire Dawa sub-cities added); registration (`auth_screen.dart`) has region/sub-city pickers; `Api` caches the user's profile region (`setProfile`, persisted in prefs); report/SOS/missing/geofence submissions send `Api.region`/`Api.subCity`.
7. Backend `.env`: `ENCRYPTION_KEY` set to a random 32-byte hex value (see `backend/.env`, git-ignored).

## BUILD ERRORS SEEN SO FAR (all fixed)
- `cmdline-tools` v12 -> "SDK XML v4" / "install properties" -> fixed by mirror SDK.
- EMPTY `ndk\28.2.13676358` -> `CXX1101 did not have source.properties` -> fixed.
- `:jni` plugin hardcodes `flutter.ndkVersion` (28.2) -> fixed by creating valid 28.2 NDK folder.
- `Failed to install build-tools;36.0.0` -> fixed once `build-tools\36.0.0` was fully populated.
- `:flutter_webrtc:checkReleaseAarMetadata` (compiled against android-31, AndroidX needs 34+) -> fixed by the root `compileSdk 36` override.
- `Cannot run Project.afterEvaluate(Action) when the project is already evaluated` -> use the try/afterEvaluate fallback, not a bare afterEvaluate.
- `dl.google.com` is SLOW/throttles (10-25 MB/min, stalls). Retry if downloads stall.

## USER ACTION ITEMS (assistant cannot do these)
1. **Firewall (Administrator PowerShell)** so the phone can reach the backend:
   ```powershell
   New-NetFirewallRule -DisplayName "ZEGA Backend 5000" -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow -Profile Any
   ```
2. Optional full-feature credentials to paste later:
   - Africa's Talking: API key + username + sender ID (real OTP SMS)
   - Supabase: project URL + keys (cloud Postgres)
   - Firebase: service-account JSON + storage bucket (push/storage)
   App runs without them (graceful fallback).

## INSTALL ON PHONE
1. Copy `app-release.apk` to phone -> allow "install unknown apps" -> install.
2. Backend URL is auto-detected: the app probes the LAN hosts in `mobile/lib/services/api.dart` (`_candidateHosts`) and caches the one that answers `/health`. No more hardcoded IP. To use a public server instead, open **Settings -> Backend server** and paste the URL, or rebuild with `--dart-define=ZEGA_API_BASE=<url>` (see ROUND 2).
3. Demo logins (pwd `password123`): 0911000001 System Admin, ...002 Regional, ...003 Dispatcher, ...004 Police, ...005 Citizen.

## KEY PATHS / ENV
- Project: `C:\Users\hp g7\ZEGA-ALERT` (backend port 5000, admin-web Vite port 5173)
- Flutter: `C:\flutter\bin\flutter.bat` (3.47.0) | Java Temurin 17
- Old SDK: `C:\Program Files (x86)\Android\android-sdk` | New SDK: `C:\Users\hp g7\Android\Sdk`
- DB: postgres user `zega` / `zega_dev_2026` @ localhost:5432 / db `zega_alert`
- Apply DB migrations (idempotent): `npm run db:migrate` (workdir `backend`). Run this after any fresh DB/schema.
- Start backend: `Start-Process node -ArgumentList "src/server.js" -WorkingDirectory "C:\Users\hp g7\ZEGA-ALERT\backend" -WindowStyle Hidden`
- Kill backend: `(Get-NetTCPConnection -LocalPort 5000 -State Listen).OwningProcess | % { Stop-Process -Id $_ -Force }`

## VERIFIED WORKING
`node app.js` imports OK; AES-256-GCM crypto round-trip; login + `/verification/status` + `/verification/qr`;
PII encrypted at rest (`enc:v1:`); missing-person + SOS create/read decrypt OK; `flutter analyze` = 0 errors.

## GIT + POSTMAN + CREDENTIALS (latest)

### Git
- Initialized with `.gitignore` (excludes `.env`, Firebase admin JSON, `google-services.json`, `*.apk`, `*.jks`, `node_modules`, `build/`, `.dart_tool/`, etc.).
- Initial commit: `a079d42` — "Initial commit: ZEGA-ALERT (backend, admin-web, mobile) per spec".
- No remote configured. Add with `git remote add origin <url>` when ready.

### Postman
- `postman/ZEGA-ALERT.postman_collection.json` — full endpoint coverage (auth, reports, SOS, persons, announcements, legal, chat, POD, share, callbacks, dispatch, geofences, feedback, admin, upload, verification, translations, position, policy).
- `postman/ZEGA-ALERT.postman_environment.json` — local env with `baseUrl`, `accessToken`, `refreshToken`.
- Login request auto-saves tokens via test script. Import both into Postman to start testing.

### Live Credentials Status
| Service | Backend | Mobile | What's needed |
|---|---|---|---|
| **Firebase (FCM/Storage/Firestore)** | ✅ Live (service-account JSON present; storage bucket `zega-alert.firebasestorage.app`) | ✅ Configured (see below) | Nothing — done. |
| **Supabase (hosted Postgres)** | ⚠️ Code ready, not configured | N/A | Set `SUPABASE_URL` + `SUPABASE_KEY` (+ optional `SUPABASE_DB_URL`) in `backend/.env`. Takes precedence over `DATABASE_URL`. |
| **Africa's Talking (SMS)** | ⚠️ Code ready, dev-mode fallback | N/A | Set `AT_USERNAME` + `AT_API_KEY` (+ optional `AT_SENDER_ID`) in `backend/.env`. Without key, SMS logs to console instead of sending. |
| **Translation engine** | ⚠️ Code ready, placeholder fallback | N/A | Set `TRANSLATE_API_URL` (LibreTranslate-compatible endpoint) + optional `TRANSLATE_API_KEY` in `backend/.env`. Without it, placeholder translations are stored. |
| **Google Maps** | N/A (admin-web) | N/A | Set `VITE_GOOGLE_MAPS_API_KEY` in `admin-web/.env` (enable "Maps JavaScript API"). Without it the map shows a friendly placeholder; the rest of the app works. |
| **Fayda National ID (NIDP)** | ⚠️ Code ready, dev auto-approve | N/A | Set `FAYDA_API_URL` (+ optional `FAYDA_API_KEY`) in `backend/.env`. Without it, ID submissions are auto-approved in dev. |

### .env keys reference (all in `backend/.env`)
```
# Required (already set)
DATABASE_URL=postgres://zega:zega_dev_2026@localhost:5432/zega_alert
PORT=5000
JWT_SECRET=<set in backend/.env — change in production>
ENCRYPTION_KEY=<random 32-byte hex, set in backend/.env>
FIREBASE_SERVICE_ACCOUNT=<path to service-account json, or use FIREBASE_SERVICE_ACCOUNT_JSON in prod>
FCM_PROJECT_ID=zega-alert
FIREBASE_STORAGE_BUCKET=zega-alert.firebasestorage.app

# Optional — paste your keys to go live
AT_USERNAME=sandbox
AT_API_KEY=
SUPABASE_URL=
SUPABASE_KEY=
SUPABASE_DB_URL=
FIREBASE_STORAGE_BUCKET=
TRANSLATE_API_URL=
TRANSLATE_API_KEY=
FAYDA_API_URL=
FAYDA_API_KEY=
```

### admin-web/.env keys
```
VITE_API_URL=                                  # public backend URL (no trailing slash)
VITE_GOOGLE_MAPS_API_KEY=                      # Google Maps JavaScript API key
```

## Deployment (public URL)
- `backend/Dockerfile` — Node 20 image; `npm ci --omit=dev`; CMD `npm run start:deploy`.
- `backend/scripts/deploy-migrate.js` — runs schema.sql -> migration_defence.sql ->
  migration_gaps.sql (strict) -> seed.sql (tolerant) on boot. Verified locally
  (61/18/22/24 statements, idempotent).
- `backend/scripts/sql-split.js` — SQL splitter that understands `DO $$ ... $$`,
  strings, and comments (used by both run-sql.js and deploy-migrate.js).
- `backend/package.json` — `"start:deploy"` added.
- `render.yaml` (repo root) — Blueprint: Docker API + free Postgres + static admin site.
- `DEPLOY.md` (repo root) — step-by-step Render/Railway instructions + env var table.
- Backend already honors `PORT`, `DATABASE_URL` (TLS auto for non-local hosts), and
  `NODE_ENV=production`; `FIREBASE_SERVICE_ACCOUNT_JSON` accepts inline JSON.
- To connect the app after deploy: set Server in-app to the public URL, or build with
  `--dart-define=ZEGA_API_BASE=https://<host>`.

### LIVE (deployed)
- API: https://zega-alert-api.onrender.com  (`/health` -> `{"ok":true}`; login works)
- Admin web: https://zega-alert-admin.onrender.com
- DB: Render Postgres (external URL in the API's `DATABASE_URL` env var; schema+seed applied)
- Mobile: APK built with `--dart-define=ZEGA_API_BASE=https://zega-alert-api.onrender.com`
  so it works on any network (delivered as `zega-alert-updated-v5-public.zip`).
- Fixes that made deploy work: external DB URL (region), firestore/storage added as real
  deps + lazy-loaded (they are optionalDependencies of firebase-admin and were skipped by
  `npm ci --omit=dev`).


