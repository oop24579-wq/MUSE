import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../theme/app_theme.dart';

/// Smoked frosted glass — blur + translucent tint + inner light (no shadows/borders).
class HeaderGlassChip extends StatelessWidget {
  const HeaderGlassChip({
    super.key,
    required this.isDark,
    required this.height,
    required this.borderRadius,
    required this.child,
    this.width,
    this.padding,
    this.onTap,
    this.onLongPress,
    this.onLongPressStart,
  });

  final bool isDark;
  final double height;
  final double? width;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(LongPressStartDetails)? onLongPressStart;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onLongPressStart: onLongPressStart,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: SizedBox(
            height: height,
            width: width,
            child: Stack(
              fit: StackFit.expand,
              children: [
                HeaderGlassSurface(
                  isDark: isDark,
                  borderRadius: borderRadius,
                ),
                Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: Center(child: child),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Identical glass fill used by header settings + credits chips.
class HeaderGlassSurface extends StatelessWidget {
  const HeaderGlassSurface({
    super.key,
    required this.isDark,
    required this.borderRadius,
  });

  final bool isDark;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark
        ? AppTheme.accentBlue.withValues(alpha: 0.11)
        : Colors.white.withValues(alpha: 0.34);
    final edgeSheen = isDark ? 0.16 : 0.28;
    final topSheen = isDark ? 0.14 : 0.24;
    final depthTint = isDark
        ? AppTheme.accentBlue.withValues(alpha: 0.05)
        : AppTheme.accentBlue.withValues(alpha: 0.04);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: baseColor,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: topSheen),
                Colors.transparent,
              ],
              stops: const [0.0, 0.55],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white.withValues(alpha: edgeSheen),
                Colors.transparent,
              ],
              stops: const [0.0, 0.52],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                Colors.white.withValues(alpha: edgeSheen),
                Colors.transparent,
              ],
              stops: const [0.0, 0.52],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                depthTint,
                Colors.transparent,
              ],
              stops: const [0.0, 0.48],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: RadialGradient(
              center: const Alignment(-0.65, -0.75),
              radius: 1.05,
              colors: [
                Colors.white.withValues(alpha: isDark ? 0.10 : 0.18),
                Colors.transparent,
              ],
              stops: const [0.0, 0.72],
            ),
          ),
        ),
      ],
    );
  }
}

/// Circular glass icon button — matches [AppHeader] settings chip.
class HeaderGlassIconButton extends StatelessWidget {
  const HeaderGlassIconButton({
    super.key,
    required this.isDark,
    required this.icon,
    required this.onTap,
    this.badgeHeight,
  });

  final bool isDark;
  final IconData icon;
  final VoidCallback onTap;
  final double? badgeHeight;

  static double defaultSize(BuildContext context) => 14.sp + 3.w;

  @override
  Widget build(BuildContext context) {
    final size = badgeHeight ?? defaultSize(context);
    final iconColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;

    return HeaderGlassChip(
      isDark: isDark,
      height: size,
      width: size,
      borderRadius: BorderRadius.circular(size / 2),
      onTap: onTap,
      child: Icon(icon, color: iconColor, size: 14.sp),
    );
  }
}

/// Glass PRO pill — shares the frosted [HeaderGlassChip] surface with the
/// header notify/settings buttons, keeping the gold "PRO" identity via gradient
/// text so all header chips match.
class HeaderGlassProChip extends StatelessWidget {
  const HeaderGlassProChip({
    super.key,
    required this.isDark,
    required this.onTap,
    this.height,
  });

  final bool isDark;
  final VoidCallback onTap;
  final double? height;

  static const _goldGradient = AppTheme.proBadgeGradient;

