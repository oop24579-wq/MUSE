import 'package:flutter/material.dart';

import 'onboarding_config.dart';
import 'variants/onboarding_variants.dart';

/// Routes to the active onboarding layout ([OnboardingConfig.kOnboardingVariant]).
class OnboardingRouter extends StatelessWidget {
  const OnboardingRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return switch (OnboardingConfig.active) {
      OnboardingVariant.onboarding1 => const Onboarding1Scaffold(),
      OnboardingVariant.onboarding2 => const Onboarding2Scaffold(),
      OnboardingVariant.onboarding3 => const Onboarding3Scaffold(),
      OnboardingVariant.onboarding4 => const Onboarding4Scaffold(),
      OnboardingVariant.onboarding5 => const Onboarding5Scaffold(),
    };
  }
}
