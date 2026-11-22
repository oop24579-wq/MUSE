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

/// Paywall 5 — urgency countdown, magenta plans, fan benefit cards.
class Paywall5Scaffold extends StatefulWidget {
  const Paywall5Scaffold({super.key, required this.args});

  final PaywallScaffoldArgs args;

  @override
  State<Paywall5Scaffold> createState() => _Paywall5ScaffoldState();
}

class _Paywall5ScaffoldState extends State<Paywall5Scaffold> {
  late final PaywallResolvedPackages _packages;
  late PaywallSelectedPlan _selected;
  final _busy = ValueNotifier(false);
  late final PaywallPurchaseHandler _handler;
  Timer? _closeTimer;
  Timer? _countdownTimer;
  bool _closeVisible = false;
  Duration _countdown = const Duration(minutes: 9, seconds: 57);

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
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _countdown.inSeconds <= 0) return;
      setState(() => _countdown -= const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _countdownTimer?.cancel();
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

  String _countdownText() {
    final m = _countdown.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _countdown.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final savings = paywallSavingsPercent(_packages.annual, _packages.weekly);
    final appName = l10n.appTitle;
    final mq = MediaQuery.sizeOf(context);
    final heroH = (mq.height * 0.24).clamp(140.0, 220.0);

    if (!_packages.hasAny) {
      return PaywallNoPackagesView(
        l10n: l10n,
        handler: _handler,
        busy: _busy,
        onClose: _handleClose,
        backgroundColor: PaywallVariantPalette.p5Shell,
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: PaywallVariantPalette.p5Shell,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: PaywallCollageBackground(
                shell: PaywallVariantPalette.p5Shell,
              ),
            ),
            SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: 1.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Row(
                          children: [
                            AnimatedOpacity(
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
                          ],
                        ),
                      ),
                      SizedBox(height: heroH),
                      SizedBox(height: 1.6.h),
                      Text(
                        l10n.paywallHeadline(appName),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 0.6.h),
                      Text(
                        l10n.paywallUnlockLine1,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 9.sp,
                          color: Colors.white60,
                        ),
                      ),
                      Text(
                        _countdownText(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w800,
                          color: PaywallVariantPalette.p5Accent,
                        ),
                      ),
                      SizedBox(height: 1.6.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5.w),
                        child: Column(
                          children: [
                            if (_packages.annual != null)
                              _dualPricePlanCard(
                                l10n: l10n,
                                title: l10n.paywallPlanYearly,
                                leftPrice:
                                    _packages.annual!.storeProduct.priceString,
                                rightPrice: paywallAnnualPerWeekPrice(
                                  _packages.annual!,
                                ),
                                selected:
                                    _selected == PaywallSelectedPlan.annual,
                                savings: savings,
                                onTap: () => setState(
                                  () => _selected = PaywallSelectedPlan.annual,
                                ),
                              ),
                            if (_packages.annual != null &&
                                _packages.weekly != null)
                              SizedBox(height: 1.2.h),
                            if (_packages.weekly != null)
                              _dualPricePlanCard(
                                l10n: l10n,
                                title: l10n.paywallPlanWeekly,
                                leftPrice:
                                    _packages.weekly!.storeProduct.priceString,
                                rightPrice:
                                    _packages.weekly!.storeProduct.priceString,
                                selected:
                                    _selected == PaywallSelectedPlan.weekly,
                                savings: null,
                                onTap: () => setState(
                                  () => _selected = PaywallSelectedPlan.weekly,
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5.w),
                        child: Text(
                          l10n.paywallHelpTitle,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 1.h),
                      SizedBox(
                        height: 9.h,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _overlappingBenefitCard(
                              offset: -48,
                              scale: 0.82,
                              label: l10n.paywallHelpFeature2,
                            ),
                            _overlappingBenefitCard(
                              offset: 48,
                              scale: 0.82,
                              label: l10n.paywallHelpFeature3,
                            ),
                            _overlappingBenefitCard(
                              offset: 0,
                              scale: 1,
                              label: l10n.paywallHelpFeature1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(5.w, 1.h, 5.w, 0),
                child: PaywallContinueButton(
                  label: l10n.paywallContinue,
                  gradient: PaywallVariantPalette.p5Cta,
                  busy: _busy,
                  onTap: () => _handler.subscribe(
                    package: _packages.packageFor(_selected),
                    l10n: l10n,
                    busy: _busy,
                  ),
                ),
              ),
              SizedBox(height: 1.2.h),
              PaywallFooterLinks(
                l10n: l10n,
                handler: _handler,
                busy: _busy,
              ),
              SizedBox(height: 0.6.h),
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }

  Widget _overlappingBenefitCard({
    required double offset,
    required double scale,
    required String label,
  }) {
    return Transform.translate(
      offset: Offset(offset, 0),
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 42.w,
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
          decoration: BoxDecoration(
            color: PaywallVariantPalette.p5Card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: PaywallVariantPalette.p5Accent.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 9.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dualPricePlanCard({
    required AppLocalizations l10n,
    required String title,
    required String leftPrice,
    required String? rightPrice,
    required bool selected,
    required int? savings,
    required VoidCallback onTap,
  }) {
    const radius = BorderRadius.all(Radius.circular(16));
    Widget card = Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: PaywallVariantPalette.p5Card,
            border: Border.all(
              color: selected
                  ? PaywallVariantPalette.p5Accent
                  : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        leftPrice,
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          color: Colors.white60,
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
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        l10n.paywallPerWeekLabel,
                        style: GoogleFonts.inter(
                          fontSize: 9.sp,
                          color: Colors.white54,
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
      badgeTop: -12,
      badgeRight: 12,
      topPadding: 13,
      badge: PaywallSaveBadge(
        label: l10n.paywallSavePercent(savings),
        gradient: PaywallVariantPalette.p5Cta,
      ),
    );
  }
}
