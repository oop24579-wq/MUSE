import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../shared/onboarding_page_content.dart';

/// Card Carousel hero — one featured card per page with depth silhouettes (variant 4).
///
/// Shows only the current page image. Decorative card backs behind suggest a
/// carousel deck without mixing other onboarding images.
class OnboardingCarouselHero extends StatefulWidget {
  const OnboardingCarouselHero({
    super.key,
    required this.page,
    required this.pageKey,
  });

  final OnboardingPageContent page;
  final int pageKey;

  @override
  State<OnboardingCarouselHero> createState() => _OnboardingCarouselHeroState();
}

class _OnboardingCarouselHeroState extends State<OnboardingCarouselHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _enterController;
  late Animation<double> _fade;
  late Animation<double> _scale;

  static const _labels = ['Welcome', 'Watch', 'Follow', 'Rewards'];

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic),
    );
    _enterController.forward();
  }

  @override
  void didUpdateWidget(OnboardingCarouselHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageKey != widget.pageKey) {
      _enterController.reset();
      _enterController.forward();
    }
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.page.accentColor ?? AppTheme.accentBlue;

    return AnimatedBuilder(
      animation: _enterController,
      builder: (context, child) {
        return Opacity(
          opacity: _fade.value,
          child: Transform.scale(scale: _scale.value, child: child),
        );
      },
      child: SizedBox(
        width: 88.w,
        height: 44.h,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            _DeckSilhouette(offsetX: -10.w, offsetY: 1.2.h, width: 48.w, height: 28.h),
            _DeckSilhouette(offsetX: 10.w, offsetY: 1.2.h, width: 48.w, height: 28.h),
            _FeaturedCard(
              page: widget.page,
              pageKey: widget.pageKey,
              accent: accent,
              label: _labels[widget.pageKey.clamp(0, _labels.length - 1)],
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty card shape — depth only, no image.
class _DeckSilhouette extends StatelessWidget {
  const _DeckSilhouette({
    required this.offsetX,
    required this.offsetY,
    required this.width,
    required this.height,
  });

  final double offsetX;
  final double offsetY;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(offsetX, offsetY),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.divider, width: 1),
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.page,
    required this.pageKey,
    required this.accent,
    required this.label,
  });

  final OnboardingPageContent page;
  final int pageKey;
  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56.w,
      height: 34.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentBlue, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (page.imageAsset != null)
              Image.asset(page.imageAsset!, fit: BoxFit.cover)
            else
              ColoredBox(color: accent.withValues(alpha: 0.25)),
            ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
            Positioned(
              left: 4.w,
              right: 4.w,
              bottom: 2.5.h,
              child: Row(
                children: [
                  Icon(page.icon, color: Colors.white, size: 18.sp),
                  SizedBox(width: 2.5.w),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (pageKey == 2)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 2.5.w,
                        vertical: 0.5.h,
                      ),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '42 min',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
