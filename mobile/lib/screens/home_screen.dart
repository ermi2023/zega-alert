import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/socket_service.dart';
import '../widgets/auth_gate.dart';

import 'missing_report_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _announcements = [];
  List<dynamic> _missing = [];
  List<dynamic> _wanted = [];
  bool _sending = false;
  String? _status;
  String? _loadError;
  bool _loading = true;
  bool _offline = false;
  Timer? _sosTimer;
  Timer? _etaTimer;
  String? _activeSosId;
  double? _sosLat;
  double? _sosLng;
  List<dynamic> _dispatchUnits = [];
  List<dynamic> _officers = [];

  @override
  void initState() {
    super.initState();
    SocketService.connect();
    SocketService.onSosStatus = (data) {
      final status = data['status']?.toString();
      if (status == 'resolved' || status == 'cancelled' || status == 'completed') {
        _stopAllStreams();
      }
    };
    _load();
  }

  void _stopAllStreams() {
    _sosTimer?.cancel();
    _etaTimer?.cancel();
    _sosTimer = null;
    _etaTimer = null;
    _activeSosId = null;
  }

  @override
  void dispose() {
    _stopAllStreams();
    super.dispose();
  }

  // Stream live location to the dispatcher while the SOS is active (doc SD-4).
  void _startLocationStream(String sosId) {
    _sosTimer?.cancel();
    _sosTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
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

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; _offline = false; });
    try {
      final ann = await Api.get('/announcements');
      final missing = await Api.get('/persons/missing');
      final wanted = await Api.get('/persons/wanted');
      await DatabaseService.cacheList('announcements', ann);
      await DatabaseService.cacheList('missing_persons', missing);
      await DatabaseService.cacheList('wanted_persons', wanted);
      setState(() { _announcements = ann; _missing = missing; _wanted = wanted; });
    } catch (e) {
      final ann = await DatabaseService.getCachedList('announcements');
      final missing = await DatabaseService.getCachedList('missing_persons');
      final wanted = await DatabaseService.getCachedList('wanted_persons');
      if (ann.isNotEmpty || missing.isNotEmpty || wanted.isNotEmpty) {
        setState(() {
          _announcements = ann;
          _missing = missing;
          _wanted = wanted;
          _offline = true;
        });
      } else {
        setState(() => _loadError = 'Failed to load data: $e');
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _sos() async {
    if (!await ensureAuthed(context, reason: 'Sign in to send an SOS alert with your live location.')) return;
    if (!mounted) return;
    setState(() { _sending = true; _status = null; });
    try {
      final pos = await LocationService.best();
      if (pos == null) {
        setState(() => _status = 'Could not get your location. Turn on location services and try again.');
        return;
      }
      // Load officer roster for nearest selection.
      try {
        final staff = await Api.get('/auth/staff?q=');
        if (staff is List) _officers = staff.where((o) => o['role'] == 'police' && (o['is_active'] == true)).toList();
      } catch (_) {
        try {
          final staff = await Api.get('/admin/users?role=police');
          if (staff is List) _officers = staff.where((o) => o['is_active'] == true).toList();
        } catch (_) {}
      }
      // Sort by distance from current position.
      _officers.sort((a, b) {
        double d(Map o) {
          final lat = (o['latitude'] as num?)?.toDouble();
          final lng = (o['longitude'] as num?)?.toDouble();
          if (lat == null || lng == null) return double.infinity;
          return _haversine(pos.latitude, pos.longitude, lat, lng);
        }
        return d(a).compareTo(d(b));
      });

      // Show nearest-officer selection dialog.
      final selected = <String>{};
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('Select officers to dispatch'),
            content: SizedBox(
              width: double.maxFinite,
              child: _officers.isEmpty
                  ? const Text('No on-duty officers found. Proceeding without pre-assignment.')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _officers.length,
                      itemBuilder: (_, i) {
                        final o = _officers[i];
                        final lat = (o['latitude'] as num?)?.toDouble();
                        final lng = (o['longitude'] as num?)?.toDouble();
                        final dist = (lat != null && lng != null) ? _haversine(pos.latitude, pos.longitude, lat, lng) : null;
                        return CheckboxListTile(
                          value: selected.contains(o['id']),
                          onChanged: (v) => setLocal(() => v == true ? selected.add(o['id']) : selected.remove(o['id'])),
                          title: Text(o['full_name'] ?? 'Officer'),
                          subtitle: Text('${o['region'] ?? '—'}${dist != null ? ' · ${dist.toStringAsFixed(0)} m' : ''}'),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send SOS')),
            ],
          ),
        ),
      );
      if (confirmed != true) { setState(() => _sending = false); return; }

      final data = await Api.post('/sos', {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'address_text': 'Emergency from mobile app',
        'region': Api.region,
        'sub_city': Api.subCity,
        if (selected.isNotEmpty) 'assigned_officers': selected.toList(),
      });
      final alert = data['alert'];
      final sosId = alert?['id']?.toString();
      if (sosId != null) {
        _activeSosId = sosId;
        _sosLat = pos.latitude;
        _sosLng = pos.longitude;
        SocketService.joinSosRoom(sosId);
        _startLocationStream(sosId);
        _startEtaPolling(sosId);
      }
      setState(() => _status = 'SOS sent. Units dispatched. Streaming your live location.');
      _showDispatch(data['dispatch']?['assignments'] ?? []);
    } catch (e) {
      setState(() => _status = 'Could not send SOS: $e');
    } finally {
      setState(() => _sending = false);
    }
  }

  void _startEtaPolling(String sosId) {
    _etaTimer?.cancel();
    _etaTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final units = await Api.get('/dispatch/$sosId/units');
        if (units is List) {
          setState(() => _dispatchUnits = units);
        }
      } catch (_) {}
    });
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) * math.sin(dLon / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  void _showDispatch(List assignments) {
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('SOS dispatched'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Units on the way: ${assignments.length}'),
              const SizedBox(height: 12),
              if (_sosLat != null && _sosLng != null)
                SizedBox(
                  height: 220,
                  child: FlutterMap(
                    options: MapOptions(initialCenter: LatLng(_sosLat!, _sosLng!), initialZoom: 13),
                    children: [
                      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.zega.alert'),
                      MarkerLayer(markers: [
                        Marker(point: LatLng(_sosLat!, _sosLng!), width: 36, height: 36, child: const Icon(Icons.location_on, color: Colors.red, size: 36)),
                        ..._dispatchUnits.where((u) => u['latitude'] != null && u['longitude'] != null).map((u) => Marker(point: LatLng((u['latitude'] as num).toDouble(), (u['longitude'] as num).toDouble()), width: 30, height: 30, child: const Icon(Icons.local_police, color: Colors.blue, size: 30))),
                      ]),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              if (_dispatchUnits.isNotEmpty) ...[
                const Text('Units', style: TextStyle(fontWeight: FontWeight.bold)),
                ..._dispatchUnits.map((u) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.local_police, color: Colors.blue),
                  title: Text(u['officer_name'] ?? u['assigned_to'] ?? 'Officer'),
                  subtitle: Text('ETA: ${u['eta_seconds'] != null ? '${(u['eta_seconds'] / 60).toStringAsFixed(1)} min' : '—'} · ${u['distance_m'] != null ? '${u['distance_m']} m' : ''}'),
                  trailing: Text(u['status'] ?? ''),
                )),
              ],
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(loc.appTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(loc.appSubtitle, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          if (_offline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.amber.shade100,
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(loc.offlineMode, style: const TextStyle(fontSize: 13, color: Colors.amber)),
                ],
              ),
            ),
          Semantics(
            button: true,
            label: 'SOS Emergency button. Double tap to send emergency alert with your GPS location.',
            child: SizedBox(
              height: 96,
              child: FilledButton(
                onPressed: _sending ? null : _sos,
                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_sending ? Icons.hourglass_top : Icons.sos, size: 32, color: Colors.white),
                  const SizedBox(height: 4),
                  Text(_sending ? loc.sending : loc.sosEmergency, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
              ),
            ),
          ),
          if (_status != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_status!, style: TextStyle(color: _status!.startsWith('Could') ? Colors.red : Colors.green))),
          if (_loadError != null) Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [const Icon(Icons.error_outline, color: Colors.red), const SizedBox(width: 8), Expanded(child: Text(_loadError!, style: const TextStyle(color: Colors.red)))]))),
          if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          const SizedBox(height: 20),
          Text(loc.announcements, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ..._announcements.take(3).map((a) => Semantics(
            label: 'Announcement: ${a['title']}. ${a['body']}',
            child: Card(
              child: ListTile(
                leading: Icon(a['category'] == 'warning' ? Icons.warning_amber : Icons.campaign, color: a['category'] == 'warning' ? Colors.amber : Colors.green),
                title: Text(a['title']),
                subtitle: Text(a['body']),
                trailing: Semantics(
                  button: true,
                  label: loc.shareAnnouncement(a['title']),
                  child: IconButton(
                    icon: const Icon(Icons.share, size: 20),
                    tooltip: loc.share,
                    onPressed: () async {
                      final r = await Share.share('${a['title']}\n\n${a['body']}\n\nShared via ZEGA-ALERT');
                      await Api.recordShare('announcement', a['id'] as String?, platform: Api.platformFromRaw(r.raw));
                    },
                  ),
                ),
              ),
            ),
          )),
          const SizedBox(height: 12),
          Text(loc.missingPersons, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Semantics(
                button: true,
                label: loc.reportAMissingPerson,
                child: TextButton.icon(
                  onPressed: () async {
                    if (!await ensureAuthed(context, reason: 'Sign in to report a missing person.')) return;
                    if (!context.mounted) return;
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MissingReportScreen(onDone: _load)));
                  },
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: Text(loc.reportMissing),
                ),
              ),
            ],
          ),
          ..._missing.where((m) => m['status'] == 'missing').take(3).map((m) => Semantics(
            label: 'Missing person: ${m['name']}. Last seen: ${m['last_seen_address'] ?? "unknown"}.',
            child: Card(
              child: ListTile(
                leading: CircleAvatar(child: Text((m['name'] as String).substring(0, 1))),
                title: Text(m['name']),
                subtitle: Text(loc.lastSeen(m['last_seen_address'] ?? 'unknown')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(loc.missing, style: const TextStyle(color: Colors.orange, fontSize: 12)),
                    const SizedBox(width: 4),
                    Semantics(
                      button: true,
                      label: loc.shareMissingPerson(m['name']),
                      child: IconButton(
                        icon: const Icon(Icons.share, size: 18),
                        tooltip: loc.share,
                        onPressed: () async {
                          final r = await Share.share('MISSING PERSON: ${m['name']}\nLast seen: ${m['last_seen_address'] ?? "unknown"}\n${m['description'] ?? ""}\n\nShared via ZEGA-ALERT');
                          await Api.recordShare('missing_person', m['id'] as String?, platform: Api.platformFromRaw(r.raw));
                        },
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Report a sighting for ${m['name']}',
                      child: IconButton(
                        icon: const Icon(Icons.visibility, size: 18),
                        tooltip: loc.reportSighting,
                        onPressed: () async {
                          if (!await ensureAuthed(context, reason: 'Sign in to report a sighting.')) return;
                          if (!context.mounted) return;
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => SightingReportScreen(missingPersonId: m['id'] as String, onDone: _load)));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )),
          const SizedBox(height: 12),
          Text(loc.wantedPersons, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ..._wanted.where((w) => w['status'] == 'wanted').take(3).map((w) => Semantics(
            label: 'Wanted person: ${w['name']}. Crime: ${w['crime_description'] ?? "unknown"}. Danger level: ${w["danger_level"] ?? "unknown"}.',
            child: Card(
              child: ListTile(
                leading: CircleAvatar(child: Text((w['name'] as String).substring(0, 1))),
                title: Text(w['name']),
                subtitle: Text(w['crime_description'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(loc.wanted, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    const SizedBox(width: 4),
                    Semantics(
                      button: true,
                      label: loc.shareWantedPerson(w['name']),
                      child: IconButton(
                        icon: const Icon(Icons.share, size: 18),
                        tooltip: loc.share,
                        onPressed: () async {
                          final r = await Share.share('WANTED PERSON: ${w['name']}\nCrime: ${w['crime_description'] ?? "unknown"}\nDanger level: ${w["danger_level"] ?? "unknown"}\n\nShared via ZEGA-ALERT');
                          await Api.recordShare('wanted_person', w['id'] as String?, platform: Api.platformFromRaw(r.raw));
                        },
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Report a sighting for ${w['name']}',
                      child: IconButton(
                        icon: const Icon(Icons.visibility, size: 18),
                        tooltip: loc.reportSighting,
                        onPressed: () async {
                          if (!await ensureAuthed(context, reason: 'Sign in to report a sighting.')) return;
                          if (!context.mounted) return;
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => SightingReportScreen(wantedPersonId: w['id'] as String, onDone: _load)));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }
}
