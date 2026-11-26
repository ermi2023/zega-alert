import 'package:flutter/material.dart';

/// ZEGA-ALERT Premium Design System
/// Based on the brand identity specification for a professional public safety application.

class ZegaTheme {
  // ============================================================
  // Brand Color Palette
  // ============================================================

  /// Primary Navy - Dominant brand color for headers, primary actions, trust elements
  static const Color primaryNavy = Color(0xFF142B4A);

  /// Secondary Blue - Interactive elements, links, focus states
  static const Color secondaryBlue = Color(0xFF2563EB);

  /// Accent Teal - Success states, verification, security indicators
  static const Color accentTeal = Color(0xFF0D9488);

  /// Background - Clean, light neutral for screens
  static const Color background = Color(0xFFF5F7FA);

  /// White - Card surfaces, input backgrounds
  static const Color white = Color(0xFFFFFFFF);

  /// Main Text - Primary content, headings
  static const Color mainText = Color(0xFF172B4D);

  /// Secondary Text - Subtitles, hints, secondary info
  static const Color secondaryText = Color(0xFF64748B);

  /// Input Border - Subtle field boundaries
  static const Color inputBorder = Color(0xFFE2E8F0);

  /// Input Border Focused - Active field state
  static const Color inputBorderFocused = Color(0xFF2563EB);

  /// Error Red - Validation errors, destructive actions
  static const Color errorRed = Color(0xFFDC2626);

  /// Success Green - Positive feedback
  static const Color successGreen = Color(0xFF10B981);

  /// Warning Amber - Caution states
  static const Color warningAmber = Color(0xFFF59E0B);

  // ============================================================
  // Semantic Color Aliases (for easy theming)
  // ============================================================

  static const Color primary = primaryNavy;
  static const Color onPrimary = white;
  static const Color secondary = secondaryBlue;
  static const Color onSecondary = white;
  static const Color tertiary = accentTeal;
  static const Color onTertiary = white;
  static const Color surface = white;
  static const Color onSurface = mainText;
  static const Color surfaceVariant = background;
  static const Color onSurfaceVariant = secondaryText;
  static const Color outline = inputBorder;
  static const Color outlineFocused = inputBorderFocused;
  static const Color error = errorRed;
  static const Color onError = white;

