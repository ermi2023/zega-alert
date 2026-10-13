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
7. Backend `.env`: `ENCRYPTION_KEY=72870d832d75c7cce311836c11ed6d9fe43a40edacbe5c6166086fb0f16b06e9`.

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
2. Phone on same Wi-Fi as PC. Backend host in `mobile/lib/services/api.dart` = `_lanHost='10.108.92.91'`.
   If PC LAN IP changed, edit it and rebuild.
3. Demo logins (pwd `password123`): 0911000001 System Admin, ...002 Regional, ...003 Dispatcher, ...004 Police, ...005 Citizen.

## KEY PATHS / ENV
- Project: `C:\Users\hp g7\ZEGA-ALERT` (backend port 5000, admin-web Vite port 5173)
- Flutter: `C:\flutter\bin\flutter.bat` (3.47.0) | Java Temurin 17
- Old SDK: `C:\Program Files (x86)\Android\android-sdk` | New SDK: `C:\Users\hp g7\Android\Sdk`
- DB: postgres user `zega` / `zega_dev_2026` @ localhost:5432 / db `zega_alert`
- Start backend: `Start-Process node -ArgumentList "src/server.js" -WorkingDirectory "C:\Users\hp g7\ZEGA-ALERT\backend" -WindowStyle Hidden`
- Kill backend: `(Get-NetTCPConnection -LocalPort 5000 -State Listen).OwningProcess | % { Stop-Process -Id $_ -Force }`

## VERIFIED WORKING
`node app.js` imports OK; AES-256-GCM crypto round-trip; login + `/verification/status` + `/verification/qr`;
PII encrypted at rest (`enc:v1:`); missing-person + SOS create/read decrypt OK; `flutter analyze` = 0 errors.
