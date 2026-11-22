import 'package:flutter/material.dart';

/// Shared page model for modern onboarding variants (2–5).
class OnboardingPageContent {
  const OnboardingPageContent({
    required this.title,
    required this.description,
    required this.icon,
    this.titlePrefix,
    this.imageAsset,
    this.accentColor,
  });

  final String title;
  final String? titlePrefix;
  final String description;
  final IconData icon;
  final String? imageAsset;
  final Color? accentColor;
}
