import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'strings.dart';
import 'pt_br.dart';
import 'en_us.dart';

class LocaleNotifier extends ChangeNotifier {
  Locale _locale = const Locale('pt', 'BR');
  bool _initialized = false;

  LocaleNotifier() {
    _init();
  }

  Locale get locale => _locale;
  bool get isInitialized => _initialized;

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString('manet_locale_language_code');
      if (savedCode != null) {
        if (savedCode == 'en') {
          _locale = const Locale('en', 'US');
        } else {
          _locale = const Locale('pt', 'BR');
        }
      } else {
        // Detect system language
        final systemLocale = ui.PlatformDispatcher.instance.locale;
        if (systemLocale.languageCode.startsWith('pt')) {
          _locale = const Locale('pt', 'BR');
        } else {
          _locale = const Locale('en', 'US');
        }
      }
    } catch (_) {
      // Fallback if preferences fail
      _locale = const Locale('pt', 'BR');
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('manet_locale_language_code', locale.languageCode);
    } catch (_) {}
  }
}

class AppLocalizations extends InheritedNotifier<LocaleNotifier> {
  const AppLocalizations({
    super.key,
    required super.notifier,
    required super.child,
  });

  static AppStrings of(BuildContext context) {
    final l10n = context.dependOnInheritedWidgetOfExactType<AppLocalizations>();
    final locale = l10n?.notifier?.locale ?? const Locale('pt', 'BR');
    if (locale.languageCode == 'en') {
      return EnUsStrings();
    }
    return PtBrStrings();
  }

  static Locale localeOf(BuildContext context) {
    final l10n = context.dependOnInheritedWidgetOfExactType<AppLocalizations>();
    return l10n?.notifier?.locale ?? const Locale('pt', 'BR');
  }

  static void setLocaleOf(BuildContext context, Locale locale) {
    final l10n = context.getInheritedWidgetOfExactType<AppLocalizations>();
    l10n?.notifier?.setLocale(locale);
  }
}

extension LocalizationsExtension on BuildContext {
  AppStrings get l10n => AppLocalizations.of(this);
  Locale get currentLocale => AppLocalizations.localeOf(this);
  void setLocale(Locale locale) => AppLocalizations.setLocaleOf(this, locale);
}
