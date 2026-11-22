import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../models/drama/series_model.dart';

enum SeriesBadgeKind { newRelease, hot, vip, exclusive, dubbed }

/// Small corner badge (NEW / HOT / VIP / EXCLUSIVE / DUBBED).
class SeriesBadge extends StatelessWidget {
  const SeriesBadge({super.key, required this.kind, this.compact = true});

  final SeriesBadgeKind kind;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, colors, textColor) = _style(kind);
    final fontSize = compact ? 7.sp : 8.sp;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 1.6.w : 2.w, vertical: compact ? 0.25.h : 0.35.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          height: 1,
        ),
      ),
    );
  }

  static (String, List<Color>, Color) _style(SeriesBadgeKind kind) {
    switch (kind) {
      case SeriesBadgeKind.newRelease:
        return ('NEW', const [Color(0xFF10B981), Color(0xFF059669)], Colors.white);
      case SeriesBadgeKind.hot:
        return ('HOT', const [Color(0xFFFF5252), Color(0xFFD32F2F)], Colors.white);
      case SeriesBadgeKind.vip:
        return ('VIP', const [Color(0xFFFFD54F), Color(0xFFFFB300)], Colors.black87);
      case SeriesBadgeKind.exclusive:
        return ('EXCLUSIVE', const [Color(0xFFFF6E40), Color(0xFFE64A19)], Colors.white);
      case SeriesBadgeKind.dubbed:
        return ('DUBBED', const [Color(0xFFFF7EB3), Color(0xFFFF5E9E)], Colors.white);
    }
  }
}

/// Picks the single most important badge for a series (VIP > HOT > NEW > …).
SeriesBadgeKind? primaryBadgeFor(SeriesModel s) {
  if (s.isVipOnly) return SeriesBadgeKind.vip;
  if (s.isHot) return SeriesBadgeKind.hot;
  if (s.isNew) return SeriesBadgeKind.newRelease;
  if (s.isExclusive) return SeriesBadgeKind.exclusive;
  if (s.isDubbed) return SeriesBadgeKind.dubbed;
  return null;
}
