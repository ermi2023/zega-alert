import 'package:flutter/material.dart';
import '../services/api.dart';

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
    setState(() { _loading = true; _error = null; });
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
      setState(() => _error = 'Failed to load notifications: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await Api.post('/notifications/$id/read', {});
      setState(() {
        _notifications = _notifications.map((n) {
          if (n is Map && n['id']?.toString() == id) {
            final m = Map<String, dynamic>.from(n);
            m['read_at'] = DateTime.now().toIso8601String();
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
      setState(() {
        _notifications = _notifications.map((n) {
          if (n is Map) {
            final m = Map<String, dynamic>.from(n);
            m['read_at'] ??= DateTime.now().toIso8601String();
            return m;
          }
          return n;
        }).toList();
      });
    } catch (_) {}
  }

  String _emoji(String? type) {
    switch (type) {
      case 'alert': return '🚨';
      case 'warning': return '⚠️';
      case 'sos': return '🆘';
      case 'system': return '⚙️';
      default: return 'ℹ️';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => n is Map && n['read_at'] == null).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(unread > 0 ? 'Notifications ($unread)' : 'Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
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
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _notifications.isEmpty
                  ? const Center(child: Text('No notifications yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, i) {
                          final n = _notifications[i];
                          if (n is! Map) return const SizedBox.shrink();
                          final isRead = n['read_at'] != null;
                          final id = n['id']?.toString();
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isRead ? Colors.grey.shade200 : Colors.blue.shade100,
                              child: Text(_emoji(n['type']?.toString()), style: const TextStyle(fontSize: 18)),
                            ),
                            title: Text(
                              n['title']?.toString() ?? '',
                              style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n['body']?.toString() ?? ''),
                                if (n['created_at'] != null)
                                  Text(
                                    DateTime.tryParse(n['created_at'].toString())?.toLocal().toString().substring(0, 16) ?? '',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                              ],
                            ),
                            trailing: isRead
                                ? const Icon(Icons.check_circle_outline, color: Colors.grey, size: 20)
                                : IconButton(
                                    icon: const Icon(Icons.mark_email_read_outlined, color: Colors.blue, size: 20),
                                    tooltip: 'Mark read',
                                    onPressed: id != null ? () => _markRead(id) : null,
                                  ),
                            isThreeLine: true,
                            tileColor: isRead ? null : Colors.blue.withOpacity(0.04),
                          );
                        },
                      ),
                    ),
    );
  }
}
