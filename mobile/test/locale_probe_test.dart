import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zega_alert_mobile/main.dart';
import 'package:zega_alert_mobile/l10n/app_localizations.dart';

/// Regression test: switching to a language Flutter does not ship Material
/// translations for (Oromifa `om`, Tigrinya `ti`) used to crash with
/// "No MaterialLocalizations found". The fallback delegates must prevent that.
void main() {
  for (final code in ['en', 'am', 'om', 'ti']) {
    testWidgets('app renders in locale "$code" without exceptions', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const ZegaAlertApp());
      await tester.pump();

      ZegaAlertApp.of(tester.element(find.byType(MaterialApp)))?.setLanguage(code);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold).first);
      // MaterialLocalizations must always resolve (real or English fallback).
      expect(MaterialLocalizations.of(context), isNotNull);
      // App strings must resolve to the requested language.
      expect(AppLocalizations.of(context).localeName, code);
      expect(tester.takeException(), isNull);
    });
  }
}
