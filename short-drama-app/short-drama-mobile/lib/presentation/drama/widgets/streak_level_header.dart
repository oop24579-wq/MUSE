import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

/// Streak flame + level ring shown under the coin balance on the Rewards tab.
///
/// Left: a circular progress ring of XP toward the next level with the level
/// number in the centre. Right: a flame chip with the current streak count.
class StreakLevelHeader extends StatelessWidget {
  const StreakLevelHeader({
    super.key,
    required this.streak,
    required this.level,
    required this.xp,
    required this.nextLevelXp,
  });

  final int streak;
  final int level;
  final int xp;
  final int nextLevelXp;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final subColor = textColor.withValues(alpha: 0.55);
    final progress =
        nextLevelXp > 0 ? (xp / nextLevelXp).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Row(
        children: [
          // Level ring.
          SizedBox(
            width: 15.w,
            height: 15.w,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 15.w,
                  height: 15.w,
                  child: CircularProgressIndicator(
                    value: progress.toDouble(),
                    strokeWidth: 4,
                    backgroundColor: textColor.withValues(alpha: 0.10),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$level',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    Text(
                      'LEVEL',
                      style: TextStyle(
                        color: subColor,
                        fontSize: 6.5.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$xp / $nextLevelXp XP',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 0.3.h),
                Text(
                  nextLevelXp > xp
                      ? '${nextLevelXp - xp} XP to level ${level + 1}'
                      : 'Level up ready!',
                  style: TextStyle(color: subColor, fontSize: 9.sp),
                ),
              ],
            ),
          ),
          // Streak flame chip.
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.9.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6D00).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFFFF6D00).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Color(0xFFFF6D00),
                  size: 18,
                ),
                SizedBox(width: 1.w),
                Text(
                  '$streak',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 1.w),
                Text(
                  streak == 1 ? 'day' : 'days',
                  style: TextStyle(color: subColor, fontSize: 9.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
