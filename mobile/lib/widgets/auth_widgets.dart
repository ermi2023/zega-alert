import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';

/// A premium text input field with consistent styling for auth screens.
/// Supports prefix icon, suffix action (visibility toggle), validation, and custom keyboard types.
class ZegaTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final int? maxLength;
  final int maxLines;
  final FocusNode? focusNode;
  final bool autofocus;

  const ZegaTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helperText,
    this.prefixIcon,
    this.prefix,
    this.suffix,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.enabled = true,
    this.maxLength,
    this.maxLines = 1,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  State<ZegaTextField> createState() => _ZegaTextFieldState();
}

class _ZegaTextFieldState extends State<ZegaTextField> {
  late FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _hasFocus = _focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      inputFormatters: widget.inputFormatters,
      enabled: widget.enabled,
      maxLength: widget.maxLength,
      maxLines: widget.maxLines,
      autofocus: widget.autofocus,
      style: ZegaTheme.bodyLarge,
      cursorColor: ZegaTheme.primaryNavy,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helperText,
        prefixIcon: widget.prefixIcon != null
            ? Icon(
                widget.prefixIcon,
                size: 22,
                color: _hasFocus
                    ? ZegaTheme.primaryNavy
                    : ZegaTheme.secondaryText,
              )
            : null,
        prefix: widget.prefix,
        suffixIcon: widget.suffix,
        counterText: '',
        filled: true,
        fillColor: ZegaTheme.white,
        // The theme's inputDecorationTheme handles borders, but we can override for focus state
      ),
    );
  }
}

/// A specialized phone number input field with country code selector.
class ZegaPhoneField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String defaultCountryCode;
  final List<String> countryCodes;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final bool enabled;
  final FocusNode? focusNode;

  const ZegaPhoneField({
    super.key,
    required this.controller,
    this.label = 'Phone Number',
    this.hint,
    this.defaultCountryCode = '+251',
    this.countryCodes = const ['+251'],
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
    this.focusNode,
  });

  @override
  State<ZegaPhoneField> createState() => _ZegaPhoneFieldState();
}

class _ZegaPhoneFieldState extends State<ZegaPhoneField> {
  late String _selectedCountryCode;
  late FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _selectedCountryCode = widget.defaultCountryCode;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _hasFocus = _focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.phone,
      textInputAction: widget.onFieldSubmitted != null
          ? TextInputAction.done
          : TextInputAction.next,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      enabled: widget.enabled,
      style: ZegaTheme.bodyLarge,
      cursorColor: ZegaTheme.primaryNavy,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        filled: true,
        fillColor: ZegaTheme.white,
        prefixIcon: Icon(
          Icons.phone_outlined,
          size: 22,
          color: _hasFocus ? ZegaTheme.primaryNavy : ZegaTheme.secondaryText,
        ),
        prefix: _CountryCodeSelector(
          selectedCode: _selectedCountryCode,
          codes: widget.countryCodes,
          onChanged: (code) => setState(() => _selectedCountryCode = code),
          hasFocus: _hasFocus,
        ),
        counterText: '',
      ),
    );
  }

  /// Returns the full phone number with country code
  String get fullPhoneNumber =>
      '$_selectedCountryCode ${widget.controller.text}';
}

/// Internal widget for country code selection in phone field
class _CountryCodeSelector extends StatelessWidget {
  final String selectedCode;
  final List<String> codes;
  final ValueChanged<String> onChanged;
  final bool hasFocus;

  const _CountryCodeSelector({
    required this.selectedCode,
    required this.codes,
    required this.onChanged,
    required this.hasFocus,
  });

  @override
  Widget build(BuildContext context) {
    if (codes.length <= 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Text(
          selectedCode,
          style: ZegaTheme.bodyLarge.copyWith(
            color: hasFocus ? ZegaTheme.primaryNavy : ZegaTheme.mainText,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCode,
          items: codes
              .map(
                (code) => DropdownMenuItem(
                  value: code,
                  child: Text(
                    code,
                    style: ZegaTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => onChanged(value!),
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 20,
            color: hasFocus ? ZegaTheme.primaryNavy : ZegaTheme.secondaryText,
          ),
          borderRadius: BorderRadius.circular(ZegaTheme.radiusMedium),
          dropdownColor: ZegaTheme.white,
          style: ZegaTheme.bodyLarge,
          underline: const SizedBox(),
        ),
      ),
    );
  }
}

/// A premium primary button with loading and disabled states.
class ZegaPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double? width;
  final double height;
  final double borderRadius;

  const ZegaPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.leadingIcon,
    this.trailingIcon,
    this.width,
    this.height = 56,
    this.borderRadius = ZegaTheme.radiusLarge,
  });

  @override
  State<ZegaPrimaryButton> createState() => _ZegaPrimaryButtonState();
}

