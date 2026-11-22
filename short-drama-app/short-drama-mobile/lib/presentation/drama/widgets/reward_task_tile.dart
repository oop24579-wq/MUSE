import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../models/drama/reward_models.dart';
import 'coin_balance_header.dart';

/// A single starter-task row with a coin reward and action button.
class RewardTaskTile extends StatelessWidget {
  const RewardTaskTile({super.key, required this.task, this.onAction});

  final RewardTaskModel task;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final done = task.completed;

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
          Image.asset(
            'assets/images/coin.png',
            width: 6.w,
            height: 6.w,
            fit: BoxFit.contain,
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
                if (task.description != null)
                  Text(
                    task.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.5),
                      fontSize: 9.sp,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 2.w),
          if (done)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF4CAF50), size: 18),
                SizedBox(width: 1.w),
                Text('Done',
                    style: TextStyle(
                        color: textColor.withValues(alpha: 0.5),
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w600)),
              ],
            )
          else if (task.eligible)
            _PressableRewardButton(coins: task.coins, onTap: onAction)
          else
            // The server refuses a claim it has not marked eligible, so the
            // reward is shown dimmed as something to work toward rather than
            // as a button that answers `incomplete` every time.
            Opacity(
              opacity: 0.45,
              child: _PressableRewardButton(coins: task.coins),
            ),
        ],
      ),
    );
  }
}

/// Gold "+coins" claim pill with a tactile press: a subtle scale-down + fade.
class _PressableRewardButton extends StatefulWidget {
  const _PressableRewardButton({required this.coins, this.onTap});

  final int coins;
  final VoidCallback? onTap;

  @override
  State<_PressableRewardButton> createState() => _PressableRewardButtonState();
}

class _PressableRewardButtonState extends State<_PressableRewardButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.8 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
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
                const CoinGlyph(size: 14),
                SizedBox(width: 1.w),
                Text(
                  '+${widget.coins}',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 10.sp,
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
