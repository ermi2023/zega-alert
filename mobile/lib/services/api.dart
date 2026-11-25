import 'dart:convert';

import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, TargetPlatform, defaultTargetPlatform;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'database_service.dart';
import 'net_info_stub.dart' if (dart.library.io) 'net_info_io.dart' as netinfo;

class Api {
  static const int port = 5000;

  /// Build-time backend base URL, e.g.
  /// `flutter build apk --dart-define=ZEGA_API_BASE=https://api.example.et`.
  /// Empty in normal local builds (falls back to LAN auto-detect).
  static const String _envBase = String.fromEnvironment('ZEGA_API_BASE');

  static const String appVersion = '1.0.2';

  /// User-set backend base URL (e.g. a public HTTPS tunnel), persisted from the
  /// Settings screen. Takes precedence over everything else when present.
  static String? _overrideBase;

  /// The currently active explicit override, if any (for the settings UI).
  static String? get overrideBaseUrl => _overrideBase;
  static bool get hasEnvBase => _envBase.isNotEmpty;

  /// Well-known backend hosts probed before scanning the local subnet.
  static const List<String> _candidateHosts = [
    '192.168.137.1', // Windows Mobile Hotspot gateway
    '10.0.2.2', // Android emulator host loopback
    '192.168.56.1', // VirtualBox host-only network
  ];

  /// Last discovered LAN backend host (null until a probe/scan succeeds).
  static String? _lanHost;

  /// Point the app at an explicit backend URL (no trailing slash). Pass null or
  /// an empty string to clear it and fall back to LAN auto-detection.
  static Future<void> setBaseUrl(String? url) async {
    final clean = (url ?? '').trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    if (clean.isEmpty) {
      _overrideBase = null;
      await prefs.remove('apiBaseUrl');
    } else {
      _overrideBase = clean;
      await prefs.setString('apiBaseUrl', clean);
    }
  }

  /// Resolve which backend to use at startup: a saved/compiled explicit URL
  /// wins; otherwise probe well-known hosts, then scan the device's own subnet
  /// (the PC's IP changes with DHCP, so we can't hardcode it). Safe no-op on
  /// web and desktop.
  static Future<void> resolveHost() async {
    _overrideBase = null;
    _lanHost = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('apiBaseUrl');
      if (saved != null && saved.isNotEmpty) _overrideBase = saved;
    } catch (_) {}

    if (_overrideBase != null || _envBase.isNotEmpty)
      return; // explicit URL wins
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    // Auto-discovery only matters during development; release builds go straight
    // to the cloud API (avoiding a slow subnet scan at launch).
    if (!kDebugMode) return;

    String? cached;
    try {
      cached = (await SharedPreferences.getInstance()).getString('lanHost');
    } catch (_) {}

    // 1) Probe known hosts (and the last known-good one) concurrently.
    final known = <String>[
      if (cached != null && cached.isNotEmpty) cached,
      ..._candidateHosts,
    ];
    final probed = await Future.wait(
      known.map((h) => _hostAlive(h, ms: 1500).then((ok) => ok ? h : null)),
    );
    final hit = probed.firstWhere((h) => h != null, orElse: () => null);
    if (hit != null) {
      await _useHost(hit);
      return;
    }

    // 2) Scan the network(s) the phone is actually on.
    final scanned = await _scanLocalSubnets();
    if (scanned != null) {
      await _useHost(scanned);
      return;
    }

