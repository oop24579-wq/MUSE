import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../services/api/token_store.dart';
import '../../../services/auth/auth_service.dart';
import '../../../services/marketing/marketing_analytics_service.dart';
import '../../../services/marketing/marketing_funnel_events.dart';
import '../../../services/onesignal_service.dart';
import '../../../services/onboarding_service.dart';
import '../../../services/paywall_preload_service.dart';
import '../../../services/rating_service.dart';

/// Session-aware exit navigation for every onboarding completion path
/// (flow controller + privacy consent/settings screens).
///
/// Wiring v2 GAP-FIXED: onboarding completion used to navigate straight to
/// Home assuming a session exists, but bootstrap no longer auto-creates a
/// guest session on fresh installs and splash gates returning launches on a
/// restored session (else '/login'). A first-run user therefore landed on
/// Home session-less. Now: with a stored session (TokenStore refresh token,
/// via [AuthService.hasStoredSession]) OR a live Firebase user, go to
/// [withSessionRoute] as before; with neither, go to '/login'. Every auth
/// probe is guarded — any failure is treated as "no session".
void navigateOnboardingExit(
  BuildContext context, {
  required String withSessionRoute,
}) {
  var hasSession = false;
  try {
    hasSession = AuthService.instance.hasStoredSession;
  } catch (_) {
    // AuthService construction touches FirebaseAuth.instance; if Firebase
    // is not ready, fall back to the raw TokenStore check (which is exactly
    // what hasStoredSession reads).
    try {
      final refresh = TokenStore.instance.refreshToken;
      hasSession = refresh != null && refresh.isNotEmpty;
    } catch (_) {
      hasSession = false;
    }
  }
  if (!hasSession) {
    try {
      hasSession = FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      hasSession = false;
    }
  }
  if (!context.mounted) return;
  Navigator.pushReplacementNamed(
    context,
    hasSession ? withSessionRoute : '/login',
  );
}

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
      navigateOnboardingExit(context, withSessionRoute: '/home');
    }
  }
}
