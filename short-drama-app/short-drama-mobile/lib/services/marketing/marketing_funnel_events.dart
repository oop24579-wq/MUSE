import 'package:shared_preferences/shared_preferences.dart';

import 'marketing_analytics_service.dart';
import 'marketing_event_names.dart';
import 'meta_app_events_service.dart';

/// Typed funnel helpers for RadioPod marketing analytics.
abstract final class MarketingFunnelEvents {
  static Future<void> trackOnboardingStarted() => MarketingAnalyticsService
      .instance
      .trackOnce(MarketingDedupKeys.onboardingStarted, MarketingEventNames.onboardingStarted);

  static Future<void> trackOnboardingCompleted({int? durationMs}) =>
      MarketingAnalyticsService.instance.trackMarketingEvent(
        MarketingEventNames.onboardingCompleted,
        params: {
          if (durationMs != null) 'duration_ms': durationMs,
        },
      );

  static Future<void> trackOnboardingClick(String step) =>
      MarketingAnalyticsService.instance.trackMarketingEvent(
        MarketingEventNames.onboardingClick,
        params: {'step': step},
      );

  static Future<void> trackOnboardingClickOnce(String step, String dedupKey) =>
      MarketingAnalyticsService.instance.trackOnce(
        dedupKey,
        MarketingEventNames.onboardingClick,
        params: {'step': step},
      );

  static Future<void> trackInputFilled(String fieldName) =>
      MarketingAnalyticsService.instance.trackOnce(
        MarketingDedupKeys.inputFilledPrompt,
        MarketingEventNames.inputFilled,
        params: {'field_name': fieldName},
      );

  static Future<void> trackQuickActionView(String featureName) =>
      MarketingAnalyticsService.instance.trackOnce(
        MarketingDedupKeys.quickActionView(featureName),
        MarketingEventNames.quickActionView,
        params: {'feature_name': featureName},
      );

  static Future<void> trackQuickActionUsed(
    String featureName, {
    required bool success,
  }) =>
      MarketingAnalyticsService.instance.trackMarketingEvent(
        MarketingEventNames.quickActionUsed,
        params: {'feature_name': featureName, 'success': success},
      );

  static Future<void> trackClickCta(String ctaName, String location) =>
      MarketingAnalyticsService.instance.trackMarketingEvent(
        MarketingEventNames.clickCta,
        params: {'cta_name': ctaName, 'location': location},
      );

  static Future<void> trackViewPaywall({
    required String trigger,
    String currentPlan = 'free',
    String currency = 'USD',
    double value = 0,
  }) =>
      MarketingAnalyticsService.instance.trackMarketingEvent(
        MarketingEventNames.viewPaywall,
        params: {
          'trigger': trigger,
          'current_plan': currentPlan,
          'currency': currency,
          'value': value,
        },
      );

  /// Single checkout impression per tap — GA4 [begin_checkout] / Meta InitiatedCheckout.
  static Future<void> trackCheckoutStarted({
    required String packageId,
    required String planId,
    required String planName,
    required double value,
    required String currency,
  }) =>
      MarketingAnalyticsService.instance.trackMarketingEvent(
        MarketingEventNames.beginCheckout,
        params: {
          'package_id': packageId,
          'plan_id': planId,
          'plan_name': planName,
          'value': value,
          'currency': currency,
          'payment_provider': 'revenuecat',
        },
      );

  static Future<void> trackPurchase({
    required String transactionId,
    required double value,
    required String currency,
    required String planId,
    required String planName,
    required String packageId,
    bool isSubscription = true,
  }) async {
    final dedupKey = MarketingDedupKeys.purchaseSent(transactionId);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(dedupKey) == true) return;

    final params = {
      'transaction_id': transactionId,
      'value': value,
      'currency': currency,
      'plan_id': planId,
      'plan_name': planName,
      'package_id': packageId,
      'payment_provider': 'revenuecat',
    };
    await MarketingAnalyticsService.instance.trackMarketingEvent(
      MarketingEventNames.purchase,
      params: params,
      isSubscriptionPurchase: isSubscription,
    );
    await prefs.setBool(dedupKey, true);
    await MetaAppEventsService.instance.flush();
  }

  static Future<void> trackLogin(String method, {String currency = 'USD'}) =>
      MarketingAnalyticsService.instance.trackMarketingEvent(
        MarketingEventNames.login,
        params: {'method': method, 'currency': currency, 'value': 0},
      );

  static Future<void> trackSignUp(String method, {String currency = 'USD'}) =>
      MarketingAnalyticsService.instance.trackMarketingEvent(
        MarketingEventNames.signUp,
        params: {'method': method, 'currency': currency, 'value': 0},
      );

  static Future<void> trackSignOut() =>
      MarketingAnalyticsService.instance.trackMarketingEvent(
        MarketingEventNames.signOut,
      );

  static Future<void> trackAccountLinked(String method) =>
      MarketingAnalyticsService.instance.trackMarketingEvent(
        MarketingEventNames.accountLinked,
        params: {'method': method, 'from_anonymous': true},
      );

  static Future<void> trackAnonymousSessionStarted() =>
      MarketingAnalyticsService.instance.trackMarketingEvent(
        MarketingEventNames.anonymousSessionStarted,
      );

  static Future<void> trackRestorePurchases({required bool success}) =>
      MarketingAnalyticsService.instance.trackMarketingEvent(
        MarketingEventNames.restorePurchases,
        params: {'success': success},
      );

  static Future<void> trackError(String errorType, {Map<String, Object?>? extra}) =>
      MarketingAnalyticsService.instance.trackMarketingEvent(
        MarketingEventNames.errorOccurred,
        params: {'error_type': errorType, ...?extra},
      );
}
