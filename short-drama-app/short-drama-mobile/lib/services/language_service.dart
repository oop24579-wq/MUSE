import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

/// Language service for managing app language
class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  static LanguageService get instance => _instance;

  LanguageService._internal();

  static const String _languageKey = 'app_language';
  static const String _defaultLanguage = 'en';

  /// Supported languages
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'it': 'Italiano',
    'pt': 'Português',
    'ru': 'Русский',
    'ja': '日本語',
    'ko': '한국어',
    'zh': '中文',
    'ar': 'العربية',
    'tr': 'Türkçe',
  };

  /// Flag emoji for each supported language code.
  static const Map<String, String> languageFlags = {
    'en': '🇺🇸',
    'es': '🇪🇸',
    'fr': '🇫🇷',
    'de': '🇩🇪',
    'it': '🇮🇹',
    'pt': '🇧🇷',
    'ru': '🇷🇺',
    'ja': '🇯🇵',
    'ko': '🇰🇷',
    'zh': '🇨🇳',
    'ar': '🇸🇦',
    'tr': '🇹🇷',
  };

  /// Get flag emoji for a language code.
  String getLanguageFlag(String languageCode) {
    return languageFlags[languageCode] ?? '🌐';
  }

  /// Get current language code
  Future<String> getCurrentLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_languageKey);
      
      if (savedLanguage != null && supportedLanguages.containsKey(savedLanguage)) {
        return savedLanguage;
      }
      
      // Try to detect device language
      final deviceLanguage = _getDeviceLanguage();
      if (deviceLanguage != null && supportedLanguages.containsKey(deviceLanguage)) {
        return deviceLanguage;
      }
      
      // Return default
      return _defaultLanguage;
    } catch (e) {
      debugPrint('❌ Error getting current language: $e');
      return _defaultLanguage;
    }
  }

  /// Set app language
  /// Note: This method is kept for backward compatibility
  /// The actual locale change should be done through LocaleProvider
  Future<void> setLanguage(String languageCode) async {
    try {
      if (!supportedLanguages.containsKey(languageCode)) {
        throw Exception('Unsupported language: $languageCode');
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
      debugPrint('✅ Language preference saved: $languageCode');
    } catch (e) {
      debugPrint('❌ Error setting language: $e');
      rethrow;
    }
  }

  /// Get device language code
  String? _getDeviceLanguage() {
    try {
      final locale = ui.PlatformDispatcher.instance.locale;
      final languageCode = locale.languageCode;
      return languageCode;
    } catch (e) {
      debugPrint('❌ Error getting device language: $e');
      return null;
    }
  }

  /// Get language display name
  String getLanguageName(String languageCode) {
    return supportedLanguages[languageCode] ?? languageCode.toUpperCase();
  }

  /// Get all supported languages
  Map<String, String> getSupportedLanguages() {
    return supportedLanguages;
  }
}

