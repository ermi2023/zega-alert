import 'dart:async';
import 'dart:convert';
import 'api.dart';
import 'connectivity_service.dart';
import 'database_service.dart';

/// Flushes the offline outbox when connectivity is restored.
/// Queued reports/missing-person submissions survive app restarts because
/// they live in the sqflite `outbox` table.
class SyncService {
  static bool _started = false;
  static bool _flushing = false;
  static StreamSubscription<bool>? _sub;

  /// Called with the number of items still pending after a flush attempt.
  static void Function(int pending)? onSynced;

  static void start() {
    if (_started) return;
    _started = true;
    _sub = ConnectivityService.onConnectivityChanged.listen((online) {
      if (online) flush();
    });
    flush();
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }

  static Future<int> pendingCount() async {
    try {
      return await DatabaseService.outboxCount();
    } catch (_) {
      return 0;
    }
  }

  static Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      if (!await ConnectivityService.isConnected()) return;
      final items = await DatabaseService.getOutbox();
      for (final item in items) {
        final id = item['id'] as int;
        final method = item['method'] as String;
        final path = item['path'] as String;
        final raw = item['body'] as String?;
        try {
          final body = raw == null ? null : (jsonDecode(raw) as Map<String, dynamic>);
          await Api.request(method, path, body);
          await DatabaseService.removeOutbox(id);
        } on ApiException {
          // Server rejected the payload; drop it so it can't block the queue.
          await DatabaseService.removeOutbox(id);
        } catch (_) {
          // Still offline — stop and retry on the next connectivity event.
          await DatabaseService.bumpAttempts(id);
          break;
        }
      }
      final remaining = await DatabaseService.outboxCount();
      onSynced?.call(remaining);
    } finally {
      _flushing = false;
    }
  }
}
