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
}
