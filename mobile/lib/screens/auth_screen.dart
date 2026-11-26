import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/constants.dart';
import '../l10n/app_localizations.dart';
import 'forgot_password_screen.dart';
import '../services/api.dart';
import '../services/biometric_service.dart';
import '../main.dart';

const Color _etGreen = Color(0xFF078930);
const Color _etYellow = Color(0xFFFCDD09);
const Color _etRed = Color(0xFFDA121A);
const Color _deepGreen = Color(0xFF0C2D48);
const Color _ink = Color(0xFF0A1929);
const Color _brandNavy = Color(0xFF183C59);
const Color _policeGold = Color(0xFFF59E0B);
// Pre-blended constants (equivalent to withValues(alpha: 0.55)) so they can be
// used inside a const widget tree — withValues() is a runtime method.
// alpha 0.55 = 0x8C; alpha 0.78 = 0xC7; alpha 0.92 = 0xEB.
const Color _brandNavyAlpha55 = Color(0x8C183C59);
const Color _policeGoldAlpha55 = Color(0x8CF59E0B);
const Color _brandNavyAlpha78 = Color(0xC7183C59);
const Color _brandNavyAlpha92 = Color(0xEB183C59);

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
  bool _acceptedTerms = false;
  String _error = '';
  String? _region;
  String? _subCity;

  bool get _formIsValid {
    if (_busy) return false;
    if (!_register) {
      final identifier = _id.text.trim();
      final isEmail = identifier.contains('@');
      final idValid = isEmail
          ? RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(identifier)
          : _normalizePhone(identifier).length == 10 &&
                _normalizePhone(identifier).startsWith('0');
      return idValid && _password.text.isNotEmpty;
    }
    return _name.text.trim().isNotEmpty &&
        _normalizePhone(_phone.text).length == 10 &&
        _normalizePhone(_phone.text).startsWith('0') &&
        _registrationPasswordError(_password.text) == null &&
        _acceptedTerms &&
        _region != null;
  }

  String? _registrationPasswordError(String? value) {
    if (value == null || value.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Include an uppercase letter, number and symbol';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _initBiometrics();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    try {
      final r = await Api.get('/app/version');
      final latest = r['version']?.toString() ?? '';
      final url = r['url']?.toString();
      if (latest.isNotEmpty &&
          latest != Api.appVersion &&
          url != null &&
          mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Update available'),
            content: Text('Version $latest is available. Update now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: const Text('Download'),
              ),
            ],
          ),
        );
      }
    } catch (_) {}
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
    setState(() {
      _error = '';
      _busy = true;
    });
    try {
      final ok = await BiometricService.authenticate();
      if (!ok) {
        setState(() => _error = 'Biometric authentication cancelled.');
        return;
      }
      final refreshed = await Api.refreshSession();
      if (!refreshed) {
        setState(
          () => _error =
              Api.refreshFailureMessage ??
              'Your session has ended. Please sign in again.',
        );
        return;
      }
      if (mounted)
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    } catch (e) {
      setState(() => _error = Api.userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _goHome() async {
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _error = '';
      _busy = true;
    });
    try {
      if (_register) {
        if (_region == null) {
          setState(() {
            _error = 'Please select your region.';
            _busy = false;
          });
          return;
        }
        final phone = _normalizePhone(_phone.text.trim());
        if (phone.length != 10 || !phone.startsWith('0')) {
          setState(() {
            _error = 'Enter a valid phone number, e.g. 0911234567.';
            _busy = false;
          });
          return;
        }
        if (!_acceptedTerms) {
          setState(() {
            _error = 'You must accept the Terms of Service to register.';
            _busy = false;
          });
          return;
        }
        Map<String, dynamic>? registered;
        try {
          registered = await Api.post('/auth/register', {
            'full_name': _name.text.trim(),
            'phone': phone,
            'email': _email.text.trim(),
            'password': _password.text,
            'region': _region,
            'sub_city': _subCity,
            'accepted_terms': true,
            'accepted_privacy': true,
          }) as Map<String, dynamic>?;
        } on ApiException catch (e) {
          // A previous attempt may have created the account even if this
          // device never received the response. Fall through to sign-in.
          if (!e.message.toLowerCase().contains('already exists')) rethrow;
        }

        // Phone verification is best-effort: when the SMS gateway delivers an
        // OTP we prompt for it, otherwise the server returns the code (or has
        // already trusted the signup). Either way we must never block sign-in.
        final devOtp = registered?['devOtp']?.toString();
        if (devOtp == null || devOtp.isEmpty) {
          final otp = await _askOtp();
          if (otp != null && otp.isNotEmpty) {
            try {
              await Api.post('/auth/verify-otp', {
                'contact': phone,
                'code': otp,
                'purpose': 'verify_phone',
              });
            } catch (_) {
              /* verification is optional; continue to sign-in */
            }
          }
        } else {
          try {
            await Api.post('/auth/verify-otp', {
              'contact': phone,
              'code': devOtp,
              'purpose': 'verify_phone',
            });
          } catch (_) {}
        }

        final data = await Api.post('/auth/login', {
          'phone': phone,
          'password': _password.text,
        });
        await _persistSession(data);
        await _goHome();
        return;
      }

      final id = _id.text.trim();
      final body = id.contains('@')
          ? {'email': id, 'password': _password.text}
          : {'phone': _normalizePhone(id), 'password': _password.text};
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
    await Api.setToken(
      data['accessToken'],
      userId: data['user']['id'] as String,
    );
    await Api.setRefreshToken(data['refreshToken']);
    await Api.setProfile(data['user'] as Map<String, dynamic>?);
  }

  /// Accepts local (09xxxxxxxx / 9xxxxxxxx) and international (+251...) forms
  /// and stores the local format the backend uses.
  String _normalizePhone(String raw) {
    var p = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (p.startsWith('+251')) {
      p = p.substring(4);
    } else if (p.startsWith('251') && p.length > 9) {
      p = p.substring(3);
    }
    if (p.isEmpty || p.startsWith('0')) return p;
    return p.length == 9 ? '0$p' : p;
  }

  String _friendlyError(Object e) {
    return Api.userMessage(
      e,
      fallback:
          'Could not connect. Check your internet connection and try again.',
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
            Text(
              'Current: ${Api.baseUrl}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Auto-detect'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await Api.setBaseUrl(result);
    if (mounted) setState(() {});
  }

  Future<String?> _askOtp() async {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.enterOtp),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: loc.checkOtpHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(loc.verify),
          ),
        ],
      ),
    );
    return code;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomPad = (bottomInset - 22).clamp(10.0, 60.0).toDouble();

    return Scaffold(
      backgroundColor: _ink,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _hero(),
            Transform.translate(
              offset: const Offset(0, -34),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _card(scheme, loc),
                  ),
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: _busy ? null : _enterAsGuest,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text('Continue as guest'),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _editServerUrl,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                    icon: const Icon(Icons.dns_outlined, size: 16),
                    label: Text(
                      'Server: ${Api.baseUrl}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  SizedBox(height: bottomPad),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enterAsGuest() async {
    await _goHome();
  }

  Future<void> _forgotPassword() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(initialPhone: _id.text.trim()),
      ),
    );
  }

  Widget _hero() {
    return SizedBox(
      height: 336,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.none,
            scale: 3.2,
            alignment: Alignment.center,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_brandNavyAlpha78, _brandNavyAlpha92, _ink],
                stops: const [0.0, 0.58, 1.0],
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -52,
            child: Transform.rotate(
              angle: 0.65,
              child: const SizedBox(
                width: 56,
                height: 310,
                child: Column(
                  children: [
                    Expanded(child: ColoredBox(color: _brandNavyAlpha55)),
                    Expanded(child: ColoredBox(color: _policeGoldAlpha55)),
                    Expanded(child: ColoredBox(color: _brandNavyAlpha55)),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 54),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _shieldBadge(),
                      const SizedBox(width: 14),
                      Expanded(child: _wordmark()),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'Your Safety, Our Priority.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wordmark() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'ZEGA-ALERT',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: const SizedBox(
            width: 104,
            height: 5,
            child: Row(
              children: [
                Expanded(child: ColoredBox(color: _brandNavy)),
                Expanded(child: ColoredBox(color: _policeGold)),
                Expanded(child: ColoredBox(color: _brandNavy)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _shieldBadge() {
    return SizedBox(
      width: 76,
      height: 88,
      child: PhysicalShape(
        clipper: _ShieldClipper(),
        color: Colors.white,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.55),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: ClipPath(
            clipper: _ShieldClipper(),
            child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _card(ColorScheme scheme, AppLocalizations loc) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 38,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Form(
        key: _form,
        onChanged: () => setState(() {}),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _modeToggle(loc),
            const SizedBox(height: 22),
            Text(
              _register ? 'Create your account' : 'Welcome back!',
              style: const TextStyle(
                color: Color(0xFF142B4A),
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _register
                  ? 'Join ZEGA-ALERT to help keep your community safe.'
                  : 'Sign in to access your account and stay connected.',
              style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 18),
            if (_register) ...[
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: loc.fullName,
                  prefixIcon: const Icon(Icons.person_outline),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? loc.required : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: loc.phone,
                  hintText: '911 234 567',
                  prefixText: '+251 ',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  helperText: 'Ethiopian mobile number',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return loc.required;
                  final phone = _normalizePhone(v);
                  return phone.length == 10 && phone.startsWith('0')
                      ? null
                      : 'Enter a valid Ethiopian mobile number.';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  helperText: 'Add an email so you can also sign in with it',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _region,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: loc.regionLabel,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: const OutlineInputBorder(),
                ),
                items: ethiopianRegions
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  _region = v;
                  _subCity = subCitiesByRegion[v]?.first;
                }),
              ),
              if ((subCitiesByRegion[_region] ?? []).isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _subCity,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: loc.subCityLabel,
                    prefixIcon: const Icon(Icons.location_city_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  items: subCitiesByRegion[_region]!
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _subCity = v),
                ),
              ],
              const SizedBox(height: 12),
            ] else ...[
              TextFormField(
                controller: _id,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Phone number or email',
                  hintText: 'e.g. +251 911 234 567',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final id = value?.trim() ?? '';
                  if (id.isEmpty) return loc.required;
                  if (id.contains('@')) {
                    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(id)
                        ? null
                        : 'Enter a valid email address.';
                  }
                  final phone = _normalizePhone(id);
                  return phone.length == 10 && phone.startsWith('0')
                      ? null
                      : 'Enter a valid phone number.';
                },
              ),
              const SizedBox(height: 12),
            ],
            if (_register) ...[
              Row(
                children: [
                  Checkbox(
                    value: _acceptedTerms,
                    activeColor: const Color(
                      0xFF1E40AF,
                    ), // Police Blue when checked
                    checkColor: Colors.white,
                    onChanged: (bool? value) {
                      setState(() {
                        _acceptedTerms = value ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _acceptedTerms = !_acceptedTerms);
                      },
                      child: const Text(
                        'I accept the Terms of Service and Privacy Policy',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _busy ? null : _submit(),
              decoration: InputDecoration(
                labelText: loc.password,
                helperText: _register
                    ? 'At least 8 characters with an uppercase letter, number and symbol.'
                    : null,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
                border: const OutlineInputBorder(),
              ),
              validator: _register
                  ? _registrationPasswordError
                  : (v) => (v == null || v.isEmpty) ? loc.required : null,
            ),
            if (!_register)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _forgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.blueGrey,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error,
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _formIsValid ? _submit : null,
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _register ? 'Sign Up' : loc.signingIn,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
            if (!_register) ...[
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF0D9488),
                    size: 16,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Your information is protected.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _modeToggle(AppLocalizations loc) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          Expanded(
            child: _toggleButton(
              'Sign in',
              !_register,
              () => setState(() => _register = false),
            ),
          ),
          Expanded(
            child: _toggleButton(
              'Create account',
              _register,
              () => setState(() => _register = true),
            ),
          ),
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
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

class _ShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.16)
      ..lineTo(w, h * 0.52)
      ..quadraticBezierTo(w, h * 0.86, w * 0.5, h)
      ..quadraticBezierTo(0, h * 0.86, 0, h * 0.52)
      ..lineTo(0, h * 0.16)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