  // ============================================================
  // Typography Scale
  // ============================================================

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.5,
    color: mainText,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.3,
    color: mainText,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: 0,
    color: mainText,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: 0,
    color: mainText,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.1,
    color: mainText,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.45,
    letterSpacing: 0.1,
    color: mainText,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.15,
    color: mainText,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.25,
    color: mainText,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: 0.4,
    color: secondaryText,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.1,
    color: mainText,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.45,
    letterSpacing: 0.5,
    color: mainText,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0.5,
    color: secondaryText,
  );

  // ============================================================
  // Spacing System (8px base unit)
  // ============================================================

  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space56 = 56.0;
  static const double space64 = 64.0;

  // ============================================================
  // Border Radius
  // ============================================================

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 14.0;  // Primary input/button radius
  static const double radiusXLarge = 20.0; // Card radius
  static const double radiusRound = 28.0;  // Hero elements

  // ============================================================
  // Elevation / Shadows
  // ============================================================

  static const List<BoxShadow> shadowSubtle = [
    BoxShadow(
      color: Color(0x0D172B4D), // mainText with 5% opacity
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> shadowCard = [
    BoxShadow(
      color: Color(0x14172B4D), // mainText with 8% opacity
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0A172B4D), // mainText with 4% opacity
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> shadowElevated = [
    BoxShadow(
      color: Color(0x1A172B4D), // mainText with 10% opacity
      blurRadius: 32,
      offset: Offset(0, 16),
    ),
    BoxShadow(
      color: Color(0x0F172B4D), // mainText with 6% opacity
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> shadowButtonPressed = [
    BoxShadow(
      color: Color(0x14172B4D),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  // ============================================================
  // Animation Durations
  // ============================================================

  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 350);

  // ============================================================
  // Gradients
  // ============================================================

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryNavy, secondaryBlue],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, white],
    stops: [0.0, 0.6],
  );

  // Additional spacing tokens
  static const double space14 = 14.0;

  // ============================================================
  // ThemeData Factory
  // ============================================================

  static ThemeData lightTheme({bool useMaterial3 = true}) {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      tertiary: tertiary,
      onTertiary: onTertiary,
      error: error,
      onError: onError,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceVariant,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outline,
      shadow: const Color(0x14172B4D),
      scrim: const Color(0x80172B4D),
      inverseSurface: mainText,
      onInverseSurface: white,
      inversePrimary: secondaryBlue,
    );

    return ThemeData(
      useMaterial3: useMaterial3,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter', // Will fallback to system font if not available

      // Text Theme
      textTheme: TextTheme(
        displayLarge: headlineLarge,
        displayMedium: headlineMedium,
        displaySmall: headlineSmall,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      ).apply(
        bodyColor: mainText,
        displayColor: mainText,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: space16,
          vertical: space16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: const BorderSide(color: inputBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: const BorderSide(color: inputBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: const BorderSide(color: inputBorderFocused, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: const BorderSide(color: errorRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: const BorderSide(color: inputBorder, width: 1),
        ),
        labelStyle: bodyMedium.copyWith(color: secondaryText),
        floatingLabelStyle: labelMedium.copyWith(color: primaryNavy),
        hintStyle: bodyMedium.copyWith(color: secondaryText.withValues(alpha: 0.6)),
        errorStyle: bodySmall.copyWith(color: errorRed),
        helperStyle: bodySmall.copyWith(color: secondaryText),
        prefixIconColor: secondaryText,
        suffixIconColor: secondaryText,
        iconColor: secondaryText,
      ),

      // Button Themes
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryNavy,
          foregroundColor: white,
          disabledBackgroundColor: primaryNavy.withValues(alpha: 0.4),
          disabledForegroundColor: white.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(vertical: space16, horizontal: space24),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: labelLarge.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (states) {
              if (states.contains(WidgetState.pressed)) {
                return white.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return white.withValues(alpha: 0.08);
              }
              if (states.contains(WidgetState.focused)) {
                return white.withValues(alpha: 0.1);
              }
              return null;
            },
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryNavy,
          disabledForegroundColor: secondaryText.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: space14, horizontal: space24),
          minimumSize: const Size(double.infinity, 56),
          side: const BorderSide(color: primaryNavy, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge),
          ),
          textStyle: labelLarge.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (states) {
              if (states.contains(WidgetState.pressed)) {
                return primaryNavy.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return primaryNavy.withValues(alpha: 0.08);
              }
              return null;
            },
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondaryBlue,
          disabledForegroundColor: secondaryText.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: space8, horizontal: space12),
          textStyle: labelLarge.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (states) {
              if (states.contains(WidgetState.pressed)) {
                return secondaryBlue.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return secondaryBlue.withValues(alpha: 0.08);
              }
              return null;
            },
          ),
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: shadowCard.first.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXLarge),
          side: const BorderSide(color: inputBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: mainText,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: titleLarge.copyWith(fontWeight: FontWeight.w700),
        iconTheme: const IconThemeData(color: mainText, size: 24),
        actionsIconTheme: const IconThemeData(color: mainText, size: 24),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: inputBorder,
        thickness: 1,
        space: space24,
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryNavy;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(white),
        side: const BorderSide(color: inputBorder, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryNavy;
          }
          return secondaryText;
        }),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryNavy;
          }
          return white;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryNavy.withValues(alpha: 0.4);
          }
          return inputBorder;
        }),
        trackOutlineColor: WidgetStateProperty.all(inputBorder),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryNavy,
        linearTrackColor: inputBorder,
        circularTrackColor: inputBorder,
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryNavy,
        inactiveTrackColor: inputBorder,
        thumbColor: primaryNavy,
        overlayColor: primaryNavy.withValues(alpha: 0.12),
        valueIndicatorColor: primaryNavy,
        valueIndicatorTextStyle: labelSmall.copyWith(color: white),
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: primaryNavy,
        unselectedLabelColor: secondaryText,
        indicatorColor: primaryNavy,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: labelLarge.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: labelLarge.copyWith(fontWeight: FontWeight.w400),
        dividerColor: Colors.transparent,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: white,
        selectedItemColor: primaryNavy,
        unselectedItemColor: secondaryText,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: labelSmall.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: labelSmall.copyWith(fontWeight: FontWeight.w400),
      ),

      // Navigation Bar Theme
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: white,
        indicatorColor: primaryNavy.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          if (states.contains(WidgetState.selected)) {
            return labelSmall.copyWith(fontWeight: FontWeight.w600, color: primaryNavy);
          }
          return labelSmall.copyWith(fontWeight: FontWeight.w400, color: secondaryText);
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryNavy, size: 24);
          }
          return const IconThemeData(color: secondaryText, size: 24);
        }),
        height: 72,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: shadowElevated.first.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXLarge)),
        titleTextStyle: titleLarge.copyWith(fontWeight: FontWeight.w700),
        contentTextStyle: bodyMedium,
      ),

      // SnackBar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: mainText.withValues(alpha: 0.92),
        contentTextStyle: bodyMedium.copyWith(color: white),
        actionTextColor: secondaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
        elevation: 4,
      ),

      // Tooltip Theme
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: mainText.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        textStyle: labelSmall.copyWith(color: white),
        padding: const EdgeInsets.symmetric(horizontal: space12, vertical: space8),
        preferBelow: false,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        disabledColor: surfaceVariant.withValues(alpha: 0.5),
        selectedColor: primaryNavy.withValues(alpha: 0.12),
        secondarySelectedColor: primaryNavy.withValues(alpha: 0.12),
        labelStyle: labelMedium.copyWith(color: mainText),
        secondaryLabelStyle: labelMedium.copyWith(color: primaryNavy),
        padding: const EdgeInsets.symmetric(horizontal: space12, vertical: space8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: inputBorder),
        ),
        side: const BorderSide(color: inputBorder),
        brightness: Brightness.light,
        elevation: 0,
        pressElevation: 0,
      ),
    );
  }

  static ThemeData darkTheme({bool useMaterial3 = true}) {
    // For now, return light theme - dark mode can be implemented later
    return lightTheme(useMaterial3: useMaterial3);
  }
}