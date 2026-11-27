# ZEGA-ALERT Mobile App

**Crime Reporting, Missing Person Finder & Emergency Assistance** — Flutter citizen mobile app.

## Overview

This is the citizen-facing mobile app for the ZEGA-ALERT system. It provides Home, Report, SOS, News, and Safety Zones in the bottom navigation; Settings is available from the top bar.

## Features

- **Home**: SOS emergency button with GPS, announcements, missing/wanted persons lists
- **Report**: Submit crime reports with category, severity, evidence (photo/video/audio), anonymous option
- **News**: 4-tab view — Announcements, Legal articles, Missing persons, Sightings
- **Messages**: Real-time chat with staff via Socket.io
- **Safety Zones**: View official local zones and open each mapped boundary; updates and incidents appear in Notifications. Android users can optionally enable on-device entry alerts in Settings → Personal information.
- **Settings**: Account management, profile, region/city selection, language, accessibility, dark mode, callbacks
- **Registration**: Phone OTP is entered on screen; in development, the temporary OTP is displayed in the app when SMS is unavailable
- **Identity**: In Settings, verify with a 16-digit FAN or scan the original ID QR; only the FAN is checked against admin-managed mock records

## Architecture

```
lib/
├── main.dart                 # App entry point, theme, navigation
├── config/
│   └── constants.dart        # Regions, sub-cities, static data
├── models/
│   └── models.dart           # Data classes (User, Report, SosAlert, etc.)
├── screens/
│   ├── auth_screen.dart      # Login/Register with OTP
│   ├── home_screen.dart      # SOS, announcements, missing persons
│   ├── report_screen.dart    # Crime report list + submission
│   ├── news_screen.dart      # News tabs (announcements, legal, missing, sightings)
│   ├── communication_screen.dart  # Real-time chat
│   ├── callbacks_screen.dart # Police callback follow-ups
│   ├── settings_screen.dart  # Account, language, zones, accessibility
│   └── missing_report_screen.dart  # Missing person + sighting forms
├── services/
│   ├── api.dart              # REST API client with JWT auth
│   └── socket_service.dart   # Socket.io wrapper for real-time events
└── widgets/
    └── photo_upload.dart     # Reusable camera/gallery photo upload widget
```

## Setup

```bash
cd mobile
flutter create .          # generates android/ios/etc scaffolding
flutter pub get
flutter run               # on an emulator/device
```

### Optional background Safety Zone entry alerts (Android)

In **Settings → Personal information**, enable **Safety Zone entry alerts** to
receive a local notification when the device enters an active published zone.
Android requires the app's location permission to be set to **Allow all the
time**, device notifications to be enabled, and device Location to be on. An
ongoing Android notification indicates that background monitoring is active;
continuous GPS can use additional battery.

Coordinates used for these entry alerts are checked on the device and are not
uploaded. Saved Region/Sub-city values remain available for area-based
information if tracking is off or unavailable. SOS and report actions may use
location separately when submitted. Entry alerts are a supplementary warning,
not a guarantee of safety; force-stopping the app or device power restrictions
may stop background monitoring.

## Smaller Android releases for all CPU architectures

For Google Play, build one Android App Bundle with 32-bit ARM, 64-bit ARM, and
x86_64 support. Play delivers only the native libraries each device needs:

```bash
flutter build appbundle --release \
  --target-platform=android-arm,android-arm64,android-x64
```

To install or share a single APK directly across supported devices, build a
universal APK:

```bash
flutter build apk --release \
  --target-platform=android-arm,android-arm64,android-x64
```

This creates `build/app/outputs/flutter-apk/app-release.apk` with all three
architectures. Share the same file with every supported device; Android uses
the native libraries matching that device. The universal APK is larger because
it includes every architecture. For the smallest device-specific downloads,
publish the App Bundle to Google Play instead.

## Configuration

The API base URL is configured in `lib/services/api.dart`:
- **Android emulator**: `http://10.0.2.2:5000` (maps to host localhost)
- **Physical device**: Change to your backend server IP

### Live SOS audio and video

The backend supplies WebRTC ICE configuration to the mobile app and dispatch
dashboard. STUN is used by default; reliable calls across cellular networks and
restrictive firewalls also require a reachable TURN relay. Configure
`TURN_URLS`, `TURN_USERNAME`, and `TURN_CREDENTIAL` on the backend using your
TURN provider's details. `TURN_URLS` accepts comma-separated `turn:` or
`turns:` endpoints. Without a configured TURN relay, some networks will not
allow audio/video to connect even when microphone and camera permissions are
granted. If the deployed backend is older and does not have the ICE-config
route yet, the app temporarily falls back to STUN; deploy the backend updates
to enable TURN.

## Demo Login

| Role    | Phone       | Password     |
|---------|-------------|--------------|
| Citizen | 0911000005  | password123  |

## Key Packages

| Package | Purpose |
|---------|---------|
| `http` | REST API calls |
| `socket_io_client` | Real-time WebSocket events |
| `shared_preferences` | Token persistence |
| `geolocator` | GPS location for SOS/reports |
| `url_launcher` | Phone calls from Settings |
| `image_picker` | Camera/gallery photo capture |
| `intl` | Date/time formatting |
