import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Thin Firebase Analytics adapter used by [MarketingAnalyticsService].
/// Must call [initialize] after [Firebase.initializeApp] (during AppBootstrap).
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;

  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  FirebaseAnalyticsObserver? _observer;

  bool get isInitialized => _analytics != null;

  /// Available only after [initialize]. Used for automatic route screen tracking.
  FirebaseAnalyticsObserver? get observer => _observer;

  Future<void> initialize() async {
    try {
      debugPrint('📊 Initializing Analytics Service...');
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
      await _analytics!.setAnalyticsCollectionEnabled(false);
      debugPrint('✅ Analytics Service initialized (collection disabled until consent)');
    } catch (e) {
      debugPrint('❌ Analytics Service initialization error: $e');
    }
  }

  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.setAnalyticsCollectionEnabled(enabled);
    } catch (e) {
      debugPrint('❌ Error setting analytics collection: $e');
    }
  }

  Future<void> setUserId(String userId) async {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.setUserId(id: userId.isEmpty ? null : userId);
    } catch (e) {
      debugPrint('❌ Error setting user ID: $e');
    }
  }

  Future<void> setUserProperty(String name, String value) async {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('❌ Error setting user property: $e');
    }
  }

  Future<void> logScreenView(String screenName) async {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint('❌ Error logging screen view: $e');
    }
  }

  Future<void> logLogin({required String method}) async {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.logLogin(loginMethod: method);
    } catch (e) {
      debugPrint('❌ Error logging login: $e');
    }
  }

  Future<void> logSignUp({required String method}) async {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.logSignUp(signUpMethod: method);
    } catch (e) {
      debugPrint('❌ Error logging sign up: $e');
    }
  }

  Future<void> logBeginCheckout({
    required String currency,
    required double value,
    String? itemId,
    String? itemName,
  }) async {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.logBeginCheckout(
        value: value,
        currency: currency,
        items: [
          if (itemId != null || itemName != null)
            AnalyticsEventItem(
              itemId: itemId,
              itemName: itemName,
              price: value,
            ),
        ],
      );
    } catch (e) {
      debugPrint('❌ Error logging begin checkout: $e');
    }
  }

  Future<void> logPurchase({
    required String currency,
    required double value,
    String? transactionId,
    String? itemId,
    String? itemName,
  }) async {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.logPurchase(
        currency: currency,
        value: value,
        transactionId: transactionId,
        items: [
          if (itemId != null || itemName != null)
            AnalyticsEventItem(
              itemId: itemId,
              itemName: itemName,
              price: value,
            ),
        ],
      );
    } catch (e) {
      debugPrint('❌ Error logging purchase: $e');
    }
  }

  Future<void> logCustomEvent(
    String eventName, {
    Map<String, Object>? parameters,
  }) async {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.logEvent(name: eventName, parameters: parameters);
    } catch (e) {
      debugPrint('❌ Error logging custom event: $e');
    }
  }
}
