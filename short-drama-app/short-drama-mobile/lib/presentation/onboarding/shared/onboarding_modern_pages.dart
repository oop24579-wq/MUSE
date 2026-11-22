import 'package:flutter/material.dart';

import '../../../core/app_export.dart';
import '../../../l10n/app_localizations.dart';
import 'onboarding_page_content.dart';

/// Four-page copy shared by onboarding variants 2–5.
List<OnboardingPageContent> modernOnboardingPages(BuildContext context) {
  final appName = AppLocalizations.of(context)?.appTitle ?? 'HERO DRAMA';
  return [
    OnboardingPageContent(
      title: appName,
      titlePrefix: 'Welcome to',
      description: 'Thousands of short dramas, ready to binge anytime.',
      icon: Icons.movie_filter_rounded,
      imageAsset: 'assets/images/onboarding/onboarding_welcome.png',
      accentColor: AppTheme.accentBlue,
    ),
    OnboardingPageContent(
      title: 'Bite-Sized Drama',
      description: 'Addictive stories told in fast, vertical episodes.',
      icon: Icons.play_circle_fill_rounded,
      imageAsset: 'assets/images/onboarding/onboarding_ai_songs.png',
      accentColor: AppTheme.accentBlueLight,
    ),
    OnboardingPageContent(
      title: 'Never Miss an Episode',
      description: 'Follow your favorites and resume where you left off.',
      icon: Icons.bookmark_added_rounded,
      imageAsset: 'assets/images/onboarding/onboarding_ai_covers.png',
      accentColor: AppTheme.accentSecondary,
    ),
    OnboardingPageContent(
      title: 'Earn & Unlock',
      description: 'Collect daily coins and unlock premium episodes.',
      icon: Icons.card_giftcard_rounded,
      imageAsset: 'assets/images/onboarding/onboarding_ai_music_videos.png',
      accentColor: AppTheme.accentBlueMuted,
    ),
  ];
}

String onboardingWelcomeSubtitle(BuildContext context) {
  final appName = AppLocalizations.of(context)?.appTitle ?? 'HERO DRAMA';
  return 'Welcome to $appName';
}
