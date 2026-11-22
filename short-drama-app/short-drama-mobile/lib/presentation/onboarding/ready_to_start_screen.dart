import 'package:flutter/material.dart';

import 'onboarding_router.dart';

export 'onboarding_config.dart';
export 'onboarding_router.dart';

/// Entry point for the onboarding flow.
/// Layout is selected by [OnboardingConfig.kOnboardingVariant] (hot restart).
class ReadyToStartScreen extends StatelessWidget {
  const ReadyToStartScreen({super.key});

  @override
  Widget build(BuildContext context) => const OnboardingRouter();
}
