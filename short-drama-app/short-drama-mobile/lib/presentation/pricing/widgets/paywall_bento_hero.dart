import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import 'animated_paywall_collage.dart';

/// Paywall hero / background — an animated poster collage that slides at a
/// slight angle, with a bottom fade into the paywall shell for legibility.
class PaywallBentoHero extends StatelessWidget {
  const PaywallBentoHero({super.key, required this.height, this.imageUrls});

  final double height;

  /// Optional real catalog posters; falls back to the curated drama set.
  final List<String>? imageUrls;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          RepaintBoundary(
            child: AnimatedPaywallCollage(imageUrls: imageUrls),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppTheme.paywallHeroFadeGradient(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
