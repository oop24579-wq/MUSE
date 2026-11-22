import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:drama_now/services/app_config_service.dart';
import 'package:drama_now/services/auth/auth_service.dart';
import 'package:drama_now/services/firebase/firebase_service.dart';
import 'package:drama_now/services/firebase/remote_config_service.dart';
import 'package:drama_now/services/onesignal_service.dart';

/// Runs the heavy app initialization exactly once, off the critical path that
/// blocks the first frame.
class AppBootstrap {
  AppBootstrap._();

  static Future<void>? _future;

  static Future<void> ensureInitialized() => _future ??= _run();

  static Future<void> _run() async {
    unawaited(_clearCacheQuietly());

    try {
      await FirebaseService.initialize();
      debugPrint('✅ Firebase and Remote Config loaded');
    } catch (e) {
      debugPrint('❌ Failed to initialize Firebase: $e');
    }

    final rc = RemoteConfigService.instance;
    rc.logMissingConfigKeys();

    try {
      await OneSignalService.initialize();
    } catch (e) {
      debugPrint('❌ OneSignal initialization failed: $e');
    }

    if (rc.isBackendConfigReady) {
      // Remote app config (feature flags etc.) — never blocks/breaks startup.
      unawaited(AppConfigService.instance.load());
      try {
        await AuthService.instance.initialize();
        await AuthService.instance.ensureAuthenticated();
        debugPrint('✅ Auth + web API session ready');
      } catch (e) {
        debugPrint('❌ Auth initialization failed: $e');
      }
    } else {
      debugPrint(
        '⚠️ Skipping API auth — set api_base_url in Firebase Remote Config',
      );
    }
  }

  static Future<void> _clearCacheQuietly() async {
    try {
      debugPrint('🧹 Clearing app cache...');
      await DefaultCacheManager().emptyCache();
      debugPrint('✅ Cache cleared successfully');
    } catch (e) {
      debugPrint('⚠️ Error clearing cache: $e');
    }
  }
}
