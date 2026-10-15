import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/biometric_service.dart';
import '../main.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _register = false;
  bool _showPassword = false;
  bool _busy = false;
  bool _canBioLogin = false;
  String _error = '';
  String? _region;
  String? _subCity;

  @override
  void initState() {
    super.initState();
    _initBiometrics();
  }

  @override
  void dispose() {
    _id.dispose();
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _initBiometrics() async {
    final available = await BiometricService.isAvailable();
    if (mounted) {
      setState(() => _canBioLogin = available && Api.refreshToken != null);
    }
  }

  Future<void> _biometricLogin() async {
    setState(() { _error = ''; _busy = true; });
    try {
      final ok = await BiometricService.authenticate();
      if (!ok) {
        setState(() => _error = 'Biometric authentication cancelled.');
        return;
      }
      final refreshed = await Api.refreshSession();
      if (!refreshed) {
        setState(() => _error = 'Session expired. Please sign in with your password.');
        return;
      }
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _goHome() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
  }

  Future<void> _submit() async {
    setState(() { _error = ''; _busy = true; });
    try {
      if (_register) {
        if (_region == null) {
          setState(() { _error = 'Please select your region.'; _busy = false; });
          return;
        }
        final phone = _phone.text.trim();
        await Api.post('/auth/register', {
          'full_name': _name.text.trim(),
          'phone': phone,
          'email': _email.text.trim(),
          'password': _password.text,
          'region': _region,
          'sub_city': _subCity,
        });
        final otp = await _askOtp();
        await Api.post('/auth/verify-otp', {'contact': phone, 'code': otp, 'purpose': 'verify_phone'});
        final data = await Api.post('/auth/login', {'phone': phone, 'password': _password.text});
        await _persistSession(data);
        await _goHome();
        return;
      }

      final id = _id.text.trim();
      final body = id.contains('@')
          ? {'email': id, 'password': _password.text}
          : {'phone': id, 'password': _password.text};
      final data = await Api.post('/auth/login', body);
      await _persistSession(data);
      await _goHome();
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _persistSession(dynamic data) async {
    await Api.setToken(data['accessToken'], userId: data['user']['id'] as String);
    await Api.setRefreshToken(data['refreshToken']);
    await Api.setProfile(data['user'] as Map<String, dynamic>?);
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('ClientException') || s.contains('timed out') || s.contains('errno = 110')) {
      return 'Cannot reach the server at ${Api.baseUrl}.\n'
          'Check your internet connection, or tap "Server" below to set a different backend URL.';
    }
    return s;
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
    if (mounted) setState(() {});
  }

  Future<String> _askOtp() async {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.enterOtp),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: loc.checkOtpHint)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(loc.verify))],
      ),
    );
    return code ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.primary, scheme.primary.withValues(alpha: 0.85), scheme.surface],
            stops: const [0.0, 0.32, 0.32],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(scheme),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _modeToggle(loc),
                              const SizedBox(height: 18),
                              if (_register) ...[
                                TextFormField(
                                  controller: _name,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(labelText: loc.fullName, prefixIcon: const Icon(Icons.person_outline), border: const OutlineInputBorder()),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _phone,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(labelText: loc.phone, prefixIcon: const Icon(Icons.phone_outlined), border: const OutlineInputBorder()),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(labelText: 'Email (optional)', helperText: 'Add an email so you can also sign in with it', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _region,
                                  decoration: InputDecoration(labelText: loc.regionLabel, prefixIcon: const Icon(Icons.location_on_outlined), border: const OutlineInputBorder()),
                                  items: ethiopianRegions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                                  onChanged: (v) => setState(() {
                                    _region = v;
                                    _subCity = subCitiesByRegion[v]?.first;
                                  }),
                                ),
                                if ((subCitiesByRegion[_region] ?? []).isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    value: _subCity,
                                    decoration: InputDecoration(labelText: loc.subCityLabel, prefixIcon: const Icon(Icons.location_city_outlined), border: const OutlineInputBorder()),
                                    items: subCitiesByRegion[_region]!.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                    onChanged: (v) => setState(() => _subCity = v),
                                  ),
                                ],
                                const SizedBox(height: 12),
                              ] else ...[
                                TextFormField(
                                  controller: _id,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(labelText: 'Email or phone number', hintText: 'e.g. you@example.et or 0911000005', prefixIcon: Icon(Icons.alternate_email), border: OutlineInputBorder()),
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextFormField(
                                controller: _password,
                                obscureText: !_showPassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _busy ? null : _submit(),
                                decoration: InputDecoration(
                                  labelText: loc.password,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _showPassword = !_showPassword),
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              if (_error.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Row(children: [const Icon(Icons.error_outline, color: Colors.red, size: 18), const SizedBox(width: 6), Expanded(child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 13)))]),
                                ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 50,
                                child: FilledButton(
                                  onPressed: _busy ? null : _submit,
                                  child: _busy
                                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : Text(_register ? loc.register : loc.signingIn, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              if (_canBioLogin && !_register) ...[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _busy ? null : _biometricLogin,
                                  icon: const Icon(Icons.fingerprint),
                                  label: const Text('Sign in with biometrics'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (!_register)
                      TextButton.icon(
                        onPressed: _busy ? null : _enterAsGuest,
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        icon: const Icon(Icons.explore_outlined),
                        label: const Text('Browse as guest — no account needed'),
                      ),
                    TextButton.icon(
                      onPressed: _busy ? null : _editServerUrl,
                      style: TextButton.styleFrom(foregroundColor: Colors.white70),
                      icon: const Icon(Icons.dns_outlined, size: 16),
                      label: Text('Server: ${Api.baseUrl}', style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _enterAsGuest() async {
    await _goHome();
  }

  Widget _header(ColorScheme scheme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
          child: const Icon(Icons.shield_moon_outlined, size: 56, color: Colors.white),
        ),
        const SizedBox(height: 12),
        const Text('ZEGA-ALERT', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const Text('Emergency & crime reporting for every Ethiopian', style: TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _modeToggle(AppLocalizations loc) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(child: _toggleButton('Sign in', !_register, () => setState(() => _register = false))),
          Expanded(child: _toggleButton('Create account', _register, () => setState(() => _register = true))),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool selected, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
