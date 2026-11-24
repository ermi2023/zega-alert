import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../config/theme.dart';
import '../config/constants.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/location_service.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';
import '../main.dart';

/// Premium Registration Screen for ZEGA-ALERT
/// Implements the exact design specification with:
/// - Header with back navigation
/// - Registration Form (5 fields + dropdowns)
/// - Location permission toggle
/// - Terms & Privacy Policy checkbox
/// - Create Account Button
/// - Login Navigation link
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Focus nodes
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  // State
  bool _isLoading = false;
  String _error = '';
  String? _selectedRegion;
  String? _selectedSubCity;
  bool _acceptedTerms = false;
  bool _isKeyboardVisible = false;
  bool _useDeviceLocation = false;
  bool _isFetchingLocation = false;
  String? _detectedAddress;

  // Animations
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
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
    _nameFocus.addListener(_onFocusChange);
    _phoneFocus.addListener(_onFocusChange);
    _emailFocus.addListener(_onFocusChange);
    _passwordFocus.addListener(_onFocusChange);
    _confirmPasswordFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    final keyboardVisible = _nameFocus.hasFocus ||
        _phoneFocus.hasFocus ||
        _emailFocus.hasFocus ||
        _passwordFocus.hasFocus ||
        _confirmPasswordFocus.hasFocus;
    if (keyboardVisible != _isKeyboardVisible && mounted) {
      setState(() => _isKeyboardVisible = keyboardVisible);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
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

  /// Validate full name
  String? _validateName(String? value) {
    final loc = AppLocalizations.of(context);
    if (value == null || value.trim().isEmpty) {
      return loc.required;
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  /// Validate phone number (Ethiopian mobile) - required for registration
  String? _validatePhone(String? value) {
    final loc = AppLocalizations.of(context);
    if (value == null || value.trim().isEmpty) {
      return loc.required;
    }
    final phone = _normalizePhone(value);
    if (phone.length == 10 && phone.startsWith('0')) return null;
    return 'Enter a valid Ethiopian mobile number (e.g., 0911234567)';
  }

  /// Validate email (optional)
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) return null;
    return 'Enter a valid email address';
  }

  /// Validate password
  String? _validatePassword(String? value) {
    final loc = AppLocalizations.of(context);
    if (value == null || value.isEmpty) {
      return loc.required;
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  /// Validate confirm password
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Validate region selection
  String? _validateRegion(String? value) {
    if (_useDeviceLocation) return null;
    if (value == null || value.isEmpty) {
      return 'Please select your region';
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
    if (s.toLowerCase().contains('already exists') || s.toLowerCase().contains('duplicate')) {
      return 'An account with this phone number or email already exists.';
    }
    if (s.toLowerCase().contains('validation') || s.toLowerCase().contains('invalid')) {
      return 'Please check your information and try again.';
    }
    return s;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_acceptedTerms) {
      setState(() => _error = 'You must accept the Terms of Service and Privacy Policy to register.');
      return;
    }
    if (_selectedRegion == null) {
      setState(() => _error = _useDeviceLocation
          ? 'Could not detect location. Please select region manually.'
          : 'Please check "Use my current location" or select your region.');
      return;
    }
    if (!mounted) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _error = '';
      _isLoading = true;
    });

    try {
      final phone = _normalizePhone(_phoneController.text.trim());

      // Step 1: Register
      Map<String, dynamic>? registered;
      try {
        registered = await Api.post('/auth/register', {
          'full_name': _nameController.text.trim(),
          'phone': phone,
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'region': _selectedRegion,
          'sub_city': _selectedSubCity,
          'accepted_terms': true,
          'accepted_privacy': true,
        }) as Map<String, dynamic>?;
      } on ApiException catch (e) {
        if (!e.message.toLowerCase().contains('already exists')) rethrow;
      }

      // Step 2: Phone verification (best-effort)
      final devOtp = registered?['devOtp']?.toString();
      if (devOtp == null || devOtp.isEmpty) {
        final otp = await _askOtp(phone);
        if (otp != null && otp.isNotEmpty) {
          try {
            await Api.post('/auth/verify-otp',
                {'contact': phone, 'code': otp, 'purpose': 'verify_phone'});
          } catch (_) {}
        }
      } else {
        try {
          await Api.post('/auth/verify-otp',
              {'contact': phone, 'code': devOtp, 'purpose': 'verify_phone'});
        } catch (_) {}
      }

      // Step 3: Auto-login after registration
      if (!mounted) return;
      final data = await Api.post('/auth/login', {
        'phone': phone,
        'password': _passwordController.text,
      });

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

  Future<String?> _askOtp(String phone) async {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZegaTheme.radiusXLarge)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ZegaTheme.primaryNavy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ZegaTheme.radiusMedium),
              ),
              child: const Icon(Icons.sms_outlined, color: ZegaTheme.primaryNavy, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Verify Phone Number')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We\'ve sent a 6-digit code to\n$phone',
              style: ZegaTheme.bodyMedium.copyWith(height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: ZegaTheme.headlineSmall.copyWith(letterSpacing: 8),
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                hintText: '000000',
                filled: true,
                fillColor: ZegaTheme.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ZegaTheme.radiusLarge),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ZegaTheme.radiusLarge),
                  borderSide: const BorderSide(color: ZegaTheme.primaryNavy, width: 2),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: Text('Not Now', style: ZegaTheme.labelLarge),
          ),
          ZegaPrimaryButton(
            label: loc.verify,
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            height: 44,
          ),
        ],
      ),
    );
    return code?.isEmpty ?? true ? null : code;
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _onRegionChanged(String? region) {
    setState(() {
      _selectedRegion = region;
      _selectedSubCity = subCitiesByRegion[region]?.first;
    });
  }

  Future<void> _onToggleUseLocation(bool? value) async {
    final enabled = value ?? false;
    setState(() {
      _useDeviceLocation = enabled;
      _error = '';
    });

    if (!enabled) {
      return;
    }

    setState(() => _isFetchingLocation = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _error = 'Location permission is denied permanently. Please enable it in system settings.';
            _useDeviceLocation = false;
            _isFetchingLocation = false;
          });
        }
        return;
      }

      final pos = await LocationService.best(gpsTimeout: const Duration(seconds: 8));
      if (pos == null) {
        if (mounted) {
          setState(() {
            _error = 'Unable to determine your current location. Please select region manually.';
            _useDeviceLocation = false;
            _isFetchingLocation = false;
          });
        }
        return;
      }

      final geo = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
      String? matchedRegion;
      String? matchedSubCity;
      String? addressText;

      if (geo != null) {
        addressText = geo['address'] as String?;
        final rName = (geo['region'] ?? geo['city'] ?? '').toString().toLowerCase();
        for (final r in ethiopianRegions) {
          if (rName.contains(r.toLowerCase()) || r.toLowerCase().contains(rName)) {
            matchedRegion = r;
            break;
          }
        }
        if (matchedRegion != null) {
          final subCities = subCitiesByRegion[matchedRegion] ?? [];
          final cName = (geo['city'] ?? geo['locality'] ?? '').toString().toLowerCase();
          for (final sc in subCities) {
            if (cName.contains(sc.toLowerCase()) || sc.toLowerCase().contains(cName)) {
              matchedSubCity = sc;
              break;
            }
          }
        }
      }

      matchedRegion ??= 'Addis Ababa';
      matchedSubCity ??= subCitiesByRegion[matchedRegion]?.first;
      addressText ??= '$matchedRegion, Ethiopia';

      if (mounted) {
        setState(() {
          _selectedRegion = matchedRegion;
          _selectedSubCity = matchedSubCity;
          _detectedAddress = addressText;
          _isFetchingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error detecting location: $e';
          _useDeviceLocation = false;
          _isFetchingLocation = false;
        });
      }
    }
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Back Button
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 22),
            color: ZegaTheme.mainText,
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            tooltip: 'Back',
          ),
        ),
        const SizedBox(height: ZegaTheme.space8),

        // Federal Police Logo
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZegaTheme.radiusRound),
            boxShadow: [
              BoxShadow(
                color: ZegaTheme.primaryNavy.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Image(
              image: AssetImage('assets/images/efp_logo.png'),
              width: 32,
              height: 32,
            ),
          ),
        ),
        const SizedBox(height: ZegaTheme.space16),

        // App Logo
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: ZegaTheme.primaryGradient,
            borderRadius: BorderRadius.circular(ZegaTheme.radiusRound),
            boxShadow: [
              BoxShadow(
                color: ZegaTheme.primaryNavy.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.shield_outlined,
              color: ZegaTheme.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: ZegaTheme.space16),

        // App Name
        Text(
          'ZEGA-ALERT',
          style: ZegaTheme.headlineMedium.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: ZegaTheme.primaryNavy,
            height: 1.2,
          ),
        ),
        const SizedBox(height: ZegaTheme.space20),

        // Section Title
        Text(
          'Create Your Account',
          style: ZegaTheme.headlineSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: ZegaTheme.mainText,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ZegaTheme.space8),

        // Supportive Text
        Text(
          'Join ZEGA-ALERT to help keep your community safe and stay informed.',
          style: ZegaTheme.bodyLarge.copyWith(
            color: ZegaTheme.secondaryText,
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRegistrationFormCard(AppLocalizations loc) {
    return ZegaAuthCard(
      child: Form(
        key: _formKey,
        onChanged: () => setState(() {}),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Full Name
            ZegaTextField(
              controller: _nameController,
              focusNode: _nameFocus,
              label: loc.fullName,
              hint: 'Enter your full name',
              prefixIcon: Icons.person_outline,
              textInputAction: TextInputAction.next,
              validator: _validateName,
              onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
              autofocus: true,
            ),
            const SizedBox(height: ZegaTheme.space20),

            // Phone Number
            ZegaPhoneField(
              controller: _phoneController,
              focusNode: _phoneFocus,
              label: loc.phone,
              hint: '911 234 567',
              defaultCountryCode: '+251',
              countryCodes: const ['+251'],
              validator: _validatePhone,
              onFieldSubmitted: (_) => _emailFocus.requestFocus(),
            ),
            const SizedBox(height: ZegaTheme.space20),

            // Email (Optional)
            ZegaTextField(
              controller: _emailController,
              focusNode: _emailFocus,
              label: 'Email (Optional)',
              hint: 'your@email.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _validateEmail,
              helperText: 'Add an email so you can also sign in with it',
            ),
            const SizedBox(height: ZegaTheme.space20),

            // Password
            ZegaPasswordField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              label: loc.password,
              hint: 'Create a strong password',
              textInputAction: TextInputAction.next,
              validator: _validatePassword,
              helperText: 'At least 8 characters',
            ),
            const SizedBox(height: ZegaTheme.space20),

            // Confirm Password
            ZegaPasswordField(
              controller: _confirmPasswordController,
              focusNode: _confirmPasswordFocus,
              label: 'Confirm Password',
              hint: 'Re-enter your password',
              textInputAction: TextInputAction.done,
              validator: _validateConfirmPassword,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: ZegaTheme.space20),

            // Location Permission Checkbox & Auto-detection
            _buildLocationCheckbox(loc),

            if (_detectedAddress != null && _useDeviceLocation) ...[
              const SizedBox(height: ZegaTheme.space8),
              _buildDetectedAddressBanner(),
            ],

            // Fallback / Manual Region & Subcity Selection
            if (!_useDeviceLocation) ...[
              const SizedBox(height: ZegaTheme.space12),
              _buildRegionDropdown(loc),
              if (_selectedRegion != null) ...[
                const SizedBox(height: ZegaTheme.space20),
                _buildSubCityDropdown(loc),
              ],
            ],
            const SizedBox(height: ZegaTheme.space16),

            // Terms & Privacy Policy Checkbox
            _buildTermsCheckbox(),

            // Error Message
            if (_error.isNotEmpty) ...[
              const SizedBox(height: ZegaTheme.space16),
              _buildErrorBanner(),
            ],

            const SizedBox(height: ZegaTheme.space24),

            // Create Account Button
            ZegaPrimaryButton(
              label: 'Create Account',
              onPressed: _isLoading ? null : _submit,
              isLoading: _isLoading,
              isEnabled: _formKey.currentState?.validate() ?? false,
              leadingIcon: Icons.person_add_rounded,
              height: 56,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCheckbox(AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _useDeviceLocation
            ? ZegaTheme.primaryNavy.withValues(alpha: 0.05)
            : ZegaTheme.white,
        borderRadius: BorderRadius.circular(ZegaTheme.radiusMedium),
        border: Border.all(
          color: _useDeviceLocation ? ZegaTheme.primaryNavy : ZegaTheme.inputBorder,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: _useDeviceLocation,
            onChanged: _isFetchingLocation ? null : _onToggleUseLocation,
            activeColor: ZegaTheme.primaryNavy,
            checkColor: ZegaTheme.white,
            side: BorderSide(
              color: _useDeviceLocation ? ZegaTheme.primaryNavy : ZegaTheme.inputBorder,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ZegaTheme.radiusSmall),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: _isFetchingLocation ? null : () => _onToggleUseLocation(!_useDeviceLocation),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.my_location_rounded,
                        size: 16,
                        color: _useDeviceLocation ? ZegaTheme.primaryNavy : ZegaTheme.secondaryText,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Use my current location',
                          style: ZegaTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _useDeviceLocation ? ZegaTheme.primaryNavy : ZegaTheme.mainText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Automatically set your address, region and sub-city using GPS',
                    style: ZegaTheme.bodySmall.copyWith(
                      color: ZegaTheme.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isFetchingLocation)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetectedAddressBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ZegaTheme.successGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ZegaTheme.radiusMedium),
        border: Border.all(color: ZegaTheme.successGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: ZegaTheme.successGreen, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detected Address',
                  style: ZegaTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ZegaTheme.successGreen,
                  ),
                ),
                Text(
                  _detectedAddress ?? '',
                  style: ZegaTheme.bodySmall.copyWith(color: ZegaTheme.mainText),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionDropdown(AppLocalizations loc) {
    return DropdownButtonFormField<String>(
      value: _selectedRegion,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: loc.regionLabel,
        prefixIcon: Icon(
          Icons.location_on_outlined,
          size: 22,
          color: ZegaTheme.secondaryText,
        ),
        filled: true,
        fillColor: ZegaTheme.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZegaTheme.radiusLarge),
          borderSide: const BorderSide(color: ZegaTheme.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZegaTheme.radiusLarge),
          borderSide: const BorderSide(color: ZegaTheme.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZegaTheme.radiusLarge),
          borderSide: const BorderSide(color: ZegaTheme.primaryNavy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZegaTheme.radiusLarge),
          borderSide: const BorderSide(color: ZegaTheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZegaTheme.space16,
          vertical: ZegaTheme.space16,
        ),
      ),
      style: ZegaTheme.bodyLarge.copyWith(color: ZegaTheme.mainText),
      dropdownColor: ZegaTheme.white,
      icon: Icon(
        Icons.keyboard_arrow_down,
        color: ZegaTheme.secondaryText,
        size: 24,
      ),
      items: ethiopianRegions.map((region) => DropdownMenuItem(
        value: region,
        child: Text(
          region,
          style: ZegaTheme.bodyLarge,
          overflow: TextOverflow.ellipsis,
        ),
      )).toList(),
      onChanged: _onRegionChanged,
      validator: _validateRegion,
      selectedItemBuilder: (context) => ethiopianRegions.map((region) => Text(
        region,
        style: ZegaTheme.bodyLarge.copyWith(color: ZegaTheme.mainText),
        overflow: TextOverflow.ellipsis,
      )).toList(),
    );
  }

  Widget _buildSubCityDropdown(AppLocalizations loc) {
    final subCities = subCitiesByRegion[_selectedRegion] ?? [];

    return DropdownButtonFormField<String>(
      value: _selectedSubCity,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: loc.subCityLabel,
        prefixIcon: Icon(
          Icons.location_city_outlined,
          size: 22,
          color: ZegaTheme.secondaryText,
        ),
        filled: true,
        fillColor: ZegaTheme.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZegaTheme.radiusLarge),
          borderSide: const BorderSide(color: ZegaTheme.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZegaTheme.radiusLarge),
          borderSide: const BorderSide(color: ZegaTheme.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZegaTheme.radiusLarge),
          borderSide: const BorderSide(color: ZegaTheme.primaryNavy, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZegaTheme.space16,
          vertical: ZegaTheme.space16,
        ),
      ),
      style: ZegaTheme.bodyLarge.copyWith(color: ZegaTheme.mainText),
      dropdownColor: ZegaTheme.white,
      icon: Icon(
        Icons.keyboard_arrow_down,
        color: ZegaTheme.secondaryText,
        size: 24,
      ),
      items: subCities.map((subCity) => DropdownMenuItem(
        value: subCity,
        child: Text(
          subCity,
          style: ZegaTheme.bodyLarge,
          overflow: TextOverflow.ellipsis,
        ),
      )).toList(),
      onChanged: (value) => setState(() => _selectedSubCity = value),
      selectedItemBuilder: (context) => subCities.map((subCity) => Text(
        subCity,
        style: ZegaTheme.bodyLarge.copyWith(color: ZegaTheme.mainText),
        overflow: TextOverflow.ellipsis,
      )).toList(),
    );
  }

  Widget _buildTermsCheckbox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ZegaTheme.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _acceptedTerms,
            onChanged: (bool? value) {
              setState(() => _acceptedTerms = value ?? false);
            },
            activeColor: ZegaTheme.primaryNavy,
            checkColor: ZegaTheme.white,
            side: BorderSide(
              color: _acceptedTerms ? ZegaTheme.primaryNavy : ZegaTheme.inputBorder,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ZegaTheme.radiusSmall),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: ZegaTheme.space4),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
              child: RichText(
                text: TextSpan(
                  style: ZegaTheme.bodySmall.copyWith(height: 1.5),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: ZegaTheme.bodySmall.copyWith(
                        color: ZegaTheme.secondaryBlue,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: ZegaTheme.bodySmall.copyWith(
                        color: ZegaTheme.secondaryBlue,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ),
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

  Widget _buildLoginNavigation(AppLocalizations loc) {
    return ZegaAuthNavigation(
      label: 'Already have an account?',
      actionLabel: 'Sign In',
      onActionPressed: _navigateToLogin,
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
                        // HEADER (Branding + Welcome)
                        // ============================================================
                        _buildHeader(),

                        const SizedBox(height: ZegaTheme.space32),

                        // ============================================================
                        // REGISTRATION FORM CARD
                        // ============================================================
                        _buildRegistrationFormCard(loc),

                        const SizedBox(height: ZegaTheme.space24),

                        // ============================================================
                        // LOGIN NAVIGATION
                        // ============================================================
                        _buildLoginNavigation(loc),

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
}