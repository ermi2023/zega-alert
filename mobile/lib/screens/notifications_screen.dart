import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/notification_state.dart';
import 'geofence_map_screen.dart';
import 'news_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Api.get('/notifications?limit=50');
      final List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['notifications'] is List) {
        list = data['notifications'] as List<dynamic>;
      } else {
        list = [];
      }
      setState(() => _notifications = list);
    } catch (e) {
      setState(
        () => _error = Api.userMessage(
          e,
          fallback: AppLocalizations.of(context).notificationLoadFailed,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await Api.post('/notifications/$id/read', {});
      NotificationState.notifyChanged();
      setState(() {
        _notifications = _notifications.map((n) {
          if (n is Map && n['id']?.toString() == id) {
            final m = Map<String, dynamic>.from(n);
            m['is_read'] = true;
            return m;
          }
          return n;
        }).toList();
      });
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      await Api.post('/notifications/read-all', {});
      NotificationState.notifyChanged();
      setState(() {
        _notifications = _notifications.map((n) {
          if (n is Map) {
            final m = Map<String, dynamic>.from(n);
            m['is_read'] = true;
            return m;
          }
          return n;
        }).toList();
      });
    } catch (_) {}
  }

  String _emoji(String? type) {
    switch (type) {
      case 'geofence_alert':
        return '🛡️';
      case 'alert':
        return '🚨';
      case 'warning':
        return '⚠️';
      case 'sos':
        return '🆘';
      case 'system':
        return '⚙️';
      default:
        return 'ℹ️';
    }
  }

  Future<void> _openGeofence(Map metadata) async {
    final geofenceId = metadata['geofenceId']?.toString();
    if (geofenceId == null || geofenceId.isEmpty) return;

    try {
      final region = Api.region;
      final endpoint = region == null
          ? '/geofences'
          : '/geofences?region=${Uri.encodeQueryComponent(region)}';
      final result = await Api.get(endpoint);
      if (!mounted) return;
      Map? zone;
      if (result is List) {
        for (final item in result) {
          if (item is Map && item['id']?.toString() == geofenceId) {
            zone = item;
            break;
          }
        }
      }
      final selectedZone = zone;
      if (selectedZone == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).safetyZoneNoLongerActive),
          ),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GeofenceMapScreen(
            geofence: Map<String, dynamic>.from(selectedZone),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Api.userMessage(
              error,
              fallback: AppLocalizations.of(context).couldNotOpenSafetyZone,
            ),
          ),
        ),
      );
    }
  }

  int? _newsTabForNotification(String? type) {
    switch (type) {
      case 'announcement':
        return 0;
      case 'missing_person':
        return 1;
      case 'wanted_person':
        return 2;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final unread = _notifications
        .where((n) => n is Map && n['is_read'] != true)
        .length;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          unread > 0 ? '${loc.notifications} ($unread)' : loc.notifications,
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(loc.markAllRead),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.blueGrey)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: Text(loc.retry)),
                ],
              ),
            )
          : _notifications.isEmpty
          ? Center(child: Text(loc.noNotificationsYet))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, i) {
                  final n = _notifications[i];
                  if (n is! Map) return const SizedBox.shrink();
                  final isRead = n['is_read'] == true;
                  final id = n['id']?.toString();
                  final metadata = n['metadata'];
                  final notificationType = metadata is Map
                      ? metadata['type']?.toString()
                      : n['type']?.toString();
                  final newsTab = _newsTabForNotification(notificationType);
                  return ListTile(
                    onTap: newsTab != null
                        ? () async {
                            if (id != null) await _markRead(id);
                            if (!context.mounted) return;
                            final navigator = Navigator.of(context);
                            await navigator.push(
                              MaterialPageRoute(
                                builder: (_) => NewsScreen(initialTab: newsTab),
                              ),
                            );
                            if (mounted) await _load();
                          }
                        : notificationType == 'geofence_alert'
                        ? () async {
                            if (id != null) await _markRead(id);
                            if (!context.mounted || metadata is! Map) return;
                            await _openGeofence(metadata);
                          }
                        : null,
                    leading: CircleAvatar(
                      backgroundColor: isRead
                          ? Colors.grey.shade200
                          : Colors.blue.shade100,
                      child: Text(
                        _emoji(notificationType),
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    title: Text(
                      n['title']?.toString() ?? '',
                      style: TextStyle(
                        fontWeight: isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n['body']?.toString() ?? ''),
                        if (n['created_at'] != null)
                          Text(
                            DateTime.tryParse(n['created_at'].toString())
                                    ?.toLocal()
                                    .toString()
                                    .substring(0, 16) ??
                                '',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                    trailing: isRead
                        ? const Icon(
                            Icons.check_circle_outline,
                            color: Colors.grey,
                            size: 20,
                          )
                        : IconButton(
                            icon: const Icon(
                              Icons.mark_email_read_outlined,
                              color: Colors.blue,
                              size: 20,
                            ),
                            tooltip: loc.markRead,
                            onPressed: id != null ? () => _markRead(id) : null,
                          ),
                    isThreeLine: true,
                    tileColor: isRead
                        ? null
                        : Colors.blue.withValues(alpha: 0.04),
                  );
                },
              ),
            ),
    );
  }
}
