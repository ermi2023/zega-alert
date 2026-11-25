import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/biometric_service.dart';
import '../widgets/auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import '../main.dart';

/// Login screen for ZEGA-ALERT.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  // Focus nodes for keyboard management
  final _identifierFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // State
  bool _isLoading = false;
  bool _canBioLogin = false;
  String _error = '';
  bool _isKeyboardVisible = false;

  // Animations
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initBiometrics();
    _setupFocusListeners();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: ZegaTheme.durationNormal,
      vsync: this,
    );
    _slideController = AnimationController(
      duration: ZegaTheme.durationNormal,
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  void _setupFocusListeners() {
    _identifierFocus.addListener(_onFocusChange);
    _passwordFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    final keyboardVisible =
        _identifierFocus.hasFocus || _passwordFocus.hasFocus;
    if (keyboardVisible != _isKeyboardVisible && mounted) {
      setState(() => _isKeyboardVisible = keyboardVisible);
    }
  }

  Future<void> _initBiometrics() async {
    final available = await BiometricService.isAvailable();
    if (mounted) {
      setState(() => _canBioLogin = available && Api.refreshToken != null);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _identifierFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Normalize phone number to local format expected by backend
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

  /// Validate email
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional field
    if (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim()))
      return null;
    return 'Enter a valid email address';
  }

  /// Combined validator for identifier (phone or email)
  String? _validateIdentifier(String? value) {
    final loc = AppLocalizations.of(context);
    if (value == null || value.trim().isEmpty) {
      return loc.required;
    }
    final trimmed = value.trim();
    if (trimmed.contains('@')) {
      return _validateEmail(trimmed);
    }
    final phone = _normalizePhone(trimmed);
    return phone.length == 10 && phone.startsWith('0')
        ? null
        : 'Enter a valid phone number or email';
  }

  /// Validate password
  String? _validatePassword(String? value) {
    final loc = AppLocalizations.of(context);
    if (value == null || value.isEmpty) {
      return loc.required;
    }
    return null;
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') ||
        s.contains('ClientException') ||
        s.toLowerCase().contains('timeout') ||
        s.contains('errno = 110')) {
      return 'Cannot reach the server at ${Api.baseUrl}.\nCheck your internet connection.';
    }
    if (s.toLowerCase().contains('unauthorized') ||
        s.toLowerCase().contains('invalid credentials')) {
      return 'Invalid phone/email or password. Please try again.';
    }
    if (s.toLowerCase().contains('not found') ||
        s.toLowerCase().contains('user not found')) {
      return 'No account found with this phone/email.';
    }
    return s;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!mounted) return;

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _error = '';
      _isLoading = true;
    });

    try {
      final identifier = _identifierController.text.trim();
      final body = identifier.contains('@')
          ? {'email': identifier, 'password': _passwordController.text}
          : {
              'phone': _normalizePhone(identifier),
              'password': _passwordController.text,
            };

      final data = await Api.post('/auth/login', body);

      if (!mounted) return;

      await Api.setToken(
        data['accessToken'],
        userId: data['user']['id'] as String,
      );
      await Api.setRefreshToken(data['refreshToken']);
      await Api.setProfile(data['user'] as Map<String, dynamic>?);

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    } catch (e) {
      if (mounted) {
        setState(() => _error = _friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _biometricLogin() async {
    if (!mounted) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _error = '';
      _isLoading = true;
    });

    try {
      final ok = await BiometricService.authenticate();
      if (!ok) {
        if (mounted)
          setState(() => _error = 'Biometric authentication cancelled.');
        return;
      }
      final refreshed = await Api.refreshSession();
      if (!refreshed) {
        if (mounted)
          setState(
            () =>
                _error = 'Session expired. Please sign in with your password.',
          );
        return;
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToRegister() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  void _continueAsGuest() {
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
  }

  void _navigateToForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          initialPhone: _identifierController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return ZegaAuthScreen(
      backgroundColor: ZegaTheme.primaryNavy,
      resizeToAvoidBottomInset: true,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isKeyboardOpen =
                  MediaQuery.of(context).viewInsets.bottom > 100;
              final heroHeight =
                  (constraints.maxHeight * (isKeyboardOpen ? 0.22 : 0.37))
                      .clamp(
                        isKeyboardOpen ? 104.0 : 170.0,
                        isKeyboardOpen ? 145.0 : 280.0,
                      )
                      .toDouble();

              return Column(
                children: [
                  SizedBox(
                    height: heroHeight,
                    child: _buildBrandingHeader(heroHeight),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: ZegaTheme.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          20,
                          26,
                          20,
                          isKeyboardOpen ? 16 : 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Welcome Back',
                              textAlign: TextAlign.center,
                              style: ZegaTheme.headlineSmall.copyWith(
                                color: ZegaTheme.primaryNavy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Thank you for helping keep our community safe.',
                              textAlign: TextAlign.center,
                              style: ZegaTheme.bodySmall.copyWith(
                                color: ZegaTheme.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildLoginForm(loc),
                            const SizedBox(height: 14),
                            _buildRegistrationNavigation(loc),
                            TextButton(
                              onPressed: _isLoading ? null : _continueAsGuest,
                              style: TextButton.styleFrom(
                                foregroundColor: ZegaTheme.secondaryText,
                                textStyle: ZegaTheme.bodySmall,
                              ),
                              child: const Text('Skip'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBrandingHeader(double height) {
    final logoSize = (height * 0.46).clamp(64.0, 104.0).toDouble();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'ZEGA-ALERT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(AppLocalizations loc) {
    return Form(
      key: _formKey,
      onChanged: () => setState(() {}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ZegaTextField(
            controller: _identifierController,
            focusNode: _identifierFocus,
            label: 'Phone Number or Email',
            hint: 'e.g., +251 911 234 567 or user@email.com',
            prefixIcon: Icons.person_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _validateIdentifier,
            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: 16),
          ZegaPasswordField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            label: loc.password,
            hint: 'Enter your password',
            textInputAction: TextInputAction.done,
            validator: _validatePassword,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildErrorBanner(),
          ],
          const SizedBox(height: 18),
          ZegaPrimaryButton(
            label: 'Log In',
            onPressed: _isLoading ? null : _submit,
            isLoading: _isLoading,
            isEnabled: _formKey.currentState?.validate() ?? false,
            height: 52,
            borderRadius: 28,
          ),
          Align(
            alignment: Alignment.center,
            child: ZegaTextButton(
              label: 'Forgot your password?',
              onPressed: _isLoading ? null : _navigateToForgotPassword,
              style: ZegaTheme.bodySmall.copyWith(
                color: ZegaTheme.primaryNavy,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_canBioLogin && !_isLoading) ...[
            const SizedBox(height: 8),
            ZegaSecondaryButton(
              label: 'Sign in with Biometrics',
              onPressed: _biometricLogin,
              leadingIcon: Icons.fingerprint,
              height: 48,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(ZegaTheme.space16),
      decoration: BoxDecoration(
        color: ZegaTheme.mainText.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(ZegaTheme.radiusMedium),
        border: Border.all(color: ZegaTheme.mainText.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: ZegaTheme.mainText,
            size: 20,
          ),
          const SizedBox(width: ZegaTheme.space12),
          Expanded(
            child: Text(
              _error,
              style: ZegaTheme.bodyMedium.copyWith(
                color: ZegaTheme.mainText,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationNavigation(AppLocalizations loc) {
    return ZegaAuthNavigation(
      label: "Don't have an account?",
      actionLabel: 'Sign up',
      onActionPressed: _navigateToRegister,
      labelStyle: ZegaTheme.bodyMedium.copyWith(color: Colors.white70),
      actionStyle: ZegaTheme.labelLarge.copyWith(
        fontWeight: FontWeight.w600,
        color: ZegaTheme.warningAmber,
      ),
    );
  }
}
