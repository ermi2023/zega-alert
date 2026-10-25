import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../screens/announcement_detail_screen.dart';
import '../services/api.dart';
import '../widgets/auth_gate.dart';
import 'missing_report_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _announcements = [];
  List<dynamic> _legal = [];
  List<dynamic> _missing = [];
  List<dynamic> _sightings = [];
  String? _loadError;
  String? _legalCategory;
  String? _legalLang;

  Future<void> _loadLegal() async {
    final params = <String>[];
    if (_legalCategory != null && _legalCategory!.isNotEmpty) params.add('category=$_legalCategory');
    if (_legalLang != null && _legalLang!.isNotEmpty) params.add('language=$_legalLang');
    final path = params.isEmpty ? '/legal' : '/legal?${params.join('&')}';
    try {
      final data = await Api.get(path);
      if (mounted) setState(() => _legal = data);
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Failed to load: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final results = await Future.wait([
        Api.get('/announcements'),
        Api.get('/legal'),
        Api.get('/persons/missing'),
        Api.get('/persons/sightings'),
      ]);
      setState(() {
        _announcements = results[0];
        _legal = results[1];
        _missing = results[2];
        _sightings = results[3];
      });
    } catch (e) {
      setState(() => _loadError = 'Failed to load: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(16), child: Text(loc.newsAndInformation, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        if (_loadError != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [const Icon(Icons.error_outline, color: Colors.red), const SizedBox(width: 8), Expanded(child: Text(_loadError!, style: const TextStyle(color: Colors.red)))])))),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [Tab(text: loc.announcementsTab), Tab(text: loc.legalTab), Tab(text: loc.missingTab), Tab(text: loc.sightingsTab)],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _list(_announcements, (a) => ListTile(
                title: Text(a['title']),
                subtitle: Text(a['body']),
                leading: Icon(_categoryIcon(a['category'])),
                trailing: IconButton(
                  icon: const Icon(Icons.share, size: 20),
                  tooltip: loc.share,
                  onPressed: () async {
                    final r = await Share.share('${a['title']}\n\n${a['body']}\n\nShared via ZEGA-ALERT');
                    await Api.recordShare('announcement', a['id'] as String?, platform: Api.platformFromRaw(r.raw));
                  },
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AnnouncementDetailScreen(item: Map<String, dynamic>.from(a)))),
              )),
              _legalTab(),
              _missingTab(),
              _sightingsTab(),
            ],
          ),
        ),
      ],
    );
  }

  IconData _categoryIcon(dynamic category) => switch (category) {
    'warning' => Icons.warning_amber,
    'road_closure' => Icons.traffic,
    'missing_item' => Icons.inventory_2_outlined,
    'legal' => Icons.gavel,
    'event' => Icons.event,
    _ => Icons.article,
  };

  Widget _list(List items, Widget Function(dynamic) tile) {
    final loc = AppLocalizations.of(context);
    if (items.isEmpty) return Center(child: Text(loc.nothingHereYet));
    return RefreshIndicator(onRefresh: _load, child: ListView.builder(itemCount: items.length, itemBuilder: (_, i) => Card(child: tile(items[i]))));
  }

  Future<void> _openMissingReport() async {
    if (!await ensureAuthed(context, reason: 'Sign in to report a missing person.')) return;
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MissingReportScreen(onDone: _load)));
  }

  Future<void> _openSighting(dynamic person, {String? wantedId}) async {
    if (!await ensureAuthed(context, reason: 'Sign in to report a sighting.')) return;
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SightingReportScreen(
      missingPersonId: person['id'] as String?,
      wantedPersonId: wantedId,
      onDone: _load,
    )));
  }

  Widget _missingTab() {
    final loc = AppLocalizations.of(context);
    if (_missing.isEmpty) return Center(child: Text(loc.nothingHereYet));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _missing.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _openMissingReport,
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(loc.reportAMissingPerson),
              ),
            );
          }
          final m = _missing[i - 1];
          final found = m['status'] != 'missing';
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text((m['name'] as String).substring(0, 1))),
              title: Text(m['name']),
              subtitle: Text(m['status'] == 'missing' ? '${m['case_code'] != null ? '[${m['case_code']}] ' : ''}${loc.missing} · ${m['last_seen_address'] ?? loc.unknownLocation}' : '${m['case_code'] != null ? '[${m['case_code']}] ' : ''}FOUND'),
              trailing: found ? null : IconButton(icon: const Icon(Icons.visibility), tooltip: loc.reportSighting, onPressed: () => _openSighting(m)),
            ),
          );
        },
      ),
    );
  }

  Widget _legalTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _legalCategory,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
                  items: [null, 'rights', 'duties', 'penalties', 'procedures', 'other'].map((c) => DropdownMenuItem(value: c, child: Text(c ?? 'All'))).toList(),
                  onChanged: (v) { setState(() => _legalCategory = v); _loadLegal(); },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _legalLang,
                  decoration: const InputDecoration(labelText: 'Language', border: OutlineInputBorder(), isDense: true),
                  items: [null, 'en', 'am', 'om', 'ti'].map((l) => DropdownMenuItem(value: l, child: Text(l ?? 'All'))).toList(),
                  onChanged: (v) { setState(() => _legalLang = v); _loadLegal(); },
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _list(_legal, (l) => ListTile(
          title: Text(l['title']),
          subtitle: Text('${l['category']} · ${l['language']}'),
          trailing: (l['review_status'] == 'under_review')
              ? const Chip(label: Text('Under Review', style: TextStyle(fontSize: 11)))
              : null,
        ))),
      ],
    );
  }

  Widget _sightingsTab() {
    final loc = AppLocalizations.of(context);
    if (_sightings.isEmpty) return Center(child: Text(loc.nothingHereYet));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _sightings.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Text(loc.citizenSightingsInfo, style: const TextStyle(color: Colors.grey)),
            );
          }
          final s = _sightings[i - 1];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.place, color: Colors.green),
              title: Text(s['address_text'] ?? loc.unknownLocation),
              subtitle: Text(s['description'] ?? ''),
            ),
          );
        },
      ),
    );
  }
}
