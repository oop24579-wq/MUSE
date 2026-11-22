import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

/// A gold coin glyph used across the Rewards UI and header chip.
class CoinGlyph extends StatelessWidget {
  const CoinGlyph({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '\$',
        style: TextStyle(
          color: const Color(0xFF7A5200),
          fontSize: size * 0.6,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

/// Large coin-balance banner shown at the top of the Rewards tab.
///
/// The number counts up (or down) with an ease-out tween whenever [balance]
/// changes, so a claim visibly lands in the balance. Public API is unchanged
/// (`balance`, `label`) so existing call sites keep working.
class CoinBalanceHeader extends StatefulWidget {
  const CoinBalanceHeader({super.key, required this.balance, this.label = 'Your coins'});

  final int balance;
  final String label;

  @override
  State<CoinBalanceHeader> createState() => _CoinBalanceHeaderState();
}

class _CoinBalanceHeaderState extends State<CoinBalanceHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late Animation<int> _count;
  int _from = 0;

  @override
  void initState() {
    super.initState();
    _from = widget.balance;
    _count = AlwaysStoppedAnimation<int>(widget.balance);
  }

  @override
  void didUpdateWidget(CoinBalanceHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.balance != widget.balance) {
      _from = oldWidget.balance;
      _count = IntTween(begin: _from, end: widget.balance).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: TextStyle(
              color: const Color(0xFFFFCC80),
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 0.8.h),
          Row(
            children: [
              Image.asset(
                'assets/images/coin.png',
                width: 7.w,
                height: 7.w,
                fit: BoxFit.contain,
              ),
              SizedBox(width: 2.w),
              AnimatedBuilder(
                animation: _count,
                builder: (context, _) => Text(
                  '${_count.value}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w900,
                    height: 1,
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
