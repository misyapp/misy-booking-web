import 'package:flutter/foundation.dart';
import 'package:rider_ride_hailing_app/contants/transit_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférence de langue pour la nouvelle UI trilingue (Transport en commun).
/// Le legacy de l'app reste en FR — on bascule progressivement.
class LocaleProvider extends ChangeNotifier {
  static const String _prefsKey = 'misy_locale';

  AppLocale _locale = AppLocale.fr;
  bool _initialized = false;

  AppLocale get locale => _locale;
  bool get initialized => _initialized;

  Future<void> load() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    _locale = _parse(raw) ?? AppLocale.fr;
    _initialized = true;
    notifyListeners();
  }

  Future<void> setLocale(AppLocale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.name);
  }

  static AppLocale? _parse(String? raw) {
    if (raw == null) return null;
    for (final l in AppLocale.values) {
      if (l.name == raw) return l;
    }
    return null;
  }
}
