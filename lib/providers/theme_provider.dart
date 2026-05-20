import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FontSizeOption { small, medium, large, extraLarge }

extension FontSizeOptionExtension on FontSizeOption {
  String get displayName {
    switch (this) {
      case FontSizeOption.small:
        return 'Small';
      case FontSizeOption.medium:
        return 'Medium';
      case FontSizeOption.large:
        return 'Large';
      case FontSizeOption.extraLarge:
        return 'Extra Large';
    }
  }

  double get scaleFactor {
    switch (this) {
      case FontSizeOption.small:
        return 0.75;
      case FontSizeOption.medium:
        return 1.0;
      case FontSizeOption.large:
        return 1.15;
      case FontSizeOption.extraLarge:
        return 1.30;
    }
  }
}

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _fontSizeKey = 'font_size_option';

  ThemeMode _themeMode = ThemeMode.system;
  FontSizeOption _fontSizeOption = FontSizeOption.medium;

  ThemeMode get themeMode => _themeMode;
  FontSizeOption get fontSizeOption => _fontSizeOption;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  double get fontSizeScaleFactor => _fontSizeOption.scaleFactor;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? 0;
    _themeMode = ThemeMode.values[themeIndex];

    final fontSizeIndex =
        prefs.getInt(_fontSizeKey) ?? FontSizeOption.medium.index;
    if (fontSizeIndex >= 0 && fontSizeIndex < FontSizeOption.values.length) {
      _fontSizeOption = FontSizeOption.values[fontSizeIndex];
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  Future<void> setFontSizeOption(FontSizeOption option) async {
    _fontSizeOption = option;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_fontSizeKey, option.index);
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }
}
