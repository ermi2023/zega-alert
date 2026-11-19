import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../widgets/auth_gate.dart';
import '../widgets/fullscreen_image_viewer.dart';
import '../widgets/road_closure_map_widget.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _loadError;
  String _selectedTab = 'all'; // 'all' or 'road_closures'

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
    _loadNews();
  }

  @override
  void dispose() {
    for (final c in _commentControllers.values) {
      c.dispose();
    }
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
    });
    try {
      final data = await Api.get('/announcements');
      if (mounted) {
        final list = data is List ? data : [];
        for (final item in list) {
          final id = item['id'] as String;
          final key = 'announcement_$id';
          _likeCounts[key] = (item['like_count'] as num?)?.toInt() ?? 0;
          _dislikeCounts[key] = (item['dislike_count'] as num?)?.toInt() ?? 0;
          _commentCounts[key] = (item['comment_count'] as num?)?.toInt() ?? 0;
        }
        setState(() {
          _items = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'Failed to load updates: $e';
          _loading = false;
        });
      }
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
        if (reaction == 'like') _likeCounts[key] = (currentLikes - 1).clamp(0, 999999);
        if (reaction == 'dislike') _dislikeCounts[key] = (currentDislikes - 1).clamp(0, 999999);
      } else {
        // Switching or new
        if (currentReaction == 'like') _likeCounts[key] = (currentLikes - 1).clamp(0, 999999);
        if (currentReaction == 'dislike') _dislikeCounts[key] = (currentDislikes - 1).clamp(0, 999999);

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
          _likeCounts[key] = (res['like_count'] as num?)?.toInt() ?? _likeCounts[key]!;
          _dislikeCounts[key] = (res['dislike_count'] as num?)?.toInt() ?? _dislikeCounts[key]!;
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

    if (!await ensureAuthed(context, reason: 'Sign in to write a comment.')) return;
    if (!mounted) return;

    controller.clear();
    try {
      final res = await Api.addComment('announcement', id, text);
      if (res is Map && res['comment'] != null && mounted) {
        setState(() {
          final list = _commentsData[key] ?? [];
          list.add(res['comment']);
          _commentsData[key] = list;
          _commentCounts[key] = (res['comment_count'] as num?)?.toInt() ?? list.length;
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

  List<dynamic> _getFilteredItems() {
    if (_selectedTab == 'road_closures') {
      return _items.where((i) => i['category'] == 'road_closure').toList();
    }
    return _items;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredItems();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Filter Tabs (All Updates / Road Closures)
          _buildFilterTabs(),

          // Feed Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadNews,
              color: const Color(0xFF0F172A),
              child: _loading && _items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null && _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 12),
                              Text(_loadError!),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _loadNews, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Text(
                                _selectedTab == 'road_closures'
                                    ? 'No active road closures.'
                                    : 'No updates at the moment.',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(top: 8, bottom: 24),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = filtered[index] as Map<String, dynamic>;
                                return _buildNewsCard(context, item);
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // All Updates
          InkWell(
            onTap: () => setState(() => _selectedTab = 'all'),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedTab == 'all' ? const Color(0xFF00338D) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedTab == 'all' ? const Color(0xFF00338D) : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.newspaper,
                    size: 16,
                    color: _selectedTab == 'all' ? Colors.white : const Color(0xFF334155),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'All Updates',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _selectedTab == 'all' ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Road Closures
          InkWell(
            onTap: () => setState(() => _selectedTab = 'road_closures'),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedTab == 'road_closures' ? const Color(0xFF00338D) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedTab == 'road_closures' ? const Color(0xFF00338D) : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.traffic,
                    size: 16,
                    color: _selectedTab == 'road_closures' ? Colors.white : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Road Closures',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _selectedTab == 'road_closures' ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsCard(BuildContext context, Map<String, dynamic> item) {
    final id = item['id'] as String;
    final key = 'announcement_$id';
    final category = item['category'] as String? ?? 'news';
    final isRoadClosure = category == 'road_closure';

    final title = item['title'] as String? ?? 'Announcement';
    final body = item['body'] as String? ?? '';
    final imageUrl = item['image_url'] as String?;
    final sourceLabel = item['source_label'] as String? ?? 'EFP Media Desk';
    final badgeLabel = item['badge_label'] as String? ??
        (isRoadClosure ? 'TRAFFIC ALERT' : (category == 'warning' ? 'ADVISORY' : 'PRESS RELEASE'));
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                          isRoadClosure ? Icons.warning_rounded : Icons.info_rounded,
                          size: 16,
                          color: isRoadClosure ? const Color(0xFFF59E0B) : const Color(0xFF1E3A8A),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          badgeLabel,
                          style: TextStyle(
                            color: isRoadClosure ? const Color(0xFFF59E0B) : const Color(0xFF1E3A8A),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.45,
                  ),
                ),

                // Traffic details (Starts in 2 hrs | Detour active)
                if (isRoadClosure && (startTime != null || detourInfo != null)) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (startTime != null) ...[
                        const Icon(Icons.access_time, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          startTime,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 14),
                      ],
                      if (detourInfo != null) ...[
                        const Icon(Icons.map_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          detourInfo,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
                        border: Border.all(color: const Color(0xFF00338D).withOpacity(0.2)),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.shield, size: 14, color: Color(0xFF00338D)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$sourceLabel • Just now',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Like Button with count
                    InkWell(
                      onTap: () => _handleReaction(id, 'like'),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                              size: 18,
                              color: isLiked ? const Color(0xFF1E40AF) : const Color(0xFF475569),
                            ),
                            if (likeCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '$likeCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isLiked ? const Color(0xFF1E40AF) : const Color(0xFF475569),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              isDisliked ? Icons.thumb_down : Icons.thumb_down_alt_outlined,
                              size: 18,
                              color: isDisliked ? const Color(0xFFDC2626) : const Color(0xFF475569),
                            ),
                            if (dislikeCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '$dislikeCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDisliked ? const Color(0xFFDC2626) : const Color(0xFF475569),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              isCommentsExpanded ? Icons.chat_bubble : Icons.chat_bubble_outline,
                              size: 18,
                              color: isCommentsExpanded ? const Color(0xFF1E40AF) : const Color(0xFF475569),
                            ),
                            if (commentCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '$commentCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isCommentsExpanded ? const Color(0xFF1E40AF) : const Color(0xFF475569),
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
                        final r = await Share.share('$title\n\n$body\n\nShared via EthioShield');
                        await Api.recordShare('announcement', id, platform: Api.platformFromRaw(r.raw));
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Icon(Icons.share_outlined, size: 18, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 5. Expandable Comments Section
          if (isCommentsExpanded)
            _buildCommentSection(id),
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
                final isStaff = c['user_role'] != null && c['user_role'] != 'citizen';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isStaff ? const Color(0xFF1E3A8A) : Colors.grey.shade400,
                        child: Text(
                          author.isNotEmpty ? author[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                text,
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
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
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF1E40AF), size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
