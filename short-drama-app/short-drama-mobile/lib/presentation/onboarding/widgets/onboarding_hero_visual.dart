import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

enum OnboardingHeroType { welcome, liveRadio, podcasts, library }

class OnboardingHeroVisual extends StatefulWidget {
  const OnboardingHeroVisual({
    super.key,
    required this.type,
    required this.imageAsset,
    required this.pageKey,
  });

  final OnboardingHeroType type;
  final String imageAsset;
  final int pageKey;

  @override
  State<OnboardingHeroVisual> createState() => _OnboardingHeroVisualState();
}

class _OnboardingHeroVisualState extends State<OnboardingHeroVisual>
    with TickerProviderStateMixin {
  late AnimationController _enterController;
  late AnimationController _loopController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void didUpdateWidget(OnboardingHeroVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageKey != widget.pageKey) {
      _enterController.reset();
      _enterController.forward();
    }
  }

  void _setupAnimations() {
    _enterController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _loopController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic),
    );

    _enterController.forward();
  }

  @override
  void dispose() {
    _enterController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_enterController, _loopController]),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: SizedBox(
        width: 78.w,
        height: 42.h,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _buildImage(),
            ..._buildOverlays(),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.type == OnboardingHeroType.liveRadio ? 999 : 20),
      child: Image.asset(
        widget.imageAsset,
        width: widget.type == OnboardingHeroType.liveRadio ? 62.w : 78.w,
        height: widget.type == OnboardingHeroType.liveRadio ? 62.w : 42.h,
        fit: BoxFit.cover,
      ),
    );
  }

  List<Widget> _buildOverlays() {
    switch (widget.type) {
      case OnboardingHeroType.welcome:
        return [_buildWelcomeBadge()];
      case OnboardingHeroType.liveRadio:
        return [_buildRadioRing()];
      case OnboardingHeroType.podcasts:
        return [_buildPodcastOverlay()];
      case OnboardingHeroType.library:
        return [_buildTransformPulse()];
    }
  }

  Widget _buildWelcomeBadge() {
    return Positioned(
      bottom: 2.h,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_rounded,
                    color: const Color(0xFFFFD700), size: 16.sp),
                SizedBox(width: 1.5.w),
                Text(
                  'Thousands of dramas',
                  style: TextStyle(
                    color: const Color(0xFFFFD700),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 1.5.w),
                Icon(Icons.emoji_events_rounded,
                    color: const Color(0xFFFFD700), size: 16.sp),
              ],
            ),
            SizedBox(height: 0.6.h),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                5,
                (_) => Icon(Icons.star_rounded,
                    color: const Color(0xFFFFD700), size: 14.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioRing() {
    final pulse = 0.5 + 0.5 * math.sin(_loopController.value * 2 * math.pi);
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.accentBlue.withValues(alpha: 0.2 + pulse * 0.25),
              width: 3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPodcastOverlay() {
    final pulse = 0.5 + 0.5 * math.sin(_loopController.value * 2 * math.pi);
    return Positioned(
      bottom: 3.h,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _waveBars(isLeft: true),
              Container(
                width: 14.w,
                height: 14.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accentBlue.withValues(alpha: 0.6 + pulse * 0.4),
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 6.w,
                    height: 6.w,
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              _waveBars(isLeft: false),
            ],
          ),
          SizedBox(height: 0.8.h),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _waveBars({required bool isLeft}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final phase = _loopController.value + index * 0.15;
        final height = 8 + 12 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi));
        return Container(
          width: 2.5,
          height: height,
          margin: EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildTransformPulse() {
    final pulse = 0.5 + 0.5 * math.sin(_loopController.value * 2 * math.pi);
    return Positioned(
      right: 4.w,
      bottom: 8.h,
      child: Transform.scale(
        scale: 0.95 + pulse * 0.08,
        child: Container(
          width: 12.w,
          height: 12.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            color: AppTheme.surface,
          ),
          child: Icon(Icons.auto_awesome, color: AppTheme.accentBlue, size: 14.sp),
        ),
      ),
    );
  }
}
