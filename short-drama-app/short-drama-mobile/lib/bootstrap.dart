import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:drama_now/core/app_navigator.dart';
import 'package:drama_now/services/api/api_client.dart';
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
    // Round 4: any 503 MAINTENANCE response anywhere in the app routes to
    // the MaintenanceScreen (single global handling in ApiClient; the
    // latch there prevents stacks/loops).
    ApiClient.instance.onMaintenance = () {
      appNavigatorKey.currentState?.pushNamed('/maintenance');
    };

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
        // Gated auth: only ensure a session when one already exists —
        // a live Firebase user (initialize() already exchanged for it)
        // or a stored web refresh token the splash can restore. A truly
        // fresh install must reach the splash/login flow with NO
        // session; ensureAuthenticated() would otherwise silently
        // create an anonymous guest session on every cold start.
        final auth = AuthService.instance;
        if (auth.currentUser != null || auth.hasStoredSession) {
          await auth.ensureAuthenticated();
          debugPrint('✅ Auth + web API session ready');
        } else {
          debugPrint(
            '🔐 No existing session — deferring to the login gate',
          );
        }
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
