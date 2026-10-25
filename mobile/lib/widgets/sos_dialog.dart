import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api.dart';
import '../services/location_service.dart';
import '../services/socket_service.dart';
import 'auth_gate.dart';

/**
 * Implements Figure 17 (AD-3: Emergency SOS Response Workflow) & Table 9 (UC-18):
 * 1. 3-second visual countdown and vibration
 * 2. Cancel within 3s aborts SOS
 * 3. Immediate GPS acquisition and backend transmission
 * 4. Real-time ETA updates and live officer tracking map
 * 5. Continuous background location streaming until deactivated
 */
Future<void> triggerEmergencySos(BuildContext context) async {
  if (!await ensureAuthed(context, reason: 'Sign in to send an SOS alert with your live location.')) {
    return;
  }
  if (!context.mounted) return;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _SosFlowDialog(),
  );
}

class _SosFlowDialog extends StatefulWidget {
  const _SosFlowDialog();

  @override
  State<_SosFlowDialog> createState() => _SosFlowDialogState();
}

class _SosFlowDialogState extends State<_SosFlowDialog> with SingleTickerProviderStateMixin {
  int _secondsRemaining = 3;
  Timer? _countdownTimer;
  Timer? _locationStreamTimer;
  Timer? _etaPollingTimer;
  bool _aborted = false;
  bool _dispatched = false;
  bool _sending = false;
  String? _sosId;
  double? _myLat;
  double? _myLng;
  List<dynamic> _units = [];
  String? _statusText;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _startCountdown();
  }

  void _startCountdown() {
    HapticFeedback.heavyImpact();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        _countdownTimer = null;
        _sendSos();
      }
    });
  }

  Future<void> _sendSos() async {
    setState(() {
      _sending = true;
      _secondsRemaining = 0;
      _statusText = 'Acquiring GPS coordinates & connecting to dispatcher...';
    });

    try {
      final pos = await LocationService.best();
      if (pos == null) {
        setState(() {
          _sending = false;
          _statusText = 'Could not acquire GPS. Please enable location services.';
        });
        return;
      }

      _myLat = pos.latitude;
      _myLng = pos.longitude;

      final data = await Api.post('/sos', {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'address_text': 'Emergency from Mobile App',
        'region': Api.region,
        'sub_city': Api.subCity,
      });

      final alert = data['alert'];
      final sosId = alert?['id']?.toString();
      final assignments = data['dispatch']?['assignments'] ?? [];

      if (sosId != null) {
        _sosId = sosId;
        SocketService.joinSosRoom(sosId);
        _startLocationStreaming(sosId);
        _startEtaPolling(sosId);
      }

      if (mounted) {
        setState(() {
          _sending = false;
          _dispatched = true;
          _units = assignments is List ? assignments : [];
          _statusText = 'Help dispatched. Responding officers notified.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _statusText = 'Dispatch alert failed: $e';
        });
      }
    }
  }

  void _startLocationStreaming(String sosId) {
    _locationStreamTimer?.cancel();
    _locationStreamTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      try {
        final pos = await LocationService.best();
        if (pos == null) return;
        await Api.post('/position/sos', {
          'sosId': sosId,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
        });
      } catch (_) {}
    });
  }

  void _startEtaPolling(String sosId) {
    _etaPollingTimer?.cancel();
    _etaPollingTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      try {
        final units = await Api.get('/dispatch/$sosId/units');
        if (units is List && mounted) {
          setState(() => _units = units);
        }
      } catch (_) {}
    });
  }

  void _abort() {
    _countdownTimer?.cancel();
    _locationStreamTimer?.cancel();
    _etaPollingTimer?.cancel();
    setState(() => _aborted = true);
    Navigator.of(context).pop();
  }

  void _resolveAndClose() async {
    if (_sosId != null) {
      try {
        await Api.patch('/sos/$_sosId/status', {'status': 'resolved'});
      } catch (_) {}
    }
    _locationStreamTimer?.cancel();
    _etaPollingTimer?.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _locationStreamTimer?.cancel();
    _etaPollingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dispatched) {
      return _buildDispatchedView();
    }
    return _buildCountdownView();
  }

  Widget _buildCountdownView() {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1010),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.red, width: 2)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.15).animate(
              CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade900.withOpacity(0.4),
                border: Border.all(color: Colors.red.shade500, width: 3),
              ),
              child: Center(
                child: _sending
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        '$_secondsRemaining',
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'EMERGENCY SOS',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            _statusText ?? 'Notifying nearest police officers in $_secondsRemaining seconds...',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _sending ? null : _abort,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white60, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('CANCEL / ABORT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchedView() {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.sos, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HELP IS ON THE WAY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      Text('Live patrol dispatch active', style: TextStyle(fontSize: 12, color: Colors.white60)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade900, borderRadius: BorderRadius.circular(6)),
                  child: const Text('DISPATCHED', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_myLat != null && _myLng != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 220,
                  child: FlutterMap(
                    options: MapOptions(initialCenter: LatLng(_myLat!, _myLng!), initialZoom: 14),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.zega.alert',
                      ),
                      MarkerLayer(markers: [
                        Marker(
                          point: LatLng(_myLat!, _myLng!),
                          width: 36,
                          height: 36,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 36),
                        ),
                        ..._units.where((u) => u['latitude'] != null && u['longitude'] != null).map((u) => Marker(
                          point: LatLng((u['latitude'] as num).toDouble(), (u['longitude'] as num).toDouble()),
                          width: 30,
                          height: 30,
                          child: const Icon(Icons.local_police, color: Colors.blue, size: 30),
                        )),
                      ]),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Text('Responding Patrol Units', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Expanded(
              child: _units.isEmpty
                  ? const Center(child: Text('Routing nearest regional officer...', style: TextStyle(color: Colors.white60)))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _units.length,
                      itemBuilder: (_, i) {
                        final u = _units[i];
                        final etaSec = u['eta_seconds'] as int?;
                        final distM = u['distance_m'] as num?;
                        return Card(
                          color: const Color(0xFF1E293B),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.local_police, color: Colors.blueAccent),
                            title: Text(u['staff_name'] ?? u['officer_name'] ?? 'Officer On Duty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              'ETA: ${etaSec != null ? '${math.max(1, (etaSec / 60).round())} min' : 'calculating...'}${distM != null ? ' · ${(distM / 1000).toStringAsFixed(1)} km away' : ''}',
                              style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.blue.shade900, borderRadius: BorderRadius.circular(4)),
                              child: Text((u['status'] ?? 'En Route').toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _resolveAndClose,
                    style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                    child: const Text('I AM SAFE / END EMERGENCY'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
