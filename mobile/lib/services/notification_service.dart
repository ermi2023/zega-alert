import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'api.dart';

class NotificationService {
  static FirebaseMessaging? _messaging;

  static Future<void> initialize() async {
    try {
      if (kIsWeb) return;
      _messaging = FirebaseMessaging.instance;
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await _messaging!.getToken();
        if (token != null) {
          await _registerToken(token);
        }

        _messaging!.onTokenRefresh.listen((newToken) {
          _registerToken(newToken);
        });
      }

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }
    } catch (_) {
      // Firebase not configured — app works without push
    }
  }

  static Future<void> _registerToken(String token) async {
    if (Api.token == null) return;
    try {
      await Api.put('/auth/me', {'device_token': token});
    } catch (_) {
      // Will retry on next app open
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      print('[FCM FOREGROUND] ${notification.title}: ${notification.body}');
    }
  }

  static void _handleMessageTap(RemoteMessage message) {
    final data = message.data;
    if (data.containsKey('sosId')) {
      // Could navigate to SOS details
    }
  }
}
