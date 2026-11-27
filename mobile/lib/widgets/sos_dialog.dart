import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/location_service.dart';
import '../services/socket_service.dart';
import '../services/sos_live_stream_service.dart';
import 'map_tile_layers.dart';
import 'auth_gate.dart';

/// Implements Figure 17 (AD-3: Emergency SOS Response Workflow) & Table 9 (UC-18):
/// 1. 3-second visual countdown and vibration
/// 2. Cancel within 3s aborts SOS
/// 3. Immediate GPS acquisition and backend transmission
/// 4. Real-time ETA updates and live officer tracking map
/// 5. Continuous background location streaming until deactivated
Future<void> triggerEmergencySos(BuildContext context) async {
  final loc = AppLocalizations.of(context);
  if (!await ensureAuthed(context, reason: loc.signInToSendSos)) {
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

class _SosFlowDialogState extends State<_SosFlowDialog>
    with SingleTickerProviderStateMixin {
  int _secondsRemaining = 3;
  Timer? _countdownTimer;
  Timer? _locationStreamTimer;
  Timer? _etaPollingTimer;
  bool _aborted = false;
  bool _dispatched = false;
  bool _sending = false;
  bool _endingEmergency = false;
  bool _satelliteMap = false;
  String? _sosId;
  double? _myLat;
  double? _myLng;
  List<dynamic> _units = [];
  String? _statusText;
  SosLiveStreamService? _liveStream;
  String? _liveStatus;
  String? _liveError;

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
    if (_aborted) return;
    final loc = AppLocalizations.of(context);
    setState(() {
      _sending = true;
      _secondsRemaining = 0;
      _statusText = loc.sosSendingStatus;
    });

    try {
      final pos = await LocationService.gps();
      _myLat = pos?.latitude;
      _myLng = pos?.longitude;

      final data = await Api.post('/sos', {
        'latitude': pos?.latitude,
        'longitude': pos?.longitude,
        'address_text': pos == null ? null : 'Emergency from Mobile App',
        'region': Api.region,
        'sub_city': Api.subCity,
      });

      final alert = data['alert'];
      final sosId = alert?['id']?.toString();
      final assignments = data['dispatch']?['assignments'] ?? [];
      final dispatchData = data['dispatch'];
      final dispatch = dispatchData is Map<String, dynamic>
          ? dispatchData
          : const <String, dynamic>{};
      final stationName = dispatch['station_name']?.toString();
      final statusText = dispatch['recipient_count'] == 0
          ? loc.sosNoDispatchRecipients
          : dispatch['route'] == 'central_dispatch'
          ? (dispatch['station_id'] != null
                ? loc.sosNearestNoOfficers
                : loc.sosLocationMissingCentral)
          : loc.sosSentToStation(stationName ?? loc.nearestPoliceStation);

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
          _statusText = statusText;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _statusText = Api.userMessage(e, fallback: loc.sosSendFailed);
        });
      }
    }
  }

  Future<void> _startLiveStream(String mediaType) async {
    final loc = AppLocalizations.of(context);
    final sosId = _sosId;
    if (sosId == null ||
        _liveStatus == 'connecting' ||
        _liveStatus == 'waiting' ||
        _liveStatus == 'live') {
      return;
    }

    final stream = SosLiveStreamService();
    stream.onStatusChanged = (status, error) {
      if (!mounted) return;
      setState(() {
        _liveStatus = status;
        _liveError = error;
      });
    };
    setState(() {
      _liveStream = stream;
      _liveStatus = 'connecting';
      _liveError = null;
    });

    try {
      await stream.start(sosId, mediaType: mediaType);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _liveStatus = 'error';
        _liveError = Api.userMessage(error, fallback: loc.sosLiveStreamFailed);
      });
    }
  }

  Future<void> _stopLiveStream() async {
    await _liveStream?.stop();
  }

  void _startLocationStreaming(String sosId) {
    _locationStreamTimer?.cancel();
    _locationStreamTimer = Timer.periodic(const Duration(seconds: 12), (
      _,
    ) async {
      try {
        final pos = await LocationService.gps();
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

  Future<void> _resolveAndClose() async {
    if (_endingEmergency) return;
    setState(() => _endingEmergency = true);
    try {
      final sosId = _sosId;
      if (sosId == null) {
        throw StateError('The emergency alert ID is missing.');
      }
      await _stopLiveStream();
      await Api.post('/sos/$sosId/resolve');
      _locationStreamTimer?.cancel();
      _etaPollingTimer?.cancel();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Api.userMessage(
                error,
                fallback:
                    'Could not end the emergency alert. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _endingEmergency = false);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _locationStreamTimer?.cancel();
    _etaPollingTimer?.cancel();
    if (_liveStream != null) unawaited(_liveStream!.stop());
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
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1010),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.red, width: 2),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.15).animate(
              CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeInOut,
              ),
            ),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade900.withValues(alpha: 0.4),
                border: Border.all(color: Colors.red.shade500, width: 3),
              ),
              child: Center(
                child: _sending
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        '$_secondsRemaining',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            loc.sosEmergencyTitle,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusText ?? loc.sosNotifyCountdown(_secondsRemaining),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                loc.sosCancelAbort,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchedView() {
    final loc = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sos, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.sosHelpIsOnWay,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          loc.sosLivePatrolActive,
                          style: TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade900,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      loc.sosDispatched,
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildLiveStreamControls(),
              const SizedBox(height: 12),
              if (_myLat != null && _myLng != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 220,
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(_myLat!, _myLng!),
                            initialZoom: 14,
                          ),
                          children: [
                            mapTileLayer(satellite: _satelliteMap),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(_myLat!, _myLng!),
                                  width: 36,
                                  height: 36,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 36,
                                  ),
                                ),
                                ..._units
                                    .where(
                                      (u) =>
                                          u['latitude'] != null &&
                                          u['longitude'] != null,
                                    )
                                    .map(
                                      (u) => Marker(
                                        point: LatLng(
                                          (u['latitude'] as num).toDouble(),
                                          (u['longitude'] as num).toDouble(),
                                        ),
                                        width: 30,
                                        height: 30,
                                        child: const Icon(
                                          Icons.local_police,
                                          color: Colors.blue,
                                          size: 30,
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                            mapAttribution(satellite: _satelliteMap),
                          ],
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            child: IconButton(
                              tooltip: _satelliteMap
                                  ? loc.switchToStreetMap
                                  : loc.switchToSatelliteImagery,
                              onPressed: () => setState(
                                () => _satelliteMap = !_satelliteMap,
                              ),
                              icon: Icon(
                                _satelliteMap
                                    ? Icons.map_outlined
                                    : Icons.satellite_alt,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                loc.sosRespondingUnits,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: _units.isEmpty
                    ? 54
                    : math.min(180.0, _units.length * 84.0),
                child: _units.isEmpty
                    ? Center(
                        child: Text(
                          loc.sosRoutingOfficer,
                          style: TextStyle(color: Colors.white60),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _units.length,
                        itemBuilder: (_, i) {
                          final u = _units[i];
                          final etaSec = u['eta_seconds'] as int?;
                          final distM = u['distance_m'] as num?;
                          final etaMin = etaSec != null
                              ? math.max(1, (etaSec / 60).round())
                              : null;
                          final distKm = distM != null
                              ? (distM / 1000).toStringAsFixed(1)
                              : null;
                          final etaLabel = etaMin != null
                              ? loc.sosEtaMinutes(etaMin)
                              : loc.sosCalculating;
                          final distLabel = distKm != null
                              ? loc.sosDistanceAway(distKm)
                              : '';
                          return Card(
                            color: const Color(0xFF1E293B),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.local_police,
                                color: Colors.blueAccent,
                              ),
                              title: Text(
                                u['staff_name'] ??
                                    u['officer_name'] ??
                                    loc.sosOfficerOnDuty,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                loc.sosEtaWithDistance(etaLabel, distLabel),
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade900,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  (u['status']?.toString().toLowerCase() ==
                                          'en_route'
                                      ? loc.sosStatusEnRoute
                                      : (u['status'] ?? '')
                                            .toString()
                                            .toUpperCase()),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
                      onPressed: _endingEmergency ? null : _resolveAndClose,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                      ),
                      child: _endingEmergency
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(loc.sosSafeEndEmergency),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStreamControls() {
    final loc = AppLocalizations.of(context);
    final isStarting = _liveStatus == 'connecting';
    final isActive =
        _liveStatus == 'waiting' ||
        _liveStatus == 'live' ||
        _liveStatus == 'disconnected';
    final statusLabel = switch (_liveStatus) {
      'connecting' => loc.sosLiveConnecting,
      'waiting' => loc.sosLiveWaiting,
      'live' => loc.sosLiveNow,
      'disconnected' => loc.sosLiveInterrupted,
      'ended' => loc.sosLiveEnded,
      'error' => loc.sosLiveStartFailed,
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.sosLiveTitle,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            loc.sosLivePrivacyNote,
            style: TextStyle(color: Colors.white60, fontSize: 11),
          ),
          if (statusLabel != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (isStarting)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    _liveStatus == 'live' ? Icons.circle : Icons.info_outline,
                    size: 14,
                    color: _liveStatus == 'live'
                        ? Colors.redAccent
                        : Colors.amber,
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _liveError ?? statusLabel,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                if (isActive)
                  TextButton(
                    onPressed: _stopLiveStream,
                    child: Text(loc.sosEnd),
                  ),
              ],
            ),
          ],
          if (_liveStream?.mediaType == 'video' && isActive) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: RTCVideoView(
                _liveStream!.localRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ],
          if (!isStarting && !isActive) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _startLiveStream('audio'),
                  icon: const Icon(Icons.mic),
                  label: Text(loc.sosStartLiveAudio),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _startLiveStream('video'),
                  icon: const Icon(Icons.videocam),
                  label: Text(loc.sosStartLiveVideo),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
