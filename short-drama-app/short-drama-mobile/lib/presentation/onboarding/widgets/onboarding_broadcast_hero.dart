import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../shared/onboarding_page_content.dart';

/// Broadcast Signal hero — radio waves, live badge, genre chips (variant 2).
class OnboardingBroadcastHero extends StatefulWidget {
  const OnboardingBroadcastHero({
    super.key,
    required this.page,
    required this.pageKey,
  });

  final OnboardingPageContent page;
  final int pageKey;

  @override
  State<OnboardingBroadcastHero> createState() =>
      _OnboardingBroadcastHeroState();
}

class _OnboardingBroadcastHeroState extends State<OnboardingBroadcastHero>
    with TickerProviderStateMixin {
  late AnimationController _enterController;
  late AnimationController _loopController;
  late Animation<double> _scale;
  late Animation<double> _fade;

  static const _genres = ['Jazz', 'News', 'Rock', 'Talk', 'Pop'];

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _scale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOut),
    );
    _enterController.forward();
  }

  @override
  void didUpdateWidget(OnboardingBroadcastHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageKey != widget.pageKey) {
      _enterController.reset();
      _enterController.forward();
    }
  }

  @override
  void dispose() {
    _enterController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.page.accentColor ?? AppTheme.accentBlue;

    return AnimatedBuilder(
      animation: Listenable.merge([_enterController, _loopController]),
      builder: (context, child) {
        return Opacity(
          opacity: _fade.value,
          child: Transform.scale(scale: _scale.value, child: child),
        );
      },
      child: SizedBox(
        width: 84.w,
        height: 44.h,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ..._buildRadioRings(accent),
            _buildCenterCard(accent),
            ..._buildGenreChips(accent),
            _buildLiveBadge(accent),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRadioRings(Color accent) {
    return List.generate(3, (i) {
      final phase = _loopController.value + i * 0.2;
      final scale = 0.55 + i * 0.18 + 0.06 * math.sin(phase * 2 * math.pi);
      final opacity = (0.35 - i * 0.08) *
          (0.6 + 0.4 * math.sin(phase * 2 * math.pi));
      return Positioned(
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 70.w,
            height: 70.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.withValues(alpha: opacity.clamp(0.05, 0.5)),
                width: 2,
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildCenterCard(Color accent) {
    final image = widget.page.imageAsset;
    return Container(
      width: 58.w,
      height: 34.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null)
              Image.asset(image, fit: BoxFit.cover)
            else
              ColoredBox(color: accent.withValues(alpha: 0.3)),
            ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
            Center(
              child: Icon(
                widget.page.icon,
                size: 18.w,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGenreChips(Color accent) {
    if (widget.pageKey != 1) return const [];

    return List.generate(_genres.length, (i) {
      final angle = (i / _genres.length) * 2 * math.pi - math.pi / 2;
      final orbit = 38.w + 4 * math.sin(_loopController.value * 2 * math.pi + i);
      return Positioned(
        left: 42.w + math.cos(angle) * orbit * 0.55 - 8.w,
        top: 22.h + math.sin(angle) * orbit * 0.35,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 500 + i * 100),
          curve: Curves.easeOutBack,
          builder: (context, v, child) {
            return Transform.scale(scale: v, child: child);
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.6.h),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _genres[i],
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildLiveBadge(Color accent) {
    final pulse = 0.5 + 0.5 * math.sin(_loopController.value * 2 * math.pi);
    if (widget.pageKey != 1) return const SizedBox.shrink();

    return Positioned(
      top: 2.h,
      right: 6.w,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.85 + pulse * 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9 + pulse * 0.1),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 1.5.w),
            Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
