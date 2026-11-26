import 'package:flutter_test/flutter_test.dart';
import 'package:zega_alert_mobile/services/safety_zone_tracking_service.dart';

void main() {
  group('SafetyZoneTrackingService.isInsideSafetyZone', () {
    test('checks circular boundaries in meters', () {
      const zone = {
        'type': 'zone',
        'center_lat': 9.0,
        'center_lng': 38.7,
        'radius_m': 100,
      };

      expect(
        SafetyZoneTrackingService.isInsideSafetyZone(zone, 9.0, 38.7),
        isTrue,
      );
      expect(
        SafetyZoneTrackingService.isInsideSafetyZone(zone, 9.0, 38.702),
        isFalse,
      );
    });

    test('checks polygon boundaries and includes points on the edge', () {
      const zone = {
        'type': 'zone',
        'polygon': [
          [0, 0],
          [0, 1],
          [1, 1],
          [1, 0],
        ],
      };

      expect(
        SafetyZoneTrackingService.isInsideSafetyZone(zone, 0.5, 0.5),
        isTrue,
      );
      expect(
        SafetyZoneTrackingService.isInsideSafetyZone(zone, 1.5, 0.5),
        isFalse,
      );
      expect(
        SafetyZoneTrackingService.isInsideSafetyZone(zone, 0, 0.5),
        isTrue,
      );
    });

    test('does not monitor inactive or non-safety-zone areas', () {
      expect(
        SafetyZoneTrackingService.isInsideSafetyZone(
          const {
            'type': 'hospital',
            'center_lat': 9.0,
            'center_lng': 38.7,
            'radius_m': 100,
          },
          9.0,
          38.7,
        ),
        isFalse,
      );
      expect(
        SafetyZoneTrackingService.isInsideSafetyZone(
          const {
            'type': 'zone',
            'is_active': false,
            'center_lat': 9.0,
            'center_lng': 38.7,
            'radius_m': 100,
          },
          9.0,
          38.7,
        ),
        isFalse,
      );
    });
  });
}
