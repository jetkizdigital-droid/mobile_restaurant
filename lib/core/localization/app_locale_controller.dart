import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleController extends ChangeNotifier {
  AppLocaleController._();

  static final AppLocaleController instance = AppLocaleController._();
  static const String _storageKey = 'jetkiz_restaurant_locale';

  Locale _locale = const Locale('ru');

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;
  bool get isKazakh => languageCode == 'kk';

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_storageKey)?.trim().toLowerCase();
      _locale = saved == 'kk' ? const Locale('kk') : const Locale('ru');
    } catch (_) {
      _locale = const Locale('ru');
    }
  }

  Future<void> setLanguageCode(String languageCode) async {
    final normalized = languageCode.trim().toLowerCase() == 'kk' ? 'kk' : 'ru';
    if (_locale.languageCode == normalized) return;

    _locale = Locale(normalized);
    notifyListeners();

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_storageKey, normalized);
    } catch (_) {
      // A storage failure must not prevent the language from changing now.
    }
  }

  Future<void> toggle() async {
    await setLanguageCode(isKazakh ? 'ru' : 'kk');
  }
}

extension JetkizLocalization on BuildContext {
  // The app overrides Localizations below the stable Navigator. Depending on
  // that scope rebuilds visible screens when RU/ҚАЗ changes without replacing
  // the Navigator or active routes.
  bool get isKazakh => Localizations.localeOf(this).languageCode == 'kk';

  String tr(String ru, String kk) => isKazakh ? kk : ru;
}
