import 'dart:async';

import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/database_service.dart';
import '../services/notification_state.dart';
import '../services/socket_service.dart';
import '../widgets/auth_gate.dart';
import '../widgets/fullscreen_image_viewer.dart';
import '../widgets/offline_person_image.dart';
import '../widgets/translatable_text.dart';
import 'missing_report_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _missing = [];
  List<dynamic> _wanted = [];
  String? _loadError;
  bool _loading = true;
  bool _offline = false;
  bool _showFilterBar = false;
  String _selectedFilter = 'All'; // 'All', 'Missing', 'Wanted'

  // Expanded descriptions
  final Set<String> _expandedCards = {};

  // Likes state: entityKey -> count
  final Map<String, int> _likeCounts = {};
  final Set<String> _likedEntities = {};

  // Comments state: entityKey -> isExpanded (bool)
  final Set<String> _expandedComments = {};
  final Map<String, int> _commentCounts = {};
  final Map<String, List<dynamic>> _commentsData = {};
  final Map<String, bool> _commentsLoading = {};
  final Map<String, TextEditingController> _commentControllers = {};

  // Image page controllers for carousels: entityKey -> currentIndex
  final Map<String, int> _carouselIndexes = {};

  @override
  void initState() {
    super.initState();
    SocketService.connect();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getCommentController(String key) {
    if (!_commentControllers.containsKey(key)) {
      _commentControllers[key] = TextEditingController();
    }
    return _commentControllers[key]!;
  }

  Future<void> _load({bool clearPersonNotifications = false}) async {
    setState(() {
      _loading = true;
      _loadError = null;
      _offline = false;
    });
    try {
      final missing = await Api.get('/persons/missing');
      final wanted = await Api.get('/persons/wanted');
      await DatabaseService.cacheList('missing_persons', missing);
      await DatabaseService.cacheList('wanted_persons', wanted);

      // Populate counts from list
      for (final m in (missing as List<dynamic>? ?? [])) {
        final key = 'missing_person_${m['id']}';
        _likeCounts[key] = (m['like_count'] as num?)?.toInt() ?? 0;
        _commentCounts[key] = (m['comment_count'] as num?)?.toInt() ?? 0;
      }
      for (final w in (wanted as List<dynamic>? ?? [])) {
        final key = 'wanted_person_${w['id']}';
        _likeCounts[key] = (w['like_count'] as num?)?.toInt() ?? 0;
        _commentCounts[key] = (w['comment_count'] as num?)?.toInt() ?? 0;
      }

      setState(() {
        _missing = missing is List ? missing : [];
        _wanted = wanted is List ? wanted : [];
      });
      if (clearPersonNotifications && Api.isLoggedIn) {
        try {
          await Api.post('/notifications/read-content-updates', {
            'scope': 'persons',
          });
          NotificationState.notifyChanged();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  Api.userMessage(
                    e,
                    fallback: 'Could not clear notifications right now.',
                  ),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      final missing = await DatabaseService.getCachedList('missing_persons');
      final wanted = await DatabaseService.getCachedList('wanted_persons');
      if (missing.isNotEmpty || wanted.isNotEmpty) {
        setState(() {
          _missing = missing;
          _wanted = wanted;
          _offline = true;
        });
      } else {
        setState(
          () => _loadError = Api.userMessage(
            e,
            fallback: 'Could not load data right now.',
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike(String entityType, String entityId) async {
    final key = '${entityType}_$entityId';
    final wasLiked = _likedEntities.contains(key);
    final currentCount = _likeCounts[key] ?? 0;

    // Optimistic UI update
    setState(() {
      if (wasLiked) {
        _likedEntities.remove(key);
        _likeCounts[key] = (currentCount - 1).clamp(0, 999999);
      } else {
        _likedEntities.add(key);
        _likeCounts[key] = currentCount + 1;
      }
    });

    try {
      final res = await Api.toggleLike(entityType, entityId);
      if (res is Map) {
        setState(() {
          if (res['liked'] == true) {
            _likedEntities.add(key);
          } else {
            _likedEntities.remove(key);
          }
          if (res['like_count'] != null) {
            _likeCounts[key] = (res['like_count'] as num).toInt();
          }
        });
      }
    } catch (e) {
      // Revert on error (e.g. unauthenticated)
      setState(() {
        if (wasLiked) {
          _likedEntities.add(key);
          _likeCounts[key] = currentCount;
        } else {
          _likedEntities.remove(key);
          _likeCounts[key] = currentCount;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Api.userMessage(e, fallback: 'Please sign in to like posts.'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleComments(String entityType, String entityId) async {
    final key = '${entityType}_$entityId';
    final isExpanded = _expandedComments.contains(key);

    if (isExpanded) {
      setState(() => _expandedComments.remove(key));
    } else {
      setState(() {
        _expandedComments.add(key);
        _commentsLoading[key] = true;
      });
      _fetchComments(entityType, entityId);
    }
  }

  Future<void> _fetchComments(String entityType, String entityId) async {
    final key = '${entityType}_$entityId';
    try {
      final res = await Api.getComments(entityType, entityId);
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

  Future<void> _postComment(String entityType, String entityId) async {
    final key = '${entityType}_$entityId';
    final controller = _getCommentController(key);
    final text = controller.text.trim();
    if (text.isEmpty) return;

    if (!await ensureAuthed(context, reason: 'Sign in to write a comment.'))
      return;
    if (!mounted) return;

    controller.clear();
    try {
      final res = await Api.addComment(entityType, entityId, text);
      if (res is Map && res['comment'] != null) {
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
          SnackBar(
            content: Text(
              Api.userMessage(e, fallback: 'Could not post your comment.'),
            ),
          ),
        );
      }
    }
  }

  bool _matchesSearch(Map<String, dynamic> person) {
    final query = widget.searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [
      person['name'],
      person['case_code'],
      person['last_seen_address'],
      person['description'],
      person['crime_description'],
    ].any((value) => value?.toString().toLowerCase().contains(query) ?? false);
  }

  List<Map<String, dynamic>> _filteredList() {
    final list = <Map<String, dynamic>>[];

    if (_selectedFilter == 'All' || _selectedFilter == 'Wanted') {
      for (final w in _wanted) {
        if ((w['status'] == 'wanted' || w['status'] == null) &&
            _matchesSearch(Map<String, dynamic>.from(w as Map))) {
          list.add({'item': w, 'kind': 'wanted'});
        }
      }
    }
    if (_selectedFilter == 'All' || _selectedFilter == 'Missing') {
      for (final m in _missing) {
        if ((m['status'] == 'missing' || m['status'] == null) &&
            _matchesSearch(Map<String, dynamic>.from(m as Map))) {
          list.add({'item': m, 'kind': 'missing'});
        }
      }
    }

    list.sort((a, b) {
      final aPublishedAt = _publicationDate(a['item']);
      final bPublishedAt = _publicationDate(b['item']);
      if (aPublishedAt == null) return bPublishedAt == null ? 0 : 1;
      if (bPublishedAt == null) return -1;
      return bPublishedAt.compareTo(aPublishedAt);
    });

    return list;
  }

  DateTime? _publicationDate(dynamic person) {
    final date = person['approved_at'] ?? person['created_at'];
    return DateTime.tryParse(date?.toString() ?? '');
  }

  bool _handleFilterBarScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    var shouldShow = _showFilterBar;
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse) {
        shouldShow = true;
      } else if (notification.direction == ScrollDirection.forward) {
        shouldShow = false;
      }
    } else if (notification is ScrollEndNotification &&
        notification.metrics.pixels <=
            notification.metrics.minScrollExtent + 1) {
      shouldShow = false;
    }
    if (_showFilterBar != shouldShow) {
      setState(() => _showFilterBar = shouldShow);
    }
    return false;
  }

  List<String> _extractImages(Map<String, dynamic> person) {
    final List<String> list = [];
    if (person['photos'] != null && person['photos'] is List) {
      for (final p in person['photos']) {
        if (p != null && p.toString().isNotEmpty) {
          final url = Api.assetUrl(p.toString());
          if (url != null && url.isNotEmpty) list.add(url);
        }
      }
    }
    final primaryPhoto = Api.assetUrl(person['photo_url']?.toString());
    if (primaryPhoto != null &&
        primaryPhoto.isNotEmpty &&
        !list.contains(primaryPhoto)) {
      list.insert(0, primaryPhoto);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final items = _filteredList();
    final sectionWidgets = _buildHomeSectionWidgets(loc);

    return NotificationListener<ScrollNotification>(
      onNotification: _handleFilterBarScroll,
      child: RefreshIndicator(
        onRefresh: () => _load(clearPersonNotifications: true),
        color: const Color(0xFF1E3A8A),
        child: Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _showFilterBar
                  ? _buildFilterTabs(loc)
                  : const SizedBox(width: double.infinity),
            ),
            if (_offline)
              Container(
                color: Colors.amber.shade100,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_off,
                      size: 16,
                      color: Colors.amber.shade900,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You are offline. Showing cached records.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: sectionWidgets.length + items.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index < sectionWidgets.length) {
                    return sectionWidgets[index];
                  }
                  final itemIndex = index - sectionWidgets.length;
                  if (itemIndex < items.length) {
                    final itemData = items[itemIndex];
                    return _buildPersonCard(
                      context,
                      itemData['item'] as Map<String, dynamic>,
                      isWanted: itemData['kind'] == 'wanted',
                    );
                  }
                  if (_loading) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (_loadError != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.blueGrey,
                          ),
                          const SizedBox(height: 12),
                          Text(_loadError!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _load,
                            child: Text(loc.retry),
                          ),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No records found',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHomeSectionWidgets(AppLocalizations loc) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Semantics(
              button: true,
              label: loc.reportAMissingPerson,
              child: TextButton.icon(
                onPressed: () async {
                  if (!await ensureAuthed(
                    context,
                    reason: 'Sign in to report a missing person.',
                  ))
                    return;
                  if (!mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MissingReportScreen(onDone: _load),
                    ),
                  );
                },
                icon: const Icon(Icons.person_add_alt_1, size: 16),
                label: Text(loc.reportMissing),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildFilterTabs(AppLocalizations loc) {
    final filters = ['All', 'Missing', 'Wanted'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters.map((filter) {
                  final isSelected = _selectedFilter == filter;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF334155),
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      backgroundColor: const Color(0xFFF1F5F9),
                      selectedColor: const Color(0xFF0F172A),
                      checkmarkColor: Colors.white,
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF0F172A)
                              : Colors.transparent,
                        ),
                      ),
                      onSelected: (_) {
                        setState(() => _selectedFilter = filter);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          IconButton(
            tooltip: loc.refreshWantedMissing,
            onPressed: _loading
                ? null
                : () => _load(clearPersonNotifications: true),
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonCard(
    BuildContext context,
    Map<String, dynamic> person, {
    required bool isWanted,
  }) {
    final loc = AppLocalizations.of(context);
    final id = person['id'] as String? ?? '';
    final entityType = isWanted ? 'wanted_person' : 'missing_person';
    final entityKey = '${entityType}_$id';

    final name = (person['name'] as String?)?.trim() ?? 'Unknown';
    final age = person['age'];
    final location =
        (person['last_seen_address'] as String?) ??
        (isWanted
            ? 'Last known location not specified'
            : 'Last seen location unknown');
    final isExpanded = _expandedCards.contains(id);
    final fullDescription =
        (isWanted ? person['crime_description'] : person['description'])
            as String? ??
        '';
    final images = _extractImages(person);
    final fullscreenDetails = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isWanted ? 'Wanted person' : 'Missing person',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (age != null)
          Text(
            'Age: $age',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        if (person['gender']?.toString().isNotEmpty ?? false)
          Text(
            'Gender: ${person['gender']}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        Text(
          'Location: $location',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        if (person['case_code']?.toString().isNotEmpty ?? false)
          Text(
            'Case code: ${person['case_code']}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        if (fullDescription.isNotEmpty) ...[
          const SizedBox(height: 8),
          TranslatableText(
            text: fullDescription,
            style: const TextStyle(color: Colors.white, height: 1.4),
          ),
        ],
      ],
    );

    final isLiked = _likedEntities.contains(entityKey);
    final likeCount = _likeCounts[entityKey] ?? 0;
    final isCommentsExpanded = _expandedComments.contains(entityKey);
    final commentCount = _commentCounts[entityKey] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP HEADER: User Info ABOVE Image
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    if (images.isEmpty) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FullscreenImageViewer(
                          images: images,
                          initialIndex: 0,
                          title: name,
                          details: fullscreenDetails,
                          cachePersonPhotos: true,
                        ),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: isWanted
                        ? const Color(0xFFDC2626).withOpacity(0.15)
                        : const Color(0xFF2563EB).withOpacity(0.15),
                    child: images.isNotEmpty
                        ? ClipOval(
                            child: OfflinePersonImage(
                              url: images.first,
                              width: 44,
                              height: 44,
                            ),
                          )
                        : Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isWanted
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF2563EB),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (age != null) ...[
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Age $age',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isWanted
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isWanted ? 'Wanted' : 'Missing',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (fullDescription.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState: isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: TranslatableText(
                      text: fullDescription,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                    secondChild: TranslatableText(
                      text: fullDescription,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (fullDescription.length > 70)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedCards.remove(id);
                          } else {
                            _expandedCards.add(id);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 6),
                        child: Text(
                          isExpanded ? 'Read less' : 'Read more',
                          style: const TextStyle(
                            color: Color(0xFF1E40AF),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 6),
          _buildImageSection(
            entityKey,
            name,
            isWanted,
            images,
            onTap: () {
              if (images.isEmpty) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FullscreenImageViewer(
                    images: images,
                    initialIndex: 0,
                    title: name,
                    details: fullscreenDetails,
                    cachePersonPhotos: true,
                  ),
                ),
              );
            },
          ),
          // Likes & comments summary
          if (likeCount > 0 || commentCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Row(
                children: [
                  if (likeCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E40AF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.thumb_up,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$likeCount',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (commentCount > 0)
                    GestureDetector(
                      onTap: () => _toggleComments(entityType, id),
                      child: Text(
                        '$commentCount ${commentCount == 1 ? "comment" : "comments"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          const Divider(height: 12, thickness: 0.5, indent: 12, endIndent: 12),

          // 5. ACTION BUTTONS: Like | Comment | Share | Report (Scrollable or Fitted to prevent overflow)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Like Button
                  InkWell(
                    onTap: () => _toggleLike(entityType, id),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                            size: 17,
                            color: isLiked
                                ? const Color(0xFF1E40AF)
                                : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            likeCount > 0 ? 'Like ($likeCount)' : 'Like',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isLiked
                                  ? const Color(0xFF1E40AF)
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Comment Button
                  InkWell(
                    onTap: () => _toggleComments(entityType, id),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCommentsExpanded
                                ? Icons.chat_bubble
                                : Icons.chat_bubble_outline,
                            size: 17,
                            color: isCommentsExpanded
                                ? const Color(0xFF1E40AF)
                                : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            commentCount > 0
                                ? 'Comment ($commentCount)'
                                : 'Comment',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isCommentsExpanded
                                  ? const Color(0xFF1E40AF)
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Share Button
                  InkWell(
                    onTap: () async {
                      final r = await Share.share(
                        isWanted
                            ? 'WANTED PERSON: $name\nCrime: ${person['crime_description'] ?? "unknown"}\n\nShared via ZEGA-ALERT'
                            : 'MISSING PERSON: $name\nLast seen: $location\n\nShared via ZEGA-ALERT',
                      );
                      await Api.recordShare(
                        entityType,
                        id,
                        platform: Api.platformFromRaw(r.raw),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.share_outlined,
                            size: 17,
                            color: Color(0xFF475569),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Share',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Direct Report / Sighting Button
                  InkWell(
                    onTap: () async {
                      if (!await ensureAuthed(
                        context,
                        reason: loc.signInToReportSighting,
                      ))
                        return;
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SightingReportScreen(
                            missingPersonId: isWanted ? null : id,
                            wantedPersonId: isWanted ? id : null,
                            title: loc.reportSightingForPerson(name),
                            onDone: _load,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 17,
                            color: isWanted
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Report',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isWanted
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 6. EXPANDABLE INLINE COMMENT SECTION (Facebook Style)
          if (isCommentsExpanded) _buildCommentSection(entityType, id),
        ],
      ),
    );
  }

  Widget _buildImageSection(
    String entityKey,
    String name,
    bool isWanted,
    List<String> images, {
    required VoidCallback onTap,
  }) {
    if (images.isEmpty) {
      return GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1.2,
          child: _placeholderImage(name, isWanted),
        ),
      );
    }

    if (images.length == 1) {
      return GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1.2,
          child: OfflinePersonImage(
            url: images.first,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholderImage(name, isWanted),
          ),
        ),
      );
    }

    // Multiple images (2 or more) - Carousel Frame View
    final currentIndex = _carouselIndexes[entityKey] ?? 0;

    return Column(
      children: [
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 1.2,
              child: PageView.builder(
                itemCount: images.length,
                onPageChanged: (idx) {
                  setState(() => _carouselIndexes[entityKey] = idx);
                },
                itemBuilder: (context, idx) {
                  return GestureDetector(
                    onTap: onTap,
                    child: OfflinePersonImage(
                      url: images[idx],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _placeholderImage(name, isWanted),
                    ),
                  );
                },
              ),
            ),
            // Frame badge showing e.g. "1/3"
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${currentIndex + 1}/${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Dots indicator
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(images.length, (idx) {
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: currentIndex == idx
                    ? const Color(0xFF1E40AF)
                    : Colors.grey.shade300,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCommentSection(String entityType, String entityId) {
    final loc = AppLocalizations.of(context);
    final key = '${entityType}_$entityId';
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
          // Comments list
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Center(
                child: Text(
                  'No comments yet. Be the first to comment!',
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
                final body = (c['body'] as String?) ?? '';
                final isStaff =
                    c['user_role'] != null && c['user_role'] != 'citizen';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isStaff
                            ? const Color(0xFF1E3A8A)
                            : Colors.grey.shade400,
                        child: Text(
                          author.isNotEmpty ? author[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    author,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (isStaff) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E3A8A),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        (c['user_role'] as String)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                body,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                ),
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

          // Fixed-position comment input field at bottom of comment section
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
                      hintText: loc.writeCommentHint,
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _postComment(entityType, entityId),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => _postComment(entityType, entityId),
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFF1E40AF),
                  ),
                  splashRadius: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImage(String name, bool isWanted) {
    return Container(
      color: const Color(0xFF1E293B),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: isWanted
                  ? Colors.red.shade900
                  : const Color(0xFF334155),
              child: Text(
                name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 36,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
