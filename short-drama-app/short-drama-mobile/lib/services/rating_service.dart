import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service to handle in-app rating and store listing for both Android and iOS.
class RatingService {
  static final RatingService _instance = RatingService._internal();
  factory RatingService() => _instance;
  RatingService._internal();

  static const _keyLastReviewPromptAt = 'last_review_prompt_at_ms';
  static const _keyPendingPostOnboardingReview =
      'pending_post_onboarding_review';

  /// Minimum time between automatic in-app review prompts on home open.
  static const reviewPromptInterval = Duration(hours: 12);

  final InAppReview _inAppReview = InAppReview.instance;

  /// Call when onboarding finishes so the first home visit shows in-app review.
  Future<void> markPendingReviewAfterOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPendingPostOnboardingReview, true);
  }

  /// Shows the native in-app review sheet when eligible (home open).
  ///
  /// - First home visit after onboarding: always prompts.
  /// - Returning users: prompts if never prompted before, or if [reviewPromptInterval]
  ///   has passed since the last attempt.
  ///
  /// Returns `true` when a prompt was attempted.
  Future<bool> maybePromptReviewOnHomeOpen() async {
    final prefs = await SharedPreferences.getInstance();

    final pendingPostOnboarding =
        prefs.getBool(_keyPendingPostOnboardingReview) ?? false;
    if (pendingPostOnboarding) {
      await prefs.setBool(_keyPendingPostOnboardingReview, false);
      await _recordAndRequestReview();
      return true;
    }

    if (!_isEligibleForPrompt(prefs)) {
      return false;
    }

    await _recordAndRequestReview();
    return true;
  }

  bool _isEligibleForPrompt(SharedPreferences prefs) {
    final lastMs = prefs.getInt(_keyLastReviewPromptAt);
    if (lastMs == null) return true;

    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastMs),
    );
    return elapsed >= reviewPromptInterval;
  }

  Future<void> _recordAndRequestReview() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _keyLastReviewPromptAt,
      DateTime.now().millisecondsSinceEpoch,
    );
    await requestReview();
  }

  /// Open the app's store listing page (Play Store or App Store).
  /// Use this for manual "Rate Us" buttons — opens the store directly.
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async {
    try {
      await _inAppReview.openStoreListing(
        appStoreId: appStoreId,
        microsoftStoreId: microsoftStoreId,
      );
      debugPrint('✅ Store listing opened successfully');
    } catch (e) {
      debugPrint('❌ Error opening store listing: $e');
      await _openStoreFallback();
    }
  }

  Future<void> _openStoreFallback() async {
    try {
      String url;
      if (Platform.isIOS) {
        const appStoreId = 'YOUR_APP_STORE_ID';
        url = appStoreId != 'YOUR_APP_STORE_ID'
            ? 'https://apps.apple.com/app/id$appStoreId'
            : 'https://apps.apple.com';
      } else if (Platform.isAndroid) {
        url =
            'https://play.google.com/store/apps/details?id=com.shortdrama.watch';
      } else {
        return;
      }
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('❌ Fallback store URL failed: $e');
    }
  }

  /// Request in-app review (has quota limits) or fallback to store listing.
  Future<void> requestReview({
    String? appStoreId,
    String? microsoftStoreId,
  }) async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        debugPrint('✅ In-app review requested');
      } else {
        await openStoreListing(
          appStoreId: appStoreId,
          microsoftStoreId: microsoftStoreId,
        );
      }
    } catch (e) {
      debugPrint('❌ Error requesting review: $e');
      await openStoreListing(
        appStoreId: appStoreId,
        microsoftStoreId: microsoftStoreId,
      );
    }
  }
}
