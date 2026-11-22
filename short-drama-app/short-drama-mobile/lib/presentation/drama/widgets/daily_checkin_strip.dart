import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../models/drama/reward_models.dart';
import 'coin_balance_header.dart';

/// The 7-day daily check-in strip with a claim button.
class DailyCheckinStrip extends StatelessWidget {
  const DailyCheckinStrip({
    super.key,
    required this.days,
    required this.bonusCoins,
    this.onBonus,
  });

  final List<CheckinDay> days;

  /// Coins granted for watching the rewarded ad (from Remote Config).
  final int bonusCoins;

  /// Triggers the rewarded-ad → grant-coins flow.
  final Future<void> Function()? onBonus;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkBlue : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily check-in',
            style: TextStyle(
              color: textColor,
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 1.5.h),
          Row(
            children: [
              for (final d in days)
                Expanded(child: _DayTile(day: d, textColor: textColor)),
            ],
          ),
          SizedBox(height: 1.8.h),
          _BonusCoinsButton(coins: bonusCoins, onPressed: onBonus),
        ],
      ),
    );
  }
}

/// Gold "+N Bonus Coins" button that plays a rewarded ad. Presses give tactile
/// feedback — a subtle scale-down + fade — and it shows a spinner while busy.
class _BonusCoinsButton extends StatefulWidget {
  const _BonusCoinsButton({required this.coins, this.onPressed});

  final int coins;
  final Future<void> Function()? onPressed;

  @override
  State<_BonusCoinsButton> createState() => _BonusCoinsButtonState();
}

class _BonusCoinsButtonState extends State<_BonusCoinsButton> {
  bool _pressed = false;
  bool _busy = false;

  void _setPressed(bool value) {
    if (mounted && !_busy) setState(() => _pressed = value);
  }

  Future<void> _handleTap() async {
    if (_busy || widget.onPressed == null) return;
    setState(() {
      _busy = true;
      _pressed = false;
    });
    try {
      await widget.onPressed!();
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
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 1.4.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _busy
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black87,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.smart_display_rounded,
                        color: Colors.white,
                        size: 5.w,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        '+${widget.coins} Bonus Coins',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day, required this.textColor});

  final CheckinDay day;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final highlight = day.isToday;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 0.5.w),
      padding: EdgeInsets.symmetric(vertical: 1.h),
      decoration: BoxDecoration(
        gradient: highlight
            ? const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFFB300)])
            : null,
        color: highlight
            ? null
            : (day.claimed
                ? const Color(0xFFFFB300).withValues(alpha: 0.15)
                : textColor.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Opacity(
            opacity: day.claimed && !highlight ? 0.5 : 1,
            child: const CoinGlyph(size: 22),
          ),
          SizedBox(height: 0.6.h),
          Text(
            '+${day.coins}',
            style: TextStyle(
              color: highlight ? Colors.black87 : textColor,
              fontSize: 8.5.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 0.2.h),
          Text(
            'Day ${day.dayIndex}',
            style: TextStyle(
              color: highlight
                  ? Colors.black.withValues(alpha: 0.6)
                  : textColor.withValues(alpha: 0.5),
              fontSize: 7.sp,
            ),
          ),
          if (day.claimed && !highlight)
            const Icon(Icons.check_circle, size: 10, color: Color(0xFFFFB300)),
        ],
      ),
    );
  }
}
