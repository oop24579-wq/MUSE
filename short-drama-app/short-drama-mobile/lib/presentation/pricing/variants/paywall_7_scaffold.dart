import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../l10n/app_localizations.dart';
import '../paywall_router.dart';
import '../shared/paywall_common_widgets.dart';
import '../shared/paywall_packages.dart';
import '../shared/paywall_purchase_handler.dart';
import '../shared/paywall_variant_palette.dart';
import '../widgets/animated_paywall_collage.dart';

/// Paywall 7 — full-screen portrait hero, checklist perks, peach CTA.
class Paywall7Scaffold extends StatefulWidget {
  const Paywall7Scaffold({super.key, required this.args});

  final PaywallScaffoldArgs args;

  @override
  State<Paywall7Scaffold> createState() => _Paywall7ScaffoldState();
}

class _Paywall7ScaffoldState extends State<Paywall7Scaffold> {
  late final PaywallResolvedPackages _packages;
  late PaywallSelectedPlan _selected;
  final _busy = ValueNotifier(false);
  late final PaywallPurchaseHandler _handler;
  Timer? _closeTimer;
  bool _closeVisible = false;

  @override
  void initState() {
    super.initState();
    _packages = PaywallResolvedPackages.from(widget.args.offering);
    _selected = _packages.defaultPlan();
    _handler = PaywallPurchaseHandler(
      context: context,
      onPurchaseCompleted: widget.args.onPurchaseCompleted,
      onProUnlocked: widget.args.onProUnlocked,
    );
    _closeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _closeVisible = true);
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _busy.dispose();
    super.dispose();
  }

  void _handleClose() {
    if (widget.args.onDismiss != null) {
      widget.args.onDismiss!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final savings = paywallSavingsPercent(_packages.annual, _packages.weekly);

    if (!_packages.hasAny) {
      return PaywallNoPackagesView(
        l10n: l10n,
        handler: _handler,
        busy: _busy,
        onClose: _handleClose,
        backgroundColor: PaywallVariantPalette.p7Shell,
      );
    }

    final perks = [
      (l10n.paywallHelpFeature1, null),
      (l10n.paywallHelpFeature2, null),
      (l10n.paywallHelpFeature3, null),
      (l10n.paywallHelpFeature4, null),
      (l10n.paywallFeatureNoAds, null),
    ];

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: PaywallVariantPalette.p7Shell,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: PaywallCollageBackground(
                shell: PaywallVariantPalette.p7Shell,
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.6.h),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AnimatedOpacity(
                        opacity: _closeVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 280),
                        child: IgnorePointer(
                          ignoring: !_closeVisible,
                          child: PaywallChromeButton(
                            icon: Icons.close,
                            onTap: _handleClose,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(6.w, 0, 6.w, 2.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Spacer(),
                          Text(
                            '${l10n.paywallUnlockLine1} ${l10n.paywallUnlockLine2}',
                            style: GoogleFonts.inter(
                              fontSize: 26.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 0.6.h),
                          Text(
                            l10n.paywallFeatureCreateMusic,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          SizedBox(height: 2.5.h),
                          ...perks.map((p) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: 1.1.h),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 3.w),
                                  Expanded(
                                    child: Text(
                                      p.$1,
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          SizedBox(height: 2.5.h),
                          if (_packages.weekly != null)
                            _highlightPlanCard(
                              l10n: l10n,
                              title: l10n.paywallPlanWeekly,
                              price:
                                  '${_packages.weekly!.storeProduct.priceString} / week',
                              perWeek: null,
                              selected: _selected == PaywallSelectedPlan.weekly,
                              savings: null,
                              onTap: () => setState(
                                () => _selected = PaywallSelectedPlan.weekly,
                              ),
                            ),
                          if (_packages.weekly != null && _packages.annual != null)
                            SizedBox(height: 1.2.h),
                          if (_packages.annual != null)
                            _highlightPlanCard(
                              l10n: l10n,
                              title: l10n.paywallPlanYearly,
                              price:
                                  '${_packages.annual!.storeProduct.priceString} / year',
                              perWeek: paywallAnnualPerWeekPrice(
                                _packages.annual!,
                              ),
                              selected: _selected == PaywallSelectedPlan.annual,
                              savings: savings,
                              onTap: () => setState(
                                () => _selected = PaywallSelectedPlan.annual,
                              ),
                            ),
                          SizedBox(height: 1.6.h),
                          Text(
                            l10n.paywallCancelAnytime,
                            style: GoogleFonts.inter(
                              fontSize: 8.5.sp,
                              color: Colors.white60,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          PaywallContinueButton(
                            label: l10n.paywallContinue,
                            gradient: PaywallVariantPalette.p7Cta,
                            textColor: const Color(0xFF1A1408),
                            busy: _busy,
                            onTap: () => _handler.subscribe(
                              package: _packages.packageFor(_selected),
                              l10n: l10n,
                              busy: _busy,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          PaywallFooterLinks(
                            l10n: l10n,
                            handler: _handler,
                            busy: _busy,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _highlightPlanCard({
    required AppLocalizations l10n,
    required String title,
    required String price,
    required String? perWeek,
    required bool selected,
    required int? savings,
    required VoidCallback onTap,
  }) {
    const radius = BorderRadius.all(Radius.circular(14));
    Widget card = Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: PaywallVariantPalette.p7Card.withValues(alpha: 0.85),
            border: Border.all(
              color: selected
                  ? PaywallVariantPalette.p7Accent
                  : Colors.white.withValues(alpha: 0.15),
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected
                      ? PaywallVariantPalette.p7Accent
                      : Colors.white54,
                  size: 20,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        price,
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                if (perWeek != null)
                  Text(
                    '≈ $perWeek / week',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: PaywallVariantPalette.p7Accent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (savings == null || savings <= 0) return card;

    return PaywallFloatingSaveBadgeCard(
      card: card,
      badge: PaywallSaveBadge(
        label: l10n.paywallSavePercent(savings),
        gradient: PaywallVariantPalette.p7Cta,
      ),
    );
  }
}
