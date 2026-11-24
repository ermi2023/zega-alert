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

/// Premium Login Screen for ZEGA-ALERT
/// Implements the exact design specification with:
/// - Branding Header (logo, app name, tagline)
/// - Welcome Section (headline + supportive text)
/// - Login Form (phone/email + password with validation)
/// - Sign In Button (primary CTA with loading state)
/// - Registration Navigation (link to create account)
/// - Security Footer (trust indicator)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
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
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  void _setupFocusListeners() {
    _identifierFocus.addListener(_onFocusChange);
    _passwordFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    final keyboardVisible = _identifierFocus.hasFocus || _passwordFocus.hasFocus;
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
    if (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) return null;
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
    return phone.length == 10 && phone.startsWith('0') ? null : 'Enter a valid phone number or email';
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
    if (s.toLowerCase().contains('unauthorized') || s.toLowerCase().contains('invalid credentials')) {
      return 'Invalid phone/email or password. Please try again.';
    }
    if (s.toLowerCase().contains('not found') || s.toLowerCase().contains('user not found')) {
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
          : {'phone': _normalizePhone(identifier), 'password': _passwordController.text};

      final data = await Api.post('/auth/login', body);

      if (!mounted) return;

      await Api.setToken(data['accessToken'], userId: data['user']['id'] as String);
      await Api.setRefreshToken(data['refreshToken']);
      await Api.setProfile(data['user'] as Map<String, dynamic>?);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
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
        if (mounted) setState(() => _error = 'Biometric authentication cancelled.');
        return;
      }
      final refreshed = await Api.refreshSession();
      if (!refreshed) {
        if (mounted) setState(() => _error = 'Session expired. Please sign in with your password.');
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 100;

    return ZegaAuthScreen(
      backgroundColor: ZegaTheme.background,
      resizeToAvoidBottomInset: true,
      child: ZegaAuthBackground(
        child: Column(
          children: [
            // Spacer to push content down slightly on large screens
            SizedBox(height: isKeyboardOpen ? ZegaTheme.space8 : ZegaTheme.space24),

            // Main content with animations
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: isKeyboardOpen ? ZegaTheme.space16 : ZegaTheme.space32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ============================================================
                        // BRANDING HEADER
                        // ============================================================
                        _buildBrandingHeader(loc),

                        const SizedBox(height: ZegaTheme.space32),

                        // ============================================================
                        // WELCOME SECTION
                        // ============================================================
                        _buildWelcomeSection(loc),

                        const SizedBox(height: ZegaTheme.space32),

                        // ============================================================
                        // LOGIN FORM CARD
                        // ============================================================
                        _buildLoginFormCard(loc),

                        const SizedBox(height: ZegaTheme.space24),

                        // ============================================================
                        // REGISTRATION NAVIGATION
                        // ============================================================
                        _buildRegistrationNavigation(loc),

                        const SizedBox(height: ZegaTheme.space24),

                        // ============================================================
                        // SECURITY FOOTER
                        // ============================================================
                        _buildSecurityFooter(),

                        // Bottom spacing for keyboard
                        SizedBox(height: isKeyboardOpen ? ZegaTheme.space16 : ZegaTheme.space8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingHeader(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Federal Police Logo
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZegaTheme.radiusRound),
            boxShadow: [
              BoxShadow(
                color: ZegaTheme.primaryNavy.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Center(
            child: Image(
              image: AssetImage('assets/images/efp_logo.png'),
              width: 36,
              height: 36,
            ),
          ),
        ),
        const SizedBox(height: ZegaTheme.space16),

        // App Logo / Shield Badge
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: ZegaTheme.primaryGradient,
            borderRadius: BorderRadius.circular(ZegaTheme.radiusRound),
            boxShadow: [
              BoxShadow(
                color: ZegaTheme.primaryNavy.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.shield_outlined,
              color: ZegaTheme.white,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: ZegaTheme.space16),

        // App Name
        Text(
          'ZEGA-ALERT',
          style: ZegaTheme.headlineMedium.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: ZegaTheme.primaryNavy,
            height: 1.2,
          ),
        ),
        const SizedBox(height: ZegaTheme.space8),

        // Tagline
        Text(
          'Your Safety, Our Priority.',
          style: ZegaTheme.bodyLarge.copyWith(
            color: ZegaTheme.secondaryText,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWelcomeSection(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Welcome Back',
          style: ZegaTheme.headlineSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: ZegaTheme.mainText,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ZegaTheme.space12),
        Text(
          'Sign in to access your account and stay connected to your community safety network.',
          style: ZegaTheme.bodyLarge.copyWith(
            color: ZegaTheme.secondaryText,
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginFormCard(AppLocalizations loc) {
    return ZegaAuthCard(
      child: Form(
        key: _formKey,
        onChanged: () => setState(() {}),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Phone/Email Field
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
              autofocus: true,
            ),
            const SizedBox(height: ZegaTheme.space20),

            // Password Field
            ZegaPasswordField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              label: loc.password,
              hint: 'Enter your password',
              textInputAction: TextInputAction.done,
              validator: _validatePassword,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: ZegaTheme.space16),

            // Forgot Password Link
            Align(
              alignment: Alignment.centerRight,
              child: ZegaTextButton(
                label: 'Forgot Password?',
                onPressed: _isLoading ? null : _navigateToForgotPassword,
                style: ZegaTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: ZegaTheme.secondaryBlue,
                ),
              ),
            ),

            // Error Message
            if (_error.isNotEmpty) ...[
              const SizedBox(height: ZegaTheme.space16),
              _buildErrorBanner(),
            ],

            const SizedBox(height: ZegaTheme.space24),

            // Sign In Button
            ZegaPrimaryButton(
              label: loc.signingIn,
              onPressed: _isLoading ? null : _submit,
              isLoading: _isLoading,
              isEnabled: _formKey.currentState?.validate() ?? false,
              leadingIcon: Icons.login_rounded,
              height: 56,
            ),

            // Biometric Login
            if (_canBioLogin && !_isLoading) ...[
              const SizedBox(height: ZegaTheme.space16),
              ZegaSecondaryButton(
                label: 'Sign in with Biometrics',
                onPressed: _biometricLogin,
                leadingIcon: Icons.fingerprint,
                height: 52,
              ),
            ],
          ],
        ),
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
      actionLabel: 'Create Account',
      onActionPressed: _navigateToRegister,
      labelStyle: ZegaTheme.bodyMedium.copyWith(color: ZegaTheme.secondaryText),
      actionStyle: ZegaTheme.labelLarge.copyWith(
        fontWeight: FontWeight.w600,
        color: ZegaTheme.secondaryBlue,
      ),
    );
  }

  Widget _buildSecurityFooter() {
    return ZegaSecurityFooter(
      message: 'Your information is protected with bank-grade encryption.',
      icon: Icons.verified_user_outlined,
    );
  }
}