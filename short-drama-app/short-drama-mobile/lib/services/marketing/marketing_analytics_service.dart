import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/analytics_service.dart';
import '../onboarding_service.dart';
import '../auth/auth_service.dart';
import 'marketing_event_names.dart';
import 'meta_app_events_service.dart';

/// Unified marketing analytics — fans out to Firebase GA4 + Meta App Events.
/// RadioPod marketing analytics (Firebase, Meta, Amplitude-style events).
class MarketingAnalyticsService {
  static final MarketingAnalyticsService _instance =
      MarketingAnalyticsService._();
  static MarketingAnalyticsService get instance => _instance;

  MarketingAnalyticsService._();

  bool _bootstrapped = false;
  String? _appVersion;
  bool? _isPro;
  bool? _isAnonymous;

  Future<void> initialize() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await MetaAppEventsService.instance.initialize();
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
    } catch (_) {}
  }

  /// Enable/disable collection on Firebase + Meta. Call after consent.
  Future<void> setCollectionEnabled(bool enabled) async {
    try {
      await AnalyticsService.instance.setAnalyticsCollectionEnabled(enabled);
      await MetaAppEventsService.instance.setCollectionEnabled(enabled);
      if (enabled) {
        await _trackSessionStartOnce();
        if (Platform.isIOS) {
          await _requestAttAndConfigureMeta();
        }
      }
    } catch (e) {
      debugPrint('❌ setCollectionEnabled error: $e');
    }
  }

  /// Sync analytics identity after auth changes.
  Future<void> syncUserIdentity({
    required String userId,
    bool? isAnonymous,
    bool? isPro,
    String? email,
    String? firstName,
    String? lastName,
  }) async {
    _isAnonymous = isAnonymous;
    _isPro = isPro;

    if (!await _hasConsent()) return;

    await AnalyticsService.instance.setUserId(userId);
    await MetaAppEventsService.instance.setUserId(userId);

    if (isAnonymous != true && email != null && email.isNotEmpty) {
      await MetaAppEventsService.instance.setUserData(
        email: email,
        firstName: firstName,
        lastName: lastName,
      );
    }

    if (isPro != null) {
      await AnalyticsService.instance.setUserProperty('is_pro', isPro.toString());
    }
    if (isAnonymous != null) {
      await AnalyticsService.instance.setUserProperty(
        'is_anonymous',
        isAnonymous.toString(),
      );
    }
  }

  Future<void> clearUserIdentity() async {
    await AnalyticsService.instance.setUserId('');
    await MetaAppEventsService.instance.clearUser();
    _isAnonymous = null;
    _isPro = null;
  }

  void updateUserContext({bool? isPro, bool? isAnonymous}) {
    if (isPro != null) _isPro = isPro;
    if (isAnonymous != null) _isAnonymous = isAnonymous;
  }

  /// Core event API — consent-gated, enriched, dual-destination.
  Future<void> trackMarketingEvent(
    String eventName, {
    Map<String, Object?>? params,
    bool isSubscriptionPurchase = false,
    bool bypassConsent = false,
  }) async {
    if (!bypassConsent && !await _hasConsent()) return;

    final enriched = await _enrichParams(params);
    final firebaseParams = _firebaseParams(enriched);

    try {
      await _logFirebase(eventName, firebaseParams);
      await MetaAppEventsService.instance.trackEvent(
        eventName,
        params: enriched,
        isSubscriptionPurchase: isSubscriptionPurchase,
      );
      if (kDebugMode) {
        debugPrint('📊 Marketing event: $eventName $enriched');
      }
    } catch (e) {
      debugPrint('❌ trackMarketingEvent error ($eventName): $e');
    }
  }

  /// Fire only if dedup key not yet set this session/install.
  Future<void> trackOnce(
    String dedupKey,
    String eventName, {
    Map<String, Object?>? params,
    bool bypassConsent = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(dedupKey) == true) return;
    await trackMarketingEvent(
      eventName,
      params: params,
      bypassConsent: bypassConsent,
    );
    await prefs.setBool(dedupKey, true);
  }

  Future<bool> _hasConsent() async {
    await OnboardingService.instance.initialize();
    return OnboardingService.instance.isAnalyticsEnabled();
  }

  Future<Map<String, Object?>> _enrichParams(
    Map<String, Object?>? params,
  ) async {
    final result = <String, Object?>{...?params};
    result['platform'] = Platform.isIOS ? 'ios' : 'android';
    if (_appVersion != null) result['app_version'] = _appVersion!;
    if (_isAnonymous != null) result['is_anonymous'] = _isAnonymous!;
    if (_isPro != null) result['is_pro'] = _isPro!;

    final user = AuthService.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      final email = user.email;
      if (email != null && email.isNotEmpty) {
        result['user_email'] = email;
      }
      final name = user.displayName;
      if (name != null && name.isNotEmpty) {
        final parts = name.trim().split(RegExp(r'\s+'));
        if (parts.isNotEmpty) result['user_first_name'] = parts.first;
        if (parts.length > 1) {
          result['user_last_name'] = parts.sublist(1).join(' ');
        }
      }
    }
    return result;
  }

  Map<String, Object> _firebaseParams(Map<String, Object?> params) {
    return params.map((k, v) {
      if (v == null) return MapEntry(k, '' as Object);
      if (v is String || v is num) return MapEntry(k, v);
      if (v is bool) return MapEntry(k, v ? 1 : 0);
      return MapEntry(k, v.toString());
    });
  }

  Future<void> _logFirebase(
    String eventName,
    Map<String, Object> params,
  ) async {
    switch (eventName) {
      case MarketingEventNames.login:
        await AnalyticsService.instance.logLogin(
          method: params['method'] as String? ?? 'unknown',
        );
        break;
      case MarketingEventNames.signUp:
        await AnalyticsService.instance.logSignUp(
          method: params['method'] as String? ?? 'unknown',
        );
        break;
      case MarketingEventNames.purchase:
        await AnalyticsService.instance.logPurchase(
          currency: params['currency'] as String? ?? 'USD',
          value: (params['value'] as num?)?.toDouble() ?? 0,
          transactionId: params['transaction_id'] as String?,
          itemId: params['package_id'] as String? ?? params['plan_id'] as String?,
          itemName: params['plan_name'] as String?,
        );
        break;
      case MarketingEventNames.beginCheckout:
        await AnalyticsService.instance.logBeginCheckout(
          currency: params['currency'] as String? ?? 'USD',
          value: (params['value'] as num?)?.toDouble() ?? 0,
          itemId: params['plan_id'] as String? ?? params['package_id'] as String?,
          itemName: params['plan_name'] as String?,
        );
        break;
      case MarketingEventNames.screenView:
        await AnalyticsService.instance.logScreenView(
          params['screen_name'] as String? ?? 'unknown',
        );
        break;
      default:
        await AnalyticsService.instance.logCustomEvent(eventName, parameters: params);
    }
  }

  Future<void> _trackSessionStartOnce() async {
    await trackOnce(
      MarketingDedupKeys.sessionStart,
      MarketingEventNames.sessionStart,
      params: {'platform': Platform.isIOS ? 'ios' : 'android'},
    );
  }

  Future<void> _requestAttAndConfigureMeta() async {
    try {
      var status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        status = await AppTrackingTransparency.requestTrackingAuthorization();
      }
      await MetaAppEventsService.instance.setAdvertiserTracking(
        enabled: status == TrackingStatus.authorized,
      );
    } catch (e) {
      debugPrint('⚠️ ATT request error: $e');
    }
  }
}
