import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'auth_screen.dart';
import 'id_verification_screen.dart';
import 'communication_screen.dart';
import '../services/api.dart';
import '../widgets/auth_gate.dart';
import '../widgets/pod_actions.dart';
import 'callbacks_screen.dart';
import 'geofence_editor_screen.dart';
import '../config/constants.dart';

const _languages = [
  (code: 'en', label: 'EN'),
  (code: 'am', label: 'AMH'),
  (code: 'om', label: 'ORM'),
  (code: 'ti', label: 'TIGIR'),
  (code: 'so', label: 'SOM'),
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
      final legal = await Api.get('/legal');
      _legal = legal as List<dynamic>;
      List<dynamic> geofences = [];
      if (_loggedIn) {
        final me = await Api.get('/auth/me') as Map<String, dynamic>;
        _name.text = me['full_name'] ?? '';
        _accessibility = me['accessibility_mode'] ?? false;
        _language = me['preferred_language'] ?? 'en';
        _region = me['region'] ?? 'Addis Ababa';
        _subCity = me['sub_city'] ?? (subCitiesByRegion[_region]?.first ?? '');
        final geofenceResult = await Api.get('/geofences');
        geofences = geofenceResult is List ? geofenceResult : [];
        await Api.setProfile(me);
        if (mounted) ZegaAlertApp.of(context)?.setLanguage(_language);
      } else if (mounted) {
        _language = ZegaAlertApp.of(context)?.languageCode ?? _language;
      }
      if (mounted) {
        setState(() {
          _geofences = geofences;
          _loadError = null;
        });
      }
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
      if (!mounted) return;
      ZegaAlertApp.of(context)?.setLanguage(_language);
      setState(() => _status = 'Saved.');
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    }
  }

  Future<void> _addGeofence() async {
    final loc = AppLocalizations.of(context);
    if (_geofences.length >= 10) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum of 10 active safety zones reached. Delete one first.')));
      return;
    }
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const GeofenceEditorScreen()),
    );
    if (created == true) {
      await _load();
      if (mounted) setState(() => _status = loc.safetyZoneCreated);
    }
  }

  Future<void> _editGeofence(Map<String, dynamic> geofence) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => GeofenceEditorScreen(geofence: geofence)),
    );
    if (updated == true) {
      await _load();
      if (mounted) setState(() => _status = 'Safety zone updated.');
    }
  }

  Map<String, dynamic>? _legalTranslation(dynamic item) {
    final translations = item['translations'];
    if (translations is! Map) return null;
    final localized = translations[_language];
    return localized is Map ? Map<String, dynamic>.from(localized) : null;
  }

  Future<void> _deleteGeofence(String id) async {
    try {
      await Api.delete('/geofences/$id');
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      setState(() => _status = loc.safetyZoneDeleted);
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    }
    _load();
  }

  Future<void> _toggleGeofence(String id, bool active) async {
    try {
      await Api.patch('/geofences/$id', {'is_active': active});
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _logout() async {
    final refreshToken = Api.refreshToken;
    try {
      await Api.post('/auth/logout', {'refreshToken': refreshToken});
    } catch (_) {
      // Offline or already-expired session - revoke when connectivity returns.
      await Api.queuePendingLogout(refreshToken);
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
              initialValue: ethiopianRegions.contains(_region) ? _region : null,
              decoration: InputDecoration(labelText: loc.regionLabel, border: const OutlineInputBorder()),
              items: ethiopianRegions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _region = v;
                    _subCity = subCitiesByRegion[v]?.first ?? '';
                  });
                }
              },
            ),
          ),
          if ((subCitiesByRegion[_region] ?? []).isNotEmpty) ...[
            const SizedBox(height: 12),
            Semantics(
              label: 'Sub city dropdown. Currently set to $_subCity.',
              child: DropdownButtonFormField<String>(
                initialValue: (subCitiesByRegion[_region] ?? const []).contains(_subCity) ? _subCity : null,
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
            initialValue: _language,
            decoration: InputDecoration(labelText: loc.preferredLanguage, border: const OutlineInputBorder()),
            items: _languages.map((l) => DropdownMenuItem(value: l.code, child: Text(l.label))).toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _language = v);
              ZegaAlertApp.of(context)?.setLanguage(v);
              if (_loggedIn) {
                Api.put('/auth/me', {'preferred_language': v}).catchError((_) {});
              }
            },
          ),
        ),
        const SizedBox(height: 16),

        if (_loggedIn) ...[
          _section(loc.safetyZones, Icons.location_on_outlined),
          ..._geofences.map((g) => Semantics(
            label: 'Safety zone: ${g['label'] ?? g['name'] ?? 'Zone'}. Type: ${g['type'] ?? 'zone'}. Sensitivity: ${g['sensitivity'] ?? 'medium'}. Radius: ${g['radius_m'] != null ? '${g['radius_m']} meters' : 'not set'}.',
            child: Card(
              child: ListTile(
                dense: true,
                onTap: () => _editGeofence(Map<String, dynamic>.from(g as Map)),
                leading: const Icon(Icons.radar, color: Colors.green),
                title: Text(g['label'] ?? g['name'] ?? 'Zone'),
                subtitle: Text('${g['type'] ?? 'zone'} · ${g['sensitivity'] ?? 'medium'} · ${g['radius_m'] != null ? '${g['radius_m']}m' : 'radius not set'}'),
                trailing: Semantics(
                  button: true,
                  label: 'Delete safety zone: ${g['name'] ?? 'Zone'}',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(value: g['is_active'] != false, onChanged: (v) => _toggleGeofence(g['id'] as String, v)),
                      IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteGeofence(g['id'] as String)),
                    ],
                  ),
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
        ..._legal.take(5).map((l) {
          final tr = _legalTranslation(l);
          final title = tr?['title'] ?? l['title'] ?? '';
          final body = tr?['body'] ?? l['body'] ?? '';
          return Semantics(
            label: 'Legal information: $title. Category: ${l['category'] ?? ''}. Language: $_language.',
            child: Card(
              child: ExpansionTile(
                dense: true,
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(title),
                subtitle: Text('${l['category'] ?? ''} · ${l['language'] ?? 'en'}'),
                children: [Padding(padding: const EdgeInsets.all(12), child: Text(body))],
              ),
            ),
          );
        }),
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

        _section('About & support', Icons.info_outline),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About ZEGA-ALERT'),
                subtitle: Text('Version ${Api.appVersion}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _about,
              ),
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text('Contact us'),
                subtitle: const Text('Hotlines 991 and 907'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _contact,
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms & Conditions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _terms,
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _privacy,
              ),
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('Rate ZEGA-ALERT'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _rateApp,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _section('Support & Feedback', Icons.support_agent_outlined),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF1E40AF)),
                title: const Text('Chat with Admin'),
                subtitle: const Text('Follow up on reports'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CommunicationScreen()));
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Leave Feedback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Tell us how we can improve...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(Icons.star_outline, size: 20, color: Colors.grey.shade400),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Feedback submitted. Thank you!')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: const Text('Submit', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

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
            label: 'People of Determination actions. Request a direct call or record a sign language video.',
            child: const PodActions(showHeading: false),
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

  Future<void> _dial(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (_) {}
  }

  void _about() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ZEGA-ALERT'),
        content: SingleChildScrollView(
          child: Text(
            'ZEGA-ALERT is the Ethiopian Federal Police citizen safety app. '
            'It connects you to emergency dispatch, crime reporting, missing and '
            'wanted persons, official announcements and two-way communication '
            'with officers — in English, Amharic, Oromifa, Tigrinya and Ethio Somali.\n\n'
            'Version ${Api.appVersion}',
            style: TextStyle(height: 1.4),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _contact() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contact us'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.local_police),
              title: const Text('Police emergency'),
              subtitle: const Text('991'),
              onTap: () => _dial('991'),
            ),
            ListTile(
              leading: const Icon(Icons.emergency),
              title: const Text('Ambulance / rescue'),
              subtitle: const Text('907'),
              onTap: () => _dial('907'),
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email support'),
              subtitle: const Text('support@zega-alert.et'),
              onTap: () async {
                await launchUrl(Uri(scheme: 'mailto', path: 'support@zega-alert.et'));
              },
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _terms() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Use ZEGA-ALERT only for genuine emergencies, crime reports and '
            'public-safety information.\n\n'
            '2. Knowingly sending false reports is an offence and may lead to '
            'account suspension and legal action.\n\n'
            '3. Emergency features depend on network coverage and location '
            'services. Always call 991 if the app cannot connect.\n\n'
            '4. Reports you submit are shared with the responsible police '
            'station and regional administrators for investigation.\n\n'
            '5. Keep your account credentials private. You are responsible for '
            'activity on your account.',
            style: TextStyle(height: 1.4),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _privacy() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'ZEGA-ALERT collects only the information needed to keep you safe: '
            'your name, phone number, region and the content of reports you '
            'choose to submit.\n\n'
            'Location is used for SOS alerts, nearest-station lookup, safety '
            'zones and incident mapping. It is transmitted only while you use '
            'these features.\n\n'
            'Contact details on missing-person notices are encrypted at rest. '
            'Sensitive information is visible only to authorised police staff.\n\n'
            'You can browse news, wanted and missing persons as a guest. You '
            'can delete your account by contacting support.',
            style: TextStyle(height: 1.4),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _rateApp() async {
    final uri = Uri.parse('https://play.google.com/store/search?q=ZEGA-ALERT&c=apps');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search for ZEGA-ALERT in your app store to rate us.')),
      );
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
