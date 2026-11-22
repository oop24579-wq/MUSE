import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../models/drama/episode_model.dart';

/// Compact numbered episode chip (grid) with lock indicator.
class EpisodeGridTile extends StatelessWidget {
  const EpisodeGridTile({
    super.key,
    required this.episode,
    this.selected = false,
    this.onTap,
  });

  final EpisodeModel episode;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final locked = episode.isLocked;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentBlue.withValues(alpha: 0.9)
              : (isDark ? AppTheme.cardDarkBlue : AppTheme.cardLight),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppTheme.accentBlue
                : textColor.withValues(alpha: 0.08),
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '${episode.episodeNumber}',
                style: TextStyle(
                  color: selected ? Colors.white : textColor,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (locked)
              Positioned(
                top: 1.w,
                right: 1.w,
                child: Icon(
                  episode.isVipOnly ? Icons.workspace_premium_rounded : Icons.lock_rounded,
                  size: 12,
                  color: episode.isVipOnly
                      ? const Color(0xFFFFC107)
                      : textColor.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A detailed episode row (thumb + number/title + duration + lock/play).
class EpisodeListTile extends StatelessWidget {
  const EpisodeListTile({
    super.key,
    required this.episode,
    this.onTap,
    this.playing = false,
  });

  final EpisodeModel episode;
  final VoidCallback? onTap;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final locked = episode.isLocked;

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.2.h),
      leading: SizedBox(
        width: 9.w,
        child: Text(
          episode.episodeNumber.toString().padLeft(2, '0'),
          style: TextStyle(
            color: playing ? AppTheme.accentBlue : textColor.withValues(alpha: 0.7),
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      title: Text(
        episode.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontSize: 11.sp,
          fontWeight: playing ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        episode.durationLabel,
        style: TextStyle(
          color: textColor.withValues(alpha: 0.5),
          fontSize: 9.sp,
        ),
      ),
      trailing: locked
          ? Icon(
              episode.isVipOnly ? Icons.workspace_premium_rounded : Icons.lock_rounded,
              size: 20,
              color: episode.isVipOnly
                  ? const Color(0xFFFFC107)
                  : textColor.withValues(alpha: 0.55),
            )
          : Icon(
              playing ? Icons.equalizer_rounded : Icons.play_circle_outline_rounded,
              size: 24,
              color: playing
                  ? AppTheme.accentBlue
                  : textColor.withValues(alpha: 0.7),
            ),
    );
  }
}