    if (cached != null && cached.isNotEmpty) _lanHost = cached;
  }

  static Future<void> _useHost(String host) async {
    _lanHost = host;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lanHost', host);
    } catch (_) {}
  }

  static Future<String?> _scanLocalSubnets() async {
    final subnets = await netinfo.localIpv4Subnets();
    for (final subnet in subnets) {
      final host = await _scanSubnet(subnet);
      if (host != null) return host;
    }
    return null;
  }

  static Future<String?> _scanSubnet(String subnet) async {
    const batchSize = 48;
    for (var start = 1; start <= 254; start += batchSize) {
      final end = start + batchSize - 1 > 254 ? 254 : start + batchSize - 1;
      final futures = <Future<String?>>[
        for (var h = start; h <= end; h++)
          _hostAlive(
            '$subnet.$h',
            ms: 900,
          ).then((ok) => ok ? '$subnet.$h' : null),
      ];
      final results = await Future.wait(futures);
      for (final r in results) {
        if (r != null) return r;
      }
    }
    return null;
  }

  static Future<bool> _hostAlive(String host, {int ms = 2000}) async {
    try {
      final res = await http
          .get(Uri.parse('http://$host:$port/health'))
          .timeout(Duration(milliseconds: ms));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static const String _defaultCloudBase = 'https://zega-alert-api.onrender.com';

  static String get baseUrl {
    if (_overrideBase != null && _overrideBase!.isNotEmpty)
      return _overrideBase!;
    if (_envBase.isNotEmpty) return _envBase;
    if (kIsWeb) return 'http://localhost:$port';
    // Prefer a backend discovered on the local network, otherwise fall back to
    // the production Render cloud API.
    if (_lanHost != null && _lanHost!.isNotEmpty)
      return 'http://$_lanHost:$port';
    return _defaultCloudBase;
  }

  static String get socketUrl => baseUrl;

  /// Turn a stored asset path into an absolute URL. Uploads are usually stored
  /// as relative paths (`/uploads/...`), while Firebase-backed uploads are
  /// already absolute — this handles both without double-prefixing.
  static String? assetUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final u = url.trim();
    if (u.startsWith('http://') ||
        u.startsWith('https://') ||
        u.startsWith('data:'))
      return u;
    return '$baseUrl${u.startsWith('/') ? '' : '/'}$u';
  }

  static String? _token;
  static String? _userId;
  static String? _refreshToken;
  static String? _region;
  static String? _subCity;
  static Map<String, dynamic>? _profile;
  static const String _profileCacheKey = 'public_user_profile';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static String? _role;
  static String? get token => _token;
  static String? get userId => _userId;
  static String? get refreshToken => _refreshToken;

  /// True once a real account is signed in (false while browsing as a guest).
  static bool get isLoggedIn => _token != null;

  /// Region / sub-city chosen by the signed-in user (used on report, SOS and
  /// missing-person submissions). Null when the user has not set a location.
  static String? get region => _region;
  static String? get subCity => _subCity;
  static String? get role => _role;
  static Map<String, dynamic>? get profile =>
      _profile == null ? null : Map<String, dynamic>.from(_profile!);

  /// Cache only public profile fields; credentials are never stored here.
  static Future<void> setProfile(Map<String, dynamic>? user) async {
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    const publicFields = [
      'full_name',
      'email',
      'phone',
      'role',
      'region',
      'sub_city',
      'accessibility_mode',
      'preferred_language',
      'is_verified',
      'created_at',
    ];
    final publicProfile = <String, dynamic>{};
    for (final field in publicFields) {
      if (user.containsKey(field)) publicProfile[field] = user[field];
    }
    _profile = {...?_profile, ...publicProfile};
    await DatabaseService.cacheValue(_profileCacheKey, _profile);

    final role = (user['role'] as String?)?.trim();
    if (role != null && role.isNotEmpty) {
      _role = role;
      await prefs.setString('role', role);
    }
    final r = (user['region'] as String?)?.trim();
    final s = (user['sub_city'] as String?)?.trim();
    _region = (r != null && r.isNotEmpty) ? r : _region;
    _subCity = (s != null && s.isNotEmpty) ? s : _subCity;
    if (_region != null) await prefs.setString('region', _region!);
    if (_subCity != null) await prefs.setString('sub_city', _subCity!);
  }

  static Future<void> setToken(String t, {String? userId}) async {
    _token = t;
    _userId = userId;
    final prefs = await SharedPreferences.getInstance();
    if (kIsWeb) {
      // Browser tokens stay memory-only; do not persist auth credentials in localStorage.
      await prefs.remove('token');
      await prefs.remove('userId');
      return;
    }
    await _secureStorage.write(key: 'token', value: t);
    await prefs.remove('token');
    if (userId != null) await prefs.setString('userId', userId);
  }

  static Future<void> setRefreshToken(String? t) async {
    _refreshToken = t;
    final prefs = await SharedPreferences.getInstance();
    if (kIsWeb) {
      await prefs.remove('refreshToken');
      return;
    }
    if (t == null) {
      await _secureStorage.delete(key: 'refreshToken');
      await prefs.remove('refreshToken');
    } else {
      await _secureStorage.write(key: 'refreshToken', value: t);
      await prefs.remove('refreshToken');
    }
  }

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedProfile = await DatabaseService.getCachedValue(
      _profileCacheKey,
    );
    if (cachedProfile is Map) {
      _profile = Map<String, dynamic>.from(cachedProfile);
    }
    if (kIsWeb) {
      _token = null;
      _userId = null;
      _refreshToken = null;
      await prefs.remove('token');
      await prefs.remove('userId');
      await prefs.remove('refreshToken');
      _region = prefs.getString('region');
      _subCity = prefs.getString('sub_city');
      return;
    }
    _token = await _secureStorage.read(key: 'token');
    final legacyToken = prefs.getString('token');
    if (_token == null && legacyToken != null) {
      _token = legacyToken;
      await _secureStorage.write(key: 'token', value: legacyToken);
    }
    await prefs.remove('token');
    _userId = prefs.getString('userId');
    _refreshToken = await _secureStorage.read(key: 'refreshToken');
    final legacyRefreshToken = prefs.getString('refreshToken');
    if (_refreshToken == null && legacyRefreshToken != null) {
      _refreshToken = legacyRefreshToken;
      await _secureStorage.write(
        key: 'refreshToken',
        value: legacyRefreshToken,
      );
    }
    await prefs.remove('refreshToken');
    _region = prefs.getString('region');
    _subCity = prefs.getString('sub_city');
    _role = prefs.getString('role');
  }

  /// Exchange the stored refresh token for a fresh access token.
  /// Used by biometric login. Returns true on success.
  static Future<bool> refreshSession() async {
    if (_refreshToken == null) return false;
    try {
      final data = await _send('POST', '/auth/refresh', {
        'refreshToken': _refreshToken,
      });
      await setToken(data['accessToken'], userId: _userId);
      if (data['refreshToken'] != null)
        await setRefreshToken(data['refreshToken']);
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
    _role = null;
    _profile = null;
    final prefs = await SharedPreferences.getInstance();
    await DatabaseService.removeCachedValue(_profileCacheKey);
    if (kIsWeb) {
      await prefs.remove('token');
      await prefs.remove('userId');
      await prefs.remove('refreshToken');
      await prefs.remove('region');
      await prefs.remove('sub_city');
      await prefs.remove('role');
      return;
    }
    await _secureStorage.delete(key: 'token');
    await _secureStorage.delete(key: 'refreshToken');
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('refreshToken');
    await prefs.remove('region');
    await prefs.remove('sub_city');
    await prefs.remove('role');
  }

  /// Preserve the refresh token when logout happens offline so it can be
  /// revoked on the server once connectivity returns.
  static Future<void> queuePendingLogout(String? refreshToken) async {
    if (refreshToken == null || refreshToken.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pendingRefreshRevoke', refreshToken);
  }

  static Future<void> flushPendingLogout() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString('pendingRefreshRevoke');
    if (pending == null || pending.isEmpty) return;
    try {
      await _send('POST', '/auth/logout', {'refreshToken': pending});
      await prefs.remove('pendingRefreshRevoke');
    } on ApiException {
      await prefs.remove('pendingRefreshRevoke');
    } catch (_) {
      // Still offline; retry on the next connectivity event.
    }
  }

  static Future<dynamic> _send(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final uri = Uri.parse('$baseUrl/api$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_token != null) headers['Authorization'] = 'Bearer $_token';
    final req = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);
    final streamed = await req.send().timeout(const Duration(seconds: 45));
    final res = await http.Response.fromStream(streamed)
        .timeout(const Duration(seconds: 45));
    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(res.body);
    } on FormatException {
      data = null;
    }
    if (res.statusCode >= 400) {
      final message = data is Map ? data['message'] : null;
      throw ApiException(
        message?.toString() ?? 'Request failed (${res.statusCode})',
      );
    }
    return data is Map ? data['data'] : null;
  }

  static Future<dynamic> get(String path) => _send('GET', path);
  static Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _send('POST', path, body);

  /// Public raw request used by the offline sync service.
  static Future<dynamic> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) => _send(method, path, body);

  /// Try to POST immediately; if the device is offline (network error rather
  /// than a rejected request) queue it in the local outbox for later sync.
  /// Returns {'queued': true} when queued, otherwise {'queued': false, 'data': ...}.
  static Future<Map<String, dynamic>> postOrQueue(
    String path,
    Map<String, dynamic> body,
  ) async {
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
  static Future<void> recordShare(
    String contentType,
    String? contentId, {
    String platform = 'other',
  }) async {
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

  static Future<dynamic> patch(String path, [Map<String, dynamic>? body]) =>
      _send('PATCH', path, body);
  static Future<dynamic> put(String path, [Map<String, dynamic>? body]) =>
      _send('PUT', path, body);
  static Future<dynamic> delete(String path) => _send('DELETE', path);

  static Future<dynamic> getReport(String id) => _send('GET', '/reports/$id');

  // Social endpoints
  static Future<dynamic> toggleLike(
    String entityType,
    String entityId, {
    String reaction = 'like',
  }) => _send('POST', '/social/$entityType/$entityId/like', {
    'reaction': reaction,
  });

  static Future<dynamic> getSocialCounts(String entityType, String entityId) =>
      _send('GET', '/social/$entityType/$entityId/counts');

  static Future<dynamic> getComments(String entityType, String entityId) =>
      _send('GET', '/social/$entityType/$entityId/comments');

  static Future<dynamic> addComment(
    String entityType,
    String entityId,
    String body,
  ) => _send('POST', '/social/$entityType/$entityId/comments', {'body': body});

  static Future<dynamic> getPhotos(String entityType, String entityId) =>
      _send('GET', '/social/$entityType/$entityId/photos');

  static Future<dynamic> addPhotos(
    String entityType,
    String entityId,
    List<String> photos,
  ) =>
      _send('POST', '/social/$entityType/$entityId/photos', {'photos': photos});

  // On-demand translation (news + missing/wanted descriptions).
  // Returns { text, source, target, cached? } on success.
  static bool hasUsableTranslation(
    Map<String, dynamic> result,
    String originalText,
  ) {
    final translated = result['text']?.toString().trim() ?? '';
    final source = result['source']?.toString().toLowerCase();
    return translated.isNotEmpty &&
        translated != originalText.trim() &&
        source != 'original' &&
        source != 'placeholder' &&
        !translated.startsWith('[Amharic]') &&
        !translated.startsWith('[Oromifa]') &&
        !translated.startsWith('[Tigrigna]') &&
        !translated.startsWith('[Somali]');
  }

  static Future<Map<String, dynamic>> translate(
    String text,
    String targetLanguage, {
    String sourceLanguage = 'en',
  }) async {
    try {
      final data = await _send('POST', '/translate', {
        'text': text,
        'target': targetLanguage,
        'source': sourceLanguage,
      });
      final result = (data is Map)
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      if (hasUsableTranslation(result, text)) return result;
    } catch (_) {
      // Old deployed servers may not have the /translate route yet.
    }

    final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
      'client': 'gtx',
      'sl': sourceLanguage,
      'tl': targetLanguage,
      'dt': 't',
      'q': text,
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw ApiException('Translation unavailable (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List ||
        decoded.isEmpty ||
        decoded.first is! List ||
        (decoded.first as List).isEmpty) {
      throw ApiException('Translation service returned no result');
    }
    final translated = (decoded.first as List)
        .whereType<List>()
        .map((part) => part.isNotEmpty ? part.first.toString() : '')
        .join();
    if (translated.trim().isEmpty) {
      throw ApiException('Translation service returned no result');
    }
    final result = <String, dynamic>{
      'text': translated,
      'source': 'google-public',
      'target': targetLanguage,
      'cached': false,
    };
    if (!hasUsableTranslation(result, text)) {
      throw ApiException('Translation service returned the original text');
    }
    return result;
  }

  static Future<dynamic> upload(
    String path,
    List<MapEntry<String, String>> files, {
    Map<String, String>? fields,
  }) async {
    final uri = Uri.parse('$baseUrl/api$path');
    final req = http.MultipartRequest('POST', uri);
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    fields?.forEach((k, v) => req.fields[k] = v);

    for (final f in files) {
      if (kIsWeb) {
        // On web, use XFile.readAsBytes() and MultipartFile.fromBytes()
        // We need to import the file_picker or image_picker XFile to read bytes
        // Since we only have the path string here, we'll use http.MultipartFile.fromBytes
        // after reading the file. But we don't have direct XFile access here.
        // The callers need to pass XFile or bytes instead of paths on web.
        // For now, we'll handle it by checking if it's a web path (blob: or data:)
        // and throw a more helpful error.
        throw UnsupportedError(
          'File upload on web requires passing XFile/bytes, not file paths. '
          'Use uploadBytes() for web uploads.',
        );
      } else {
        req.files.add(await http.MultipartFile.fromPath(f.key, f.value));
      }
    }
    final streamed = await req.send().timeout(const Duration(seconds: 120));
    final res = await http.Response.fromStream(streamed)
        .timeout(const Duration(seconds: 120));
    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(res.body);
    } on FormatException {
      data = null;
    }
    if (res.statusCode >= 400) {
      final message = data is Map ? data['message'] : null;
      throw ApiException(
        message?.toString() ?? 'Upload failed (${res.statusCode})',
      );
    }
    return data is Map ? data['data'] : null;
  }

  /// Upload files on web using bytes (XFile.readAsBytes()).
  /// Callers should pass MapEntry<String, List<int>> for file data.
  static Future<dynamic> uploadBytes(
    String path,
    List<MapEntry<String, List<int>>> files, {
    Map<String, String>? fields,
    Map<String, String>? filenames,
    Map<String, String>? contentTypes,
  }) async {
    final uri = Uri.parse('$baseUrl/api$path');
    final req = http.MultipartRequest('POST', uri);
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    fields?.forEach((k, v) => req.fields[k] = v);

    for (final f in files) {
      final filename = filenames?[f.key] ?? 'file';
      final contentType = contentTypes?[f.key] ?? 'application/octet-stream';
      final parts = contentType.split('/');
      req.files.add(
        http.MultipartFile.fromBytes(
          f.key,
          f.value,
          filename: filename,
          contentType: MediaType(parts[0], parts.length > 1 ? parts[1] : '*'),
        ),
      );
    }
    final streamed = await req.send().timeout(const Duration(seconds: 120));
    final res = await http.Response.fromStream(streamed)
        .timeout(const Duration(seconds: 120));
    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(res.body);
    } on FormatException {
      data = null;
    }
    if (res.statusCode >= 400) {
      final message = data is Map ? data['message'] : null;
      throw ApiException(
        message?.toString() ?? 'Upload failed (${res.statusCode})',
      );
    }
    return data is Map ? data['data'] : null;
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
