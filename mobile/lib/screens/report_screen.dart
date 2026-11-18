import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../screens/report_detail_screen.dart';
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
  String _query = '';
  String _filter = 'all';

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
    final query = _query.trim().toLowerCase();
    final filtered = _mine.where((r) {
      final status = (r['status'] ?? '').toString();
      final matchesFilter = switch (_filter) {
        'draft' => status == 'draft',
        'active' => ['pending', 'submitted', 'under_review', 'assigned', 'in_progress'].contains(status),
        'resolved' => ['resolved', 'closed'].contains(status),
        _ => true,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      final title = (r['title'] ?? '').toString().toLowerCase();
      final category = (r['category'] ?? '').toString().toLowerCase();
      return title.contains(query) || category.contains(query) || status.contains(query);
    }).toList();
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
          TextField(
            decoration: InputDecoration(
              hintText: 'Search reports',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in const [
                  ('all', 'All'),
                  ('active', 'Active'),
                  ('resolved', 'Resolved'),
                  ('draft', 'Drafts'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(entry.$2),
                      selected: _filter == entry.$1,
                      onSelected: (_) => setState(() => _filter = entry.$1),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text(_mine.isEmpty ? loc.noReportsYet : 'No reports match this filter.', style: const TextStyle(color: Colors.grey)))),
          ...filtered.take(20).map((r) => Semantics(
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
                onTap: () {
                  final id = r['id']?.toString();
                  if (id != null && id.isNotEmpty) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportDetailScreen(id: id)));
                  }
                },
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
  DateTime _incidentAt = DateTime.now();
  bool _useManualLocation = false;
  final _manualAddress = TextEditingController();
  final _manualLat = TextEditingController();
  final _manualLng = TextEditingController();

  static const _categories = <({String value, String label})>[
    (value: 'theft', label: 'Theft'),
    (value: 'robbery', label: 'Robbery'),
    (value: 'assault', label: 'Assault'),
    (value: 'burglary', label: 'Burglary / break-in'),
    (value: 'vandalism', label: 'Vandalism'),
    (value: 'fraud', label: 'Fraud / scam'),
    (value: 'harassment', label: 'Harassment'),
    (value: 'drug', label: 'Drug offence'),
    (value: 'traffic', label: 'Traffic incident'),
    (value: 'domestic', label: 'Domestic violence'),
    (value: 'kidnapping', label: 'Kidnapping'),
    (value: 'murder', label: 'Murder / homicide'),
    (value: 'other', label: 'Other'),
  ];

  String _fmtDt(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit({bool draft = false}) async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _status = null; });
    try {
      Position? pos;
      try {
        if (_useManualLocation) {
          final lat = double.tryParse(_manualLat.text.trim());
          final lng = double.tryParse(_manualLng.text.trim());
          if (lat != null && lng != null) {
            pos = Position(
              latitude: lat,
              longitude: lng,
              timestamp: DateTime.now(),
              accuracy: 100,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            );
          }
        } else {
          pos = await LocationService.best();
        }
      } catch (_) {}
      final result = await Api.postOrQueue('/reports', {
        'category': _category,
        'severity': _severity,
        'status': draft ? 'draft' : 'pending',
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'incident_at': _incidentAt.toUtc().toIso8601String(),
        'latitude': pos?.latitude,
        'longitude': pos?.longitude,
        'address_text': _useManualLocation ? _manualAddress.text.trim() : null,
        'region': Api.region,
        'sub_city': Api.subCity,
        'is_anonymous': _anonymous,
        'evidence': _evidence,
      });
      setState(() => _status = result['queued'] == true
          ? 'You are offline. ${draft ? 'Draft' : 'Report'} saved and will be synced automatically when back online.'
          : (draft ? 'Draft saved. You can submit it later from My Reports.' : 'Report submitted. Thank you.'));
  _title.clear();
  _desc.clear();
  _manualAddress.clear();
  _manualLat.clear();
  _manualLng.clear();
  _evidence.clear();
      widget.onDone?.call();
      if (!mounted) return;
      final queued = result['queued'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(queued
            ? 'Saved offline. ${draft ? 'Your draft' : 'Your report'} will sync automatically when you are back online.'
            : (draft
                ? 'Draft saved. You can finish and submit it from My Reports.'
                : 'Report submitted successfully. Thank you for helping keep your community safe.')),
      ));
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _addEvidence(String type) async {
    final loc = AppLocalizations.of(context);
    if (type == 'Link') {
      final value = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(loc.addType(type)),
          content: TextField(
            controller: value,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: loc.url, hintText: 'https://', border: const OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, value.text.trim().isNotEmpty), child: Text(loc.add)),
          ],
        ),
      );
      if (ok == true) {
        setState(() => _evidence.add({'type': 'link', 'value': value.text.trim()}));
      }
      return;
    }

    if (type == 'Audio' || type == 'File') {
      try {
        final picked = await FilePicker.platform.pickFiles(
          type: type == 'Audio' ? FileType.audio : FileType.any,
        );
        final path = picked?.files.single.path;
        if (path != null) await _uploadEvidence(path, type.toLowerCase());
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.uploadFailed(e))));
      }
      return;
    }

    // Photo, Video and People of Determination sign-language video.
    final isVideo = type == 'Video' || type == 'Sign language';
    final source = type == 'Sign language' ? ImageSource.camera : await _pickSource();
    if (source == null) return;
    setState(() => _busy = true);
    try {
      final file = isVideo
          ? await ImagePicker().pickVideo(
              source: source,
              maxDuration: Duration(seconds: type == 'Sign language' ? 90 : 120),
            )
          : await ImagePicker().pickImage(
              source: source,
              maxWidth: 1600,
              imageQuality: 80,
            );
      if (file != null) {
        await _uploadEvidence(file.path, type == 'Sign language' ? 'sign_language_video' : type.toLowerCase());
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.uploadFailed(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadEvidence(String path, String type) async {
    final res = await Api.upload('/upload/single', [MapEntry('file', path)]);
    final url = Api.assetUrl(res['url']?.toString());
    if (url == null || url.isEmpty) {
      throw Exception('Upload did not return a file URL');
    }
    if (mounted) setState(() => _evidence.add({'type': type, 'value': url}));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${type.replaceAll('_', ' ')} attached.')));
    }
  }

  Future<ImageSource?> _pickSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo / record'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
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
                  label: 'Crime category dropdown. Currently set to $_category.',
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Crime category', border: OutlineInputBorder()),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c.value, child: Text(c.label)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v ?? 'other'),
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: 'Incident date and time picker. Currently set to ${_incidentAt.toLocal()}',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Incident date/time'),
                    subtitle: Text(_fmtDt(_incidentAt)),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _incidentAt, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
                      if (d == null || !context.mounted) return;
                      final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_incidentAt));
                      if (t == null || !context.mounted) return;
                      setState(() => _incidentAt = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enter location manually'),
                  subtitle: const Text('Otherwise use GPS'),
                  value: _useManualLocation,
                  onChanged: (v) => setState(() => _useManualLocation = v),
                ),
                if (_useManualLocation) ...[
                  const SizedBox(height: 8),
                  TextField(controller: _manualAddress, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(controller: _manualLat, decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _manualLng, decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true))),
                  ]),
                ],
                const SizedBox(height: 12),
                Semantics(
                  label: 'Severity dropdown. Currently set to $_severity.',
                  child: DropdownButtonFormField<String>(
                    initialValue: _severity,
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _submit(draft: true),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save as draft'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
