import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zega_alert_mobile/main.dart';
import 'package:zega_alert_mobile/screens/auth_screen.dart';

void main() {
  testWidgets('shows the auth screen when not logged in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ZegaAlertApp());
    await tester.pump();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Emergency & crime reporting for every Ethiopian'), findsOneWidget);
  });
}
