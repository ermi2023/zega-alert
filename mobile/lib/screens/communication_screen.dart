import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../screens/video_call_screen.dart';
import '../services/api.dart';
import '../services/socket_service.dart';
import '../services/webrtc_service.dart';

class CommunicationScreen extends StatefulWidget {
  const CommunicationScreen({super.key});

  @override
  State<CommunicationScreen> createState() => _CommunicationScreenState();
}

class _CommunicationScreenState extends State<CommunicationScreen> {
  List<dynamic> _conversations = [];
  List<dynamic> _messages = [];
  String? _active;
  final _input = TextEditingController();
  bool _sending = false;
  String? _pendingAttachment;
  String? _pendingType;

  String? _loadError;
  int? _waitMinutes;

  Future<void> _loadWait() async {
    try {
      final d = await Api.get('/chat/wait-time');
      if (mounted) setState(() => _waitMinutes = d['estimated_wait_minutes']);
    } catch (_) {}
  }

  Future<void> _loadConversations() async {
    try {
      final data = await Api.get('/chat/conversations');
      setState(() { _conversations = data; _loadError = null; });
      if (data.isNotEmpty && _active == null) _open(data.first['id'] as String);
    } catch (e) {
      setState(() => _loadError = 'Failed to load conversations: $e');
    }
    _loadWait();
  }

  Future<void> _open(String id) async {
    setState(() => _active = id);
    SocketService.joinConversation(id);
    final data = await Api.get('/chat/conversations/$id/messages');
    if (mounted && _active == id) setState(() => _messages = data);
  }

