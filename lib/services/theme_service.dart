import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeType { system, light, dark }

class ThemeService {
  static SharedPreferences? _prefs;
  static const String _themeKey = 'app_theme';

  // Stream controller for real-time theme updates
  static final StreamController<ThemeType> _themeController =
      StreamController<ThemeType>.broadcast();

  // Stream getter for listening to theme changes
  static Stream<ThemeType> get themeStream => _themeController.stream;

  // Current theme type
  static ThemeType _currentTheme = ThemeType.system;
  static ThemeType get currentTheme => _currentTheme;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadTheme();
  }

  // Dispose method to close stream controller
  static void dispose() {
    _themeController.close();
  }

  // Load saved theme from storage
  static Future<void> _loadTheme() async {
    final String? themeString = _prefs?.getString(_themeKey);

    if (themeString != null) {
      // Convert string back to enum
      switch (themeString) {
        case 'system':
          _currentTheme = ThemeType.system;
          break;
        case 'light':
          _currentTheme = ThemeType.light;
          break;
        case 'dark':
          _currentTheme = ThemeType.dark;
          break;
        default:
          _currentTheme = ThemeType.system;
      }
    } else {
      _currentTheme = ThemeType.system;
    }

    // Emit initial theme
    _themeController.add(_currentTheme);
  }

  // Save theme and notify listeners
  static Future<void> setTheme(ThemeType theme) async {
    _currentTheme = theme;

    // Save to SharedPreferences
    await _prefs?.setString(_themeKey, theme.name);

    // Emit updated theme to stream
    _themeController.add(_currentTheme);
  }

  // Convert ThemeType to ThemeMode for MaterialApp
  static ThemeMode getThemeMode() {
    switch (_currentTheme) {
      case ThemeType.system:
        return ThemeMode.system;
      case ThemeType.light:
        return ThemeMode.light;
      case ThemeType.dark:
        return ThemeMode.dark;
    }
  }

  // Get display name for UI
  static String getThemeDisplayName(ThemeType theme) {
    switch (theme) {
      case ThemeType.system:
        return 'System';
      case ThemeType.light:
        return 'Light';
      case ThemeType.dark:
        return 'Dark';
    }
  }

  // Get icon for theme type
  static IconData getThemeIcon(ThemeType theme) {
    switch (theme) {
      case ThemeType.system:
        return Icons.brightness_auto;
      case ThemeType.light:
        return Icons.brightness_high;
      case ThemeType.dark:
        return Icons.brightness_2;
    }
  }
}
