import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'language_service.dart';

/// Provider for managing app locale
class LocaleProvider extends ChangeNotifier {
  static const String _localeKey = 'app_locale';
  Locale? _locale;

  LocaleProvider() {
    _loadLocale();
  }

  Locale? get locale => _locale;

  /// Load saved locale or use device locale
  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLocaleCode = prefs.getString(_localeKey);
      
      if (savedLocaleCode != null) {
        _locale = Locale(savedLocaleCode);
        notifyListeners();
        return;
      }
      
      // Try to detect device language
      final deviceLocale = ui.PlatformDispatcher.instance.locale;
      final languageCode = deviceLocale.languageCode;
      
      // Check if device language is supported
      if (LanguageService.supportedLanguages.containsKey(languageCode)) {
        _locale = Locale(languageCode);
        notifyListeners();
        return;
      }
      
      // Default to English
      _locale = const Locale('en');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading locale: $e');
      _locale = const Locale('en');
      notifyListeners();
    }
  }

  /// Set app locale by language code
  Future<void> setLocale(String languageCode) async {
    try {
      if (!LanguageService.supportedLanguages.containsKey(languageCode)) {
        throw Exception('Unsupported locale: $languageCode');
      }
      
      _locale = Locale(languageCode);
      notifyListeners();
      
      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, languageCode);
      
      // Also update LanguageService for consistency
      await LanguageService.instance.setLanguage(languageCode);
      
      debugPrint('✅ Locale set to: $languageCode');
    } catch (e) {
      debugPrint('❌ Error setting locale: $e');
      rethrow;
    }
  }

  /// Clear saved locale and use device default
  Future<void> clearLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localeKey);
      
      final deviceLocale = ui.PlatformDispatcher.instance.locale;
      final languageCode = deviceLocale.languageCode;
      
      if (LanguageService.supportedLanguages.containsKey(languageCode)) {
        _locale = Locale(languageCode);
      } else {
        _locale = const Locale('en');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error clearing locale: $e');
    }
  }
}

