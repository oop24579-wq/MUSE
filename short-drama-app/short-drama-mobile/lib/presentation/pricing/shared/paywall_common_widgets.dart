import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/legal_url_launcher.dart';
import '../../../theme/app_theme.dart';
import '../shared/paywall_purchase_handler.dart';

class PaywallChromeButton extends StatelessWidget {
  const PaywallChromeButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 38,
    this.backgroundColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? Colors.black.withValues(alpha: 0.48),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: size * 0.47),
        ),
      ),
    );
  }
}

class PaywallFooterLinks extends StatelessWidget {
  const PaywallFooterLinks({
    super.key,
    required this.l10n,
    required this.handler,
    required this.busy,
    this.textColor,
    this.fontSize,
  });

  final AppLocalizations l10n;
  final PaywallPurchaseHandler handler;
  final ValueNotifier<bool> busy;
  final Color? textColor;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? AppTheme.textSecondaryDark;
    final linkStyle = GoogleFonts.inter(
      fontSize: fontSize ?? 8.sp,
      fontWeight: FontWeight.w500,
      color: color,
      decoration: TextDecoration.underline,
      decorationColor: color.withValues(alpha: 0.75),
    );
    final separatorStyle = GoogleFonts.inter(
      fontSize: (fontSize ?? 8.sp) * 0.94,
      color: color.withValues(alpha: 0.8),
    );

    Widget tap(String label, VoidCallback onTap) {
      return ValueListenableBuilder<bool>(
        valueListenable: busy,
        builder: (context, isBusy, _) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isBusy ? null : onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 1.w, vertical: 0.4.h),
              child: Text(label, style: linkStyle),
            ),
          );
        },
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        tap(l10n.paywallTerms, () => LegalUrlLauncher.openTerms(context)),
        Text(' · ', style: separatorStyle),
        tap(l10n.paywallPrivacy, () => LegalUrlLauncher.openPrivacy(context)),
        Text(' · ', style: separatorStyle),
        tap(
          l10n.paywallRestore,
          () => handler.restore(l10n: l10n, busy: busy),
        ),
      ],
    );
  }
}

class PaywallContinueButton extends StatelessWidget {
  const PaywallContinueButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.busy,
    required this.gradient,
    this.textColor = Colors.white,
    this.height,
    this.pulseScale,
  });

  final String label;
  final VoidCallback? onTap;
  final ValueNotifier<bool> busy;
  final Gradient gradient;
  final Color textColor;
  final double? height;
  final Animation<double>? pulseScale;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(999));

    Widget button = ValueListenableBuilder<bool>(
      valueListenable: busy,
      builder: (context, isBusy, _) {
        return SizedBox(
          width: double.infinity,
          height: height ?? 6.4.h,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: gradient,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                splashColor: Colors.white.withValues(alpha: 0.12),
                onTap: isBusy ? null : onTap,
                child: Center(
                  child: isBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (pulseScale != null) {
      return AnimatedBuilder(
        animation: pulseScale!,
        builder: (context, child) => Transform.scale(
          scale: pulseScale!.value,
          alignment: Alignment.center,
          child: child,
        ),
        child: button,
      );
    }
    return button;
  }
}

class PaywallNoPackagesView extends StatelessWidget {
  const PaywallNoPackagesView({
    super.key,
    required this.l10n,
    required this.handler,
    required this.busy,
    required this.onClose,
    this.backgroundColor,
  });

  final AppLocalizations l10n;
  final PaywallPurchaseHandler handler;
  final ValueNotifier<bool> busy;
  final VoidCallback onClose;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: backgroundColor ?? AppTheme.paywallShell,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(6.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.paywallNoPackages,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: AppTheme.textPrimaryDark,
                  ),
                ),
                SizedBox(height: 3.h),
                PaywallFooterLinks(
                  l10n: l10n,
                  handler: handler,
                  busy: busy,
                ),
                SizedBox(height: 2.h),
                TextButton(onPressed: onClose, child: Text(l10n.paywallGotIt)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PaywallProBadge extends StatelessWidget {
  const PaywallProBadge({
    super.key,
    required this.color,
    this.label = 'PRO',
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class PaywallSaveBadge extends StatelessWidget {
  const PaywallSaveBadge({
    super.key,
    required this.label,
    required this.gradient,
  });

  final String label;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9.2.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.05,
          ),
        ),
      ),
    );
  }
}

/// Reserves [topPadding] above [card] so a floating save badge does not overlap
/// content above the plan row (e.g. social proof pill or the previous plan card).
class PaywallFloatingSaveBadgeCard extends StatelessWidget {
  const PaywallFloatingSaveBadgeCard({
    super.key,
    required this.card,
    required this.badge,
    this.badgeTop = -11,
    this.badgeRight = 10,
    this.topPadding = 12,
  });

  final Widget card;
  final Widget badge;
  final double badgeTop;
  final double badgeRight;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            right: badgeRight,
            top: badgeTop,
            child: badge,
          ),
        ],
      ),
    );
  }
}
