import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart' show MaterialPageRoute, ScaffoldMessenger, SnackBar, Text;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../screens/callbacks_screen.dart';
import '../main.dart' show navigatorKey;
import 'api.dart';

/// Must be a top-level function so it survives when the app is terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // A notification payload is displayed by the OS automatically. This handler
  // exists for app state changes / data-only messages in the background.
}

class NotificationService {
  static FirebaseMessaging? _messaging;
  static const String channelId = 'zega_alert_channel';

  static Future<void> initialize() async {
    try {
      if (kIsWeb) return;
      _messaging = FirebaseMessaging.instance;

      await _messaging!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
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
    if (notification == null) return;
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final text = [notification.title, notification.body]
        .where((s) => s != null && s.isNotEmpty)
        .join(': ');
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(text.isEmpty ? 'New alert' : text)),
    );
  }

  static void _handleMessageTap(RemoteMessage message) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final data = message.data;
    final type = (data['type'] ?? '').toString();
    if (type == 'callback' || data.containsKey('reportId')) {
      nav.push(MaterialPageRoute(builder: (_) => const CallbacksScreen()));
    }
    // SOS / other alerts keep the user on the home shell.
  }
}
