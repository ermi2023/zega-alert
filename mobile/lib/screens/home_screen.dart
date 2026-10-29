import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/database_service.dart';
import '../services/socket_service.dart';
import '../widgets/auth_gate.dart';
import '../widgets/sos_dialog.dart';

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
  String? _loadError;
  bool _loading = true;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    SocketService.connect();
    _load();
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

  Future<void> _callHotline(String number) async {
    final uri = Uri.parse('tel:$number');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
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
                onPressed: () => triggerEmergencySos(context),
                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.sos, size: 32, color: Colors.white),
                  const SizedBox(height: 4),
                  Text(loc.sosEmergency, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callHotline('991'),
                  icon: const Icon(Icons.phone, color: Color(0xFF1E40AF), size: 18),
                  label: const Text('Police 991', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callHotline('907'),
                  icon: const Icon(Icons.emergency, color: Color(0xFFDC2626), size: 18),
                  label: const Text('Rescue 907', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
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