  @override
  Widget build(BuildContext context) {
    final badgeHeight = height ?? HeaderGlassIconButton.defaultSize(context);
    final borderRadius = BorderRadius.circular(badgeHeight / 2);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: SizedBox(
            height: badgeHeight,
            // No StackFit.expand: the Row sizes the chip to its content so the
            // pill hugs "PRO" instead of demanding an infinite width.
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: HeaderGlassSurface(
                    isDark: isDark,
                    borderRadius: borderRadius,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2.6.w),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            _goldGradient.createShader(bounds),
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          size: 11.sp,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 1.2.w),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            _goldGradient.createShader(bounds),
                        child: Text(
                          'PRO',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 8.5.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hexagonal music-note glyph used in header + create CTA credit badges.
class HeaderMusicNoteGlyph extends StatelessWidget {
  const HeaderMusicNoteGlyph({
    super.key,
    required this.isDark,
    required this.size,
  });

  final bool isDark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final frameWidth = math.max(1.6, size * 0.11);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipPath(
            clipper: HeaderHexagonClipper(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFB8DCE8).withValues(alpha: 0.95),
                    AppTheme.accentBlueLight.withValues(alpha: 0.85),
                    AppTheme.accentBlue.withValues(alpha: 0.90),
                    AppTheme.accentSecondary.withValues(alpha: 0.80),
                  ],
                  stops: const [0.0, 0.35, 0.68, 1.0],
                ),
              ),
              child: SizedBox(width: size, height: size),
            ),
          ),
          ClipPath(
            clipper: HeaderHexagonClipper(inset: frameWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accentBlueLight.withValues(alpha: 0.55),
                    AppTheme.accentBlue.withValues(alpha: 0.88),
                    AppTheme.accentBlueDark.withValues(alpha: 0.95),
                  ],
                ),
              ),
              child: SizedBox(width: size, height: size),
            ),
          ),
          Icon(
            Icons.music_note_rounded,
            color: Colors.white.withValues(alpha: 0.96),
            size: size * 0.46,
          ),
        ],
      ),
    );
  }
}

class HeaderHexagonClipper extends CustomClipper<Path> {
  HeaderHexagonClipper({this.inset = 0});

  final double inset;

  @override
  Path getClip(Size size) {
    return headerHexagonPath(size, inset: inset);
  }

  @override
  bool shouldReclip(covariant HeaderHexagonClipper oldClipper) =>
      oldClipper.inset != inset;
}

Path headerHexagonPath(Size size, {double inset = 0}) {
  final path = Path();
  final cx = size.width / 2;
  final cy = size.height / 2;
  final radius = math.min(size.width, size.height) / 2 - inset;

  for (var i = 0; i < 6; i++) {
    final angle = (math.pi / 3) * i - math.pi / 2;
    final x = cx + radius * math.cos(angle);
    final y = cy + radius * math.sin(angle);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
}

/// Glass chip with hex music-note + credit count — matches [AppHeader] badge.
class HeaderCreditCostBadge extends StatelessWidget {
  const HeaderCreditCostBadge({
    super.key,
    required this.isDark,
    required this.cost,
    this.height,
    this.onTap,
    this.onLongPress,
    this.onLongPressStart,
  });

  final bool isDark;
  final int cost;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(LongPressStartDetails)? onLongPressStart;

  static double defaultHeight(BuildContext context) => 14.sp + 3.w;

  @override
  Widget build(BuildContext context) {
    final badgeHeight = height ?? defaultHeight(context);
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    const badgeRadius = BorderRadius.all(Radius.circular(10));

    return HeaderGlassChip(
      isDark: isDark,
      height: badgeHeight,
      width: badgeHeight * 2.15,
      borderRadius: badgeRadius,
      padding: EdgeInsets.symmetric(horizontal: 2.5.w),
      onTap: onTap,
      onLongPress: onLongPress,
      onLongPressStart: onLongPressStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HeaderMusicNoteGlyph(
            isDark: isDark,
            size: badgeHeight * 0.62,
          ),
          SizedBox(width: 2.w),
          Text(
            '$cost',
            style: TextStyle(
              color: textColor,
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
