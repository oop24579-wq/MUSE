import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

import '../../../core/test_flags.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/user_provider.dart';
import '../../../widgets/free_upgrade_banner.dart';
import 'settings_opacity_tap.dart';

/// Top promo strip — upgrade CTA for free users, Pro status for subscribers.
class SettingsPromoBanner extends StatelessWidget {
  const SettingsPromoBanner({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final resolvedDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final isPro = TestFlags.forceProForTest || userProvider.isPro;
        if (isPro) {
          return _ProBanner(isDark: resolvedDark);
        }
        return FreeUpgradeBanner(isDark: resolvedDark);
      },
    );
  }
}

class _ProBanner extends StatelessWidget {
  const _ProBanner({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final palette = PromoBannerPalette.of(isDark);
    final l10n = AppLocalizations.of(context)!;

    return SettingsOpacityTap(
      focusDebugLabel: 'settings_promo_pro',
      onTap: () => Navigator.pushNamed(context, '/pricing'),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        padding: EdgeInsets.fromLTRB(4.w, 2.4.h, 4.w, 2.4.h),
        decoration: settingsPromoBannerDecoration(isDark),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settingsProBannerTitle,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                  SizedBox(height: 0.4.h),
                  Text(
                    l10n.settingsProfileProSubtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: palette.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: palette.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
