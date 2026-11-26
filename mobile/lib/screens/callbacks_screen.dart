import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api.dart';
import 'callback_session_screen.dart';

class CallbacksScreen extends StatefulWidget {
  const CallbacksScreen({super.key});

  @override
  State<CallbacksScreen> createState() => _CallbacksScreenState();
}

class _CallbacksScreenState extends State<CallbacksScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loc = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await Api.get('/callbacks/mine');
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = Api.userMessage(
          e,
          fallback: loc.callbacksLoadFailed,
        );
        _loading = false;
      });
    }
  }

  Future<void> _respond(dynamic cb, String status) async {
    final loc = AppLocalizations.of(context);
    try {
      await Api.patch('/callbacks/${cb['id']}', {'status': status});
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Api.userMessage(e, fallback: loc.callbackUpdateFailed),
            ),
          ),
        );
      }
    }
  }

  Future<void> _proposeTime(dynamic cb) async {
    final loc = AppLocalizations.of(context);
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return;
    final slot = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!slot.isAfter(DateTime.now())) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.chooseFutureTime)));
      return;
    }
    try {
      await Api.patch('/callbacks/${cb['id']}', {
        'proposed_slot': slot.toUtc().toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.alternativeTimeSent)),
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Api.userMessage(
                e,
                fallback: loc.callbackSendFailed,
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _joinSession(dynamic cb) async {
    final loc = AppLocalizations.of(context);
    var data = Map<String, dynamic>.from(cb as Map);
    try {
      if (data['session_id'] == null) {
        data = Map<String, dynamic>.from(
          await Api.post('/callbacks/${data['id']}/session', {}) as Map,
        );
      }
      if (!mounted) return;
      final ended = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CallbackSessionScreen(callback: data),
        ),
      );
      if (ended == true) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Api.userMessage(e, fallback: loc.callbackSessionStartFailed),
            ),
          ),
        );
      }
    }
  }

  String _label(String s, AppLocalizations loc) => switch (s) {
    'pending' => loc.callbackStatusPending,
    'accepted' => loc.callbackStatusAccepted,
    'declined' => loc.callbackStatusDeclined,
    'completed' => loc.callbackStatusCompleted,
    'rescheduled' => loc.callbackStatusRescheduled,
    _ => s.replaceAll('_', ' ').toUpperCase(),
  };

  String _mode(String? mode, AppLocalizations loc) => switch (mode) {
    'voice' => loc.callbackModeVoice,
    'video' => loc.callbackModeVideo,
    'chat' => loc.callbackModeChat,
    _ => mode ?? loc.notAvailable,
  };

  Color _color(String s) => switch (s) {
    'accepted' => Colors.green,
    'declined' => Colors.red,
    'completed' => Colors.blueGrey,
    _ => Colors.orange,
  };

  String _slot(String? iso, AppLocalizations loc) {
    if (iso == null) return loc.noScheduledSlot;
    final d = DateTime.tryParse(iso);
    if (d == null) return loc.noScheduledSlot;
    return d.toLocal().toString().substring(0, 16);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.callbackTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              loc.callbackDescription,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_error != null)
              Card(
                color: Colors.blueGrey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.blueGrey),
                  ),
                ),
              ),
            if (!_loading && _error == null && _items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    loc.noCallbacksYet,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ..._items.map(
              (cb) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.phone_in_talk_outlined,
                            color: _color(cb['status'] ?? ''),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cb['report_title'] ?? loc.reportFollowUp,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            _label(cb['status'] ?? '', loc),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _color(cb['status'] ?? ''),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${loc.mode}: ${_mode(cb['mode'] ?? 'voice', loc)} · ${_slot(cb['requested_slot'], loc)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      if (cb['proposed_slot'] != null)
                        Text(
                          '${loc.youProposedSlot(_slot(cb['proposed_slot'], loc))} · ${loc.waitingForOfficer}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.orange,
                          ),
                        ),
                      if (cb['session_id'] != null)
                        Text(
                          loc.inAppSessionStarted,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (cb['notes'] != null &&
                          cb['notes'].toString().isNotEmpty)
                        Text(
                          cb['notes'].toString(),
                          style: const TextStyle(fontSize: 13),
                        ),
                      if (cb['status'] == 'pending' ||
                          cb['status'] == 'rescheduled') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _respond(cb, 'accepted'),
                                icon: const Icon(Icons.check, size: 18),
                                label: Text(loc.accept),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _respond(cb, 'declined'),
                                icon: const Icon(Icons.close, size: 18),
                                label: Text(loc.decline),
                              ),
                            ),
                          ],
                        ),
                        if (cb['status'] == 'pending') ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _proposeTime(cb),
                            icon: const Icon(Icons.schedule, size: 18),
                            label: Text(loc.proposeAnotherTime),
                          ),
                        ],
                      ],
                      if (cb['status'] == 'accepted') ...[
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: () => _joinSession(cb),
                          icon: Icon(
                            cb['mode'] == 'video'
                                ? Icons.videocam
                                : cb['mode'] == 'chat'
                                ? Icons.chat
                                : Icons.call,
                          ),
                          label: Text(
                            cb['session_id'] != null
                                ? loc.rejoinSession
                                : loc.startInAppSession,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
