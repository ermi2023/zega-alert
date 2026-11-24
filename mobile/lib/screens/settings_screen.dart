import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'auth_screen.dart';
import 'login_screen.dart';
import 'id_verification_screen.dart';
import 'communication_screen.dart';
import '../services/api.dart';
import '../widgets/auth_gate.dart';
import '../widgets/pod_actions.dart';
import 'callbacks_screen.dart';
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
  final _email = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _passwordForm = GlobalKey<FormState>();
  final _profileTileController = ExpansibleController();
  Map<String, dynamic> _profile = {};
  bool _accessibility = false;
  String _language = 'en';
  String _region = 'Addis Ababa';
  String _subCity = 'Arada';
  bool _darkMode = false;
  String? _status;
  String? _passwordStatus;
  bool _passwordBusy = false;
  bool _showPasswords = false;

  List<dynamic> _legal = [];

  String? _loadError;

  bool get _loggedIn => Api.isLoggedIn;

  void _editProfile() {
    _profileTileController.expand();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final formContext = _form.currentContext;
      if (formContext == null) return;
      Scrollable.ensureVisible(
        formContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _load() async {
    try {
      final legal = await Api.get('/legal');
      _legal = legal as List<dynamic>;
      if (_loggedIn) {
        final me = await Api.get('/auth/me') as Map<String, dynamic>;
        _profile = me;
        _name.text = me['full_name'] ?? '';
        _email.text = me['email'] ?? '';
        _accessibility = me['accessibility_mode'] ?? false;
        _language = me['preferred_language'] ?? 'en';
        _region = me['region'] ?? 'Addis Ababa';
        _subCity = me['sub_city'] ?? (subCitiesByRegion[_region]?.first ?? '');
        await Api.setProfile(me);
        if (mounted) ZegaAlertApp.of(context)?.setLanguage(_language);
      } else if (mounted) {
        _language = ZegaAlertApp.of(context)?.languageCode ?? _language;
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

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    _profileTileController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    try {
      await Api.put('/auth/me', {
        'full_name': _name.text.trim(),
        'email': _email.text.trim(),
        'accessibility_mode': _accessibility,
        'preferred_language': _language,
        'region': _region,
        'sub_city': _subCity,
      });
      await Api.setProfile({'region': _region, 'sub_city': _subCity});
      if (!mounted) return;
      _profile['full_name'] = _name.text.trim();
      _profile['email'] = _email.text.trim();
      _profile['region'] = _region;
      _profile['sub_city'] = _subCity;
      ZegaAlertApp.of(context)?.setLanguage(_language);
      setState(() => _status = 'Profile and settings saved.');
    } catch (e) {
      if (mounted) setState(() => _status = 'Failed: $e');
    }
  }

  Future<void> _changePassword() async {
    if (!(_passwordForm.currentState?.validate() ?? false)) return;
    setState(() {
      _passwordBusy = true;
      _passwordStatus = null;
    });
    try {
      await Api.put('/auth/change-password', {
        'currentPassword': _currentPassword.text,
        'newPassword': _newPassword.text,
      });
      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      setState(() => _passwordStatus = 'Password changed successfully.');
    } catch (e) {
      if (mounted) setState(() => _passwordStatus = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _passwordBusy = false);
    }
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
        MaterialPageRoute(builder: (_) => const LoginScreen()),
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
        Text(loc.settingsTitle,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(loc.settingsSubtitle, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        if (_status != null)
          Card(
              color: _status!.startsWith('Failed')
                  ? Colors.red.shade50
                  : Colors.green.shade50,
              child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(_status!,
                      style: TextStyle(
                          color: _status!.startsWith('Failed')
                              ? Colors.red
                              : Colors.green)))),
        if (_loadError != null)
          Card(
              color: Colors.red.shade50,
              child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_loadError!,
                            style: const TextStyle(color: Colors.red)))
                  ]))),
        const SizedBox(height: 4),
        if (!_loggedIn) _guestBanner(loc),
        if (_loggedIn) ...[
          _profileHeader(),
          _category(
            'Personal information',
            Icons.person_outline,
            [
              Semantics(
                label: 'Full name input',
                child: Form(
                  key: _form,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: loc.fullName,
                          prefixIcon: const Icon(Icons.person_outline),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? loc.required
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return null;
                          return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(email)
                              ? null
                              : 'Enter a valid email address.';
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _accountDetails(),
              _section(loc.locationLabel, Icons.location_on_outlined),
              Semantics(
                label: 'Region dropdown. Currently set to $_region.',
                child: DropdownButtonFormField<String>(
                  value: ethiopianRegions.contains(_region) ? _region : null,
                  decoration: InputDecoration(
                      labelText: loc.regionLabel,
                      border: const OutlineInputBorder()),
                  items: ethiopianRegions
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null)
                      setState(() {
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
                    value: (subCitiesByRegion[_region] ?? const [])
                            .contains(_subCity)
                        ? _subCity
                        : null,
                    decoration: InputDecoration(
                        labelText: loc.subCityLabel,
                        border: const OutlineInputBorder()),
                    items: subCitiesByRegion[_region]!
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _subCity = v ?? ''),
                  ),
                ),
              ],
            ],
            controller: _profileTileController,
          ),
        ],
        if (_loggedIn) ...[
          _category(
            'Security',
            Icons.lock_outline,
            [
              _changePasswordForm(),
              const SizedBox(height: 12),
              _identityVerification(loc),
            ],
          ),
        ],
        _category(
          'Preferences',
          Icons.tune,
          [
            _section(loc.languageLabel, Icons.language),
            Semantics(
              label:
                  'Preferred language dropdown. Currently set to $_language.',
              child: DropdownButtonFormField<String>(
                value: _language,
                decoration: InputDecoration(
                    labelText: loc.preferredLanguage,
                    border: const OutlineInputBorder()),
                items: _languages
                    .map((l) =>
                        DropdownMenuItem(value: l.code, child: Text(l.label)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _language = v);
                  ZegaAlertApp.of(context)?.setLanguage(v);
                  if (_loggedIn) {
                    Api.put('/auth/me', {'preferred_language': v})
                        .catchError((_) {});
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label:
                  'Accessibility mode toggle. ${_accessibility ? "Currently on. Increases text size and contrast for better visibility." : "Currently off."}',
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
              label:
                  'Dark mode toggle. ${_darkMode ? "Currently on" : "Currently off"}',
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
          ],
        ),
        _category(
          loc.legalInformation,
          Icons.gavel,
          [
            if (_legal.isEmpty)
              Text(loc.noLegalContent,
                  style: const TextStyle(color: Colors.grey)),
            ..._legal.take(5).map((l) => Semantics(
                  label:
                      'Legal information: ${l['title'] ?? ''}. Category: ${l['category'] ?? ''}. Language: ${l['language'] ?? 'en'}.',
                  child: Card(
                    child: ExpansionTile(
                      dense: true,
                      leading: const Icon(Icons.menu_book_outlined),
                      title: Text(l['title'] ?? ''),
                      subtitle: Text(
                          '${l['category'] ?? ''} · ${l['language'] ?? 'en'}'),
                      children: [
                        Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(l['body'] ?? ''))
                      ],
                    ),
                  ),
                )),
          ],
        ),
        _category(
          'About & support',
          Icons.info_outline,
          [
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About ZEGA-ALERT'),
                    subtitle: const Text('Version 1.0.0'),
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
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline,
                        color: Color(0xFF1E40AF)),
                    title: const Text('Chat with Admin'),
                    subtitle: const Text('Follow up on reports'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const CommunicationScreen()));
                    },
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Leave Feedback',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextField(
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Tell us how we can improve...',
                            hintStyle: TextStyle(
                                color: Colors.grey.shade400, fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
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
                                (i) => Icon(Icons.star_outline,
                                    size: 20, color: Colors.grey.shade400),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Feedback submitted. Thank you!')),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                              child: const Text('Submit',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_loggedIn) ...[
              Semantics(
                label:
                    'Callback requests. View police callback requests for your reports.',
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.phone_callback_outlined,
                        color: Colors.indigo),
                    title: Text(loc.callbackRequests),
                    subtitle: Text(loc.callbackSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const CallbacksScreen())),
                  ),
                ),
              ),
              Semantics(
                label:
                    'People of Determination actions. Request a direct call or record a sign language video.',
                child: const PodActions(showHeading: false),
              ),
            ],
          ],
        ),
        if (_loggedIn) ...[
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: Text(loc.saveSettings)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: Text(loc.logoutLabel)),
        ] else
          FilledButton.icon(
            onPressed: () => openAuth(context),
            icon: const Icon(Icons.login),
            label: const Text('Sign in / Create account'),
          ),
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
                  Text('Browsing as guest',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: scheme.onPrimaryContainer)),
                  const SizedBox(height: 2),
                  Text(
                      'Sign in to file reports, send SOS, message officers and verify your ID.',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onPrimaryContainer)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
                onPressed: () => openAuth(context),
                child: const Text('Sign in')),
          ],
        ),
      ),
    );
  }

  Widget _identityVerification(AppLocalizations loc) {
    return Semantics(
      label:
          'Identity verification. Verify your identity with your national ID card.',
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.verified_user_outlined, color: Colors.teal),
          title: Text(loc.faydaIdVerification),
          subtitle: Text(loc.faydaVerificationSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const IdVerificationScreen())),
        ),
      ),
    );
  }

  Widget _profileHeader() {
    final name = (_profile['full_name'] ?? _name.text).toString().trim();
    final phone = (_profile['phone'] ?? '').toString();
    final verified = _profile['is_verified'] == true;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFFEAF1FF),
              child: Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF142B4A),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Citizen profile' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF142B4A),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(phone, style: const TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: verified
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        verified ? 'Verified account' : 'Unverified account',
                        style: TextStyle(
                          color: verified
                              ? const Color(0xFF166534)
                              : const Color(0xFF9A3412),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit profile',
              onPressed: _editProfile,
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountDetails() {
    final createdAt = DateTime.tryParse(
      (_profile['created_at'] ?? '').toString(),
    );
    final formattedDate = createdAt == null
        ? 'Not available'
        : DateFormat.yMMMd().format(createdAt.toLocal());
    final verified = _profile['is_verified'] == true;
    return Card(
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.phone_outlined),
            title: const Text('Phone number'),
            subtitle: Text((_profile['phone'] ?? 'Not available').toString()),
            trailing: const Icon(Icons.lock_outline, size: 18),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            dense: true,
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Member since'),
            subtitle: Text(formattedDate),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            dense: true,
            leading: Icon(
              verified ? Icons.verified_outlined : Icons.info_outline,
              color: verified ? const Color(0xFF16A34A) : null,
            ),
            title: const Text('Verification status'),
            subtitle: Text(verified ? 'Verified' : 'Unverified'),
          ),
        ],
      ),
    );
  }

  Widget _changePasswordForm() {
    InputDecoration decoration(String label) => InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            onPressed: () => setState(() => _showPasswords = !_showPasswords),
            icon: Icon(_showPasswords
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
          ),
          border: const OutlineInputBorder(),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _passwordForm,
          child: Column(
            children: [
              TextFormField(
                controller: _currentPassword,
                obscureText: !_showPasswords,
                textInputAction: TextInputAction.next,
                decoration: decoration('Current password'),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your current password.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPassword,
                obscureText: !_showPasswords,
                textInputAction: TextInputAction.next,
                decoration: decoration('New password'),
                validator: (value) => value != null && value.length >= 8
                    ? null
                    : 'Use at least 8 characters.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPassword,
                obscureText: !_showPasswords,
                textInputAction: TextInputAction.done,
                decoration: decoration('Confirm new password'),
                validator: (value) => value == _newPassword.text
                    ? null
                    : 'Passwords do not match.',
              ),
              if (_passwordStatus != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _passwordStatus!,
                    style: TextStyle(
                      color: _passwordStatus!.startsWith('Failed')
                          ? Theme.of(context).colorScheme.error
                          : const Color(0xFF166534),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _passwordBusy ? null : _changePassword,
                  child: _passwordBusy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        content: const SingleChildScrollView(
          child: Text(
            'ZEGA-ALERT is the Ethiopian Federal Police citizen safety app. '
            'It connects you to emergency dispatch, crime reporting, missing and '
            'wanted persons, official announcements and two-way communication '
            'with officers — in English, Amharic, Oromifa, Tigrinya and Ethio Somali.\n\n'
            'Version 1.0.0',
            style: TextStyle(height: 1.4),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
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
                await launchUrl(
                    Uri(scheme: 'mailto', path: 'support@zega-alert.et'));
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
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
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
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
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }

  Future<void> _rateApp() async {
    final uri =
        Uri.parse('https://play.google.com/store/search?q=ZEGA-ALERT&c=apps');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Search for ZEGA-ALERT in your app store to rate us.')),
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
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _category(
    String title,
    IconData icon,
    List<Widget> children, {
    ExpansibleController? controller,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        controller: controller,
        maintainState: true,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: children,
      ),
    );
  }
}
