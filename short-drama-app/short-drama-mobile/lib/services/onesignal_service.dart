import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drama_now/services/firebase/remote_config_service.dart';

class OneSignalService {
  static Future<void>? _initFuture;
  static bool _sdkActive = false;
  static const _kNotificationsEnabled = 'notifications_enabled';
  static bool _optedIn = true;

  /// Completes when [initialize] finishes (including when SDK init is skipped).
  static Future<void> get ready async {
    final future = _initFuture;
    if (future != null) await future;
  }

  static bool get isSdkActive => _sdkActive;

  static Future<void> initialize() {
    return _initFuture ??= _runInitialize();
  }

  static Future<void> _runInitialize() async {
    try {
      final appId = RemoteConfigService.instance.oneSignalAppId;
      if (appId.isEmpty || appId == 'YOUR_ONESIGNAL_APP_ID_HERE') {
        debugPrint('⚠️ OneSignal: App ID not configured — skipping init');
        return;
      }

      OneSignal.initialize(appId);
      OneSignal.Debug.setLogLevel(OSLogLevel.warn);

      OneSignal.Notifications.addClickListener((event) {
        debugPrint(
          '🔔 OneSignal notification clicked: ${event.notification.title}',
        );
        _handleNotificationClick(event);
      });

      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        if (_optedIn) {
          event.notification.display();
        } else {
          event.preventDefault();
        }
      });

      // Yield so Android initWithContext can finish before User/Push APIs run.
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      _optedIn = prefs.getBool(_kNotificationsEnabled) ?? true;
      _sdkActive = true;
      await _applySubscriptionPreference();

      debugPrint('✅ OneSignal initialized');
    } catch (e, stack) {
      debugPrint('❌ OneSignal initialization error: $e\n$stack');
    }
  }

  static Future<void> _applySubscriptionPreference() async {
    if (!_sdkActive) return;
    if (_optedIn) {
      OneSignal.User.pushSubscription.optIn();
    } else {
      OneSignal.User.pushSubscription.optOut();
    }
  }

  static Future<T?> _whenActive<T>(FutureOr<T> Function() action) async {
    await ready;
    if (!_sdkActive) return null;
    try {
      return await action();
    } catch (e, stack) {
      debugPrint('⚠️ OneSignal operation failed: $e\n$stack');
      return null;
    }
  }

  static Future<bool> requestPermission() async {
    final result = await _whenActive(() async {
      final accepted = await OneSignal.Notifications.requestPermission(true);
      debugPrint('🔔 OneSignal permission: $accepted');
      return accepted;
    });
    return result ?? false;
  }

  static bool get hasOsPermission {
    if (!_sdkActive) return false;
    try {
      return OneSignal.Notifications.permission;
    } catch (e) {
      debugPrint('⚠️ OneSignal hasOsPermission: $e');
      return false;
    }
  }

  static bool get isEnabled => _optedIn && hasOsPermission;

  static Future<bool> enable() async {
    final result = await _whenActive(() async {
      if (!OneSignal.Notifications.permission) {
        final granted = await OneSignal.Notifications.requestPermission(true);
        if (!granted) return false;
      }
      _optedIn = true;
      OneSignal.User.pushSubscription.optIn();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kNotificationsEnabled, true);
      debugPrint('🔔 Notifications enabled');
      return true;
    });
    return result ?? false;
  }

  /// Default OneSignal opt-in after onboarding (Terms & Privacy accepted).
  /// Does not show the OS permission dialog — that only happens when the user
  /// turns notifications on in Settings.
  static Future<void> optInAfterOnboarding() async {
    await _whenActive(() async {
      _optedIn = true;
      OneSignal.User.pushSubscription.optIn();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kNotificationsEnabled, true);
      debugPrint(
        '🔔 OneSignal post-onboarding opt-in (OS permission via Settings only)',
      );
    });
  }

  static Future<void> disable() async {
    await _whenActive(() async {
      _optedIn = false;
      OneSignal.User.pushSubscription.optOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kNotificationsEnabled, false);
      debugPrint('🔔 Notifications disabled');
    });
  }

  /// Links the app user to OneSignal. Waits for SDK init — safe during startup.
  static Future<void> syncUserSession({
    required String userId,
    String? email,
    bool? isPro,
  }) async {
    await _whenActive(() async {
      OneSignal.login(userId);
      debugPrint('🔔 OneSignal external user set: $userId');
      if (email != null && email.isNotEmpty) {
        OneSignal.User.addEmail(email);
      }
      if (isPro != null) {
        OneSignal.User.addTagWithKey('is_pro', isPro.toString());
      }
    });
  }

  static Future<void> clearUserSession() async {
    await _whenActive(() async {
      OneSignal.logout();
      debugPrint('🔔 OneSignal external user removed');
    });
  }

  static void _handleNotificationClick(OSNotificationClickEvent event) {
    final data = event.notification.additionalData;
    if (data == null) return;
    debugPrint('🔔 OneSignal notification data: $data');
  }
}
