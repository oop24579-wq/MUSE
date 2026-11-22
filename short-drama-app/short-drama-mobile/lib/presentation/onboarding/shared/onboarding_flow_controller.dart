import 'package:flutter/material.dart';

import '../../../services/marketing/marketing_analytics_service.dart';
import '../../../services/marketing/marketing_funnel_events.dart';
import '../../../services/onesignal_service.dart';
import '../../../services/onboarding_service.dart';
import '../../../services/paywall_preload_service.dart';
import '../../../services/rating_service.dart';

/// Shared completion flow for all onboarding variants.
class OnboardingFlowController {
  OnboardingFlowController({
    required this.context,
    required this.screenOpenedAt,
  });

  final BuildContext context;
  final DateTime screenOpenedAt;

  void preloadPaywall() {
    PaywallPreloadService.instance.preload();
  }

  Future<void> completeOnboarding() async {
    await OnboardingService.instance.acceptAllPrivacy();
    await OnboardingService.instance.setOnboardingCompleted();
    await OneSignalService.optInAfterOnboarding();
    await MarketingAnalyticsService.instance.setCollectionEnabled(true);
    await MarketingFunnelEvents.trackOnboardingStarted();
    final durationMs =
        DateTime.now().difference(screenOpenedAt).inMilliseconds;
    await MarketingFunnelEvents.trackOnboardingCompleted(durationMs: durationMs);
    await RatingService().markPendingReviewAfterOnboarding();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }
}
