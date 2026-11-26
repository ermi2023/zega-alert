import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialPhone = ''});

  final String initialPhone;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phone = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocus = List.generate(6, (_) => FocusNode());
  final _phoneForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  Timer? _countdown;
  String? _resetToken;
  String? _developmentCode;
  String? _error;
  bool _busy = false;
  bool _showPassword = false;
  int _step = 0;
  int _secondsUntilResend = 0;

  @override
  void initState() {
    super.initState();
    _phone.text = widget.initialPhone;
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _phone.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final focus in _otpFocus) {
      focus.dispose();
    }
    super.dispose();
  }

  String _normalizedPhone() {
    var value = _phone.text.replaceAll(RegExp(r'[\s\-()]'), '');
    if (value.startsWith('+251')) {
      value = value.substring(4);
    } else if (value.startsWith('251') && value.length > 9) {
      value = value.substring(3);
    }
    if (value.length == 9) value = '0$value';
    return value;
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (!resend && !(_phoneForm.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await Api.post('/auth/request-otp', {
        'contact': _normalizedPhone(),
        'purpose': 'reset_password',
      });
      if (!mounted) return;
      _developmentCode = response is Map
          ? response['devOtp']?.toString()
          : null;
      if (resend) {
        for (final controller in _otpControllers) {
          controller.clear();
        }
      }
      setState(() {
        _step = 1;
        _secondsUntilResend = 60;
      });
      _startCountdown();
      _otpFocus.first.requestFocus();
    } catch (e) {
      if (mounted) setState(() => _error = Api.userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _secondsUntilResend <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsUntilResend = 0);
      } else {
        setState(() => _secondsUntilResend--);
      }
    });
  }

  Future<void> _verifyCode() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit verification code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await Api.post('/auth/verify-otp', {
        'contact': _normalizedPhone(),
        'code': code,
        'purpose': 'reset_password',
      });
      if (!mounted) return;
      _resetToken = response is Map ? response['resetToken']?.toString() : null;
      if (_resetToken == null || _resetToken!.isEmpty) {
        throw ApiException('The server did not confirm the verification.');
      }
      setState(() => _step = 2);
    } catch (e) {
      if (mounted) setState(() => _error = Api.userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePassword() async {
    if (!_passwordForm.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.post('/auth/reset-password', {
        'reset_token': _resetToken,
        'new_password': _newPassword.text,
      });
      if (!mounted) return;
      setState(() => _step = 3);
    } catch (e) {
      if (mounted) setState(() => _error = Api.userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FA),
        foregroundColor: const Color(0xFF142B4A),
        elevation: 0,
        title: const Text('Account recovery'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Card(
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: _step == 3
                      ? _success(colors)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _progress(colors),
                            const SizedBox(height: 24),
                            Icon(
                              _step == 0
                                  ? Icons.shield_outlined
                                  : _step == 1
                                  ? Icons.sms_outlined
                                  : Icons.lock_reset_outlined,
                              size: 42,
                              color: const Color(0xFF2563EB),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _step == 0
                                  ? 'Forgot password?'
                                  : _step == 1
                                  ? 'Verify your number'
                                  : 'Create a new password',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF142B4A),
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _step == 0
                                  ? 'We’ll send a verification code to the phone number on your account.'
                                  : _step == 1
                                  ? 'Enter the 6-digit code sent to ${_normalizedPhone()}.'
                                  : 'Choose a strong password you have not used before.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_step == 0) _phoneInput(),
                            if (_step == 1) ...[
                              _otpInput(),
                              if (_developmentCode != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFED7AA),
                                    ),
                                  ),
                                  child: Text(
                                    'Development OTP (shown because SMS delivery is unavailable): '
                                    '$_developmentCode. Available only from non-production servers.',
                                    style: const TextStyle(
                                      color: Color(0xFF9A3412),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _busy || _secondsUntilResend > 0
                                      ? null
                                      : () => _sendCode(resend: true),
                                  child: Text(
                                    _secondsUntilResend > 0
                                        ? 'Resend code in ${_secondsUntilResend}s'
                                        : 'Resend code',
                                  ),
                                ),
                              ),
                            ],
                            if (_step == 2) _passwordInputs(),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 52,
                              child: FilledButton(
                                onPressed: _busy
                                    ? null
                                    : _step == 0
                                    ? () => _sendCode()
                                    : _step == 1
                                    ? _verifyCode
                                    : _savePassword,
                                child: _busy
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _step == 0
                                            ? 'Send verification code'
                                            : _step == 1
                                            ? 'Verify code'
                                            : 'Save new password',
                                      ),
                              ),
                            ),
                            if (_step > 0)
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                        _step = 0;
                                        _error = null;
                                      }),
                                child: const Text(
                                  'Use a different phone number',
                                ),
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

  Widget _progress(ColorScheme colors) {
    return Row(
      children: List.generate(3, (index) {
        final active = index <= _step;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
            decoration: BoxDecoration(
              color: active ? colors.primary : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

  Widget _phoneInput() {
    return Form(
      key: _phoneForm,
      child: TextFormField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d+\s()-]')),
        ],
        decoration: InputDecoration(
          labelText: 'Phone number',
          hintText: '911 234 567',
          prefixText: '+251 ',
          prefixIcon: const Icon(Icons.phone_outlined),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        validator: (_) => _normalizedPhone().length == 10
            ? null
            : 'Enter a valid Ethiopian mobile number.',
      ),
    );
  }

  Widget _otpInput() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = ((constraints.maxWidth - 30) / 6)
            .clamp(34.0, 44.0)
            .toDouble();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: width,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocus[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    _otpFocus[index + 1].requestFocus();
                  } else if (value.isEmpty && index > 0) {
                    _otpFocus[index - 1].requestFocus();
                  }
                },
              ),
            );
          }),
        );
      },
    );
  }

  Widget _passwordInputs() {
    return Form(
      key: _passwordForm,
      child: Column(
        children: [
          TextFormField(
            controller: _newPassword,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            validator: (value) => value != null && value.length >= 8
                ? null
                : 'Use at least 8 characters.',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmPassword,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: 'Confirm new password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            validator: (value) =>
                value == _newPassword.text ? null : 'Passwords do not match.',
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Use at least 8 characters.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _success(ColorScheme colors) {
    return Column(
      children: [
        Icon(Icons.check_circle, color: colors.primary, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Password reset successful!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF142B4A),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your password has been updated. Sign in with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B), height: 1.45),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to sign in'),
          ),
        ),
      ],
    );
  }
}