class _ZegaPrimaryButtonState extends State<ZegaPrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: ZegaTheme.durationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isEnabled && !widget.isLoading;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: SizedBox(
            width: widget.width ?? double.infinity,
            height: widget.height,
            child: FilledButton(
              onPressed: isActive ? widget.onPressed : null,
              style:
                  FilledButton.styleFrom(
                    backgroundColor: ZegaTheme.primaryNavy,
                    foregroundColor: ZegaTheme.white,
                    disabledBackgroundColor: ZegaTheme.primaryNavy.withValues(
                      alpha: 0.4,
                    ),
                    disabledForegroundColor: ZegaTheme.white.withValues(
                      alpha: 0.6,
                    ),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ).copyWith(
                    overlayColor: WidgetStateProperty.resolveWith<Color?>((
                      states,
                    ) {
                      if (states.contains(WidgetState.pressed)) {
                        return ZegaTheme.white.withValues(alpha: 0.12);
                      }
                      if (states.contains(WidgetState.hovered)) {
                        return ZegaTheme.white.withValues(alpha: 0.08);
                      }
                      if (states.contains(WidgetState.focused)) {
                        return ZegaTheme.white.withValues(alpha: 0.1);
                      }
                      return null;
                    }),
                  ),
              child: widget.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ZegaTheme.white,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        if (widget.leadingIcon != null) ...[
                          Icon(widget.leadingIcon, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            style: ZegaTheme.labelLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (widget.trailingIcon != null) ...[
                          const SizedBox(width: 8),
                          Icon(widget.trailingIcon, size: 20),
                        ],
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// A secondary/outline button for alternative actions.
class ZegaSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isEnabled;
  final IconData? leadingIcon;
  final double? width;
  final double height;

  const ZegaSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isEnabled = true,
    this.leadingIcon,
    this.width,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: isEnabled ? onPressed : null,
        style:
            OutlinedButton.styleFrom(
              foregroundColor: ZegaTheme.primaryNavy,
              disabledForegroundColor: ZegaTheme.secondaryText.withValues(
                alpha: 0.5,
              ),
              side: const BorderSide(color: ZegaTheme.primaryNavy, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ZegaTheme.radiusLarge),
              ),
              padding: EdgeInsets.zero,
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.pressed)) {
                  return ZegaTheme.primaryNavy.withValues(alpha: 0.12);
                }
                if (states.contains(WidgetState.hovered)) {
                  return ZegaTheme.primaryNavy.withValues(alpha: 0.08);
                }
                return null;
              }),
            ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: ZegaTheme.labelLarge.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A text button for navigation links (Sign up, Forgot password, etc.)
class ZegaTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isEnabled;
  final Color? color;
  final TextStyle? style;

  const ZegaTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isEnabled = true,
    this.color,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: isEnabled ? onPressed : null,
      style:
          TextButton.styleFrom(
            foregroundColor: color ?? ZegaTheme.secondaryBlue,
            disabledForegroundColor: ZegaTheme.secondaryText.withValues(
              alpha: 0.5,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
              final baseColor = color ?? ZegaTheme.secondaryBlue;
              if (states.contains(WidgetState.pressed)) {
                return baseColor.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return baseColor.withValues(alpha: 0.08);
              }
              return null;
            }),
          ),
      child: Text(
        label,
        style:
            style ??
            ZegaTheme.labelLarge.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}

/// A combined label + link text button (e.g., "Don't have an account? Create Account")
class ZegaAuthNavigation extends StatelessWidget {
  final String label;
  final String actionLabel;
  final VoidCallback onActionPressed;
  final TextStyle? labelStyle;
  final TextStyle? actionStyle;

  const ZegaAuthNavigation({
    super.key,
    required this.label,
    required this.actionLabel,
    required this.onActionPressed,
    this.labelStyle,
    this.actionStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          label,
          style:
              labelStyle ??
              ZegaTheme.bodyMedium.copyWith(color: ZegaTheme.secondaryText),
        ),
        const SizedBox(width: 4),
        ZegaTextButton(
          label: actionLabel,
          onPressed: onActionPressed,
          style:
              actionStyle ??
              ZegaTheme.labelLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: ZegaTheme.secondaryBlue,
              ),
        ),
      ],
    );
  }
}

/// Security footer with shield icon and trust message
class ZegaSecurityFooter extends StatelessWidget {
  final String message;
  final IconData icon;

