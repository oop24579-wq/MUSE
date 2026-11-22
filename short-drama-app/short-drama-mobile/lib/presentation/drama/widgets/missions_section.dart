import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../models/drama/reward_models.dart';
import 'coin_balance_header.dart';

/// Daily missions list: icon per mission, progress bar, coin reward, and a
/// Claim button that is only enabled once the mission is completed and not
/// yet claimed (claimed missions show a check instead).
class MissionsSection extends StatelessWidget {
  const MissionsSection({
    super.key,
    required this.missions,
    required this.onClaim,
  });

  final List<DailyMission> missions;
  final Future<void> Function(DailyMission mission) onClaim;

  static IconData iconFor(DailyMission mission) {
    final slug = mission.slug.toLowerCase();
    if (slug.contains('watch') || slug.contains('episode')) {
      return Icons.play_circle_outline;
    }
    if (slug.contains('share')) return Icons.share_outlined;
    if (slug.contains('checkin') || slug.contains('login') || slug.contains('daily')) {
      return Icons.calendar_today_outlined;
    }
    if (slug.contains('follow')) return Icons.person_add_outlined;
    if (slug.contains('like') || slug.contains('favorite') || slug.contains('favourite')) {
      return Icons.favorite_border;
    }
    if (slug.contains('referral') || slug.contains('invite')) {
      return Icons.group_add_outlined;
    }
    if (slug.contains('wheel') || slug.contains('spin')) {
      return Icons.casino_outlined;
    }
    return Icons.star_outline;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        children: [
          for (final mission in missions)
            _MissionRow(mission: mission, onClaim: onClaim),
        ],
      ),
    );
  }
}

class _MissionRow extends StatefulWidget {
  const _MissionRow({required this.mission, required this.onClaim});

  final DailyMission mission;
  final Future<void> Function(DailyMission mission) onClaim;

  @override
  State<_MissionRow> createState() => _MissionRowState();
}

class _MissionRowState extends State<_MissionRow> {
  bool _busy = false;

  Future<void> _claim() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onClaim(widget.mission);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mission = widget.mission;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final subColor = textColor.withValues(alpha: 0.55);
    final claimable = mission.completed && !mission.claimed;

    return Container(
      margin: EdgeInsets.only(bottom: 1.2.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkBlue : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: textColor.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 10.5.w,
            height: 10.5.w,
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              MissionsSection.iconFor(mission),
              color: AppTheme.accentBlue,
              size: 5.5.w,
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (mission.description != null &&
                    mission.description!.isNotEmpty) ...[
                  SizedBox(height: 0.2.h),
                  Text(
                    mission.description!,
                    style: TextStyle(color: subColor, fontSize: 8.5.sp),
                  ),
                ],
                SizedBox(height: 0.7.h),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: mission.progressFraction,
                          minHeight: 5,
                          backgroundColor: textColor.withValues(alpha: 0.10),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.accentBlue,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      '${mission.progress}/${mission.target}',
                      style: TextStyle(color: subColor, fontSize: 8.5.sp),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 3.w),
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoinGlyph(size: 14),
                  SizedBox(width: 1.w),
                  Text(
                    '+${mission.coins}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 0.7.h),
              if (mission.claimed)
                const Icon(Icons.check_circle, color: AppTheme.success, size: 20)
              else
                SizedBox(
                  height: 3.4.h,
                  child: ElevatedButton(
                    onPressed: claimable && !_busy ? _claim : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          textColor.withValues(alpha: 0.12),
                      padding: EdgeInsets.symmetric(horizontal: 3.w),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Claim',
                      style:
                          TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
