import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../models/drama/series_model.dart';
import '../../../widgets/tile_image.dart';
import 'series_badge.dart';

/// Full-bleed spotlight banner for the Discover featured pager.
class FeaturedHeroCard extends StatelessWidget {
  const FeaturedHeroCard({
    super.key,
    required this.series,
    this.onTap,
    this.height,
  });

  final SeriesModel series;
  final VoidCallback? onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final badge = primaryBadgeFor(series);
    final h = height ?? 26.h;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: h,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TileImage(
                imageUrl: series.bannerUrl,
                style: TileImageStyle.cover,
                borderRadius: 18,
                fallbackIcon: Icons.movie_rounded,
              ),
              // scrim for text legibility
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.35, 0.6, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 4.w,
                right: 4.w,
                bottom: 2.h,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badge != null) ...[
                      SeriesBadge(kind: badge, compact: false),
                      SizedBox(height: 1.h),
                    ],
                    Text(
                      series.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
                      ),
                    ),
                    if (series.tagline != null) ...[
                      SizedBox(height: 0.6.h),
                      Text(
                        series.tagline!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10.sp,
                          shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
                        ),
                      ),
                    ],
                    SizedBox(height: 1.4.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 5.w, vertical: 1.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_arrow_rounded,
                                  color: Colors.black, size: 20),
                              SizedBox(width: 1.w),
                              Text(
                                'Watch Now',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10.5.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          '${series.viewCountLabel} views',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }
}
