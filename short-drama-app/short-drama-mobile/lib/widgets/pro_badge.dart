import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../theme/app_theme.dart';

/// Compact PRO pill for premium catalog rows and tiles.
class ProBadge extends StatelessWidget {
  const ProBadge({
    super.key,
    this.compact = false,
    this.showLock = false,
  });

  final bool compact;
  final bool showLock;

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 7.sp : 8.sp;
    final hPad = compact ? 1.6.w : 2.w;
    final vPad = compact ? 0.25.h : 0.35.h;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        gradient: AppTheme.proBadgeGradient,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLock) ...[
            Icon(Icons.lock_rounded, size: fontSize + 1, color: Colors.black87),
            SizedBox(width: 0.5.w),
          ],
          Text(
            'PRO',
            style: GoogleFonts.inter(
              color: Colors.black87,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Positions [ProBadge] on the top-right of catalog artwork.
class ProBadgeOverlay extends StatelessWidget {
  const ProBadgeOverlay({
    super.key,
    required this.child,
    required this.visible,
    this.compact = true,
    this.showLock = false,
  });

  final Widget child;
  final bool visible;
  final bool compact;
  final bool showLock;

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: 1.w,
          right: 1.w,
          child: ProBadge(compact: compact, showLock: showLock),
        ),
      ],
    );
  }
}

/// Trailing lock + PRO label for list rows.
class ProListTrailing extends StatelessWidget {
  const ProListTrailing({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ProBadge(compact: true, showLock: true),
        SizedBox(width: 2.w),
        Icon(
          Icons.play_circle_outline,
          color: AppTheme.textSecondaryDark.withValues(alpha: 0.55),
          size: 28,
        ),
      ],
    );
  }
}
