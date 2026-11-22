import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

/// Shared spacing + sizing helpers for drama shelves (self-contained; no
/// dependency on the legacy radiopod widgets).

double dramaSectionSpacing(BuildContext context) => 3.h;
double dramaSectionHeaderTop(BuildContext context) => 1.25.h;
double dramaHeaderSpacing(BuildContext context) => 1.5.h;

/// Portrait poster tile width for horizontal carousels.
double posterCardWidth(BuildContext context) => 30.w;

/// Poster image height (3:4 aspect).
double posterImageHeight(BuildContext context) =>
    posterCardWidth(context) * 4 / 3;

/// Total height of a poster carousel (image + 2-line title + meta line).
double posterCarouselHeight(BuildContext context) =>
    posterImageHeight(context) + 1.0.h + (11.sp * 1.3 * 2) + (9.sp * 1.4) + 1.0.h;

/// Wide landscape (16:9) card width for continue-watching / hero rows.
double landscapeCardWidth(BuildContext context) => 62.w;
double landscapeImageHeight(BuildContext context) =>
    landscapeCardWidth(context) * 9 / 16;

/// Section header: bold title + optional chevron / "see more".
class DramaSectionHeader extends StatelessWidget {
  const DramaSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeMore,
    this.showChevron = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSeeMore;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final subColor = textColor.withValues(alpha: 0.55);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        4.w,
        dramaSectionHeaderTop(context),
        4.w,
        dramaHeaderSpacing(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 0.3.h),
                    child: Text(
                      subtitle!,
                      style: TextStyle(color: subColor, fontSize: 9.5.sp),
                    ),
                  ),
              ],
            ),
          ),
          if (onSeeMore != null || showChevron)
            GestureDetector(
              onTap: onSeeMore,
              behavior: HitTestBehavior.opaque,
              child: Icon(
                Icons.chevron_right_rounded,
                color: subColor,
                size: 22,
              ),
            ),
        ],
      ),
    );
  }
}