  Future<void> _pickAttachment(String kind) async {
    String? path;
    String type = kind;
    try {
      if (kind == 'Photo') {
        final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
        path = f?.path;
        type = 'image';
      } else if (kind == 'Video') {
        final f = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 2));
        path = f?.path;
        type = 'video';
      } else {
        final r = await FilePicker.platform.pickFiles(type: FileType.any);
        path = r?.files.single.path;
        type = 'file';
        if (kind == 'Audio') type = 'audio';
      }
    } catch (_) {}
    if (path == null) return;
    setState(() => _sending = true);
    try {
      final res = await Api.upload('/upload/single', [MapEntry('file', path)]);
      final url = res['url'] as String?;
      if (url != null) {
        setState(() {
          _pendingAttachment = '${Api.baseUrl}$url';
          _pendingType = type;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _send() async {
    if ((_input.text.trim().isEmpty && _pendingAttachment == null) || _active == null) return;
    final body = <String, dynamic>{
      'body': _input.text.trim(),
      if (_pendingAttachment != null) 'attachment_url': _pendingAttachment,
      if (_pendingAttachment != null) 'attachment_type': _pendingType,
      'message_type': _pendingAttachment != null ? 'attachment' : 'text',
    };
    final msg = await Api.post('/chat/conversations/$_active/messages', body);
    final exists = _messages.any((m) => m['id'] == msg['id']);
    if (!exists) {
      setState(() { _messages.add(msg); _input.clear(); _pendingAttachment = null; _pendingType = null; });
    } else {
      setState(() { _input.clear(); _pendingAttachment = null; _pendingType = null; });
    }
  }

  void _onSocketMessage(dynamic raw) {
    if (raw is! Map) return;
    final msg = Map<String, dynamic>.from(raw);
    final exists = _messages.any((m) => m['id'] == msg['id']);
    if (exists) return;
    if (msg['conversation_id'] == _active) {
      if (mounted) setState(() => _messages.add(msg));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('New message: ${msg['body'] ?? ''}'),
          duration: const Duration(seconds: 3),
        ));
      }
      _loadConversations();
    }
  }

  Future<void> _newChat() async {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.contactStaff),
        content: TextField(controller: controller, decoration: InputDecoration(hintText: loc.staffPhoneHint), keyboardType: TextInputType.phone),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(loc.startChat))],
      ),
    );
    if (phone == null || phone.isEmpty) return;
    final users = await Api.get('/auth/staff?q=$phone');
    if (users.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.userNotFound))); return; }
    final conv = await Api.post('/chat/conversations', {'participant_ids': [users.first['id']]});
    _loadConversations();
    _open(conv['id'] as String);
  }

  Future<void> _rateChat() async {
    if (_active == null) return;
    int rating = 5;
    final comment = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Rate this conversation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  onPressed: () => setLocal(() => rating = i + 1),
                  icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber),
                )),
              ),
              TextField(controller: comment, maxLines: 2, decoration: const InputDecoration(labelText: 'Comment (optional)', border: OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await Api.post('/chat/conversations/$_active/rating', {'rating': rating, 'comment': comment.text.trim()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for your feedback')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _startVideoCall() async {
    if (_active == null) return;
    final conv = _conversations.firstWhere((c) => c['id'] == _active, orElse: () => null);
    if (conv == null) return;
    final participants = (conv['participant_ids'] as List<dynamic>?) ?? [];
    final other = participants.firstWhere((p) => p != Api.userId, orElse: () => null);
    if (other == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No other participant to call')));
      return;
    }
    try {
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => VideoCallScreen(
          targetUserId: other.toString(),
          targetName: conv['title'] ?? 'Officer',
          callType: 'video',
        )));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Call failed: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    SocketService.onChatMessage = _onSocketMessage;
    _loadConversations();
  }

  @override
  void dispose() {
    if (SocketService.onChatMessage == _onSocketMessage) {
      SocketService.onChatMessage = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Column(
      children: [
        if (_loadError != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(10), child: Text(_loadError!, style: const TextStyle(color: Colors.red))))),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(loc.messages, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  if (_active != null) IconButton(onPressed: _rateChat, icon: const Icon(Icons.star_border), tooltip: 'Rate this conversation'),
                  if (_active != null) IconButton(onPressed: _startVideoCall, icon: const Icon(Icons.videocam), tooltip: 'Video call'),
                  IconButton(onPressed: _newChat, icon: const Icon(Icons.add_circle), tooltip: loc.newChat),
                ],
              ),
            ],
          ),
        ),
        if (_waitMinutes != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(_waitMinutes! <= 0 ? 'A dispatcher is available now' : 'Estimated wait: $_waitMinutes min',
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _conversations.map((c) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c['title'] ?? loc.messages),
                selected: _active == c['id'],
                onSelected: (_) => _open(c['id'] as String),
              ),
            )).toList(),
          ),
        ),
        Expanded(
          child: _active == null
              ? Center(child: Text(loc.noConversations))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final m = _messages[i];
                          final mine = m['sender_id'] == Api.userId;
                          final att = m['attachment_url'] as String?;
                          final attType = m['attachment_type'] as String? ?? m['message_type'] as String?;
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Card(
                              color: mine ? Colors.green.shade100 : Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (att != null && att.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: attType == 'image'
                                            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(att, width: 200, fit: BoxFit.cover))
                                            : Row(children: [const Icon(Icons.attach_file, size: 18), const SizedBox(width: 6), Expanded(child: Text(att.split('/').last, overflow: TextOverflow.ellipsis))]),
                                      ),
                                    if ((m['body'] ?? '').toString().isNotEmpty) Text(m['body'] ?? ''),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_pendingAttachment != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(_pendingType == 'image' ? Icons.image : Icons.attach_file, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(_pendingAttachment!.split('/').last, overflow: TextOverflow.ellipsis)),
                                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() { _pendingAttachment = null; _pendingType = null; })),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.attach_file),
                                onSelected: _pickAttachment,
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'Photo', child: Text('Photo')),
                                  PopupMenuItem(value: 'Video', child: Text('Video')),
                                  PopupMenuItem(value: 'Audio', child: Text('Audio')),
                                  PopupMenuItem(value: 'File', child: Text('File')),
                                ],
                              ),
                              Expanded(child: TextField(controller: _input, decoration: InputDecoration(hintText: loc.typeMessage, border: const OutlineInputBorder()), onSubmitted: (_) => _send())),
                              const SizedBox(width: 8),
                              FilledButton(onPressed: _sending ? null : _send, child: Text(loc.send)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
