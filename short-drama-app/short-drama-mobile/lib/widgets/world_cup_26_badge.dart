import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../core/app_export.dart';

/// Matches the PRO / settings control height in [AppHeader].
double worldCup26BadgeHeight(BuildContext context) => 14.sp + 3.w;

/// Animated gradient stroke only — no fill, no shadow.
class _AnimatedGradientBorderPainter extends CustomPainter {
  const _AnimatedGradientBorderPainter({
    required this.colors,
    required this.begin,
    required this.end,
    required this.strokeWidth,
  });

  final List<Color> colors;
  final Alignment begin;
  final Alignment end;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= strokeWidth || size.height <= strokeWidth) return;

    final rect = Offset.zero & size;
    final radius = size.height / 2;
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius - inset),
    );

    final paint = Paint()
      ..shader = LinearGradient(
        begin: begin,
        end: end,
        colors: colors,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _AnimatedGradientBorderPainter old) =>
      old.begin != begin ||
      old.end != end ||
      old.strokeWidth != strokeWidth ||
      old.colors.length != colors.length;
}

/// World Cup '26 pill — transparent center, animated theme-colored border.
class WorldCup26Badge extends StatefulWidget {
  const WorldCup26Badge({
    super.key,
    required this.isDark,
    required this.badgeHeight,
  });

  final bool isDark;
  final double badgeHeight;

  @override
  State<WorldCup26Badge> createState() => _WorldCup26BadgeState();
}

class _WorldCup26BadgeState extends State<WorldCup26Badge>
    with SingleTickerProviderStateMixin {
  static const double _borderWidth = 1.4;

  late final AnimationController _gradientController;

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _gradientController.dispose();
    super.dispose();
  }

  List<Color> get _borderColors => widget.isDark
      ? [
          AppTheme.accentBlue,
          AppTheme.accentBlueLight,
          AppTheme.accentSecondary,
          AppTheme.accentBlue,
        ]
      : [
          AppTheme.primaryRed,
          AppTheme.primaryRedLight,
          AppTheme.accentBlue,
          AppTheme.primaryRed,
        ];

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.textPrimaryLight;

    return AnimatedBuilder(
      animation: _gradientController,
      builder: (context, child) {
        final t = _gradientController.value;
        return CustomPaint(
          foregroundPainter: _AnimatedGradientBorderPainter(
            colors: _borderColors,
            begin: Alignment(-1.0 + 2.0 * t, 0),
            end: Alignment(1.0 + 2.0 * t, 0),
            strokeWidth: _borderWidth,
          ),
          child: child,
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2.6.w + _borderWidth),
        child: SizedBox(
          height: widget.badgeHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('⚽', style: TextStyle(fontSize: 8.sp, height: 1)),
              SizedBox(width: 1.2.w),
              Text(
                "Cup '26",
                style: TextStyle(
                  color: textColor,
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
