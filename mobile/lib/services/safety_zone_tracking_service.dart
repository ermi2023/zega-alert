import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SafetyZoneTrackingIssue {
  androidOnly,
  deviceLocationOff,
  backgroundLocationPermission,
  notificationsUnavailable,
  notificationPermission,
  monitoringStartFailed,
  monitoringRestartFailed,
  monitoringStopped,
  boundaryCheckFailed,
}

class SafetyZoneTrackingException implements Exception {
  const SafetyZoneTrackingException(this.issue);

  final SafetyZoneTrackingIssue issue;
}

class SafetyZoneTrackingService {
  SafetyZoneTrackingService._();

  static const _enabledKey = 'safety_zone_location_alerts_enabled';
  static const _zonesKey = 'safety_zone_location_alerts_zones';
  static const _insideKey = 'safety_zone_location_alerts_inside';
  static const _channelId = 'safety_zone_entry_alerts';

  static final _notifications = FlutterLocalNotificationsPlugin();
  static StreamSubscription<Position>? _positionSubscription;
  static List<Map<String, dynamic>> _zones = [];
  static Map<String, bool> _insideStates = {};
  static bool _notificationsInitialized = false;
  static SafetyZoneTrackingIssue? _lastError;

  static SafetyZoneTrackingIssue? get lastError => _lastError;
  static int get monitoredZoneCount => _zones.length;

