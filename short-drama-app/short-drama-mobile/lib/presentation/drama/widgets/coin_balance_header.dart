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
class CoinBalanceHeader extends StatelessWidget {
  const CoinBalanceHeader({super.key, required this.balance, this.label = 'Your coins'});

  final int balance;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
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
              Text(
                '$balance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
