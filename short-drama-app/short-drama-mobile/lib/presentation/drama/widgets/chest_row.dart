import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../models/drama/reward_models.dart';

/// Horizontal row of milestone treasure chests.
///
/// States: locked (lock icon, "watch N episodes"), unlocked-unclaimed
/// (pulsing glow + Claim button), claimed (dimmed + check).
class ChestRow extends StatelessWidget {
  const ChestRow({super.key, required this.chests, required this.onClaim});

  final List<ChestState> chests;
  final Future<void> Function(ChestState chest) onClaim;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 17.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        itemCount: chests.length,
        separatorBuilder: (_, __) => SizedBox(width: 2.5.w),
        itemBuilder: (context, i) => _ChestCard(chest: chests[i], onClaim: onClaim),
      ),
    );
  }
}

class _ChestCard extends StatefulWidget {
  const _ChestCard({required this.chest, required this.onClaim});

  final ChestState chest;
  final Future<void> Function(ChestState chest) onClaim;

  @override
  State<_ChestCard> createState() => _ChestCardState();
}

class _ChestCardState extends State<_ChestCard> {
  bool _busy = false;

  Future<void> _claim() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onClaim(widget.chest);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chest = widget.chest;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final subColor = textColor.withValues(alpha: 0.55);
    final claimable = chest.unlocked && !chest.claimed;

    final icon = chest.claimed
        ? Icons.check_circle
        : claimable
            ? Icons.card_giftcard
            : Icons.lock_outline;
    final iconColor = chest.claimed
        ? AppTheme.success
        : claimable
            ? const Color(0xFFFFB300)
            : subColor;

    final card = Container(
      width: 30.w,
      padding: EdgeInsets.all(2.5.w),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkBlue : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: claimable
              ? const Color(0xFFFFB300).withValues(alpha: 0.65)
              : textColor.withValues(alpha: 0.06),
          width: claimable ? 1.4 : 1,
        ),
      ),
      child: Opacity(
        opacity: chest.claimed ? 0.55 : 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 8.w),
            SizedBox(height: 0.7.h),
            Text(
              '+${chest.coins} coins',
              style: TextStyle(
                color: textColor,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 0.3.h),
            if (chest.claimed)
              Text('Claimed', style: TextStyle(color: subColor, fontSize: 8.5.sp))
            else if (claimable)
              SizedBox(
                height: 3.4.h,
                child: ElevatedButton(
                  onPressed: _busy ? null : _claim,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB300),
                    foregroundColor: Colors.black87,
                    padding: EdgeInsets.symmetric(horizontal: 3.w),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Claim',
                    style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w800),
                  ),
                ),
              )
            else
              Text(
                'Watch ${chest.threshold} episodes',
                textAlign: TextAlign.center,
                style: TextStyle(color: subColor, fontSize: 8.5.sp),
              ),
          ],
        ),
      ),
    );

    if (!claimable) return card;
    return _PulsingGlow(child: card);
  }
}

/// Soft scale + glow pulse that draws the eye to a claimable chest.
class _PulsingGlow extends StatefulWidget {
  const _PulsingGlow({required this.child});

  final Widget child;

  @override
  State<_PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<_PulsingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Transform.scale(
          scale: 1 + t * 0.03,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB300)
                      .withValues(alpha: 0.18 + t * 0.22),
                  blurRadius: 14 + t * 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
