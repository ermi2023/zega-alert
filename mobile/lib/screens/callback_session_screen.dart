import 'dart:async';
import 'package:flutter/material.dart';
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
      await Api.patch('/callbacks/${widget.callback['id']}', {'status': 'completed'});
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _ending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not end session: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cb = widget.callback;
    final seconds = _watch.elapsed.inSeconds;
    final elapsed = '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    final mode = (cb['mode'] ?? 'voice').toString();
    return Scaffold(
      appBar: AppBar(title: const Text('Callback session')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Icon(mode == 'video' ? Icons.videocam : mode == 'chat' ? Icons.chat : Icons.call, size: 72, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              mode == 'chat' ? 'In-app chat session' : 'In-app $mode session',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(cb['report_title'] ?? 'Report follow-up', textAlign: TextAlign.center),
            if (cb['officer_name'] != null) ...[
              const SizedBox(height: 4),
              Text('Officer: ${cb['officer_name']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 24),
            Text(elapsed, textAlign: TextAlign.center, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            const Text('Connected · this session stays inside ZEGA-ALERT', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
            if (cb['notes'] != null && cb['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(cb['notes'].toString()))),
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
