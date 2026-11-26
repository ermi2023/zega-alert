import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../screens/callbacks_screen.dart';
import '../screens/news_screen.dart';
import '../screens/notifications_screen.dart';
import 'notification_state.dart';
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
  static bool _initialized = false;
  static const String channelId = 'zega_alert_channel';

  static Future<void> initialize() async {
    if (kIsWeb || _initialized) return;
    _initialized = true;
    try {
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
      _initialized = false;
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
    NotificationState.notifyChanged();
    final notification = message.notification;
    if (notification == null) return;
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final text = [
      notification.title,
      notification.body,
    ].where((s) => s != null && s.isNotEmpty).join(': ');
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (message.data['type'] == 'geofence_alert') {
      if (messenger == null) return;
      messenger.hideCurrentMaterialBanner();
      messenger.showMaterialBanner(
        MaterialBanner(
          leading: const Icon(
            Icons.health_and_safety,
            color: Color(0xFF8A1C1C),
            size: 30,
          ),
          content: Text(
            text.isEmpty ? 'Safety-zone alert' : text,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFFFE8D6),
          actions: [
            TextButton(
              onPressed: () {
                messenger.hideCurrentMaterialBanner();
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
              child: const Text('View alert'),
            ),
            TextButton(
              onPressed: () => messenger.hideCurrentMaterialBanner(),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
      return;
    }
    messenger?.showSnackBar(
      SnackBar(content: Text(text.isEmpty ? 'New alert' : text)),
    );
  }

  static void _handleMessageTap(RemoteMessage message) {
    NotificationState.notifyChanged();
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final data = message.data;
    final type = (data['type'] ?? '').toString();
    if (type == 'geofence_alert') {
      nav.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    } else if (type == 'callback' || data.containsKey('reportId')) {
      nav.push(MaterialPageRoute(builder: (_) => const CallbacksScreen()));
    } else if (type == 'announcement' ||
        type == 'missing_person' ||
        type == 'wanted_person') {
      final initialTab = switch (type) {
        'missing_person' => 1,
        'wanted_person' => 2,
        _ => 0,
      };
      nav.push(
        MaterialPageRoute(builder: (_) => NewsScreen(initialTab: initialTab)),
      );
    }
    // SOS / other alerts keep the user on the home shell.
  }
}
