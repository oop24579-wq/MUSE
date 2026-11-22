import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../models/drama/reward_models.dart';

/// Target counts for each 'series_milestone' reward task, keyed by slug.
/// Slugs starting with `series_collect` count My List entries; the rest count
/// watched dramas.
const Map<String, int> kSeriesMilestoneTargets = {
  'series_watch_3': 3,
  'series_watch_10': 10,
  'series_watch_25': 25,
  'series_collect_5': 5,
};

/// A "Series Rewards" milestone row: a progress bar toward a goal, then a
/// claim pill once the goal is reached.
class SeriesRewardTile extends StatelessWidget {
  const SeriesRewardTile({
    super.key,
    required this.task,
    required this.progress,
    required this.target,
    this.onClaim,
  });

  final RewardTaskModel task;
  final int progress;
  final int target;
  final Future<void> Function()? onClaim;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;

    final done = task.completed;
    final reached = progress >= target;
    final capped = progress > target ? target : progress;
    final ratio = target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 1.2.h),
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.4.h),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkBlue : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.emoji_events_rounded,
            color: const Color(0xFFFFB300).withValues(alpha: done ? 0.5 : 1),
            size: 26,
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 0.9.h),
                Row(
                  children: [
                    SizedBox(
                      width: 34.w,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: done ? 1.0 : ratio,
                          minHeight: 5,
                          backgroundColor: textColor.withValues(alpha: 0.08),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFFFFB300),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      '${done ? target : capped}/$target',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.6),
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 2.w),
          _trailing(done, reached, textColor),
        ],
      ),
    );
  }

  Widget _trailing(bool done, bool reached, Color textColor) {
    if (done) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF4CAF50), size: 18),
          SizedBox(width: 1.w),
          Text(
            'Done',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.5),
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    if (reached) {
      return _PressableClaim(coins: task.coins, onTap: onClaim);
    }
    // Locked: show the reward the user is working toward, dimmed.
    return Opacity(
      opacity: 0.45,
      child: _coinPill(task.coins),
    );
  }
}

Widget _coinPill(int coins) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.7.h),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.monetization_on_rounded,
            color: Colors.black87, size: 13),
        SizedBox(width: 1.w),
        Text(
          '+$coins',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 10.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

/// Gold "+coins" claim pill with a tactile press: scale-down + fade.
class _PressableClaim extends StatefulWidget {
  const _PressableClaim({required this.coins, this.onTap});

  final int coins;
  final Future<void> Function()? onTap;

  @override
  State<_PressableClaim> createState() => _PressableClaimState();
}

class _PressableClaimState extends State<_PressableClaim> {
  bool _pressed = false;
  bool _busy = false;

  void _setPressed(bool value) {
    if (mounted && !_busy) setState(() => _pressed = value);
  }

  Future<void> _handleTap() async {
    if (_busy || widget.onTap == null) return;
    setState(() {
      _busy = true;
      _pressed = false;
    });
    try {
      await widget.onTap!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.8 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFFB300),
                  ),
                )
              : _coinPill(widget.coins),
        ),
      ),
    );
  }
}
