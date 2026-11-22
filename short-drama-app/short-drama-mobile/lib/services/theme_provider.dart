import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import 'app_config_service.dart';

/// Theme provider to manage app theme state
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    // Apply the remote-config color preset before MaterialApp reads
    // AppTheme.darkTheme / lightTheme (this provider is created above
    // MaterialApp in main.dart, and its instance is what the app's
    // Consumer2 touches first). Guarded to the valid 1..7 preset range;
    // anything else keeps the built-in default (6 = Drama Crimson).
    final preset = AppConfigService.instance.defaultThemePreset;
    if (preset >= 1 && preset <= 7) {
      AppTheme.kColorPreset = preset;
    }
    _loadThemeMode();
    // This provider is created in main() before AppBootstrap loads
    // GET /config, so the read above usually sees the not-yet-loaded
    // default (6). Re-apply the remote preset once the config arrives.
    unawaited(_applyRemotePresetWhenReady());
  }

  Future<void> _applyRemotePresetWhenReady() async {
    for (var i = 0; i < 30 && !AppConfigService.instance.isLoaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (!AppConfigService.instance.isLoaded) return;
    final preset = AppConfigService.instance.defaultThemePreset;
    if (preset >= 1 && preset <= 7 && preset != AppTheme.kColorPreset) {
      AppTheme.kColorPreset = preset;
      notifyListeners();
    }
  }
  
  /// Load saved theme mode from shared preferences
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey);
      
      if (savedTheme != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.toString() == savedTheme,
          orElse: () => ThemeMode.dark,
        );
      } else {
        _themeMode = ThemeMode.dark;
        await _saveThemeMode();
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme mode: $e');
    }
  }
  
  /// Save theme mode to shared preferences
  Future<void> _saveThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, _themeMode.toString());
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }
  
  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await _saveThemeMode();
    notifyListeners();
  }
  
  /// Set specific theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      await _saveThemeMode();
      notifyListeners();
    }
  }
}
