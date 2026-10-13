import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../widgets/photo_upload.dart';

class MissingReportScreen extends StatefulWidget {
  const MissingReportScreen({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  State<MissingReportScreen> createState() => _MissingReportScreenState();
}

class _MissingReportScreenState extends State<MissingReportScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _desc = TextEditingController();
  final _address = TextEditingController();
  String _gender = 'Unknown';
  String? _photoUrl;
  DateTime? _lastSeenAt;
  bool _busy = false;
  String? _status;

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context);
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _status = null; });
    try {
      Position? pos;
      try { pos = await Geolocator.getCurrentPosition(); } catch (_) {}
      final result = await Api.postOrQueue('/persons/missing', {
        'name': _name.text.trim(),
        'age': int.tryParse(_age.text),
        'gender': _gender,
        'photo_url': _photoUrl,
        'description': _desc.text.trim(),
        'last_seen_address': _address.text.trim(),
        'last_seen_lat': pos?.latitude,
        'last_seen_lng': pos?.longitude,
        'last_seen_at': _lastSeenAt?.toIso8601String(),
        'region': Api.region,
        'sub_city': Api.subCity,
      });
      setState(() => _status = result['queued'] == true
          ? 'You are offline. Report saved and will be submitted automatically when back online.'
          : '${loc.missingPersonReportSubmitted} Pending Regional Admin approval before it is published publicly.');
      _name.clear();
      _age.clear();
      _desc.clear();
      _address.clear();
      _photoUrl = null;
      _lastSeenAt = null;
      widget.onDone?.call();
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _pickLastSeen() async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 3650)), lastDate: DateTime.now());
    if (picked == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() => _lastSeenAt = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.reportAMissingPerson)),
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
                TextFormField(controller: _name, decoration: InputDecoration(labelText: loc.fullNameMissingPerson, border: const OutlineInputBorder()), validator: (v) => v == null || v.isEmpty ? loc.required : null),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _age, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: loc.ageOptional, border: const OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: InputDecoration(labelText: loc.gender, border: const OutlineInputBorder()),
                        items: [DropdownMenuItem(value: 'Male', child: Text(loc.male)), DropdownMenuItem(value: 'Female', child: Text(loc.female)), DropdownMenuItem(value: 'Unknown', child: Text(loc.unknown))],
                        onChanged: (v) => setState(() => _gender = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _address, decoration: InputDecoration(labelText: loc.lastSeenLocation, border: const OutlineInputBorder())),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickLastSeen,
                  icon: const Icon(Icons.schedule),
                  label: Text(_lastSeenAt == null ? loc.lastSeenDateTime : loc.lastSeenPrefix(_lastSeenAt!.toLocal())),
                ),
                const SizedBox(height: 12),
                PhotoUploadField(label: loc.photoOfPerson, onUploaded: (url) => setState(() => _photoUrl = url)),
                const SizedBox(height: 12),
                TextFormField(controller: _desc, maxLines: 4, decoration: InputDecoration(labelText: loc.descriptionIdentifying, border: const OutlineInputBorder())),
                const SizedBox(height: 16),
                FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? loc.submitting : loc.submitReport)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SightingReportScreen extends StatefulWidget {
  const SightingReportScreen({super.key, this.onDone, this.title, this.missingPersonId, this.wantedPersonId});

  final VoidCallback? onDone;
  final String? title;
  final String? missingPersonId;
  final String? wantedPersonId;

  @override
  State<SightingReportScreen> createState() => _SightingReportScreenState();
}

class _SightingReportScreenState extends State<SightingReportScreen> {
  final _form = GlobalKey<FormState>();
  final _desc = TextEditingController();
  final _address = TextEditingController();
  String? _photoUrl;
  DateTime? _seenAt;
  bool _busy = false;
  String? _status;

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context);
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _status = null; });
    try {
      Position? pos;
      try { pos = await Geolocator.getCurrentPosition(); } catch (_) {}
      await Api.post('/persons/sightings', {
        'missing_person_id': widget.missingPersonId,
        'wanted_person_id': widget.wantedPersonId,
        'latitude': pos?.latitude,
        'longitude': pos?.longitude,
        'address_text': _address.text.trim(),
        'description': _desc.text.trim(),
        'photo_url': _photoUrl,
        'seen_at': _seenAt?.toIso8601String(),
      });
      setState(() => _status = loc.sightingReported);
      _desc.clear();
      _address.clear();
      _photoUrl = null;
      _seenAt = null;
      widget.onDone?.call();
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _pickSeen() async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now());
    if (picked == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() => _seenAt = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? loc.reportSighting)),
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
                TextFormField(controller: _address, decoration: InputDecoration(labelText: loc.whereSeen, border: const OutlineInputBorder())),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickSeen,
                  icon: const Icon(Icons.schedule),
                  label: Text(_seenAt == null ? loc.whenOptional : loc.seenAt(_seenAt!.toLocal())),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _desc, maxLines: 3, decoration: InputDecoration(labelText: loc.descriptionOptional, border: const OutlineInputBorder())),
                const SizedBox(height: 12),
                PhotoUploadField(label: loc.photoOfSighting, onUploaded: (url) => setState(() => _photoUrl = url)),
                const SizedBox(height: 16),
                FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? loc.submitting : loc.submitSighting)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
