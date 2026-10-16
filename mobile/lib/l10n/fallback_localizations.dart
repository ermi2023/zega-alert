import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// [GlobalMaterialLocalizations] only ships translations for the locales that
/// Flutter bundles: Amharic (`am`) is included, but Oromifa (`om`) and Tigrinya
/// (`ti`) are not. When the app's locale is one of those, no
/// [MaterialLocalizations] is provided and every [Scaffold] throws
/// "No MaterialLocalizations found", breaking the app.
///
/// This delegate guarantees a [MaterialLocalizations] for *every* locale: the
/// real Flutter translation when available, otherwise English
/// ([DefaultMaterialLocalizations]). The app's own strings still come from the
/// user's language via [AppLocalizations].
class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    if (GlobalMaterialLocalizations.delegate.isSupported(locale)) {
      return GlobalMaterialLocalizations.delegate.load(locale);
    }
    return SynchronousFuture<MaterialLocalizations>(
        const DefaultMaterialLocalizations());
  }

  @override
  bool shouldReload(FallbackMaterialLocalizationsDelegate old) => false;
}

/// Cupertino counterpart of [FallbackMaterialLocalizationsDelegate].
class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    if (GlobalCupertinoLocalizations.delegate.isSupported(locale)) {
      return GlobalCupertinoLocalizations.delegate.load(locale);
    }
    return SynchronousFuture<CupertinoLocalizations>(
        const DefaultCupertinoLocalizations());
  }

  @override
  bool shouldReload(FallbackCupertinoLocalizationsDelegate old) => false;
}
