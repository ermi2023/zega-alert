import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zega_alert_mobile/main.dart';
import 'package:zega_alert_mobile/l10n/app_localizations.dart';
import 'package:zega_alert_mobile/l10n/fallback_localizations.dart';
import 'package:zega_alert_mobile/screens/login_screen.dart';
import 'package:zega_alert_mobile/screens/register_screen.dart';
import 'package:zega_alert_mobile/screens/forgot_password_screen.dart';
import 'package:zega_alert_mobile/widgets/auth_widgets.dart';

Widget makeTestApp({required Widget home}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      FallbackMaterialLocalizationsDelegate(),
      GlobalWidgetsLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  // Test 1: Check navigation from LoginScreen to RegisterScreen works in isolation
  testWidgets('login navigate to register works in simple test app', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Use makeTestApp which is a simple MaterialApp without navigatorKey
    await tester.pumpWidget(makeTestApp(home: const LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);

    // Find the "Create Account" button (it's in ZegaAuthNavigation inside a SingleChildScrollView)
    final finder = find.widgetWithText(ZegaTextButton, 'Create Account');
    expect(finder, findsOneWidget);

    // Scroll to make the button visible
    await tester.dragUntilVisible(
      finder,
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    // Tap it
    await tester.tap(finder);
    await tester.pumpAndSettle();

    // Should now be on RegisterScreen
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // Test 2: Test with ZegaAlertApp (with navigatorKey) for different sizes
  final sizes = <List<int>>[
    [320, 568],
    [360, 640],
    [390, 844],
    [412, 915],
    [768, 1024]
  ];
  for (final s in sizes) {
    for (final register in [false, true]) {
      testWidgets('login ${s[0]}x${s[1]} register=$register has no overflow',
          (tester) async {
        tester.view.physicalSize = Size(s[0].toDouble(), s[1].toDouble());
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(const ZegaAlertApp(onboardingDone: true));
        await tester.pump();

        expect(find.byType(LoginScreen), findsOneWidget);
        if (register) {
          // Tap the "Create Account" text button inside ZegaAuthNavigation
          // ZegaAuthNavigation wraps a ZegaTextButton, so find the button
          final finder = find.widgetWithText(ZegaTextButton, 'Create Account');

          // Use ensureVisible to bring the button into view
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();

          // Now tap it
          await tester.tap(finder, warnIfMissed: false);
          await tester.pumpAndSettle();

          // Should now be on RegisterScreen
          expect(find.byType(RegisterScreen), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('registration fits a compact phone screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(makeTestApp(home: const RegisterScreen()));
    await tester.pumpAndSettle();

    // Find the Create Account button specifically in the primary button
    final finder = find.byWidgetPredicate((widget) =>
        widget is ZegaPrimaryButton && widget.label == 'Create Account');
    expect(finder, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password recovery fits a compact phone screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestApp(home: const ForgotPasswordScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Forgot password?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}