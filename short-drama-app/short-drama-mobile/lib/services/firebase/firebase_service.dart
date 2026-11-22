import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'package:drama_now/services/firebase/analytics_service.dart';
import 'package:drama_now/services/marketing/marketing_analytics_service.dart';
import 'package:drama_now/services/firebase/remote_config_service.dart';
import 'package:drama_now/services/firebase/storage_service.dart';

/// Core Firebase service that initializes all Firebase services
class FirebaseService {
  static bool _initialized = false;

  /// Initialize all Firebase services
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('🔥 Firebase already initialized');
      return;
    }

    try {
      debugPrint('🔥 Initializing Firebase...');

      // Initialize Firebase Core
      await Firebase.initializeApp();
      debugPrint('✅ Firebase Core initialized');

      // Initialize Crashlytics
      await _initializeCrashlytics();

      // Initialize other services
      await Future.wait([
        StorageService.instance.initialize(),
        RemoteConfigService.instance.initialize(),
        AnalyticsService.instance.initialize(),
        MarketingAnalyticsService.instance.initialize(),
      ]);

      _initialized = true;
      debugPrint('✅ All Firebase services initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Firebase initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Initialize Firebase Crashlytics
  static Future<void> _initializeCrashlytics() async {
    try {
      // Pass all uncaught errors to Crashlytics
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };

      // Pass all uncaught asynchronous errors to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      debugPrint('✅ Crashlytics initialized');
    } catch (e) {
      debugPrint('⚠️ Crashlytics initialization failed: $e');
    }
  }

  /// Check if Firebase is initialized
  static bool get isInitialized => _initialized;

  /// Log a custom error to Crashlytics
  static Future<void> logError(
    dynamic error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to log error to Crashlytics: $e');
    }
  }

  /// Set custom key-value pairs for Crashlytics
  static Future<void> setCustomKey(String key, dynamic value) async {
    try {
      await FirebaseCrashlytics.instance.setCustomKey(key, value);
    } catch (e) {
      debugPrint('⚠️ Failed to set custom key: $e');
    }
  }

  /// Set user identifier for Crashlytics
  static Future<void> setUserIdentifier(String identifier) async {
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(identifier);
    } catch (e) {
      debugPrint('⚠️ Failed to set user identifier: $e');
    }
  }
}
