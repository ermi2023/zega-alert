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
  final _phone = TextEditingController(text: '0911000005');
  final _password = TextEditingController(text: 'password123');
  final _name = TextEditingController();
  bool _register = false;
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

  Future<void> _submit() async {
    setState(() { _error = ''; _busy = true; });
    try {
      if (_register) {
        if (_region == null) {
          setState(() { _error = 'Please select your region.'; _busy = false; });
          return;
        }
        await Api.post('/auth/register', {
          'full_name': _name.text.trim(),
          'phone': _phone.text.trim(),
          'password': _password.text,
          'region': _region,
          'sub_city': _subCity,
        });
        final otp = await _askOtp();
        await Api.post('/auth/verify-otp', {'contact': _phone.text.trim(), 'code': otp, 'purpose': 'verify_phone'});
      }
      final data = await Api.post('/auth/login', {'phone': _phone.text.trim(), 'password': _password.text});
      await Api.setToken(data['accessToken'], userId: data['user']['id'] as String);
      await Api.setRefreshToken(data['refreshToken']);
      await Api.setProfile(data['user'] as Map<String, dynamic>?);
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
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
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_register ? loc.createAccount : loc.signingIn, style: Theme.of(context).textTheme.headlineSmall),
                      Text(loc.emergencyAndCrime, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 20),
                      if (_register) TextFormField(controller: _name, decoration: InputDecoration(labelText: loc.fullName, border: const OutlineInputBorder())),
                      if (_register) const SizedBox(height: 12),
                      if (_register) DropdownButtonFormField<String>(
                        value: _region,
                        decoration: InputDecoration(labelText: loc.regionLabel, border: const OutlineInputBorder()),
                        items: ethiopianRegions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (v) => setState(() {
                          _region = v;
                          _subCity = subCitiesByRegion[v]?.first;
                        }),
                      ),
                      if (_register && (subCitiesByRegion[_region] ?? []).isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _subCity,
                          decoration: InputDecoration(labelText: loc.subCityLabel, border: const OutlineInputBorder()),
                          items: subCitiesByRegion[_region]!.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => setState(() => _subCity = v),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(controller: _phone, decoration: InputDecoration(labelText: loc.phone, border: const OutlineInputBorder())),
                      const SizedBox(height: 12),
                      TextFormField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: loc.password, border: const OutlineInputBorder())),
                      if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error, style: const TextStyle(color: Colors.red))),
                      const SizedBox(height: 20),
                      FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? loc.pleaseWait : (_register ? loc.register : loc.signingIn))),
                      if (_canBioLogin) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _biometricLogin,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Login with biometrics'),
                        ),
                      ],
                      TextButton(
                        onPressed: () => setState(() => _register = !_register),
                        child: Text(_register ? loc.alreadyHaveAccount : loc.newHere),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
