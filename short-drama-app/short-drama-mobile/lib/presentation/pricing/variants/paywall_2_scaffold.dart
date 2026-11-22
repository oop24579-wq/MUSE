import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/paywall_frequency.dart';
import '../paywall_router.dart';
import '../shared/paywall_common_widgets.dart';
import '../shared/paywall_packages.dart';
import '../shared/paywall_purchase_handler.dart';
import '../shared/paywall_variant_palette.dart';
import '../widgets/animated_paywall_collage.dart';

/// Paywall 2 — hero preview, horizontal feature chips, red PRO accent.
class Paywall2Scaffold extends StatefulWidget {
  const Paywall2Scaffold({super.key, required this.args});

  final PaywallScaffoldArgs args;

  @override
  State<Paywall2Scaffold> createState() => _Paywall2ScaffoldState();
}

class _Paywall2ScaffoldState extends State<Paywall2Scaffold> {
  static const _featureIcons = [
    Icons.bolt_rounded,
    Icons.lock_open_rounded,
    Icons.download_rounded,
    Icons.radio_rounded,
  ];

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
    // Repeat paywall shows skip the 2s close-button delay entirely
    // (CODE_READINESS item 7); only the first-ever show keeps it.
    if (PaywallFrequency.cachedEverShown) {
      _closeVisible = true;
    } else {
      _closeTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _closeVisible = true);
      });
      PaywallFrequency.ensureLoaded().then((_) {
        if (mounted && PaywallFrequency.cachedEverShown) {
          _closeTimer?.cancel();
          setState(() => _closeVisible = true);
        }
      });
    }
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
    final heroH = MediaQuery.sizeOf(context).height * 0.36;
    final savings = paywallSavingsPercent(_packages.annual, _packages.weekly);

    if (!_packages.hasAny) {
      return PaywallNoPackagesView(
        l10n: l10n,
        handler: _handler,
        busy: _busy,
        onClose: _handleClose,
        backgroundColor: PaywallVariantPalette.p2Shell,
      );
    }

    final featureLabels = [
      l10n.paywallFeatureNoAds,
      l10n.paywallFeatureCreateMusic,
      l10n.paywallFeatureIdeasToSongs,
      l10n.paywallFeatureYourLyrics,
    ];

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: PaywallVariantPalette.p2Shell,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: PaywallCollageBackground(
                shell: PaywallVariantPalette.p2Shell,
              ),
            ),
            Column(
          children: [
            SizedBox(
              height: heroH,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 8,
                    left: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          'Free',
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 8,
                    right: 16,
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
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${l10n.paywallUnlockLine1} ',
                          style: GoogleFonts.inter(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const PaywallProBadge(color: PaywallVariantPalette.p2Accent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 9.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                itemCount: _featureIcons.length,
                separatorBuilder: (_, __) => SizedBox(width: 2.w),
                itemBuilder: (context, i) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
                    decoration: BoxDecoration(
                      color: PaywallVariantPalette.p2Card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_featureIcons[i], color: Colors.white, size: 18),
                        SizedBox(width: 2.w),
                        Text(
                          featureLabels[i],
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(5.w, 1.h, 5.w, 2.h),
                child: Column(
                  children: [
                    if (_packages.annual != null)
                      _planTile(
                        l10n: l10n,
                        title: l10n.paywallPlanYearly,
                        subtitle: l10n.paywallBillingJustYear(
                          _packages.annual!.storeProduct.priceString,
                        ),
                        price: _packages.annual!.storeProduct.priceString,
                        selected: _selected == PaywallSelectedPlan.annual,
                        savings: savings,
                        onTap: () => setState(
                          () => _selected = PaywallSelectedPlan.annual,
                        ),
                      ),
                    if (_packages.annual != null && _packages.weekly != null)
                      SizedBox(height: 1.2.h),
                    if (_packages.weekly != null)
                      _planTile(
                        l10n: l10n,
                        title: l10n.paywallPlanWeekly,
                        subtitle: l10n.paywallPerWeekLabel,
                        price: _packages.weekly!.storeProduct.priceString,
                        selected: _selected == PaywallSelectedPlan.weekly,
                        savings: null,
                        onTap: () => setState(
                          () => _selected = PaywallSelectedPlan.weekly,
                        ),
                      ),
                    const Spacer(),
                    PaywallContinueButton(
                      label: l10n.paywallContinue,
                      gradient: PaywallVariantPalette.p2Cta,
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
          ],
        ),
      ),
    );
  }

  Widget _planTile({
    required AppLocalizations l10n,
    required String title,
    required String subtitle,
    required String price,
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
            color: PaywallVariantPalette.p2Card,
            border: Border.all(
              color: selected
                  ? PaywallVariantPalette.p2Accent
                  : Colors.white.withValues(alpha: 0.2),
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected
                      ? PaywallVariantPalette.p2Accent
                      : Colors.white54,
                  size: 22,
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
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  price,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
        gradient: PaywallVariantPalette.p2Cta,
      ),
    );
  }
}
