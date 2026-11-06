import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'easel_theme.dart';

/// Aligns with Web `ThemeToggle` (`localStorage` key `easel_theme`).
class ThemeController extends ChangeNotifier {
  static const prefsKey = 'easel_theme';

  /// `null` = follow system; otherwise forced `light` / `dark`.
  String? preference;
  bool _ready = false;

  bool get ready => _ready;

  ThemeMode get themeMode {
    switch (preference) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  bool isDark(BuildContext context) {
    if (preference == 'light') return false;
    if (preference == 'dark') return true;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(prefsKey);
      if (stored == 'light' || stored == 'dark') {
        preference = stored;
      }
    } catch (_) {
      /* keep system */
    }
    _ready = true;
    _syncStaticPalette();
    notifyListeners();
  }

  Future<void> toggle(BuildContext context) async {
    final next = isDark(context) ? 'light' : 'dark';
    preference = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, next);
    } catch (_) {
      /* still switch for this session */
    }
    EaselColors.bind(EaselPalette.forBrightness(
      next == 'dark' ? Brightness.dark : Brightness.light,
    ));
    notifyListeners();
  }

  void _syncStaticPalette() {
    if (preference == 'light') {
      EaselColors.bind(EaselPalette.light);
    } else if (preference == 'dark') {
      EaselColors.bind(EaselPalette.dark);
    }
    // system: MaterialApp.builder binds from Theme brightness
  }
}
