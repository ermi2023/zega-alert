import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zega_alert_mobile/main.dart';
import 'package:zega_alert_mobile/screens/login_screen.dart';
import 'package:zega_alert_mobile/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:zega_alert_mobile/l10n/fallback_localizations.dart';

void main() {
  testWidgets('shows the login screen when not logged in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ZegaAlertApp(onboardingDone: true));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Your Safety, Our Priority.'), findsOneWidget);
  });
}
