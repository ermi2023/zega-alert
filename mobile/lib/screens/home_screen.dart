import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/database_service.dart';
import '../services/socket_service.dart';
import '../widgets/auth_gate.dart';
import '../widgets/pod_actions.dart';
import '../widgets/sos_dialog.dart';

import 'announcement_detail_screen.dart';
import 'missing_report_screen.dart';
import 'person_detail_screen.dart';
import 'report_screen.dart';

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
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: PodActions(),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(Icons.edit_note, color: Theme.of(context).colorScheme.primary),
              ),
              title: const Text('Report a crime', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Attach photos, video, audio, a web link or a file'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                if (!await ensureAuthed(context, reason: 'Sign in to file a crime report.')) return;
                if (!context.mounted) return;
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CrimeReportScreen()));
              },
            ),
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
                subtitle: Text(a['body'], maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AnnouncementDetailScreen(item: Map<String, dynamic>.from(a)),
                )),
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
          if (_missing.where((m) => m['status'] == 'missing').isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(loc.nothingHereYet, style: const TextStyle(color: Colors.grey))),
          ..._missing.where((m) => m['status'] == 'missing').take(5).map((m) => _personCard(m, 'missing', loc)),
          const SizedBox(height: 12),
          Text(loc.wantedPersons, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (_wanted.where((w) => w['status'] == 'wanted').isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(loc.nothingHereYet, style: const TextStyle(color: Colors.grey))),
          ..._wanted.where((w) => w['status'] == 'wanted').take(5).map((w) => _personCard(w, 'wanted', loc)),
        ],
      ),
    );
  }

  Widget _personCard(dynamic person, String kind, AppLocalizations loc) {
    final wanted = kind == 'wanted';
    final name = (person['name'] ?? 'Unknown').toString();
    final photo = Api.assetUrl(person['photo_url']?.toString());
    final subtitle = wanted
        ? (person['crime_description'] ?? '').toString()
        : loc.lastSeen((person['last_seen_address'] ?? loc.unknownLocation).toString());
    return Semantics(
      label: wanted
          ? 'Wanted person: $name. Crime: ${person['crime_description'] ?? "unknown"}. Danger level: ${person["danger_level"] ?? "unknown"}.'
          : 'Missing person: $name. Last seen: ${person['last_seen_address'] ?? "unknown"}.',
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: wanted ? Colors.red.shade50 : Colors.orange.shade50,
            foregroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
            child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                style: TextStyle(color: wanted ? Colors.red.shade700 : Colors.orange.shade800, fontWeight: FontWeight.bold)),
          ),
          title: Text(name),
          subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PersonDetailScreen(
              person: Map<String, dynamic>.from(person),
              kind: kind,
              onChanged: _load,
            ),
          )),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(wanted ? loc.wanted : loc.missing,
                  style: TextStyle(color: wanted ? Colors.red : Colors.orange, fontSize: 12)),
              Semantics(
                button: true,
                label: wanted ? loc.shareWantedPerson(name) : loc.shareMissingPerson(name),
                child: IconButton(
                  icon: const Icon(Icons.share, size: 18),
                  tooltip: loc.share,
                  onPressed: () async {
                    final r = await Share.share(wanted
                        ? 'WANTED PERSON: $name\nCrime: ${person['crime_description'] ?? "unknown"}\nDanger level: ${person["danger_level"] ?? "unknown"}\n\nShared via ZEGA-ALERT'
                        : 'MISSING PERSON: $name\nLast seen: ${person['last_seen_address'] ?? "unknown"}\n${person['description'] ?? ""}\n\nShared via ZEGA-ALERT');
                    await Api.recordShare(wanted ? 'wanted_person' : 'missing_person',
                        person['id'] as String?, platform: Api.platformFromRaw(r.raw));
                  },
                ),
              ),
              Semantics(
                button: true,
                label: 'Report a sighting for $name',
                child: IconButton(
                  icon: const Icon(Icons.visibility, size: 18),
                  tooltip: loc.reportSighting,
                  onPressed: () async {
                    if (!await ensureAuthed(context, reason: 'Sign in to report a sighting.')) return;
                    if (!mounted) return;
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SightingReportScreen(
                        missingPersonId: wanted ? null : person['id'] as String?,
                        wantedPersonId: wanted ? person['id'] as String? : null,
                        onDone: _load,
                      ),
                    ));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
