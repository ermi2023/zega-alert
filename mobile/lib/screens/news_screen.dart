import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../widgets/auth_gate.dart';
import '../widgets/fullscreen_image_viewer.dart';
import '../widgets/road_closure_map_widget.dart';
import '../widgets/translatable_text.dart';
import '../services/database_service.dart';
import 'announcement_detail_screen.dart';
import 'id_verification_screen.dart';
import 'missing_report_screen.dart';
import 'person_detail_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _items = [];
  List<dynamic> _legal = [];
  List<dynamic> _missing = [];
  List<dynamic> _wanted = [];
  List<dynamic> _sightings = [];
  String? _legalCategory;
  String? _legalLang;
  String _newsFilter = 'all';
  bool _loading = true;
  String? _loadError;
  bool _offline = false;

  // Social interactions state: entityKey -> reaction ('like' / 'dislike' / null)
  final Map<String, String?> _userReactions = {};
  final Map<String, int> _likeCounts = {};
  final Map<String, int> _dislikeCounts = {};
  final Map<String, int> _commentCounts = {};

  // Comments inline expansion
  final Set<String> _expandedComments = {};
  final Map<String, List<dynamic>> _commentsData = {};
  final Map<String, bool> _commentsLoading = {};
  final Map<String, TextEditingController> _commentControllers = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _loadNews();
  }

  @override
  void dispose() {
    for (final c in _commentControllers.values) {
      c.dispose();
    }
    _tabs.dispose();
    super.dispose();
  }

  TextEditingController _getCommentController(String key) {
    if (!_commentControllers.containsKey(key)) {
      _commentControllers[key] = TextEditingController();
    }
    return _commentControllers[key]!;
  }

  Future<void> _loadNews() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _offline = false;
    });
    try {
      final results = await Future.wait([
        Api.get('/announcements'),
        Api.get('/legal'),
        Api.get('/persons/missing'),
        Api.get('/persons/wanted'),
        Api.get('/persons/sightings'),
      ]);
      if (mounted) {
        final list = results[0] is List ? results[0] : [];
        await DatabaseService.cacheList('announcements', list);
        for (final item in list) {
          final id = item['id']?.toString();
          if (id == null || id.isEmpty) continue;
          final key = 'announcement_$id';
          _likeCounts[key] = (item['like_count'] as num?)?.toInt() ?? 0;
          _dislikeCounts[key] = (item['dislike_count'] as num?)?.toInt() ?? 0;
          _commentCounts[key] = (item['comment_count'] as num?)?.toInt() ?? 0;
        }
        setState(() {
          _items = list;
          _legal = results[1] is List ? results[1] : [];
          _missing = results[2] is List ? results[2] : [];
          _wanted = results[3] is List ? results[3] : [];
          _sightings = results[4] is List ? results[4] : [];
          _loading = false;
        });
      }
    } catch (e) {
      final cached = await DatabaseService.getCachedList('announcements');
      if (mounted) {
        if (cached.isNotEmpty) {
          setState(() {
            _items = cached;
            _offline = true;
            _loading = false;
            _loadError = null;
          });
          for (final item in cached) {
            final id = item['id'] as String?;
            if (id == null) continue;
            final key = 'announcement_$id';
            _likeCounts[key] = (item['like_count'] as num?)?.toInt() ?? 0;
            _dislikeCounts[key] = (item['dislike_count'] as num?)?.toInt() ?? 0;
            _commentCounts[key] = (item['comment_count'] as num?)?.toInt() ?? 0;
          }
        } else {
          setState(() {
            _loadError = 'Failed to load updates: $e';
            _loading = false;
          });
        }
      }
    }
  }

  Future<void> _loadLegal() async {
    final params = <String>[];
    if (_legalCategory != null && _legalCategory!.isNotEmpty) params.add('category=$_legalCategory');
    if (_legalLang != null && _legalLang!.isNotEmpty) params.add('language=$_legalLang');
    final path = params.isEmpty ? '/legal' : '/legal?${params.join('&')}';
    try {
      final data = await Api.get(path);
      if (mounted) setState(() => _legal = data is List ? data : []);
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Failed to load: $e');
    }
  }

  Future<void> _handleReaction(String id, String reaction) async {
    final key = 'announcement_$id';
    final currentReaction = _userReactions[key];
    final currentLikes = _likeCounts[key] ?? 0;
    final currentDislikes = _dislikeCounts[key] ?? 0;

    // Optimistic state calculation
    setState(() {
      if (currentReaction == reaction) {
        // Toggle off
        _userReactions[key] = null;
        if (reaction == 'like')
          _likeCounts[key] = (currentLikes - 1).clamp(0, 999999);
        if (reaction == 'dislike')
          _dislikeCounts[key] = (currentDislikes - 1).clamp(0, 999999);
      } else {
        // Switching or new
        if (currentReaction == 'like')
          _likeCounts[key] = (currentLikes - 1).clamp(0, 999999);
        if (currentReaction == 'dislike')
          _dislikeCounts[key] = (currentDislikes - 1).clamp(0, 999999);

        _userReactions[key] = reaction;
        if (reaction == 'like') _likeCounts[key] = currentLikes + 1;
        if (reaction == 'dislike') _dislikeCounts[key] = currentDislikes + 1;
      }
    });

    try {
      final res = await Api.toggleLike('announcement', id, reaction: reaction);
      if (res is Map && mounted) {
        setState(() {
          _userReactions[key] = res['user_reaction'] as String?;
          _likeCounts[key] =
              (res['like_count'] as num?)?.toInt() ?? _likeCounts[key]!;
          _dislikeCounts[key] =
              (res['dislike_count'] as num?)?.toInt() ?? _dislikeCounts[key]!;
        });
      }
    } catch (e) {
      // Revert if unauthorized or failed
      setState(() {
        _userReactions[key] = currentReaction;
        _likeCounts[key] = currentLikes;
        _dislikeCounts[key] = currentDislikes;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please sign in to react: $e')),
        );
      }
    }
  }

  Future<void> _toggleComments(String id) async {
    final key = 'announcement_$id';
    final isExpanded = _expandedComments.contains(key);

    if (isExpanded) {
      setState(() => _expandedComments.remove(key));
    } else {
      setState(() {
        _expandedComments.add(key);
        _commentsLoading[key] = true;
      });
      _fetchComments(id);
    }
  }

  Future<void> _fetchComments(String id) async {
    final key = 'announcement_$id';
    try {
      final res = await Api.getComments('announcement', id);
      if (mounted) {
        setState(() {
          _commentsData[key] = res is List ? res : [];
          _commentCounts[key] = _commentsData[key]?.length ?? 0;
          _commentsLoading[key] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _commentsLoading[key] = false);
      }
    }
  }

  Future<void> _postComment(String id) async {
    final key = 'announcement_$id';
    final controller = _getCommentController(key);
    final text = controller.text.trim();
    if (text.isEmpty) return;

    if (!await ensureAuthed(context, reason: 'Sign in to write a comment.'))
      return;
    if (!mounted) return;

    controller.clear();
    try {
      final res = await Api.addComment('announcement', id, text);
      if (res is Map && res['comment'] != null && mounted) {
        setState(() {
          final list = _commentsData[key] ?? [];
          list.add(res['comment']);
          _commentsData[key] = list;
          _commentCounts[key] =
              (res['comment_count'] as num?)?.toInt() ?? list.length;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          if (_offline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFFF7ED),
              child: Text(
                loc.offlineMode,
                style: const TextStyle(color: Color(0xFF9A3412), fontSize: 12),
              ),
            ),
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
                  onPressed: _loading ? null : _loadNews,
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
      ),
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
    final items = _newsFilter == 'all'
        ? _items.where((a) => a['category'] != 'missing_item').toList()
        : _items.where((a) => a['category'] == _newsFilter).toList();
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
          child: _loading && _items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? _empty(AppLocalizations.of(context).nothingHereYet)
                  : RefreshIndicator(
                      onRefresh: _loadNews,
                      color: const Color(0xFF0F172A),
                      child: ListView.separated(
                        padding: const EdgeInsets.only(top: 8, bottom: 24),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _buildNewsCard(
                          context,
                          Map<String, dynamic>.from(items[i] as Map),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Future<void> _openMissingReport() async {
    if (!await ensureAuthed(context, reason: 'Sign in to report a missing person.')) return;
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MissingReportScreen(onDone: _loadNews)));
  }

  Future<void> _openSighting(dynamic person, {String? wantedId}) async {
    if (!await ensureAuthed(context, reason: 'Sign in to report a sighting.')) return;
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SightingReportScreen(
        missingPersonId: person['id']?.toString(),
        wantedPersonId: wantedId,
        onDone: _loadNews,
      ),
    ));
  }

  Widget _missingTab() {
    final loc = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _loadNews,
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
      onRefresh: _loadNews,
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
              ? () => _openSighting(person, wantedId: wanted ? person['id']?.toString() : null)
              : null,
        ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PersonDetailScreen(
            person: Map<String, dynamic>.from(person as Map),
            kind: kind,
            onChanged: _loadNews,
          ),
        )),
      ),
    );
  }

  Widget _itemsTab() {
    final items = _items.where((a) => a['category'] == 'missing_item').toList();
    if (items.isEmpty) {
      return _empty('No lost or recovered items reported yet.');
    }
    return RefreshIndicator(
      onRefresh: _loadNews,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: items.length,
        itemBuilder: (_, i) => _announcementCard(items[i]),
      ),
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
            await Api.recordShare('announcement', a['id']?.toString(), platform: Api.platformFromRaw(r.raw));
          },
        ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AnnouncementDetailScreen(item: Map<String, dynamic>.from(a as Map)),
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
      onRefresh: _loadNews,
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

  Widget _buildNewsCard(BuildContext context, Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final key = 'announcement_$id';
    final category = item['category'] as String? ?? 'news';
    final isRoadClosure = category == 'road_closure';

    final title = item['title'] as String? ?? 'Announcement';
    final body = item['body'] as String? ?? '';
    final sourceLanguage = (item['language'] as String?) ?? 'en';
    final imageUrl = Api.assetUrl(item['image_url']?.toString());
    final sourceLabel = item['source_label'] as String? ?? 'ZEGA-ALERT Media Desk';
    final badgeLabel = item['badge_label'] as String? ??
        (isRoadClosure
            ? 'TRAFFIC ALERT'
            : (category == 'warning' ? 'ADVISORY' : 'PRESS RELEASE'));
    final startTime = item['start_time_label'] as String?;
    final detourInfo = item['detour_info'] as String?;

    final startLat = (item['closure_start_lat'] as num?)?.toDouble();
    final startLng = (item['closure_start_lng'] as num?)?.toDouble();
    final endLat = (item['closure_end_lat'] as num?)?.toDouble();
    final endLng = (item['closure_end_lng'] as num?)?.toDouble();
    final hasMap = isRoadClosure && (startLat != null || endLat != null);

    final userReaction = _userReactions[key];
    final isLiked = userReaction == 'like';
    final isDisliked = userReaction == 'dislike';
    final likeCount = _likeCounts[key] ?? 0;
    final dislikeCount = _dislikeCounts[key] ?? 0;
    final commentCount = _commentCounts[key] ?? 0;
    final isCommentsExpanded = _expandedComments.contains(key);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Image Banner (if article has photo)
          if (imageUrl != null && imageUrl.isNotEmpty)
            Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FullscreenImageViewer(
                        images: [imageUrl],
                        title: title,
                      ),
                    ));
                  },
                  child: AspectRatio(
                    aspectRatio: 1.85,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),

          // 2. Card Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge for cards WITHOUT image banner (e.g. Traffic Alert card with yellow accent)
                if (imageUrl == null || imageUrl.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          isRoadClosure
                              ? Icons.warning_rounded
                              : Icons.info_rounded,
                          size: 16,
                          color: isRoadClosure
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF1E3A8A),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          badgeLabel,
                          style: TextStyle(
                            color: isRoadClosure
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF1E3A8A),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Title
                TranslatableText(
                  text: title,
                  sourceLanguage: sourceLanguage,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Description (translatable on demand)
                TranslatableText(
                  text: body,
                  sourceLanguage: sourceLanguage,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.45,
                  ),
                ),

                // Traffic details (Starts in 2 hrs | Detour active)
                if (isRoadClosure &&
                    (startTime != null || detourInfo != null)) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (startTime != null) ...[
                        const Icon(Icons.access_time,
                            size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          startTime,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 14),
                      ],
                      if (detourInfo != null) ...[
                        const Icon(Icons.map_outlined,
                            size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          detourInfo,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ],
                  ),
                ],

                // 3. Map for Road Closure (Supported by Admin)
                if (hasMap) ...[
                  const SizedBox(height: 14),
                  RoadClosureMapWidget(
                    startLat: startLat,
                    startLng: startLng,
                    endLat: endLat,
                    endLng: endLng,
                    title: title,
                  ),
                ],

                const SizedBox(height: 16),

                // 4. Source & Metadata Bar with Social Action Icons (Facebook/Instagram Style)
                Row(
                  children: [
                    // Source circular badge + text
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF00338D).withOpacity(0.2)),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.shield,
                              size: 14, color: Color(0xFF00338D)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$sourceLabel • Just now',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Like Button with count
                    InkWell(
                      onTap: () => _handleReaction(id, 'like'),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_alt_outlined,
                              size: 18,
                              color: isLiked
                                  ? const Color(0xFF1E40AF)
                                  : const Color(0xFF475569),
                            ),
                            if (likeCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '$likeCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isLiked
                                      ? const Color(0xFF1E40AF)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Dislike Button with count
                    InkWell(
                      onTap: () => _handleReaction(id, 'dislike'),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              isDisliked
                                  ? Icons.thumb_down
                                  : Icons.thumb_down_alt_outlined,
                              size: 18,
                              color: isDisliked
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF475569),
                            ),
                            if (dislikeCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '$dislikeCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDisliked
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Comment Icon Button with count
                    InkWell(
                      onTap: () => _toggleComments(id),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              isCommentsExpanded
                                  ? Icons.chat_bubble
                                  : Icons.chat_bubble_outline,
                              size: 18,
                              color: isCommentsExpanded
                                  ? const Color(0xFF1E40AF)
                                  : const Color(0xFF475569),
                            ),
                            if (commentCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '$commentCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isCommentsExpanded
                                      ? const Color(0xFF1E40AF)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Share Button
                    InkWell(
                      onTap: () async {
                        final r = await Share.share(
                            '$title\n\n$body\n\nShared via ZEGA-ALERT');
                        await Api.recordShare('announcement', id,
                            platform: Api.platformFromRaw(r.raw));
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Icon(Icons.share_outlined,
                            size: 18, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 5. Expandable Comments Section
          if (isCommentsExpanded) _buildCommentSection(id),
        ],
      ),
    );
  }

  Widget _buildCommentSection(String id) {
    final key = 'announcement_$id';
    final isLoading = _commentsLoading[key] ?? false;
    final comments = _commentsData[key] ?? [];
    final controller = _getCommentController(key);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (comments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No comments yet. Share your thoughts!',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: comments.length,
              itemBuilder: (context, idx) {
                final c = comments[idx];
                final author = (c['user_name'] as String?) ?? 'Citizen';
                final text = (c['body'] as String?) ?? '';
                final isStaff =
                    c['user_role'] != null && c['user_role'] != 'citizen';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isStaff
                            ? const Color(0xFF1E3A8A)
                            : Colors.grey.shade400,
                        child: Text(
                          author.isNotEmpty ? author[0].toUpperCase() : '?',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                author,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                text,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey.shade800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          // Comment input field
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      hintStyle:
                          TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _postComment(id),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _postComment(id),
                  icon: const Icon(Icons.send_rounded,
                      color: Color(0xFF1E40AF), size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