  const ZegaSecurityFooter({
    super.key,
    this.message = 'Your information is protected and secure.',
    this.icon = Icons.verified_user_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: ZegaTheme.accentTeal, size: 16),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: ZegaTheme.bodySmall.copyWith(
              color: ZegaTheme.secondaryText,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Auth screen header with logo and branding
class ZegaAuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Widget? logo;
  final String? tagline;

  const ZegaAuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.showBackButton = false,
    this.onBackPressed,
    this.logo,
    this.tagline,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLogo =
        logo ??
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: ZegaTheme.primaryNavy,
            borderRadius: BorderRadius.circular(ZegaTheme.radiusRound),
          ),
          child: const Center(
            child: Icon(
              Icons.shield_outlined,
              color: ZegaTheme.white,
              size: 32,
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showBackButton)
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 22),
              color: ZegaTheme.mainText,
              onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ),
        if (showBackButton) const SizedBox(height: ZegaTheme.space8),
        effectiveLogo,
        const SizedBox(height: ZegaTheme.space16),
        Text(
          'ZEGA-ALERT',
          style: ZegaTheme.headlineMedium.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: ZegaTheme.primaryNavy,
          ),
        ),
        if (tagline != null) ...[
          const SizedBox(height: ZegaTheme.space8),
          Text(
            tagline!,
            style: ZegaTheme.bodyMedium.copyWith(
              color: ZegaTheme.secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: ZegaTheme.space24),
        Text(
          title,
          style: ZegaTheme.headlineSmall.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: ZegaTheme.space8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: ZegaTheme.bodyLarge.copyWith(
            color: ZegaTheme.secondaryText,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Auth card container with consistent styling
class ZegaAuthCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const ZegaAuthCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          margin ?? const EdgeInsets.symmetric(horizontal: ZegaTheme.space24),
      padding: padding ?? const EdgeInsets.all(ZegaTheme.space24),
      decoration: BoxDecoration(
        color: ZegaTheme.white,
        borderRadius: BorderRadius.circular(ZegaTheme.radiusXLarge),
        border: Border.all(color: ZegaTheme.inputBorder, width: 1),
        boxShadow: ZegaTheme.shadowCard,
      ),
      child: child,
    );
  }
}

/// Terms and conditions checkbox with clickable links
class ZegaTermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String termsText;
  final String privacyText;
  final VoidCallback? onTermsPressed;
  final VoidCallback? onPrivacyPressed;

  const ZegaTermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.termsText = 'Terms of Service',
    this.privacyText = 'Privacy Policy',
    this.onTermsPressed,
    this.onPrivacyPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: ZegaTheme.space4),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: RichText(
              text: TextSpan(
                style: ZegaTheme.bodySmall.copyWith(height: 1.5),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: termsText,
                    style: ZegaTheme.bodySmall.copyWith(
                      color: ZegaTheme.secondaryBlue,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w500,
                    ),
                    recognizer: null, // Add tap gesture if needed
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: privacyText,
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
    );
  }
}

/// Password field with visibility toggle
class ZegaPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helperText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final TextInputAction textInputAction;
  final bool enabled;
  final FocusNode? focusNode;

  const ZegaPasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.hint,
    this.helperText,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction = TextInputAction.done,
    this.enabled = true,
    this.focusNode,
  });

  @override
  State<ZegaPasswordField> createState() => _ZegaPasswordFieldState();
}

class _ZegaPasswordFieldState extends State<ZegaPasswordField> {
  bool _obscureText = true;
  late FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _hasFocus = _focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      obscureText: _obscureText,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      enabled: widget.enabled,
      style: ZegaTheme.bodyLarge,
      cursorColor: ZegaTheme.primaryNavy,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helperText,
        filled: true,
        fillColor: ZegaTheme.white,
        prefixIcon: Icon(
          Icons.lock_outline,
          size: 22,
          color: _hasFocus ? ZegaTheme.primaryNavy : ZegaTheme.secondaryText,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 22,
            color: _hasFocus ? ZegaTheme.primaryNavy : ZegaTheme.secondaryText,
          ),
          onPressed: () => setState(() => _obscureText = !_obscureText),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
        counterText: '',
      ),
    );
  }
}

/// Screen wrapper with proper keyboard handling and scroll support
class ZegaAuthScreen extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final PreferredSizeWidget? appBar;
  final bool resizeToAvoidBottomInset;
  final bool extendBodyBehindAppBar;

  const ZegaAuthScreen({
    super.key,
    required this.child,
    this.backgroundColor = ZegaTheme.primaryNavy,
    this.appBar,
    this.resizeToAvoidBottomInset = true,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: ZegaTheme.primaryNavy,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: ZegaTheme.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: appBar,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        body: SafeArea(
          top: !extendBodyBehindAppBar,
          bottom: false,
          child: child,
        ),
      ),
    );
  }
}

/// Gradient background decoration for auth screens
class ZegaAuthBackground extends StatelessWidget {
  final Widget child;

  const ZegaAuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: ZegaTheme.primaryNavy),
      child: child,
    );
  }
}

/// Animated transition between auth modes
class ZegaAuthTransition extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;

  const ZegaAuthTransition({
    super.key,
    required this.child,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
    );
  }
}
