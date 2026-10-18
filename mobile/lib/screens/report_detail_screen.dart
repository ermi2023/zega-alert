import 'package:flutter/material.dart';
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
                          Chip(label: Text(_report!.status.toUpperCase()), backgroundColor: _statusColor(_report!.status).withOpacity(0.15)),
                          Chip(label: Text(_report!.severity)),
                        ]),
                        const SizedBox(height: 12),
                        if (_report!.description != null) Text(_report!.description!, style: const TextStyle(fontSize: 15)),
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
                                  title: Text('${h.status ?? '—'}'.toUpperCase()),
                                  subtitle: Text('${_fmt(h.changedAt)}${h.changedBy != null ? ' · by ${h.changedBy}' : ''}${h.notes != null && h.notes!.isNotEmpty ? '\n${h.notes}' : ''}'),
                                  isThreeLine: true,
                                ),
                              )),
                      ],
                    ),
    );
  }
}
