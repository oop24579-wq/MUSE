import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

import '../core/test_flags.dart';
import '../l10n/app_localizations.dart';
import '../presentation/app_settings/widgets/settings_opacity_tap.dart';
import '../services/marketing/marketing_event_names.dart';
import '../services/user_provider.dart';
import '../theme/app_theme.dart';
import 'discount_offer.dart';

/// Shared light/dark palette for settings promo banners.
class PromoBannerPalette {
  const PromoBannerPalette._(this.isDark);

  factory PromoBannerPalette.of(bool isDark) => PromoBannerPalette._(isDark);

  final bool isDark;

  Color get background {
    final base = AppTheme.elevatedPanelBackground(isDark);
    if (isDark) {
      return Color.lerp(base, AppTheme.cardDarkBlue, 0.28)!;
    }
    return Color.lerp(base, const Color(0xFFEAF1FB), 0.62)!;
  }

  Color get iconSurface {
    if (isDark) {
      return Colors.white.withValues(alpha: 0.08);
    }
    return Colors.white.withValues(alpha: 0.78);
  }

  Color get iconColor {
    if (isDark) {
      return AppTheme.textPrimaryDark.withValues(alpha: 0.9);
    }
    return AppTheme.accentBlueDark.withValues(alpha: 0.88);
  }

  Color get iconDivider {
    if (isDark) {
      return Colors.white.withValues(alpha: 0.14);
    }
    return AppTheme.accentBlue.withValues(alpha: 0.16);
  }

  Color get textPrimary =>
      isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;

  Color get textSecondary =>
      isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

  List<Color> get proBadgeGradient {
    if (isDark) {
      return const [Color(0xFF9A7B2F), Color(0xFFD4AF37)];
    }
    return const [Color(0xFFC9A227), Color(0xFFE8CC72)];
  }

  Color get proBadgeIcon => isDark ? Colors.white : const Color(0xFF5C4A12);
}

/// Solid card surface used by the settings PRO / upgrade banners.
BoxDecoration settingsPromoBannerDecoration(bool isDark) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(20),
    color: PromoBannerPalette.of(isDark).background,
  );
}

/// Premium Pro badge — gold icon tile used inside promo banners.
class PremiumProBadge extends StatelessWidget {
  const PremiumProBadge({
    super.key,
    required this.isDark,
    this.size,
  });

  final bool isDark;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final palette = PromoBannerPalette.of(isDark);
    final dimension = size ?? 10.w.clamp(38.0, 46.0);

    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.proBadgeGradient,
        ),
      ),
      child: Icon(
        Icons.workspace_premium_rounded,
        color: palette.proBadgeIcon,
        size: dimension * 0.52,
      ),
    );
  }
}

/// Upgrade CTA banner for free users — reused in Settings and Library.
class FreeUpgradeBanner extends StatelessWidget {
  const FreeUpgradeBanner({
    super.key,
    required this.isDark,
    this.trigger = PaywallTrigger.settings,
    this.margin,
  });

  final bool isDark;
  final String trigger;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final resolvedDark = Theme.of(context).brightness == Brightness.dark;
    final palette = PromoBannerPalette.of(resolvedDark);
    final l10n = AppLocalizations.of(context)!;

    return SettingsOpacityTap(
      focusDebugLabel: 'free_upgrade_banner',
      onTap: () async {
        await presentPaywallWithDiscount(context, trigger: trigger);
        if (!context.mounted) return;
        await context.read<UserProvider>().refreshUser(syncProStatus: true);
      },
      child: Container(
        margin: margin ?? EdgeInsets.symmetric(horizontal: 4.w),
        padding: EdgeInsets.fromLTRB(3.5.w, 1.8.h, 3.w, 1.8.h),
        decoration: settingsPromoBannerDecoration(resolvedDark),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.settingsPromoBannerTitle,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 0.4.h),
                  Text(
                    l10n.settingsProfileUpgradeSubtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: palette.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 2.5.w),
            _UpgradePill(label: l10n.settingsProfileUpgrade),
          ],
        ),
      ),
    );
  }
}

/// Gold gradient "Upgrade" call-to-action pill — carries the PRO identity.
class _UpgradePill extends StatelessWidget {
  const _UpgradePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 0.9.h),
      decoration: BoxDecoration(
        gradient: AppTheme.proBadgeGradient,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 5),
          const Icon(
            Icons.arrow_forward_rounded,
            color: Colors.black87,
            size: 15,
          ),
        ],
      ),
    );
  }
}

/// Whether the library upgrade banner should show.
bool shouldShowLibraryProBanner({
  required bool isPro,
  required bool songsLoading,
  required String? songsError,
  required bool songsEmpty,
}) {
  if (TestFlags.forceProForTest || isPro) return false;
  if (songsLoading || songsError != null) return false;
  return songsEmpty;
}
