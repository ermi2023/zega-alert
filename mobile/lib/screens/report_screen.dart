import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';


class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<dynamic> _mine = [];
  String? _loadError;
  bool _loading = true;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; _offline = false; });
    try {
      final mine = await Api.get('/reports/mine');
      await DatabaseService.cacheList('reports', mine);
      setState(() => _mine = mine);
    } catch (e) {
      final mine = await DatabaseService.getCachedList('reports');
      if (mine.isNotEmpty) {
        setState(() {
          _mine = mine;
          _offline = true;
        });
      } else {
        setState(() => _loadError = 'Failed to load reports: $e');
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openSubmission() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CrimeReportScreen(onDone: _load)));
  }

  Future<void> _rate(dynamic r) async {
    final loc = AppLocalizations.of(context);
    final comment = TextEditingController();
    int rating = 5;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(loc.rateResponse),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  onPressed: () => setLocal(() => rating = i + 1),
                  icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
                )),
              ),
              TextField(controller: comment, maxLines: 2, decoration: InputDecoration(labelText: loc.commentOptional, border: const OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(loc.submitReport)),
          ],
        ),
      ),
    );
    if (submitted != true) return;
    try {
      await Api.post('/feedback/${r['id']}/feedback', {
        'rating': rating,
        'comment': comment.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.thanksFeedback)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  String _statusLabel(String s) => s.replaceAll('_', ' ').toUpperCase();

  Color _statusColor(String s) => switch (s) {
    'resolved' => Colors.green,
    'rejected' => Colors.red,
    'closed' => Colors.grey,
    _ => Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(loc.reportACrime, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(loc.yourReportGoesTo, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: 'New crime report button. Double tap to open the crime report form.',
            child: SizedBox(
              height: 84,
              child: FilledButton.icon(
                onPressed: _openSubmission,
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                icon: const Icon(Icons.edit_note, size: 30, color: Colors.white),
                label: Text(loc.newCrimeReport, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
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
          if (_loadError != null) Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [const Icon(Icons.error_outline, color: Colors.red), const SizedBox(width: 8), Expanded(child: Text(_loadError!, style: const TextStyle(color: Colors.red)))]))),
          if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          Text(loc.myReports, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_mine.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text(loc.noReportsYet, style: const TextStyle(color: Colors.grey)))),
          ..._mine.take(10).map((r) => Semantics(
            label: 'Report: ${r['title'] ?? 'Untitled'}. Category: ${r['category'] ?? 'unknown'}. Status: ${_statusLabel(r['status'] ?? '')}.',
            child: Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.assignment_outlined, color: _statusColor(r['status'] ?? '')),
                    title: Text(r['title'] ?? 'Untitled'),
                    subtitle: Text('${r['category'] ?? ''} · ${_shortDate(r['reported_at'])}'),
                    trailing: Text(_statusLabel(r['status'] ?? ''), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _statusColor(r['status'] ?? ''))),
                  ),
                  if (r['status'] == 'resolved')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Semantics(
                          button: true,
                          label: 'Rate response for report: ${r['title'] ?? "Untitled"}',
                          child: TextButton.icon(
                            onPressed: () => _rate(r),
                            icon: const Icon(Icons.star_outline, size: 18),
                            label: Text(loc.rateThisResponse),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  String _shortDate(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class CrimeReportScreen extends StatefulWidget {
  const CrimeReportScreen({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  State<CrimeReportScreen> createState() => _CrimeReportScreenState();
}

class _CrimeReportScreenState extends State<CrimeReportScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _category = 'theft';
  String _severity = 'medium';
  bool _anonymous = false;
  bool _busy = false;
  String? _status;
  final List<Map<String, String>> _evidence = [];

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _status = null; });
    try {
      Position? pos;
      try { pos = await LocationService.best(); } catch (_) {}
      final result = await Api.postOrQueue('/reports', {
        'category': _category,
        'severity': _severity,
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'latitude': pos?.latitude,
        'longitude': pos?.longitude,
        'region': Api.region,
        'sub_city': Api.subCity,
        'is_anonymous': _anonymous,
        'evidence': _evidence,
      });
      setState(() => _status = result['queued'] == true
          ? 'You are offline. Report saved and will be submitted automatically when back online.'
          : 'Report submitted. Thank you.');
      _title.clear();
      _desc.clear();
      _evidence.clear();
      widget.onDone?.call();
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _addEvidence(String type) async {
    final loc = AppLocalizations.of(context);
    if (type == 'Photo') {
      setState(() => _busy = true);
      try {
        final file = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80);
        if (file != null) {
          final res = await Api.upload('/upload/single', [MapEntry('file', file.path)]);
          setState(() => _evidence.add({'type': 'image', 'value': '${Api.baseUrl}${res['url']}'}));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.uploadFailed(e))));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    // People of Determination: record a sign-language video instead of a text description (doc 4.3.2).
    if (type == 'Sign language') {
      setState(() => _busy = true);
      try {
        final file = await ImagePicker().pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 90));
        if (file != null) {
          final res = await Api.upload('/upload/single', [MapEntry('file', file.path)]);
          setState(() => _evidence.add({'type': 'sign_language_video', 'value': '${Api.baseUrl}${res['url']}'}));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.uploadFailed(e))));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    final value = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.addType(type)),
        content: TextField(controller: value, decoration: InputDecoration(labelText: type == 'Link' ? loc.url : loc.filePathNote, border: const OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, value.text.trim().isNotEmpty), child: Text(loc.add)),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _evidence.add({'type': type.toLowerCase(), 'value': value.text.trim()}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.newCrimeReport)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_status != null) Card(color: _status!.startsWith('Failed') ? Colors.red.shade50 : Colors.green.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Text(_status!, style: TextStyle(color: _status!.startsWith('Failed') ? Colors.red : Colors.green)))),
          const SizedBox(height: 8),
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label: 'Title input. Required.',
                  child: TextFormField(controller: _title, decoration: InputDecoration(labelText: loc.title, border: const OutlineInputBorder()), validator: (v) => v == null || v.isEmpty ? loc.required : null),
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: 'Description input. Required.',
                  child: TextFormField(controller: _desc, maxLines: 4, decoration: InputDecoration(labelText: loc.description, border: const OutlineInputBorder()), validator: (v) => v == null || v.isEmpty ? loc.required : null),
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: 'Category dropdown. Currently set to $_category.',
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    decoration: InputDecoration(labelText: loc.category, border: const OutlineInputBorder()),
                    items: ['theft', 'assault', 'fraud', 'property', 'drug', 'traffic', 'suspicious_activity', 'other'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: 'Severity dropdown. Currently set to $_severity.',
                  child: DropdownButtonFormField<String>(
                    value: _severity,
                    decoration: InputDecoration(labelText: loc.severity, border: const OutlineInputBorder()),
                    items: ['low', 'medium', 'high', 'critical'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _severity = v!),
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: 'Report anonymously toggle. ${_anonymous ? "Currently on" : "Currently off"}',
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(loc.reportAnonymously),
                    value: _anonymous,
                    onChanged: (v) => setState(() => _anonymous = v),
                  ),
                ),
                const SizedBox(height: 8),
                Text(loc.evidenceOptional, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(avatar: const Icon(Icons.photo_camera_outlined, size: 18), label: const Text('Photo'), onPressed: () => _addEvidence('Photo')),
                    ActionChip(avatar: const Icon(Icons.videocam_outlined, size: 18), label: const Text('Video'), onPressed: () => _addEvidence('Video')),
                    ActionChip(avatar: const Icon(Icons.mic_none, size: 18), label: const Text('Audio'), onPressed: () => _addEvidence('Audio')),
                    ActionChip(avatar: const Icon(Icons.sign_language, size: 18), label: const Text('Sign language'), onPressed: () => _addEvidence('Sign language')),
                    ActionChip(avatar: const Icon(Icons.link, size: 18), label: const Text('Link'), onPressed: () => _addEvidence('Link')),
                    ActionChip(avatar: const Icon(Icons.attach_file, size: 18), label: const Text('File'), onPressed: () => _addEvidence('File')),
                  ],
                ),
                if (_evidence.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._evidence.map((e) => Card(
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.cloud_upload_outlined),
                      title: Text('${e['type']}'),
                      subtitle: Text(e['value'] ?? ''),
                      trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _evidence.remove(e))),
                    ),
                  )),
                ],
                const SizedBox(height: 16),
                Semantics(
                  button: true,
                  label: _busy ? 'Submitting report' : 'Submit report. Double tap to send your crime report.',
                  child: FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? loc.submitting : loc.submitReport)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
