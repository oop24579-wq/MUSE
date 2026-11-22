import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../shared/onboarding_page_content.dart';

/// Split Story hero — editorial top image + glass panel (variant 5).
class OnboardingSplitHero extends StatefulWidget {
  const OnboardingSplitHero({
    super.key,
    required this.page,
    required this.pageKey,
    required this.stepNumber,
  });

  final OnboardingPageContent page;
  final int pageKey;
  final int stepNumber;

  @override
  State<OnboardingSplitHero> createState() => _OnboardingSplitHeroState();
}

class _OnboardingSplitHeroState extends State<OnboardingSplitHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _kenBurnsController;
  late Animation<double> _zoom;
  late Animation<double> _pan;

  @override
  void initState() {
    super.initState();
    _kenBurnsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _zoom = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _kenBurnsController, curve: Curves.easeInOut),
    );
    _pan = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _kenBurnsController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(OnboardingSplitHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageKey != widget.pageKey) {
      _kenBurnsController.reset();
      _kenBurnsController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _kenBurnsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stepStr = widget.stepNumber.toString().padLeft(2, '0');
    final accent = widget.page.accentColor ?? AppTheme.accentBlue;
    final screenH = MediaQuery.sizeOf(context).height;

    return SizedBox(
      height: screenH * 0.52,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _kenBurnsController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_pan.value * 0.5, -_pan.value * 0.3),
                child: Transform.scale(scale: _zoom.value, child: child),
              );
            },
            child: _buildHeroImage(accent),
          ),
          Positioned(
            top: 2.h,
            left: 4.w,
            child: Text(
              stepStr,
              style: GoogleFonts.inter(
                fontSize: 56.sp,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.12),
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: EdgeInsets.fromLTRB(6.w, 3.h, 6.w, 2.h),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.75),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.page.icon, color: accent, size: 28.sp),
                      SizedBox(height: 1.5.h),
                      if (widget.page.titlePrefix != null) ...[
                        Text(
                          widget.page.titlePrefix!,
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 0.8.h),
                      ],
                      Text(
                        widget.page.title,
                        style: GoogleFonts.inter(
                          fontSize: 26.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        widget.page.description,
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.pageKey == 3)
            Positioned(
              top: 3.h,
              right: 5.w,
              child: _ProTeaser(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroImage(Color accent) {
    final image = widget.page.imageAsset;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (image != null)
          Image.asset(image, fit: BoxFit.cover)
        else
          ColoredBox(color: accent.withValues(alpha: 0.35)),
        ColoredBox(color: Colors.black.withValues(alpha: 0.4)),
        if (widget.pageKey == 1)
          Center(child: _buildFrequencySweep(accent)),
        if (widget.pageKey == 2)
          Center(child: _buildHeadphoneWave(accent)),
      ],
    );
  }

  Widget _buildFrequencySweep(Color accent) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 88.0, end: 108.0),
      duration: const Duration(seconds: 3),
      builder: (context, value, _) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${value.toStringAsFixed(1)} FM',
            style: TextStyle(
              color: accent,
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeadphoneWave(Color accent) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.headphones_rounded, color: Colors.white, size: 20.sp),
        SizedBox(width: 3.w),
        ...List.generate(5, (i) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 8, end: 24),
            duration: Duration(milliseconds: 600 + i * 120),
            curve: Curves.easeInOut,
            builder: (context, h, _) {
              return Container(
                width: 4,
                height: h + 8 * math.sin(i),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}

class _ProTeaser extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.6.h),
      decoration: BoxDecoration(
        color: AppTheme.accentBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 14.sp),
          SizedBox(width: 1.w),
          Text(
            'Pro',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
