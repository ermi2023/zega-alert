import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zega_alert_mobile/main.dart';
import 'package:zega_alert_mobile/screens/auth_screen.dart';

void main() {
  final sizes = <List<int>>[[320, 568], [360, 640], [390, 844], [412, 915], [768, 1024]];
  for (final s in sizes) {
    for (final register in [false, true]) {
      testWidgets('auth ${s[0]}x${s[1]} register=$register has no overflow', (tester) async {
        tester.view.physicalSize = Size(s[0].toDouble(), s[1].toDouble());
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(const ZegaAlertApp());
        await tester.pump();

        expect(find.byType(AuthScreen), findsOneWidget);
        if (register) {
          await tester.tap(find.text('Create account'));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
