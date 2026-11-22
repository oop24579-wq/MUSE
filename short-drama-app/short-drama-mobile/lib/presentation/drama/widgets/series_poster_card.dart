import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../models/drama/series_model.dart';
import '../../../widgets/tile_image.dart';
import 'drama_section.dart';
import 'lang_flags.dart';
import 'series_badge.dart';

/// Portrait poster tile for a series: cover + badge + view count + title/meta.
class SeriesPosterCard extends StatelessWidget {
  const SeriesPosterCard({
    super.key,
    required this.series,
    this.onTap,
    this.width,
    this.showMeta = true,
  });

  final SeriesModel series;
  final VoidCallback? onTap;
  final double? width;
  final bool showMeta;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final w = width ?? posterCardWidth(context);
    final imgH = w * 4 / 3;
    final badge = primaryBadgeFor(series);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: w,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: w,
                height: imgH,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    TileImage(
                      imageUrl: series.posterUrl,
                      style: TileImageStyle.cover,
                      borderRadius: 12,
                      fallbackIcon: Icons.movie_rounded,
                      isDark: isDark,
                    ),
                    // bottom gradient for the view-count chip
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: imgH * 0.4,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black54, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    if (badge != null)
                      Positioned(top: 1.5.w, left: 1.5.w, child: SeriesBadge(kind: badge)),
                    if (series.dubLanguages.isNotEmpty)
                      Positioned(
                        top: 1.5.w,
                        right: 1.5.w,
                        child: LangFlags(codes: series.dubLanguages, fontSize: 11),
                      ),
                    Positioned(
                      left: 2.w,
                      bottom: 1.w,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 0.5.w),
                          Text(
                            series.viewCountLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 3),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 0.8.h),
            Text(
              series.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            if (showMeta) ...[
              SizedBox(height: 0.2.h),
              Text(
                series.metaLine.isNotEmpty ? series.metaLine : series.episodeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.55),
                  fontSize: 9.sp,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
