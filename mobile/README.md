# ZEGA-ALERT Mobile App

**Crime Reporting, Missing Person Finder & Emergency Assistance** — Flutter citizen mobile app.

## Overview

This is the citizen-facing mobile app for the ZEGA-ALERT system. It provides a 5-tab UI for citizens to report crimes, send SOS emergencies, view news and missing persons, chat with staff, and manage settings.

## Features

- **Home**: SOS emergency button with GPS, announcements, missing/wanted persons lists
- **Report**: Submit crime reports with category, severity, evidence (photo/video/audio), anonymous option
- **News**: 4-tab view — Announcements, Legal articles, Missing persons, Sightings
- **Messages**: Real-time chat with staff via Socket.io
- **Settings**: Account management, region/city selection, language, safety zones, accessibility, dark mode, callbacks
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
