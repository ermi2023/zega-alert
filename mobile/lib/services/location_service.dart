import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Best-effort device location for SOS, reports and PoD requests.
///
/// The primary source is the device GPS (geolocator). When that is unavailable
/// (permission denied, location services off, or no fix before the timeout) we
/// fall back to a coarse, network-derived location from GeoAPI.info. The
/// fallback is intentionally reported with a very large [Position.accuracy] so
/// callers and responders can tell it apart from a precise GPS fix.
class LocationService {
  LocationService._();

  /// GeoAPI.info resolves the *calling* IP, so this must run on the device
  /// (not proxied through the backend, which would geolocate the server).
  static const String _networkUrl = 'https://geoapi.info/api/geo';

  /// Accuracy (metres) reported for a network-derived fix. Deliberately large
  /// so it is never mistaken for a GPS reading.
  static const double networkAccuracyMeters = 25000;

  static const Duration _networkTimeout = Duration(seconds: 6);

  /// Try the GPS first, then the network fallback. Returns null if both fail.
  static Future<Position?> best({Duration gpsTimeout = const Duration(seconds: 10)}) async {
    final gps = await _gps(gpsTimeout);
    if (gps != null) return gps;
    return (await networkLocation())?.toPosition();
  }

  static Future<Position?> _gps(Duration timeout) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      return await Geolocator.getCurrentPosition().timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  /// Coarse, IP-based location from GeoAPI.info. Never throws; null on failure.
  static Future<NetworkLocation?> networkLocation() async {
    try {
      final res = await http.get(Uri.parse(_networkUrl)).timeout(_networkTimeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body is! Map) return null;
      final loc = body['location'];
      if (loc is! Map) return null;
      final coords = loc['coordinates'];
      if (coords is! Map) return null;
      final lat = double.tryParse('${coords['latitude']}');
      final lng = double.tryParse('${coords['longitude']}');
      if (lat == null || lng == null) return null;
      return NetworkLocation(
        latitude: lat,
        longitude: lng,
        city: loc['city'] as String?,
        region: loc['region'] as String?,
        country: loc['country'] as String?,
        timezone: loc['timezone'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// A coarse, network-derived location (approximate coordinates + place names)
/// returned by GeoAPI.info when the device has no usable GPS fix.
class NetworkLocation {
  final double latitude;
  final double longitude;
  final String? city;
  final String? region;
  final String? country;
  final String? timezone;

  const NetworkLocation({
    required this.latitude,
    required this.longitude,
    this.city,
    this.region,
    this.country,
    this.timezone,
  });

  /// Adapt to a geolocator [Position] so call sites can stay unchanged. The
  /// large accuracy marks this as an approximate, network-derived fix.
  Position toPosition() => Position(
        longitude: longitude,
        latitude: latitude,
        timestamp: DateTime.now(),
        accuracy: LocationService.networkAccuracyMeters,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        isMocked: false,
      );
}
