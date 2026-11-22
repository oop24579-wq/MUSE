import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../models/drama/series_model.dart';
import '../../../widgets/tile_image.dart';
import 'series_badge.dart';

/// A Top-10 ranking row: big rank number + poster + title/meta + views.
class RankingListTile extends StatelessWidget {
  const RankingListTile({
    super.key,
    required this.rank,
    required this.series,
    this.onTap,
  });

  final int rank;
  final SeriesModel series;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final badge = primaryBadgeFor(series);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 0.8.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 11.w,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: rank <= 3
                      ? AppTheme.accentBlue
                      : textColor.withValues(alpha: 0.35),
                ),
              ),
            ),
            SizedBox(width: 2.w),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 15.w,
                height: 15.w * 4 / 3,
                child: TileImage(
                  imageUrl: series.posterUrl,
                  fallbackIcon: Icons.movie_rounded,
                  isDark: isDark,
                ),
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (badge != null) ...[
                        SeriesBadge(kind: badge),
                        SizedBox(width: 1.5.w),
                      ],
                      Expanded(
                        child: Text(
                          series.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.4.h),
                  Text(
                    series.metaLine.isNotEmpty
                        ? series.metaLine
                        : series.episodeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.55),
                      fontSize: 9.sp,
                    ),
                  ),
                  SizedBox(height: 0.4.h),
                  Row(
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          size: 14, color: textColor.withValues(alpha: 0.55)),
                      SizedBox(width: 0.5.w),
                      Text(
                        '${series.viewCountLabel} views',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.55),
                          fontSize: 8.5.sp,
                        ),
                      ),
                    ],
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
