import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../models/drama/watch_history_model.dart';
import '../../../widgets/tile_image.dart';
import 'drama_section.dart';

/// A landscape "continue watching" card showing progress + resume label.
class ContinueWatchingCard extends StatelessWidget {
  const ContinueWatchingCard({
    super.key,
    required this.entry,
    this.onTap,
    this.width,
  });

  final WatchHistoryEntry entry;
  final VoidCallback? onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final w = width ?? landscapeCardWidth(context);
    final imgH = w * 9 / 16;

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
                      imageUrl: entry.series.bannerUrl ?? entry.series.posterUrl,
                      fallbackIcon: Icons.movie_rounded,
                      isDark: isDark,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                    const Center(
                      child: Icon(Icons.play_circle_fill_rounded,
                          color: Colors.white, size: 40),
                    ),
                    Positioned(
                      left: 2.w,
                      bottom: 1.w,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.3.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.progressLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // progress bar
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: entry.episodeProgress > 0 ? entry.episodeProgress : 0.02,
                        minHeight: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor:
                            const AlwaysStoppedAnimation(Color(0xFFFF5252)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 0.7.h),
            Text(
              entry.series.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
