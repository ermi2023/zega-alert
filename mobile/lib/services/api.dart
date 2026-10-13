import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, TargetPlatform, defaultTargetPlatform;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class Api {
  static const String _lanHost = '10.108.92.91';

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://$_lanHost:5000';
    if (defaultTargetPlatform == TargetPlatform.windows) return 'http://localhost:5000';
    return 'http://$_lanHost:5000';
  }

  static String get socketUrl {
    if (kIsWeb) return 'http://localhost:5000';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://$_lanHost:5000';
    if (defaultTargetPlatform == TargetPlatform.windows) return 'http://localhost:5000';
    return 'http://$_lanHost:5000';
  }

  static String? _token;
  static String? _userId;
  static String? _refreshToken;
  static String? _region;
  static String? _subCity;
  static String? get token => _token;
  static String? get userId => _userId;
  static String? get refreshToken => _refreshToken;

  /// Region / sub-city chosen by the signed-in user (used on report, SOS and
  /// missing-person submissions). Null when the user has not set a location.
  static String? get region => _region;
  static String? get subCity => _subCity;

  /// Cache the region/sub-city from a user object (login or /auth/me).
  static Future<void> setProfile(Map<String, dynamic>? user) async {
    if (user == null) return;
    final r = (user['region'] as String?)?.trim();
    final s = (user['sub_city'] as String?)?.trim();
    _region = (r != null && r.isNotEmpty) ? r : _region;
    _subCity = (s != null && s.isNotEmpty) ? s : _subCity;
    final prefs = await SharedPreferences.getInstance();
    if (_region != null) await prefs.setString('region', _region!);
    if (_subCity != null) await prefs.setString('sub_city', _subCity!);
  }

  static Future<void> setToken(String t, {String? userId}) async {
    _token = t;
    _userId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', t);
    if (userId != null) await prefs.setString('userId', userId);
  }

  static Future<void> setRefreshToken(String? t) async {
    _refreshToken = t;
    final prefs = await SharedPreferences.getInstance();
    if (t == null) {
      await prefs.remove('refreshToken');
    } else {
      await prefs.setString('refreshToken', t);
    }
  }

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _userId = prefs.getString('userId');
    _refreshToken = prefs.getString('refreshToken');
    _region = prefs.getString('region');
    _subCity = prefs.getString('sub_city');
  }

  /// Exchange the stored refresh token for a fresh access token.
  /// Used by biometric login. Returns true on success.
  static Future<bool> refreshSession() async {
    if (_refreshToken == null) return false;
    try {
      final data = await _send('POST', '/auth/refresh', {'refreshToken': _refreshToken});
      await setToken(data['accessToken'], userId: _userId);
      if (data['refreshToken'] != null) await setRefreshToken(data['refreshToken']);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clear() async {
    _token = null;
    _userId = null;
    _refreshToken = null;
    _region = null;
    _subCity = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('refreshToken');
    await prefs.remove('region');
    await prefs.remove('sub_city');
  }

  static Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$baseUrl/api$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_token != null) headers['Authorization'] = 'Bearer $_token';
    final req = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiException(data['message'] ?? 'Request failed');
    }
    return data['data'];
  }

  static Future<dynamic> get(String path) => _send('GET', path);
  static Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body);

  /// Public raw request used by the offline sync service.
  static Future<dynamic> request(String method, String path, [Map<String, dynamic>? body]) =>
      _send(method, path, body);

  /// Try to POST immediately; if the device is offline (network error rather
  /// than a rejected request) queue it in the local outbox for later sync.
  /// Returns {'queued': true} when queued, otherwise {'queued': false, 'data': ...}.
  static Future<Map<String, dynamic>> postOrQueue(String path, Map<String, dynamic> body) async {
    try {
      final data = await _send('POST', path, body);
      return {'queued': false, 'data': data};
    } on ApiException {
      rethrow; // Server received it and rejected — do not queue.
    } catch (_) {
      if (!kIsWeb) {
        await DatabaseService.enqueue('POST', path, body);
        return {'queued': true};
      }
      rethrow;
    }
  }
  /// UC-11: record a social-share analytics event. Best-effort (never throws).
  static Future<void> recordShare(String contentType, String? contentId, {String platform = 'other'}) async {
    try {
      await _send('POST', '/share', {
        'content_type': contentType,
        'content_id': contentId,
        'platform': platform,
      });
    } catch (_) {}
  }

  /// Map a share_plus result's raw target to one of the analytics platforms.
  static String platformFromRaw(String? raw) {
    final r = (raw ?? '').toLowerCase();
    if (r.contains('facebook')) return 'facebook';
    if (r.contains('telegram')) return 'telegram';
    if (r.contains('twitter') || r.contains('x.com')) return 'twitter';
    if (r.contains('instagram')) return 'instagram';
    if (r.contains('whatsapp')) return 'whatsapp';
    if (r.contains('copy') || r.contains('pasteboard')) return 'copy_link';
    return 'other';
  }

  static Future<dynamic> patch(String path, [Map<String, dynamic>? body]) => _send('PATCH', path, body);
  static Future<dynamic> put(String path, [Map<String, dynamic>? body]) => _send('PUT', path, body);
  static Future<dynamic> delete(String path) => _send('DELETE', path);

  static Future<dynamic> upload(String path, List<MapEntry<String, String>> files,
      {Map<String, String>? fields}) async {
    final uri = Uri.parse('$baseUrl/api$path');
    final req = http.MultipartRequest('POST', uri);
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    fields?.forEach((k, v) => req.fields[k] = v);
    for (final f in files) {
      req.files.add(await http.MultipartFile.fromPath(f.key, f.value));
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiException(data['message'] ?? 'Upload failed');
    }
    return data['data'];
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
