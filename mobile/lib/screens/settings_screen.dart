import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'auth_screen.dart';
import 'id_verification_screen.dart';
import '../services/api.dart';
import '../widgets/auth_gate.dart';
import 'callbacks_screen.dart';
import '../config/constants.dart';

const _languages = [
  (code: 'en', label: 'English'),
  (code: 'am', label: 'አማርኛ (Amharic)'),
  (code: 'om', label: 'Afaan Oromoo (Oromifa)'),
  (code: 'ti', label: 'ትግርኛ (Tigrigna)'),
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _accessibility = false;
  String _language = 'en';
  String _region = 'Addis Ababa';
  String _subCity = 'Arada';
  bool _darkMode = false;
  String? _status;

  List<dynamic> _geofences = [];
  List<dynamic> _legal = [];

  String? _loadError;

  bool get _loggedIn => Api.isLoggedIn;

  Future<void> _load() async {
    try {
      _geofences = [];
      final legal = await Api.get('/legal');
      _legal = legal as List<dynamic>;
      if (_loggedIn) {
        final me = await Api.get('/auth/me') as Map<String, dynamic>;
        _name.text = me['full_name'] ?? '';
        _accessibility = me['accessibility_mode'] ?? false;
        _language = me['preferred_language'] ?? 'en';
        _region = me['region'] ?? 'Addis Ababa';
        _subCity = me['sub_city'] ?? (subCitiesByRegion[_region]?.first ?? '');
        await Api.setProfile(me);
        _geofences = await Api.get('/geofences') as List<dynamic>;
        if (mounted) ZegaAlertApp.of(context)?.setLanguage(_language);
      }
      if (mounted) setState(() => _loadError = null);
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Failed to load settings: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _save() async {
    try {
      await Api.put('/auth/me', {
        'full_name': _name.text.trim(),
        'accessibility_mode': _accessibility,
        'preferred_language': _language,
        'region': _region,
        'sub_city': _subCity,
      });
      await Api.setProfile({'region': _region, 'sub_city': _subCity});
      ZegaAlertApp.of(context)?.setLanguage(_language);
      setState(() => _status = 'Saved.');
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    }
  }

  Future<void> _addGeofence() async {
    final loc = AppLocalizations.of(context);
    final name = TextEditingController();
    final radius = TextEditingController();
    final lat = TextEditingController();
    final lng = TextEditingController();
    String type = 'zone';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.newSafetyZone),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: InputDecoration(labelText: loc.name, border: const OutlineInputBorder())),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: type,
              decoration: InputDecoration(labelText: loc.type, border: const OutlineInputBorder()),
              items: ['zone', 'school', 'police_station', 'hospital', 'event'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => type = v!,
            ),
            const SizedBox(height: 10),
            TextField(controller: lat, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: loc.centerLatitude, border: const OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: lng, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: loc.centerLongitude, border: const OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: radius, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: loc.radiusMeters, border: const OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(loc.create)),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await Api.post('/geofences', {
        'name': name.text.trim(),
        'type': type,
        'center_lat': lat.text.isEmpty ? null : double.tryParse(lat.text),
        'center_lng': lng.text.isEmpty ? null : double.tryParse(lng.text),
        'radius_m': radius.text.isEmpty ? null : int.tryParse(radius.text),
        'region': Api.region,
      });
      _load();
      setState(() => _status = loc.safetyZoneCreated);
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    }
  }

  Future<void> _deleteGeofence(String id) async {
    try {
      await Api.delete('/geofences/$id');
      final loc = AppLocalizations.of(context);
      setState(() => _status = loc.safetyZoneDeleted);
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    }
    _load();
  }

  Future<void> _logout() async {
    try {
      await Api.post('/auth/logout', {'refreshToken': Api.refreshToken});
    } catch (_) {
      // Offline or already-expired session — clear locally regardless.
    }
    await Api.clear();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(loc.settingsTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(loc.settingsSubtitle, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        if (_status != null) Card(color: _status!.startsWith('Failed') ? Colors.red.shade50 : Colors.green.shade50, child: Padding(padding: const EdgeInsets.all(10), child: Text(_status!, style: TextStyle(color: _status!.startsWith('Failed') ? Colors.red : Colors.green)))),
        if (_loadError != null) Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [const Icon(Icons.error_outline, color: Colors.red), const SizedBox(width: 8), Expanded(child: Text(_loadError!, style: const TextStyle(color: Colors.red)))]))),
        const SizedBox(height: 4),

        if (!_loggedIn) _guestBanner(loc),
        if (_loggedIn) ...[
          _section(loc.account, Icons.person_outline),
          Semantics(
            label: 'Full name input',
            child: Form(
              key: _form,
              child: TextFormField(controller: _name, decoration: InputDecoration(labelText: loc.fullName, border: const OutlineInputBorder())),
            ),
          ),
          const SizedBox(height: 16),

          _section(loc.locationLabel, Icons.location_on_outlined),
          Semantics(
            label: 'Region dropdown. Currently set to $_region.',
            child: DropdownButtonFormField<String>(
              value: ethiopianRegions.contains(_region) ? _region : null,
              decoration: InputDecoration(labelText: loc.regionLabel, border: const OutlineInputBorder()),
              items: ethiopianRegions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) {
                if (v != null) setState(() {
                  _region = v;
                  _subCity = subCitiesByRegion[v]?.first ?? '';
                });
              },
            ),
          ),
          if ((subCitiesByRegion[_region] ?? []).isNotEmpty) ...[
            const SizedBox(height: 12),
            Semantics(
              label: 'Sub city dropdown. Currently set to $_subCity.',
              child: DropdownButtonFormField<String>(
                value: (subCitiesByRegion[_region] ?? const []).contains(_subCity) ? _subCity : null,
                decoration: InputDecoration(labelText: loc.subCityLabel, border: const OutlineInputBorder()),
                items: subCitiesByRegion[_region]!.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _subCity = v ?? ''),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],

        _section(loc.languageLabel, Icons.language),
        Semantics(
          label: 'Preferred language dropdown. Currently set to $_language.',
          child: DropdownButtonFormField<String>(
            value: _language,
            decoration: InputDecoration(labelText: loc.preferredLanguage, border: const OutlineInputBorder()),
            items: _languages.map((l) => DropdownMenuItem(value: l.code, child: Text(l.label))).toList(),
            onChanged: (v) => setState(() => _language = v!),
          ),
        ),
        const SizedBox(height: 16),

        if (_loggedIn) ...[
          _section(loc.safetyZones, Icons.location_on_outlined),
          ..._geofences.map((g) => Semantics(
            label: 'Safety zone: ${g['name'] ?? 'Zone'}. Type: ${g['type'] ?? 'zone'}. Radius: ${g['radius_m'] != null ? '${g['radius_m']} meters' : 'not set'}.',
            child: Card(
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.radar, color: Colors.green),
                title: Text(g['name'] ?? 'Zone'),
                subtitle: Text('${g['type'] ?? 'zone'} · ${g['radius_m'] != null ? '${g['radius_m']}m' : 'radius not set'}'),
                trailing: Semantics(
                  button: true,
                  label: 'Delete safety zone: ${g['name'] ?? 'Zone'}',
                  child: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteGeofence(g['id'] as String)),
                ),
              ),
            ),
          )),
          Semantics(
            button: true,
            label: 'Add safety zone',
            child: OutlinedButton.icon(
              onPressed: _addGeofence,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(loc.addSafetyZone),
            ),
          ),
          const SizedBox(height: 16),
        ],

        _section(loc.legalInformation, Icons.gavel),
        ..._legal.take(5).map((l) => Semantics(
          label: 'Legal information: ${l['title'] ?? ''}. Category: ${l['category'] ?? ''}. Language: ${l['language'] ?? 'en'}.',
          child: Card(
            child: ExpansionTile(
              dense: true,
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(l['title'] ?? ''),
              subtitle: Text('${l['category'] ?? ''} · ${l['language'] ?? 'en'}'),
              children: [Padding(padding: const EdgeInsets.all(12), child: Text(l['body'] ?? ''))],
            ),
          ),
        )),
        if (_legal.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(loc.noLegalContent, style: const TextStyle(color: Colors.grey))),
        const SizedBox(height: 16),

        if (_loggedIn) ...[
          _section(loc.identityVerification, Icons.verified_user),
          Semantics(
            label: 'Identity verification. Verify your identity with your national ID card.',
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.verified_user_outlined, color: Colors.teal),
                title: Text(loc.faydaIdVerification),
                subtitle: Text(loc.faydaVerificationSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IdVerificationScreen())),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        _section(loc.accessibilityTitle, Icons.accessible_forward),
        Semantics(
          label: 'Accessibility mode toggle. ${_accessibility ? "Currently on. Increases text size and contrast for better visibility." : "Currently off."}',
          child: SwitchListTile(
            title: Text(loc.accessibilityModePoD),
            subtitle: Text(loc.accessibilitySubtitle),
            value: _accessibility,
            onChanged: (v) {
              setState(() => _accessibility = v);
              ZegaAlertApp.of(context)?.toggleAccessibility(v);
            },
          ),
        ),
        Semantics(
          label: 'Dark mode toggle. ${_darkMode ? "Currently on" : "Currently off"}',
          child: SwitchListTile(
            title: Text(loc.darkMode),
            subtitle: Text(loc.darkModeSubtitle),
            value: _darkMode,
            onChanged: (v) {
              setState(() => _darkMode = v);
              ZegaAlertApp.of(context)?.toggleDarkMode(v);
            },
          ),
        ),
        const SizedBox(height: 8),

        _section('Backend server', Icons.dns_outlined),
        Semantics(
          label: 'Backend server. Currently ${Api.baseUrl}. Double tap to change.',
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.dns_outlined, color: Colors.deepPurple),
              title: const Text('Backend server'),
              subtitle: Text(Api.baseUrl),
              trailing: const Icon(Icons.chevron_right),
              onTap: _editServerUrl,
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_loggedIn) ...[
          _section(loc.callbackRequests, Icons.phone_callback_outlined),
          Semantics(
            label: 'Callback requests. View police callback requests for your reports.',
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.phone_callback_outlined, color: Colors.indigo),
                title: Text(loc.callbackRequests),
                subtitle: Text(loc.callbackSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CallbacksScreen())),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: 'Request direct call. Double tap to call the emergency hotline.',
            child: FilledButton.tonalIcon(
              onPressed: _requestCall,
              icon: const Icon(Icons.phone_in_talk_outlined),
              label: Text(loc.requestDirectCall),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            button: true,
            label: 'Record sign language video. Double tap to open camera for sign language recording.',
            child: FilledButton.tonalIcon(
              onPressed: _recordSignLanguage,
              icon: const Icon(Icons.videocam_outlined),
              label: Text(loc.recordSignLanguage),
            ),
          ),
          const SizedBox(height: 20),

          FilledButton(onPressed: _save, child: Text(loc.saveSettings)),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _logout, icon: const Icon(Icons.logout), label: Text(loc.logoutLabel)),
        ] else ...[
          FilledButton.icon(
            onPressed: () => openAuth(context),
            icon: const Icon(Icons.login),
            label: const Text('Sign in / Create account'),
          ),
        ],
      ],
    );
  }

  Widget _guestBanner(AppLocalizations loc) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.explore_outlined, color: scheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Browsing as guest', style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onPrimaryContainer)),
                  const SizedBox(height: 2),
                  Text('Sign in to file reports, send SOS, message officers and verify your ID.',
                      style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: () => openAuth(context), child: const Text('Sign in')),
          ],
        ),
      ),
    );
  }

  Future<void> _editServerUrl() async {
    final controller = TextEditingController(text: Api.overrideBaseUrl ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current: ${Api.baseUrl}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://zega-api.example.et',
                helperText: 'Leave blank to auto-detect on the local network.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Auto-detect')),
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;
    await Api.setBaseUrl(result);
    setState(() => _status = result.trim().isEmpty
        ? 'Backend set to auto-detect on the local network.'
        : 'Backend server saved: ${Api.baseUrl}');
  }

  Future<void> _requestCall() async {
    final loc = AppLocalizations.of(context);
    setState(() => _status = null);
    double? lat;
    double? lng;
    try {
      final pos = await Geolocator.getCurrentPosition();
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {}
    try {
      final data = await Api.post('/pod/direct-call', {'latitude': lat, 'longitude': lng});
      final station = data?['station'];
      final stationName = station?['name'] ?? 'nearest station';
      final stationPhone = station?['phone'];
      setState(() => _status = 'Direct call request sent to $stationName.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.callingNumber((stationPhone ?? '0911').toString()))),
      );
      final uri = Uri(scheme: 'tel', path: (stationPhone ?? '0911').toString());
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (e) {
      setState(() => _status = loc.couldNotStartCall(e));
    }
  }

  Future<void> _recordSignLanguage() async {
    final loc = AppLocalizations.of(context);
    try {
      final file = await ImagePicker().pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 60));
      if (file == null) {
        setState(() => _status = loc.recordingCancelled);
        return;
      }
      final up = await Api.upload('/upload/single', [MapEntry('file', file.path)]);
      final url = up?['url'] as String?;
      final absUrl = (url != null && url.startsWith('/')) ? '${Api.baseUrl}$url' : url;
      double? lat;
      double? lng;
      try {
        final pos = await Geolocator.getCurrentPosition();
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}
      await Api.post('/pod/sign-language', {
        'video_url': absUrl,
        'note': 'Sign language video message',
        'latitude': lat,
        'longitude': lng,
      });
      setState(() => _status = loc.signLanguageUploaded(file.name));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.signLanguageRecorded)));
    } catch (e) {
      setState(() => _status = loc.couldNotRecordVideo(e));
    }
  }

  Widget _section(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
