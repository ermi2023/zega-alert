import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../main.dart';
import 'login_screen.dart';
import 'id_verification_screen.dart';
import 'communication_screen.dart';
import '../services/api.dart';
import '../services/person_image_cache_service.dart';
import '../services/safety_zone_tracking_service.dart';
import '../widgets/auth_gate.dart';
import '../widgets/pod_actions.dart';
import 'callbacks_screen.dart';
import 'geofence_map_screen.dart';
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
  bool _personPhotoCachingEnabled = PersonImageCacheService.enabled.value;
  bool _personPhotoCacheBusy = false;
  bool _safetyZoneTrackingEnabled = false;
  bool _safetyZoneTrackingBusy = false;
  int _cachedPersonPhotoBytes = 0;
  int _cachedPersonPhotoCount = 0;

  List<dynamic> _geofences = [];
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
    _safetyZoneTrackingEnabled = await SafetyZoneTrackingService.isEnabled();
    if (SafetyZoneTrackingService.lastError != null) {
      _status = SafetyZoneTrackingService.lastError;
    }
    final cachedProfile = Api.profile;
    if (_loggedIn && cachedProfile != null) {
      _profile = cachedProfile;
      _name.text = (cachedProfile['full_name'] ?? '').toString();
      _email.text = (cachedProfile['email'] ?? '').toString();
      _accessibility = cachedProfile['accessibility_mode'] == true;
      _language = (cachedProfile['preferred_language'] ?? 'en').toString();
      _region = (cachedProfile['region'] ?? 'Addis Ababa').toString();
      _subCity =
          (cachedProfile['sub_city'] ?? subCitiesByRegion[_region]?.first ?? '')
              .toString();
      if (mounted) setState(() {});
    }
    try {
      final legal = await Api.get('/legal');
      _legal = legal as List<dynamic>;
      List<dynamic> geofences = [];
      if (_loggedIn) {
        final me = await Api.get('/auth/me') as Map<String, dynamic>;
        _profile = me;
        _name.text = me['full_name'] ?? '';
        _email.text = me['email'] ?? '';
        _accessibility = me['accessibility_mode'] ?? false;
        _language = me['preferred_language'] ?? 'en';
        _region = me['region'] ?? 'Addis Ababa';
        _subCity = me['sub_city'] ?? (subCitiesByRegion[_region]?.first ?? '');
        final geofenceResult = await Api.get(
          '/geofences?region=${Uri.encodeQueryComponent(_region)}',
        );
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
      if (mounted)
        setState(
          () => _loadError = Api.userMessage(
            e,
            fallback: 'Could not load settings right now.',
          ),
        );
    }
  }

  Future<void> _refreshPersonPhotoCacheUsage() async {
    try {
      final bytes = await PersonImageCacheService.cachedBytes();
      final count = await PersonImageCacheService.cachedCount();
      if (mounted) {
        setState(() {
          _cachedPersonPhotoBytes = bytes;
          _cachedPersonPhotoCount = count;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _status = Api.userMessage(
            error,
            fallback: 'Could not read saved photo storage.',
          ),
        );
      }
    }
  }

  Future<void> _setPersonPhotoCaching(bool enabled) async {
    setState(() => _personPhotoCacheBusy = true);
    try {
      await PersonImageCacheService.setEnabled(enabled);
      if (mounted) {
        setState(
          () => _personPhotoCachingEnabled =
              PersonImageCacheService.enabled.value,
        );
      }
      await _refreshPersonPhotoCacheUsage();
    } catch (error) {
      if (mounted) {
        setState(() {
          _personPhotoCachingEnabled = PersonImageCacheService.enabled.value;
          _status = Api.userMessage(
            error,
            fallback: 'Could not update photo storage settings.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _personPhotoCacheBusy = false);
    }
  }

  Future<void> _clearPersonPhotoCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear saved person photos?'),
        content: const Text(
          'This removes wanted and missing-person photos saved on this device. '
          'They can be saved again while photo storage is enabled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear photos'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _personPhotoCacheBusy = true);
    try {
      await PersonImageCacheService.clear();
      await _refreshPersonPhotoCacheUsage();
    } catch (error) {
      if (mounted) {
        setState(
          () => _status = Api.userMessage(
            error,
            fallback: 'Could not clear saved photos.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _personPhotoCacheBusy = false);
    }
  }

  String _formatStorageSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  void initState() {
    super.initState();
    PersonImageCacheService.cacheRevision.addListener(
      _refreshPersonPhotoCacheUsage,
    );
    _personPhotoCachingEnabled = PersonImageCacheService.enabled.value;
    _load();
    _refreshPersonPhotoCacheUsage();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    _profileTileController.dispose();
    PersonImageCacheService.cacheRevision.removeListener(
      _refreshPersonPhotoCacheUsage,
    );
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
      _profile = {
        ..._profile,
        'full_name': _name.text.trim(),
        'email': _email.text.trim(),
        'accessibility_mode': _accessibility,
        'preferred_language': _language,
        'region': _region,
        'sub_city': _subCity,
      };
      await Api.setProfile(_profile);
      if (!mounted) return;
      ZegaAlertApp.of(context)?.setLanguage(_language);
      setState(() => _status = 'Profile and settings saved.');
    } catch (e) {
      if (mounted)
        setState(
          () => _status = Api.userMessage(
            e,
            fallback: 'Could not save your profile.',
          ),
        );
    }
  }

  Future<void> _setSafetyZoneTracking(bool enabled) async {
    final loc = AppLocalizations.of(context);
      setState(() {
        _safetyZoneTrackingBusy = true;
        _status = null;
      });
      try {
        if (!enabled) {
          await SafetyZoneTrackingService.disable();
          if (mounted) {
            setState(() {
              _safetyZoneTrackingEnabled = false;
              _status = loc.safetyZoneAlertsOff;
            });
          }
          return;
        }

        if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
          throw const SafetyZoneTrackingException(
            'Background Safety Zone alerts are currently available on Android.',
          );
        }
        if (!await Geolocator.isLocationServiceEnabled()) {
          throw const SafetyZoneTrackingException(
            'Turn on device Location to enable Safety Zone alerts.',
          );
        }

        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.always) {
          if (!mounted) return;
          final openSettings = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(loc.allowBackgroundLocation),
              content: Text(loc.allowBackgroundLocationDescription),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(loc.notNow),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(loc.openAppSettings),
                ),
              ],
            ),
          );
          if (openSettings == true) await Geolocator.openAppSettings();
          if (mounted) {
            setState(
              () => _status = loc.backgroundLocationPermissionRequired,
            );
          }
          return;
        }

        final zones = await Api.get('/geofences');
        if (zones is! List) {
          throw const FormatException('Unexpected Safety Zone response.');
        }
        await SafetyZoneTrackingService.enable(zones);
        if (mounted) {
          final monitoredZoneCount =
              SafetyZoneTrackingService.monitoredZoneCount;
          setState(() {
            _safetyZoneTrackingEnabled = true;
            _status = monitoredZoneCount == 0
                ? loc.safetyZoneAlertsOnNoZones
                : loc.safetyZoneAlertsOn;
          });
        }
      } catch (error) {
        if (mounted) {
          final message = error is SafetyZoneTrackingException
              ? error.message
              : Api.userMessage(
                  error,
                  fallback:
                      'Could not enable Safety Zone alerts. Check your connection, location permission, and notification settings.',
                );
          setState(() {
            _safetyZoneTrackingEnabled = !enabled;
            _status = message;
          });
        }
      } finally {
        if (mounted) setState(() => _safetyZoneTrackingBusy = false);
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
      if (mounted)
        setState(
          () => _passwordStatus = Api.userMessage(
            e,
            fallback: 'Could not change your password.',
          ),
        );
    } finally {
      if (mounted) setState(() => _passwordBusy = false);
    }
  }

  Map<String, dynamic>? _legalTranslation(dynamic item) {
    final translations = item['translations'];
    if (translations is! Map) return null;
    final localized = translations[_language];
    return localized is Map ? Map<String, dynamic>.from(localized) : null;
  }

  Future<void> _logout() async {
    await SafetyZoneTrackingService.disable();
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
        Text(
          loc.settingsTitle,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(loc.settingsSubtitle, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        if (_status != null)
          Card(
            color: Colors.blueGrey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                _status!,
                style: const TextStyle(color: Colors.blueGrey),
              ),
            ),
          ),
        if (_loadError != null)
          Card(
            color: Colors.blueGrey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _loadError!,
                      style: const TextStyle(color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        if (!_loggedIn) _guestBanner(loc),
        _category('Help & accessibility', Icons.accessible_forward, [
          Semantics(
            label: 'People of Determination actions. Request a direct call or record a sign language video.',
            child: const PodActions(),
          ),
          const SizedBox(height: 8),
          Semantics(
            label:
                'Police and rescue emergency contacts. Police 991, rescue 907.',
            child: ListTile(
              leading: const Icon(Icons.local_police_outlined),
              title: const Text('Police and rescue contacts'),
              subtitle: const Text('Police 991 · Ambulance / rescue 907'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _contact,
            ),
          ),
        ]),
        if (_loggedIn) ...[
          _profileHeader(),
          _category('Personal information', Icons.person_outline, [
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
            Card(
              color: const Color(0xFFEAF2FF),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.health_and_safety_outlined),
                    title: const Text('Safety Zone entry alerts'),
                    subtitle: const Text(
                      'When enabled, ZEGA Alert checks your location in the '
                      'background and alerts you when you enter an active '
                      'published Safety Zone. Available on Android.',
                    ),
                    value: _safetyZoneTrackingEnabled,
                    onChanged: _safetyZoneTrackingBusy ||
                            kIsWeb ||
                            defaultTargetPlatform != TargetPlatform.android
                        ? null
                        : _setSafetyZoneTracking,
                  ),
                  if (_safetyZoneTrackingBusy)
                    const LinearProgressIndicator(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Precise location for these alerts stays on this '
                        'device and is not uploaded. Android shows an ongoing '
                        'notification while monitoring; this can use more '
                        'battery. SOS and report actions may use location '
                        'separately. Your saved Region/Sub-city fields remain '
                        'the manual fallback and still control area-based '
                        'information.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              label: 'Region dropdown. Currently set to $_region.',
              child: DropdownButtonFormField<String>(
                value: ethiopianRegions.contains(_region) ? _region : null,
                decoration: InputDecoration(
                  labelText: loc.regionLabel,
                  border: const OutlineInputBorder(),
                ),
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
                  value:
                      (subCitiesByRegion[_region] ?? const []).contains(
                        _subCity,
                      )
                      ? _subCity
                      : null,
                  decoration: InputDecoration(
                    labelText: loc.subCityLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: subCitiesByRegion[_region]!
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _subCity = v ?? ''),
                ),
              ),
            ],
          ], controller: _profileTileController),
        ],
        if (_loggedIn) ...[
          _category('Security', Icons.lock_outline, [
            _changePasswordForm(),
            const SizedBox(height: 12),
            _identityVerification(loc),
          ]),
        ],
        _category('Preferences', Icons.tune, [
          _section(loc.languageLabel, Icons.language),
          Semantics(
            label: 'Preferred language dropdown. Currently set to $_language.',
            child: DropdownButtonFormField<String>(
              value: _language,
              decoration: InputDecoration(
                labelText: loc.preferredLanguage,
                border: const OutlineInputBorder(),
              ),
              items: _languages
                  .map(
                    (l) =>
                        DropdownMenuItem(value: l.code, child: Text(l.label)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _language = v);
                ZegaAlertApp.of(context)?.setLanguage(v);
                if (_loggedIn) {
                  Api.put('/auth/me', {
                    'preferred_language': v,
                  }).catchError((_) {});
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
        ]),
        _category('Offline data', Icons.cloud_download_outlined, [
          SwitchListTile(
            title: const Text('Save wanted and missing-person photos'),
            subtitle: const Text(
              'Photos you view are stored on this device for offline access. '
              'This is off by default.',
            ),
            value: _personPhotoCachingEnabled,
            onChanged: _personPhotoCacheBusy ? null : _setPersonPhotoCaching,
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Clear saved person photos'),
            subtitle: Text(
              '$_cachedPersonPhotoCount photos · '
              '${_formatStorageSize(_cachedPersonPhotoBytes)} used',
            ),
            trailing: _personPhotoCacheBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _personPhotoCacheBusy || _cachedPersonPhotoCount == 0
                ? null
                : _clearPersonPhotoCache,
          ),
        ]),
        if (_loggedIn)
          _category(loc.safetyZones, Icons.location_on_outlined, [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'View official safety areas published by local authorities. '
                'New or changed areas and emergency incidents inside a zone '
                'appear in Notifications; push alerts require device '
                'notifications to be enabled. This information does not '
                'guarantee safety.',
              ),
            ),
            if (_geofences.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'No official safety areas are available for this region yet.',
                ),
              ),
            ..._geofences.map((g) {
              final zone = Map<String, dynamic>.from(g as Map);
              final name = zone['label'] ?? zone['name'] ?? 'Zone';
              return Semantics(
                label:
                    'Official safety area: $name. Type: ${zone['type'] ?? 'zone'}.',
                child: Card(
                  child: ListTile(
                    dense: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GeofenceMapScreen(geofence: zone),
                      ),
                    ),
                    leading: const Icon(
                      Icons.verified_user_outlined,
                      color: Colors.green,
                    ),
                    title: Text(name),
                    subtitle: Text(
                      [
                        (zone['type'] ?? 'area').toString().replaceAll(
                          '_',
                          ' ',
                        ),
                        if (zone['region'] != null) zone['region'].toString(),
                        if (zone['radius_m'] != null)
                          '${zone['radius_m']} m radius',
                        if (zone['polygon'] is List &&
                            (zone['polygon'] as List).length >= 3)
                          'Mapped boundary',
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              );
            }),
          ]),
        _category(loc.legalInformation, Icons.gavel, [
          if (_legal.isEmpty)
            Text(
              loc.noLegalContent,
              style: const TextStyle(color: Colors.grey),
            ),
          ..._legal.take(5).map((l) {
            final translation = _legalTranslation(l);
            final title = translation?['title'] ?? l['title'] ?? '';
            final body = translation?['body'] ?? l['body'] ?? '';
            return Semantics(
              label:
                  'Legal information: $title. Category: ${l['category'] ?? ''}. Language: $_language.',
              child: Card(
                child: ExpansionTile(
                  dense: true,
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(title),
                  subtitle: Text(
                    '${l['category'] ?? ''} · ${l['language'] ?? 'en'}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(body),
                    ),
                  ],
                ),
              ),
            );
          }),
        ]),
        _category('About & support', Icons.info_outline, [
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
                  leading: const Icon(
                    Icons.chat_bubble_outline,
                    color: Color(0xFF1E40AF),
                  ),
                  title: const Text('Chat with Admin'),
                  subtitle: const Text('Follow up on reports'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CommunicationScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Leave Feedback',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Tell us how we can improve...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
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
                              (i) => Icon(
                                Icons.star_outline,
                                size: 20,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Feedback submitted. Thank you!',
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text(
                              'Submit',
                              style: TextStyle(fontSize: 12),
                            ),
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
              label: 'Callback requests. View police callback requests for your reports.',
              child: Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.phone_callback_outlined,
                    color: Colors.indigo,
                  ),
                  title: Text(loc.callbackRequests),
                  subtitle: Text(loc.callbackSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CallbacksScreen()),
                  ),
                ),
              ),
            ),
          ],
        ]),
        if (_loggedIn) ...[
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: Text(loc.saveSettings)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: Text(loc.logoutLabel),
          ),
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
                  Text(
                    'Browsing as guest',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sign in to file reports, send SOS, message officers and verify your ID.',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => openAuth(context),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _identityVerification(AppLocalizations loc) {
    return Semantics(
      label: 'Identity verification. Verify your identity with your national ID card.',
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.verified_user_outlined, color: Colors.teal),
          title: const Text('FAN identity verification'),
          subtitle: const Text(
            'Scan your original ID QR or enter its 16-digit FAN to check the administrator’s mock record.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const IdVerificationScreen()),
          ),
        ),
      ),
    );
  }

  Widget _profileHeader() {
    final name = (_profile['full_name'] ?? _name.text).toString().trim();
    final phone = (_profile['phone'] ?? '').toString();
    final verified = _profile['is_identity_verified'] == true;
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
    final verified = _profile['is_identity_verified'] == true;
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
        icon: Icon(
          _showPasswords
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
        ),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
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
                  Uri(scheme: 'mailto', path: 'support@zega-alert.et'),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _rateApp() async {
    final uri = Uri.parse(
      'https://play.google.com/store/search?q=ZEGA-ALERT&c=apps',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Search for ZEGA-ALERT in your app store to rate us.'),
        ),
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
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
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