  static Future<bool> isEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_enabledKey) ?? false;
  }

  static Future<void> enable(List<dynamic> zones) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const SafetyZoneTrackingException(
        SafetyZoneTrackingIssue.androidOnly,
      );
    }

    await updatePublishedZones(zones);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, true);

    try {
      await _startMonitoring();
    } catch (error) {
      await preferences.setBool(_enabledKey, false);
      _lastError = error is SafetyZoneTrackingException
          ? error.issue
          : SafetyZoneTrackingIssue.monitoringStartFailed;
      rethrow;
    }
  }

  static Future<void> disable() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, false);
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastError = null;
  }

  static Future<void> resumeIfEnabled() async {
    if (!await isEnabled()) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const SafetyZoneTrackingException(
        SafetyZoneTrackingIssue.androidOnly,
      );
    }

    final preferences = await SharedPreferences.getInstance();
    final savedZones = preferences.getString(_zonesKey);
    if (savedZones != null) {
      final decoded = jsonDecode(savedZones);
      if (decoded is List) {
        _zones = decoded
            .whereType<Map>()
            .map((zone) => Map<String, dynamic>.from(zone))
            .toList();
      }
    }
    final savedStates = preferences.getString(_insideKey);
    if (savedStates != null) {
      final decoded = jsonDecode(savedStates);
      if (decoded is Map) {
        _insideStates = decoded.map(
          (key, value) => MapEntry(key.toString(), value == true),
        );
      }
    }
    try {
      await _startMonitoring();
    } catch (error) {
      _lastError = error is SafetyZoneTrackingException
          ? error.issue
          : SafetyZoneTrackingIssue.monitoringRestartFailed;
      rethrow;
    }
  }

  static Future<void> updatePublishedZones(List<dynamic> records) async {
    final zones = <Map<String, dynamic>>[];
    for (final record in records) {
      if (record is! Map) {
        throw const FormatException('Unexpected Safety Zone data.');
      }
      final source = Map<String, dynamic>.from(record);
      if (source['is_active'] == false || source['type'] != 'zone') continue;

      final id = source['id']?.toString();
      if (id == null || id.isEmpty) continue;

      final rawPolygon = source['polygon'];
      final polygon = rawPolygon is String
          ? jsonDecode(rawPolygon)
          : rawPolygon;
      final zone = <String, dynamic>{
        'id': id,
        'name': (source['label'] ?? source['name'] ?? 'Safety Zone').toString(),
        'type': source['type'],
        'is_active': source['is_active'] != false,
        'center_lat': _asDouble(source['center_lat']),
        'center_lng': _asDouble(source['center_lng']),
        'radius_m': _asDouble(source['radius_m']),
        'polygon': polygon is List ? polygon : const [],
      };
      if (_hasValidBoundary(zone)) zones.add(zone);
    }

    final activeIds = zones.map((zone) => zone['id'] as String).toSet();
    _insideStates.removeWhere((id, _) => !activeIds.contains(id));
    _zones = zones;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_zonesKey, jsonEncode(zones));
    await preferences.setString(_insideKey, jsonEncode(_insideStates));
  }

  static Future<void> _startMonitoring() async {
    if (_positionSubscription != null) return;
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const SafetyZoneTrackingException(
        SafetyZoneTrackingIssue.deviceLocationOff,
      );
    }
    if (await Geolocator.checkPermission() != LocationPermission.always) {
      throw const SafetyZoneTrackingException(
        SafetyZoneTrackingIssue.backgroundLocationPermission,
      );
    }

    await _initializeNotifications();
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
      intervalDuration: const Duration(seconds: 20),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Safety Zone alerts are on',
        notificationText:
            'Location is checked on this device for active Safety Zones.',
        notificationChannelName: 'Safety Zone monitoring',
        notificationIcon: AndroidResource(name: 'ic_safety_zone'),
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      _handlePosition,
      onError: (Object error, StackTrace stackTrace) {
        _lastError =
            SafetyZoneTrackingIssue.monitoringStopped;
        debugPrint('Safety Zone location stream failed: $error');
      },
    );
    _lastError = null;
  }

  static Future<void> _initializeNotifications() async {
    if (!_notificationsInitialized) {
      await _notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_safety_zone'),
        ),
      );
    }
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      throw const SafetyZoneTrackingException(
        SafetyZoneTrackingIssue.notificationsUnavailable,
      );
    }

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Safety Zone entry alerts',
        description: 'Alerts when you enter an active published Safety Zone.',
        importance: Importance.max,
      ),
    );
    var notificationsEnabled = await android.areNotificationsEnabled() ?? false;
    if (!notificationsEnabled) {
      await android.requestNotificationsPermission();
      notificationsEnabled = await android.areNotificationsEnabled() ?? false;
    }
    if (!notificationsEnabled) {
      throw const SafetyZoneTrackingException(
        SafetyZoneTrackingIssue.notificationPermission,
      );
    }
    _notificationsInitialized = true;
  }

  static void _handlePosition(Position position) {
    unawaited(
      _evaluatePosition(position).catchError((Object error, StackTrace stack) {
        _lastError = SafetyZoneTrackingIssue.boundaryCheckFailed;
        debugPrint('Safety Zone boundary check failed: $error');
      }),
    );
  }

  static Future<void> _evaluatePosition(Position position) async {
    final preferences = await SharedPreferences.getInstance();
    for (final zone in _zones) {
      final id = zone['id'] as String;
      final inside = isInsideSafetyZone(
        zone,
        position.latitude,
        position.longitude,
      );
      final wasInside = _insideStates[id];
      if (wasInside == false && inside) {
        await _showEntryAlert(zone);
      }
      _insideStates[id] = inside;
    }
    await preferences.setString(_insideKey, jsonEncode(_insideStates));
  }

  static Future<void> _showEntryAlert(Map<String, dynamic> zone) async {
    final name = zone['name']?.toString() ?? 'an active Safety Zone';
    await _notifications.show(
      _notificationId(zone['id'] as String),
      'Safety Zone entry alert',
      'You entered $name. Review its official information and follow local authority guidance.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Safety Zone entry alerts',
          channelDescription:
              'Alerts when you enter an active published Safety Zone.',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  static int _notificationId(String value) {
    var hash = 0;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  static bool isInsideSafetyZone(
    Map<String, dynamic> zone,
    double latitude,
    double longitude,
  ) {
    if (zone['type'] != 'zone' || zone['is_active'] == false) return false;
    final polygon = zone['polygon'];
    if (polygon is List && polygon.length >= 3) {
      return _pointInPolygon(latitude, longitude, polygon);
    }

    final centerLat = _asDouble(zone['center_lat']);
    final centerLng = _asDouble(zone['center_lng']);
    final radius = _asDouble(zone['radius_m']);
    if (centerLat == null ||
        centerLng == null ||
        radius == null ||
        !centerLat.isFinite ||
        !centerLng.isFinite ||
        centerLat < -90 ||
        centerLat > 90 ||
        centerLng < -180 ||
        centerLng > 180 ||
        !radius.isFinite ||
        radius <= 0) {
      return false;
    }
    final distance = const Distance().as(
      LengthUnit.Meter,
      LatLng(latitude, longitude),
      LatLng(centerLat, centerLng),
    );
    return distance <= radius;
  }

  static bool _hasValidBoundary(Map<String, dynamic> zone) {
    final polygon = zone['polygon'];
    if (polygon is List && polygon.length >= 3) {
      return polygon.every((point) => _readPoint(point) != null);
    }
    final latitude = _asDouble(zone['center_lat']);
    final longitude = _asDouble(zone['center_lng']);
    final radius = _asDouble(zone['radius_m']);
    return latitude != null &&
        longitude != null &&
        radius != null &&
        latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        radius.isFinite &&
        radius >= 50;
  }

  static bool _pointInPolygon(
    double latitude,
    double longitude,
    List<dynamic> polygon,
  ) {
    final points = polygon.map(_readPoint).toList();
    if (points.any((point) => point == null)) return false;

    var inside = false;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      final a = points[i]!;
      final b = points[j]!;
      final cross =
          (longitude - a.longitude) * (b.latitude - a.latitude) -
          (latitude - a.latitude) * (b.longitude - a.longitude);
      if (cross.abs() < 1e-10 &&
          longitude >= (a.longitude < b.longitude ? a.longitude : b.longitude) &&
          longitude <= (a.longitude > b.longitude ? a.longitude : b.longitude) &&
          latitude >= (a.latitude < b.latitude ? a.latitude : b.latitude) &&
          latitude <= (a.latitude > b.latitude ? a.latitude : b.latitude)) {
        return true;
      }
      if ((a.latitude > latitude) != (b.latitude > latitude) &&
          longitude <
              ((b.longitude - a.longitude) * (latitude - a.latitude)) /
                      (b.latitude - a.latitude) +
                  a.longitude) {
        inside = !inside;
      }
    }
    return inside;
  }

  static LatLng? _readPoint(dynamic point) {
    if (point is List && point.length >= 2) {
      final latitude = _asDouble(point[0]);
      final longitude = _asDouble(point[1]);
      if (latitude != null &&
          longitude != null &&
          _isValidCoordinate(latitude, longitude)) {
        return LatLng(latitude, longitude);
      }
    } else if (point is Map) {
      final latitude = _asDouble(point['lat'] ?? point['latitude']);
      final longitude = _asDouble(point['lng'] ?? point['longitude']);
      if (latitude != null &&
          longitude != null &&
          _isValidCoordinate(latitude, longitude)) {
        return LatLng(latitude, longitude);
      }
    }
    return null;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool _isValidCoordinate(double? latitude, double? longitude) =>
      latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}
