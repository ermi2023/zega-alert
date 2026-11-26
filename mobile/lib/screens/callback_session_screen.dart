import 'dart:async';

import 'package:flutter/material.dart';

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
              Api.userMessage(e, fallback: 'Could not end the session.'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _startVideoCall() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not find the other call participant.'),
        ),
      );
      return;
    }

    final targetName = targetUserId == officerId
        ? cb['officer_name'] ?? 'Officer'
        : cb['citizen_name'] ?? 'Citizen';
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
    final cb = widget.callback;
    final seconds = _watch.elapsed.inSeconds;
    final elapsed =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    final mode = (cb['mode'] ?? 'voice').toString();
    return Scaffold(
      appBar: AppBar(title: const Text('Callback session')),
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
              mode == 'chat' ? 'In-app chat session' : 'In-app $mode session',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              cb['report_title'] ?? 'Report follow-up',
              textAlign: TextAlign.center,
            ),
            if (cb['officer_name'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Officer: ${cb['officer_name']}',
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
                  ? 'Callback session active · start a live video call when ready'
                  : 'Connected · this session stays inside ZEGA-ALERT',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (mode == 'video') ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _startVideoCall,
                icon: const Icon(Icons.videocam),
                label: const Text('Start live video conversation'),
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
              label: Text(_ending ? 'Ending…' : 'End session'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
