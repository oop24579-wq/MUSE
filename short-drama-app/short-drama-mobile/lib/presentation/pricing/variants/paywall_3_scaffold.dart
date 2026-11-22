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

/// Paywall 3 — tilted image grid hero, blue/cyan social proof, annual/weekly.
class Paywall3Scaffold extends StatefulWidget {
  const Paywall3Scaffold({super.key, required this.args});

  final PaywallScaffoldArgs args;

  @override
  State<Paywall3Scaffold> createState() => _Paywall3ScaffoldState();
}

class _Paywall3ScaffoldState extends State<Paywall3Scaffold>
    with TickerProviderStateMixin {
  static const _featureIcons = [
    Icons.rocket_launch_rounded,
    Icons.mic_rounded,
    Icons.podcasts_rounded,
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
    _closeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _closeVisible = true);
    });
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
    final savings = paywallSavingsPercent(_packages.annual, _packages.weekly);
    final appName = l10n.appTitle;

    if (!_packages.hasAny) {
      return PaywallNoPackagesView(
        l10n: l10n,
        handler: _handler,
        busy: _busy,
        onClose: _handleClose,
        backgroundColor: PaywallVariantPalette.p3Shell,
      );
    }

    final features = [
      l10n.paywallFeatureCreateMusic,
      l10n.paywallFeatureIdeasToSongs,
      l10n.paywallHelpFeature3,
    ];

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: PaywallVariantPalette.p3Shell,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Full-screen animated poster collage + smooth bottom→top scrim.
            Positioned.fill(
              child: PaywallCollageBackground(
                shell: PaywallVariantPalette.p3Shell,
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
                      padding: EdgeInsets.fromLTRB(5.w, 0, 5.w, 2.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(),
                          Text(
                            l10n.paywallHeadline(appName),
                            style: GoogleFonts.inter(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          ...List.generate(features.length, (i) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: 1.h),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: PaywallVariantPalette.p3Accent
                                          .withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _featureIcons[i],
                                      color: PaywallVariantPalette.p3AccentEnd,
                                      size: 15,
                                    ),
                                  ),
                                  SizedBox(width: 2.5.w),
                                  Expanded(
                                    child: Text(
                                      features[i],
                                      style: GoogleFonts.inter(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          SizedBox(height: 2.5.h),
                          if (_packages.annual != null) ...[
                            _socialProof(l10n),
                            SizedBox(height: 0.6.h),
                            _planCard(
                              l10n: l10n,
                              title: l10n.paywallPlanYearly,
                              subtitle: l10n.paywallBillingJustYear(
                                _packages.annual!.storeProduct.priceString,
                              ),
                              rightPrice: paywallAnnualPerWeekPrice(
                                _packages.annual!,
                              ),
                              rightSubtitle: l10n.paywallPerWeekLabel,
                              selected: _selected == PaywallSelectedPlan.annual,
                              savings: savings,
                              onTap: () => setState(
                                () => _selected = PaywallSelectedPlan.annual,
                              ),
                            ),
                          ],
                          if (_packages.annual != null && _packages.weekly != null)
                            SizedBox(height: 1.2.h),
                          if (_packages.weekly != null)
                            _planCard(
                              l10n: l10n,
                              title: l10n.paywallPlanWeekly,
                              subtitle: null,
                              rightPrice:
                                  _packages.weekly!.storeProduct.priceString,
                              rightSubtitle: l10n.paywallPerWeekLabel,
                              selected: _selected == PaywallSelectedPlan.weekly,
                              savings: null,
                              onTap: () => setState(
                                () => _selected = PaywallSelectedPlan.weekly,
                              ),
                            ),
                          SizedBox(height: 1.6.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF34D399),
                                size: 16,
                              ),
                              SizedBox(width: 1.5.w),
                              Text(
                                l10n.paywallCancelAnytime,
                                style: GoogleFonts.inter(
                                  fontSize: 8.5.sp,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          PaywallContinueButton(
                            label: l10n.paywallContinue,
                            gradient: PaywallVariantPalette.p3Cta,
                            busy: _busy,
                            pulseScale: _pulseScale,
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

  Widget _socialProof(AppLocalizations l10n) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: PaywallVariantPalette.p3Social,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.7.h),
        child: Text(
          l10n.paywallSocialProof,
          style: GoogleFonts.inter(
            fontSize: 8.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _planCard({
    required AppLocalizations l10n,
    required String title,
    required String? subtitle,
    required String? rightPrice,
    required String? rightSubtitle,
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
            color: PaywallVariantPalette.p3Card,
            border: Border.all(
              color: selected
                  ? PaywallVariantPalette.p3Accent
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
                  color: Colors.white,
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
                      if (subtitle != null)
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
                if (rightPrice != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        rightPrice,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (rightSubtitle != null)
                        Text(
                          rightSubtitle,
                          style: GoogleFonts.inter(
                            fontSize: 9.sp,
                            color: Colors.white60,
                          ),
                        ),
                    ],
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
        gradient: PaywallVariantPalette.p3Cta,
      ),
    );
  }
}
