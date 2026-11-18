import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../screens/announcement_detail_screen.dart';
import '../screens/person_detail_screen.dart';
import '../services/api.dart';
import '../widgets/auth_gate.dart';
import 'id_verification_screen.dart';
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
  List<dynamic> _wanted = [];
  List<dynamic> _sightings = [];
  String? _loadError;
  String? _legalCategory;
  String? _legalLang;
  String _newsFilter = 'all';
  bool _loading = false;

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
    _tabs = TabController(length: 6, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loadError = null; _loading = true; });
    try {
      final results = await Future.wait([
        Api.get('/announcements'),
        Api.get('/legal'),
        Api.get('/persons/missing'),
        Api.get('/persons/wanted'),
        Api.get('/persons/sightings'),
      ]);
      if (!mounted) return;
      setState(() {
        _announcements = results[0];
        _legal = results[1];
        _missing = results[2];
        _wanted = results[3];
        _sightings = results[4];
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Failed to load: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.newsAndInformation, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text('News, road closures, wanted & missing persons, and lost items',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Scan Fayda ID',
                onPressed: () async {
                  if (!await ensureAuthed(context, reason: 'Sign in to verify your Fayda National ID.')) return;
                  if (!context.mounted) return;
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IdVerificationScreen()));
                },
                icon: const Icon(Icons.qr_code_scanner),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : _load,
                icon: _loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        if (_loadError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_loadError!, style: const TextStyle(color: Colors.red))),
                ]),
              ),
            ),
          ),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            Tab(text: loc.announcementsTab),
            Tab(text: loc.missingTab),
            Tab(text: loc.wantedPersons),
            const Tab(text: 'Lost & found'),
            Tab(text: loc.legalTab),
            Tab(text: loc.sightingsTab),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _newsTab(),
              _missingTab(),
              _wantedTab(),
              _itemsTab(),
              _legalTab(),
              _sightingsTab(),
            ],
          ),
        ),
      ],
    );
  }

  static const _newsFilters = <({String value, String label})>[
    (value: 'all', label: 'All'),
    (value: 'news', label: 'News'),
    (value: 'warning', label: 'Alerts'),
    (value: 'road_closure', label: 'Road closures'),
    (value: 'event', label: 'Events'),
  ];

  Widget _newsTab() {
    final loc = AppLocalizations.of(context);
    final items = _newsFilter == 'all'
        ? _announcements.where((a) => a['category'] != 'missing_item').toList()
        : _announcements.where((a) => a['category'] == _newsFilter).toList();
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: _newsFilters
                .map((f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.label),
                        selected: _newsFilter == f.value,
                        onSelected: (_) => setState(() => _newsFilter = f.value),
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? _empty(loc.nothingHereYet)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _announcementCard(items[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _announcementCard(dynamic a) {
    final loc = AppLocalizations.of(context);
    final category = (a['category'] ?? 'news').toString();
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _categoryColor(category).withValues(alpha: 0.12),
          child: Icon(_categoryIcon(category), color: _categoryColor(category), size: 20),
        ),
        title: Text((a['title'] ?? '').toString()),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((a['body'] ?? '').toString(), maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(_categoryLabel(category).toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _categoryColor(category))),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.share, size: 20),
          tooltip: loc.share,
          onPressed: () async {
            final r = await Share.share(
                '${a['title']}\n\n${a['body']}\n\nShared via ZEGA-ALERT\n#ZEGAALERT #EthiopianFederalPolice');
            await Api.recordShare('announcement', a['id'] as String?, platform: Api.platformFromRaw(r.raw));
          },
        ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AnnouncementDetailScreen(item: Map<String, dynamic>.from(a)),
        )),
      ),
    );
  }

  String _categoryLabel(String category) => switch (category) {
        'warning' => 'Alert',
        'road_closure' => 'Road closure',
        'missing_item' => 'Lost & found',
        'wanted' => 'Wanted',
        'missing' => 'Missing person',
        'legal' => 'Legal',
        'event' => 'Event',
        _ => 'News',
      };

  Color _categoryColor(String category) => switch (category) {
        'warning' => Colors.amber.shade800,
        'road_closure' => Colors.deepOrange,
        'missing_item' => Colors.teal,
        'wanted' => Colors.red,
        'missing' => Colors.orange,
        'legal' => Colors.indigo,
        'event' => Colors.purple,
        _ => Colors.blue,
      };

  IconData _categoryIcon(String category) => switch (category) {
        'warning' => Icons.warning_amber,
        'road_closure' => Icons.traffic,
        'missing_item' => Icons.inventory_2_outlined,
        'wanted' => Icons.gavel,
        'missing' => Icons.person_search,
        'legal' => Icons.gavel,
        'event' => Icons.event,
        _ => Icons.article,
      };

  Future<void> _openMissingReport() async {
    if (!await ensureAuthed(context, reason: 'Sign in to report a missing person.')) return;
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MissingReportScreen(onDone: _load)));
  }

  Future<void> _openSighting(dynamic person, {String? wantedId}) async {
    if (!await ensureAuthed(context, reason: 'Sign in to report a sighting.')) return;
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SightingReportScreen(
        missingPersonId: person['id'] as String?,
        wantedPersonId: wantedId,
        onDone: _load,
      ),
    ));
  }

  Widget _missingTab() {
    final loc = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _missing.isEmpty ? 2 : _missing.length + 1,
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
          if (_missing.isEmpty) return _empty(loc.nothingHereYet);
          final m = _missing[i - 1];
          final found = m['status'] != 'missing';
          return _personCard(
            m,
            'missing',
            active: !found,
            subtitle: found
                ? '${m['case_code'] != null ? '[${m['case_code']}] ' : ''}Found'
                : '${m['case_code'] != null ? '[${m['case_code']}] ' : ''}${loc.lastSeen(m['last_seen_address'] ?? loc.unknownLocation)}',
          );
        },
      ),
    );
  }

  Widget _wantedTab() {
    final loc = AppLocalizations.of(context);
    if (_wanted.isEmpty) return _empty(loc.nothingHereYet);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _wanted.length,
        itemBuilder: (_, i) => _personCard(
          _wanted[i],
          'wanted',
          active: _wanted[i]['status'] == 'wanted',
          subtitle: '#${_wanted[i]['danger_level'] ?? 'low'} risk · ${_wanted[i]['crime_description'] ?? ''}',
        ),
      ),
    );
  }

  Widget _personCard(dynamic person, String kind, {required bool active, required String subtitle}) {
    final loc = AppLocalizations.of(context);
    final wanted = kind == 'wanted';
    final name = (person['name'] ?? 'Unknown').toString();
    final photo = Api.assetUrl(person['photo_url']?.toString());
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: wanted ? Colors.red.shade50 : Colors.orange.shade50,
          foregroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
          child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
              style: TextStyle(color: wanted ? Colors.red.shade700 : Colors.orange.shade800, fontWeight: FontWeight.bold)),
        ),
        title: Row(
          children: [
            Flexible(child: Text(name)),
            if (wanted && person['danger_level'] != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (person['danger_level'] == 'high' || person['danger_level'] == 'critical')
                      ? Colors.red.shade50
                      : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  (person['danger_level'] ?? '').toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: (person['danger_level'] == 'high' || person['danger_level'] == 'critical')
                        ? Colors.red
                        : Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: Icon(active ? Icons.visibility : Icons.check_circle_outline,
              color: active ? scheme.primary : Colors.green),
          tooltip: active ? loc.reportSighting : 'Resolved',
          onPressed: active
              ? () => _openSighting(person, wantedId: wanted ? person['id'] as String? : null)
              : null,
        ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PersonDetailScreen(
            person: Map<String, dynamic>.from(person),
            kind: kind,
            onChanged: _load,
          ),
        )),
      ),
    );
  }

  Widget _itemsTab() {
    final items = _announcements.where((a) => a['category'] == 'missing_item').toList();
    if (items.isEmpty) {
      return _empty('No lost or recovered items reported yet.');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: items.length,
        itemBuilder: (_, i) => _announcementCard(items[i]),
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
                  initialValue: _legalCategory,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
                  items: [null, 'rights', 'duties', 'penalties', 'procedures', 'other']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c ?? 'All')))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _legalCategory = v);
                    _loadLegal();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _legalLang,
                  decoration: const InputDecoration(labelText: 'Language', border: OutlineInputBorder(), isDense: true),
                  items: [null, 'en', 'am', 'om', 'ti']
                      .map((l) => DropdownMenuItem(value: l, child: Text(l ?? 'All')))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _legalLang = v);
                    _loadLegal();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _legal.isEmpty
              ? _empty(AppLocalizations.of(context).nothingHereYet)
              : RefreshIndicator(
                  onRefresh: _loadLegal,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: _legal.length,
                    itemBuilder: (_, i) {
                      final l = _legal[i];
                      return Card(
                        child: ExpansionTile(
                          leading: const Icon(Icons.menu_book_outlined),
                          title: Text(l['title'] ?? ''),
                          subtitle: Text('${l['category']} · ${l['language']}'),
                          trailing: (l['review_status'] == 'under_review')
                              ? const Chip(label: Text('Under Review', style: TextStyle(fontSize: 11)))
                              : null,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(l['body'] ?? '', style: const TextStyle(height: 1.4)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _sightingsTab() {
    final loc = AppLocalizations.of(context);
    if (_sightings.isEmpty) return _empty(loc.nothingHereYet);
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

  Widget _empty(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 42, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
