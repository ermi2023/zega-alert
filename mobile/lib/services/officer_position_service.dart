import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api.dart';

class OfficerPositionService {
  static Timer? _timer;
  static bool _active = false;

  static void start() {
    if (_active) return;
    _active = true;
    _reportPosition();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _reportPosition());
  }

  static void stop() {
    _active = false;
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _reportPosition() async {
    if (!_active || Api.token == null) return;

    try {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (_) {
        return;
      }

      await Api.post('/position/report', {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'heading': pos.heading,
        'speed': pos.speed,
      });
    } catch (_) {
      // Silent fail — will retry next cycle
    }
  }

  /// WorkManager entry point: reports a position even when the app is closed.
  /// Best-effort because OS background-location limits vary by device.
  static Future<void> reportInBackground() async {
    try {
      await Api.loadToken();
      final role = Api.role;
      if (Api.token == null || (role != 'police' && role != 'dispatcher')) return;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      ).timeout(const Duration(seconds: 25));
      await Api.post('/position/report', {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'heading': pos.heading,
        'speed': pos.speed,
        'background': true,
      });
    } catch (_) {
      // Best-effort; the foreground timer resumes when the app reopens.
    }
  }
}
