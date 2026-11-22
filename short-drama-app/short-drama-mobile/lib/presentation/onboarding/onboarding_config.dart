/// Onboarding layout variants — switch with [kOnboardingVariant] (hot restart required).
///
/// 1 = Original 4-page flow (legacy hero visuals)
/// 1 = Original 4-page flow (dots + classic pill button)
/// 2 = Broadcast Signal — line progress + flat bar button + top divider
/// 3 = Living Waveform — hero timeline + outlined button
/// 4 = Card Carousel — dots + arrow trailing button + surface card bottom
/// 5 = Split Story — dots + editorial uppercase button
enum OnboardingVariant {
  onboarding1,
  onboarding2,
  onboarding3,
  onboarding4,
  onboarding5,
}

class OnboardingConfig {
  OnboardingConfig._();

  /// ── CHANGE THIS (1–5) TO SWITCH ONBOARDING LAYOUT. Hot restart required. ──
  static const int kOnboardingVariant = 1;

  static OnboardingVariant get active => switch (kOnboardingVariant) {
        1 => OnboardingVariant.onboarding1,
        2 => OnboardingVariant.onboarding2,
        3 => OnboardingVariant.onboarding3,
        4 => OnboardingVariant.onboarding4,
        5 => OnboardingVariant.onboarding5,
        _ => OnboardingVariant.onboarding1,
      };
}
