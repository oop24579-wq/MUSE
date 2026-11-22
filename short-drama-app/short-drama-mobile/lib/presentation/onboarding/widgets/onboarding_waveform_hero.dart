import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../shared/onboarding_page_content.dart';

/// Living Waveform hero — continuous wave that shifts color per page (variant 3).
class OnboardingWaveformHero extends StatefulWidget {
  const OnboardingWaveformHero({
    super.key,
    required this.page,
    required this.pageKey,
    required this.totalPages,
  });

  final OnboardingPageContent page;
  final int pageKey;
  final int totalPages;

  @override
  State<OnboardingWaveformHero> createState() => _OnboardingWaveformHeroState();
}

class _OnboardingWaveformHeroState extends State<OnboardingWaveformHero>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _enterController;
  late Animation<double> _fade;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200 + widget.pageKey * 400),
    )..repeat();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOut),
    );
    _slide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic),
    );
    _enterController.forward();
  }

  @override
  void didUpdateWidget(OnboardingWaveformHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageKey != widget.pageKey) {
      _enterController.reset();
      _enterController.forward();
      _waveController.duration =
          Duration(milliseconds: 1200 + widget.pageKey * 400);
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.page.accentColor ?? AppTheme.accentBlue;

    return AnimatedBuilder(
      animation: Listenable.merge([_waveController, _enterController]),
      builder: (context, child) {
        return Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(0, _slide.value),
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: 88.w,
        height: 44.h,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _buildTimeline(accent),
            _buildWaveform(accent),
            _buildCenterIcon(accent),
            if (widget.pageKey == 2) _buildNewBadge(),
            if (widget.pageKey == 3) _buildProgressBar(accent),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(Color accent) {
    return Positioned(
      bottom: 6.h,
      left: 4.w,
      right: 4.w,
      child: Row(
        children: List.generate(widget.totalPages, (i) {
          final isPast = i <= widget.pageKey;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: 3,
              margin: EdgeInsets.symmetric(horizontal: 1.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isPast
                    ? accent.withValues(alpha: 0.8)
                    : AppTheme.divider.withValues(alpha: 0.5),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWaveform(Color accent) {
    return CustomPaint(
      size: Size(88.w, 28.h),
      painter: _WaveformPainter(
        progress: _waveController.value,
        accent: accent,
        pageKey: widget.pageKey,
        barCount: 48,
      ),
    );
  }

  Widget _buildCenterIcon(Color accent) {
    final image = widget.page.imageAsset;
    return Container(
      width: 36.w,
      height: 36.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 3),
      ),
      child: ClipOval(
        child: image != null
            ? Image.asset(image, fit: BoxFit.cover)
            : ColoredBox(
                color: accent.withValues(alpha: 0.25),
                child: Icon(widget.page.icon, color: accent, size: 14.w),
              ),
      ),
    );
  }

  Widget _buildNewBadge() {
    return Positioned(
      top: 4.h,
      right: 8.w,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.6.h),
          decoration: BoxDecoration(
            color: AppTheme.accentSecondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'NEW',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(Color accent) {
    final pulse = 0.5 + 0.5 * math.sin(_waveController.value * 2 * math.pi);
    return Positioned(
      bottom: 10.h,
      left: 12.w,
      right: 12.w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Continue listening',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10.sp,
            ),
          ),
          SizedBox(height: 0.5.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.35 + pulse * 0.1,
              minHeight: 5,
              backgroundColor: AppTheme.divider,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.progress,
    required this.accent,
    required this.pageKey,
    required this.barCount,
  });

  final double progress;
  final Color accent;
  final int pageKey;
  final int barCount;

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / (barCount * 1.6);
    final gap = barWidth * 0.6;
    final centerY = size.height * 0.5;
    final speedMult = 1.0 + pageKey * 0.35;
    final heightMult = switch (pageKey) {
      0 => 1.2,
      1 => 1.0,
      2 => 0.85,
      _ => 0.65,
    };

    for (var i = 0; i < barCount; i++) {
      final phase = progress * speedMult + i * 0.12;
      final h = (12 + 40 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi))) *
          heightMult;
      final x = i * (barWidth + gap);
      final paint = Paint()
        ..color = accent.withValues(
          alpha: 0.35 + 0.45 * (0.5 + 0.5 * math.sin(phase * math.pi)),
        )
        ..strokeCap = StrokeCap.round;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + barWidth / 2, centerY),
            width: barWidth,
            height: h,
          ),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pageKey != pageKey;
  }
}
