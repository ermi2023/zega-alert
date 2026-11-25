import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zega_alert_mobile/models/models.dart';
import 'package:zega_alert_mobile/services/api.dart';

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key, required this.id});
  final String id;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  Report? _report;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await Api.getReport(widget.id);
      setState(() => _report = Report.fromJson(Map<String, dynamic>.from(data)));
    } catch (e) {
      setState(() => _error = 'Failed to load report: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  bool _busy = false;

  Future<void> _attachEvidence() async {
    final device = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo), title: const Text('Photo / video'), onTap: () => Navigator.pop(ctx, 'media')),
          ListTile(leading: const Icon(Icons.attach_file), title: const Text('Document / audio'), onTap: () => Navigator.pop(ctx, 'file')),
        ]),
      ),
    );
    if (device == null) return;
    String? path;
    String type = 'file';
    if (device == 'media') {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
      path = f?.path;
      type = 'image';
    } else {
      final r = await FilePicker.platform.pickFiles(type: FileType.any);
      path = r?.files.single.path;
    }
    if (path == null) return;
    setState(() => _busy = true);
    try {
      final upload = await Api.upload('/upload/single', [MapEntry('file', path)]);
      final url = upload['url'] as String?;
      if (url == null) throw 'Upload failed';
      await Api.post('/reports/${widget.id}/evidence', {'type': type, 'value': Api.assetUrl(url)});
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evidence attached.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not attach evidence: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitDraft() async {
    setState(() => _busy = true);
    try {
      await Api.patch('/reports/${widget.id}', {'status': 'pending'});
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted for review.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmt(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String s) => switch (s) {
    'resolved' => Colors.green,
    'rejected' => Colors.red,
    'closed' => Colors.grey,
    _ => Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _report == null
                  ? const Center(child: Text('No data'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(_report!.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          Chip(label: Text(_report!.category)),
                          Chip(label: Text(_report!.status.toUpperCase()), backgroundColor: _statusColor(_report!.status).withValues(alpha: 0.15)),
                          Chip(label: Text(_report!.severity)),
                        ]),
                        const SizedBox(height: 12),
                        if (_report!.description != null) Text(_report!.description!, style: const TextStyle(fontSize: 15)),
                        if (!['resolved', 'closed', 'rejected'].contains(_report!.status)) ...[
                          const SizedBox(height: 12),
                          Row(children: [
                            if (_report!.status == 'draft')
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _busy ? null : _submitDraft,
                                  icon: const Icon(Icons.send_outlined),
                                  label: const Text('Submit report'),
                                ),
                              ),
                            if (_report!.status == 'draft') const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _attachEvidence,
                                icon: const Icon(Icons.attach_file),
                                label: Text(_busy ? 'Working…' : 'Attach evidence'),
                              ),
                            ),
                          ]),
                        ],
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Incident date/time: ${_fmt(_report!.incidentAt)}'),
                                Text('Reported: ${_fmt(_report!.reportedAt)}'),
                                if (_report!.resolvedAt != null) Text('Resolved: ${_fmt(_report!.resolvedAt)}'),
                                if (_report!.latitude != null && _report!.longitude != null)
                                  Text('Location: ${_report!.latitude!.toStringAsFixed(5)}, ${_report!.longitude!.toStringAsFixed(5)}'),
                                if (_report!.addressText != null) Text('Address: ${_report!.addressText}'),
                                if (_report!.region != null) Text('Region: ${_report!.region}'),
                                if (_report!.subCity != null) Text('Sub-city: ${_report!.subCity}'),
                                Text('Anonymous: ${_report!.isAnonymous}'),
                              ],
                            ),
                          ),
                        ),
                        if (_report!.evidence.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('Evidence', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          ..._report!.evidence.map((e) => Card(child: ListTile(dense: true, title: Text('${e['type']}'), subtitle: Text(e['value'] ?? '')))),
                        ],
                        const SizedBox(height: 16),
                        const Text('Status history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        if (_report!.history.isEmpty)
                          const Text('No history yet.', style: TextStyle(color: Colors.grey))
                        else
                          ..._report!.history.map((h) => Card(
                                child: ListTile(
                                  leading: Icon(Icons.history, color: _statusColor(h.status ?? '')),
                                  title: Text((h.status ?? '—').toUpperCase()),
                                  subtitle: Text('${_fmt(h.changedAt)}${h.changedBy != null ? ' · by ${h.changedBy}' : ''}${h.notes != null && h.notes!.isNotEmpty ? '\n${h.notes}' : ''}'),
                                  isThreeLine: true,
                                ),
                              )),
                      ],
                    ),
    );
  }
}
