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

/// Paywall 6 — blurred hero, feature showcase row, coral CTA, social proof.
class Paywall6Scaffold extends StatefulWidget {
  const Paywall6Scaffold({super.key, required this.args});

  final PaywallScaffoldArgs args;

  @override
  State<Paywall6Scaffold> createState() => _Paywall6ScaffoldState();
}

class _Paywall6ScaffoldState extends State<Paywall6Scaffold>
    with TickerProviderStateMixin {
  static const _showcaseIcons = [
    Icons.block_rounded,
    Icons.podcasts_rounded,
    Icons.high_quality_rounded,
    Icons.download_rounded,
  ];

  late final PaywallResolvedPackages _packages;
  late PaywallSelectedPlan _selected;
  final _busy = ValueNotifier(false);
  late final PaywallPurchaseHandler _handler;
  Timer? _closeTimer;
  bool _closeVisible = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.975, end: 1.025).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
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
    _pulseController.dispose();
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
    final heroH = MediaQuery.sizeOf(context).height * 0.26;
    final appName = l10n.appTitle;

    if (!_packages.hasAny) {
      return PaywallNoPackagesView(
        l10n: l10n,
        handler: _handler,
        busy: _busy,
        onClose: _handleClose,
        backgroundColor: PaywallVariantPalette.p6Shell,
      );
    }

    final showcaseLabels = [
      l10n.paywallFeatureCreateMusic,
      l10n.paywallFeatureIdeasToSongs,
      l10n.paywallFeatureNoAds,
      l10n.paywallFeatureYourLyrics,
    ];

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: PaywallVariantPalette.p6Shell,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: PaywallCollageBackground(
                shell: PaywallVariantPalette.p6Shell,
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
                    bottom: 20,
                    child: Column(
                      children: [
                        Text(
                          appName,
                          style: GoogleFonts.inter(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${l10n.paywallUnlockLine1} ${l10n.paywallUnlockLine2}',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 13.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                itemCount: _showcaseIcons.length,
                separatorBuilder: (_, __) => SizedBox(width: 2.5.w),
                itemBuilder: (context, i) {
                  return Container(
                    width: 28.w,
                    decoration: BoxDecoration(
                      color: PaywallVariantPalette.p6Card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 2.5.w,
                      vertical: 1.2.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _showcaseIcons[i],
                          color: PaywallVariantPalette.p6Accent,
                          size: 20,
                        ),
                        SizedBox(height: 0.6.h),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              showcaseLabels[i],
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.15,
                              ),
                            ),
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
                padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 2.h),
                child: Column(
                  children: [
                    if (_packages.annual != null)
                      _radioSelectPlanRow(
                        l10n: l10n,
                        title: l10n.paywallPlanYearly,
                        subtitle: l10n.paywallBillingJustYear(
                          _packages.annual!.storeProduct.priceString,
                        ),
                        rightPrice: paywallAnnualPerWeekPrice(
                          _packages.annual!,
                        ),
                        selected: _selected == PaywallSelectedPlan.annual,
                        highlight: true,
                        onTap: () => setState(
                          () => _selected = PaywallSelectedPlan.annual,
                        ),
                      ),
                    if (_packages.annual != null && _packages.weekly != null)
                      SizedBox(height: 1.2.h),
                    if (_packages.weekly != null)
                      _radioSelectPlanRow(
                        l10n: l10n,
                        title: l10n.paywallPlanWeekly,
                        subtitle: l10n.paywallPerWeekLabel,
                        rightPrice:
                            _packages.weekly!.storeProduct.priceString,
                        selected: _selected == PaywallSelectedPlan.weekly,
                        highlight: false,
                        onTap: () => setState(
                          () => _selected = PaywallSelectedPlan.weekly,
                        ),
                      ),
                    if (_packages.monthly != null) ...[
                      SizedBox(height: 1.2.h),
                      _radioSelectPlanRow(
                        l10n: l10n,
                        title: l10n.paywallPlanMonthly,
                        subtitle: null,
                        rightPrice:
                            _packages.monthly!.storeProduct.priceString,
                        selected: _selected == PaywallSelectedPlan.monthly,
                        highlight: false,
                        onTap: () => setState(
                          () => _selected = PaywallSelectedPlan.monthly,
                        ),
                      ),
                    ],
                    const Spacer(),
                    PaywallContinueButton(
                      label: l10n.paywallContinue,
                      gradient: PaywallVariantPalette.p6Cta,
                      busy: _busy,
                      pulseScale: _pulseScale,
                      onTap: () => _handler.subscribe(
                        package: _packages.packageFor(_selected),
                        l10n: l10n,
                        busy: _busy,
                      ),
                    ),
                    SizedBox(height: 1.5.h),
                    Text(
                      l10n.paywallSocialProof,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 8.5.sp,
                        color: Colors.white60,
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

  Widget _radioSelectPlanRow({
    required AppLocalizations l10n,
    required String title,
    required String? subtitle,
    required String? rightPrice,
    required bool selected,
    required bool highlight,
    required VoidCallback onTap,
  }) {
    final accent = highlight && selected
        ? PaywallVariantPalette.p6Accent
        : Colors.white54;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: PaywallVariantPalette.p6Card,
            border: Border.all(
              color: selected
                  ? PaywallVariantPalette.p6Accent
                  : Colors.white.withValues(alpha: 0.1),
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
                  color: accent,
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
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: highlight && selected
                              ? PaywallVariantPalette.p6Accent
                              : Colors.white,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 9.sp,
                            color: Colors.white54,
                          ),
                        ),
                    ],
                  ),
                ),
                if (rightPrice != null)
                  Text(
                    rightPrice,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
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
  }
}
