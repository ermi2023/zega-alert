import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'video_call_screen.dart';
import '../services/api.dart';

class CallbackSessionScreen extends StatefulWidget {
  const CallbackSessionScreen({super.key, required this.callback});

  final Map<String, dynamic> callback;

  @override
  State<CallbackSessionScreen> createState() => _CallbackSessionScreenState();
}

class _CallbackSessionScreenState extends State<CallbackSessionScreen> {
  late final Stopwatch _watch;
  Timer? _ticker;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _watch = Stopwatch()..start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _watch.stop();
    super.dispose();
  }

  Future<void> _end() async {
    final loc = AppLocalizations.of(context);
    setState(() => _ending = true);
    try {
      await Api.patch('/callbacks/${widget.callback['id']}', {
        'status': 'completed',
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _ending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Api.userMessage(e, fallback: loc.callbackSessionEndFailed),
            ),
          ),
        );
      }
    }
  }

  Future<void> _startVideoCall() async {
    final loc = AppLocalizations.of(context);
    final cb = widget.callback;
    final currentUserId = Api.userId?.toString();
    final citizenId = cb['citizen_id']?.toString();
    final officerId = cb['officer_id']?.toString();
    final targetUserId = currentUserId == citizenId
        ? officerId
        : currentUserId == officerId
        ? citizenId
        : null;
    if (targetUserId == null || targetUserId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.otherCallParticipantNotFound)));
      return;
    }

    final targetName = targetUserId == officerId
        ? cb['officer_name'] ?? loc.police
        : cb['citizen_name'] ?? loc.citizenProfile;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          targetUserId: targetUserId,
          targetName: targetName.toString(),
          callType: 'video',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cb = widget.callback;
    final seconds = _watch.elapsed.inSeconds;
    final elapsed =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    final mode = (cb['mode'] ?? 'voice').toString();
    final localizedMode = switch (mode) {
      'video' => loc.callbackModeVideo,
      'chat' => loc.callbackModeChat,
      _ => loc.callbackModeVoice,
    };
    return Scaffold(
      appBar: AppBar(title: Text(loc.callbackSessionTitle)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Icon(
              mode == 'video'
                  ? Icons.videocam
                  : mode == 'chat'
                  ? Icons.chat
                  : Icons.call,
              size: 72,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              mode == 'chat'
                  ? loc.inAppChatSession
                  : loc.inAppSessionMode(localizedMode),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              cb['report_title'] ?? loc.reportFollowUp,
              textAlign: TextAlign.center,
            ),
            if (cb['officer_name'] != null) ...[
              const SizedBox(height: 4),
              Text(
                loc.officerNamed(cb['officer_name'].toString()),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              elapsed,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              mode == 'video'
                  ? loc.callbackVideoActiveDescription
                  : loc.connectedInsideApp,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (mode == 'video') ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _startVideoCall,
                icon: const Icon(Icons.videocam),
                label: Text(loc.startLiveVideoConversation),
              ),
            ],
            if (cb['notes'] != null && cb['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(cb['notes'].toString()),
                ),
              ),
            ],
            const Spacer(),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _ending ? null : _end,
              icon: const Icon(Icons.call_end),
              label: Text(_ending ? loc.ending : loc.endSession),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
