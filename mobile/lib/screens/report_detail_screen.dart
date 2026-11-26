import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zega_alert_mobile/models/models.dart';
import 'package:zega_alert_mobile/services/api.dart';

import '../l10n/app_localizations.dart';

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
    final loc = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Api.getReport(widget.id);
      setState(
        () => _report = Report.fromJson(Map<String, dynamic>.from(data)),
      );
    } catch (e) {
      setState(
        () =>
            _error = Api.userMessage(e, fallback: loc.reportDetailsLoadFailed),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  bool _busy = false;

  Future<void> _attachEvidence() async {
    final loc = AppLocalizations.of(context);
    final device = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: Text(loc.photoVideo),
              onTap: () => Navigator.pop(ctx, 'media'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(loc.documentAudio),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (device == null) return;
    String? path;
    String type = 'file';
    if (device == 'media') {
      final f = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
      path = f?.path;
      type = 'image';
    } else {
      final r = await FilePicker.platform.pickFiles(type: FileType.any);
      path = r?.files.single.path;
    }
    if (path == null) return;
    setState(() => _busy = true);
    try {
      final upload = await Api.upload('/upload/single', [
        MapEntry('file', path),
      ]);
      final url = upload['url'] as String?;
      if (url == null) throw 'Upload failed';
      await Api.post('/reports/${widget.id}/evidence', {
        'type': type,
        'value': Api.assetUrl(url),
      });
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.reportEvidenceAttached)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Api.userMessage(e, fallback: loc.reportEvidenceAttachFailed),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitDraft() async {
    final loc = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await Api.patch('/reports/${widget.id}', {'status': 'pending'});
      await _load();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.reportSubmittedForReview)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Api.userMessage(e, fallback: loc.reportSubmitFailed)),
          ),
        );
      }
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

  String _statusLabel(String? status, AppLocalizations loc) => switch (status) {
    'draft' => loc.reportFilterDrafts,
    'pending' => loc.reportStatusPending,
    'submitted' => loc.reportStatusSubmitted,
    'in_review' => loc.reportStatusInReview,
    'investigating' => loc.reportStatusInvestigating,
    'assigned' => loc.reportStatusAssigned,
    'resolved' => loc.reportFilterResolved,
    'rejected' => loc.reportStatusRejected,
    'closed' => loc.reportStatusClosed,
    _ => status?.replaceAll('_', ' ').toUpperCase() ?? '—',
  };

  String _categoryLabel(String category, AppLocalizations loc) =>
      switch (category) {
        'theft' => loc.crimeTheft,
        'robbery' => loc.crimeRobbery,
        'assault' => loc.crimeAssault,
        'burglary' => loc.crimeBurglary,
        'vandalism' => loc.crimeVandalism,
        'fraud' => loc.crimeFraud,
        'harassment' => loc.crimeHarassment,
        'drug' => loc.crimeDrug,
        'traffic' => loc.crimeTraffic,
        'domestic' => loc.crimeDomesticViolence,
        'kidnapping' => loc.crimeKidnapping,
        'murder' => loc.crimeMurder,
        'other' => loc.crimeOther,
        _ => category,
      };

  String _severityLabel(String severity, AppLocalizations loc) =>
      switch (severity) {
        'low' => loc.severityLow,
        'medium' => loc.severityMedium,
        'high' => loc.severityHigh,
        'critical' => loc.severityCritical,
        _ => severity,
      };

  String _evidenceLabel(String type, AppLocalizations loc) => switch (type) {
    'image' || 'photo' => loc.photo,
    'video' || 'sign_language_video' => loc.video,
    'audio' => loc.audio,
    'file' => loc.file,
    _ => type,
  };

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.reportDetailsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.blueGrey),
              ),
            )
          : _report == null
          ? Center(child: Text(loc.notAvailable))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  _report!.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(_categoryLabel(_report!.category, loc))),
                    Chip(
                      label: Text(_statusLabel(_report!.status, loc)),
                      backgroundColor: _statusColor(_report!.status)
                          .withValues(alpha: 0.15),
                    ),
                    Chip(label: Text(_severityLabel(_report!.severity, loc))),
                  ],
                ),
                const SizedBox(height: 12),
                if (_report!.description != null)
                  Text(
                    _report!.description!,
                    style: const TextStyle(fontSize: 15),
                  ),
                if (![
                  'resolved',
                  'closed',
                  'rejected',
                ].contains(_report!.status)) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_report!.status == 'draft')
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _submitDraft,
                            icon: const Icon(Icons.send_outlined),
                            label: Text(loc.submitReport),
                          ),
                        ),
                      if (_report!.status == 'draft') const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _attachEvidence,
                          icon: const Icon(Icons.attach_file),
                          label: Text(_busy ? loc.working : loc.attachEvidence),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.incidentDateTimeValue(_fmt(_report!.incidentAt)),
                        ),
                        Text(loc.reportedValue(_fmt(_report!.reportedAt))),
                        if (_report!.resolvedAt != null)
                          Text(loc.resolvedValue(_fmt(_report!.resolvedAt))),
                        if (_report!.latitude != null &&
                            _report!.longitude != null)
                          Text(
                            loc.locationCoordinates(
                              _report!.latitude!.toStringAsFixed(5),
                              _report!.longitude!.toStringAsFixed(5),
                            ),
                          ),
                        if (_report!.addressText != null)
                          Text('${loc.addressLabel}: ${_report!.addressText}'),
                        if (_report!.region != null)
                          Text('${loc.region}: ${_report!.region}'),
                        if (_report!.subCity != null)
                          Text('${loc.subCity}: ${_report!.subCity}'),
                        Text(
                          loc.anonymousValue(
                            _report!.isAnonymous ? loc.yes : loc.no,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_report!.evidence.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    loc.evidenceTitle,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ..._report!.evidence.map(
                    (e) => Card(
                      child: ListTile(
                        dense: true,
                        title: Text(
                          _evidenceLabel(e['type']?.toString() ?? '', loc),
                        ),
                        subtitle: Text(e['value'] ?? ''),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  loc.statusHistoryTitle,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                if (_report!.history.isEmpty)
                  Text(loc.noHistoryYet, style: TextStyle(color: Colors.grey))
                else
                  ..._report!.history.map(
                    (h) => Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.history,
                          color: _statusColor(h.status ?? ''),
                        ),
                        title: Text(_statusLabel(h.status, loc)),
                        subtitle: Text(
                          '${_fmt(h.changedAt)}${h.changedBy != null ? ' · ${loc.byUser(h.changedBy!)}' : ''}${h.notes != null && h.notes!.isNotEmpty ? '\n${h.notes}' : ''}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
