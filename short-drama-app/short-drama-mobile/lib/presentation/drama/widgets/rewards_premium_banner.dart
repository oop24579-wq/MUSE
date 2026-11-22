import 'package:flutter/material.dart';
import 'package:provider/provider.dart' show ReadContext;
import 'package:sizer/sizer.dart';

import '../../../services/marketing/marketing_event_names.dart';
import '../../../services/paywall_preload_service.dart';
import '../../../services/user_provider.dart';
import '../../../widgets/discount_offer.dart';
import '../../pricing/shared/paywall_packages.dart';

/// "Premium Member" upsell card at the bottom of the Rewards tab. The yearly
/// price is read from the active RevenueCat offering (same source the paywall
/// uses). Tapping opens the paywall.
class RewardsPremiumBanner extends StatelessWidget {
  const RewardsPremiumBanner({super.key});

  String? _yearlyPrice() {
    final offering = PaywallPreloadService.instance.cachedOffering;
    if (offering == null) return null;
    return PaywallResolvedPackages.from(offering).annual?.storeProduct.priceString;
  }

  @override
  Widget build(BuildContext context) {
    final yearly = _yearlyPrice();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        await presentPaywallWithDiscount(
          context,
          trigger: PaywallTrigger.rewards,
        );
        if (!context.mounted) return;
        await context.read<UserProvider>().refreshUser(syncProStatus: true);
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A1512), Color(0xFF4A241A)],
          ),
          border: Border.all(
            color: const Color(0xFFFFB300).withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Premium Member',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 0.3.h),
                  Text(
                    'Unlock the full drama experience',
                    style: TextStyle(
                      color: const Color(0xFFFFCC80),
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (yearly != null) ...[
                    SizedBox(height: 0.7.h),
                    Text(
                      '$yearly/year',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFFFCC80),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
