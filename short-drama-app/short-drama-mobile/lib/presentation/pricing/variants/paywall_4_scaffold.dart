import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:sizer/sizer.dart';

import '../../../l10n/app_localizations.dart';
import '../paywall_router.dart';
import '../widgets/animated_paywall_collage.dart';
import '../shared/paywall_common_widgets.dart';
import '../shared/paywall_packages.dart';
import '../shared/paywall_purchase_handler.dart';
import '../shared/paywall_variant_palette.dart';

/// Paywall 4 — gold luxury: three vertical plan columns, countdown footers, feature spotlight.
class Paywall4Scaffold extends StatefulWidget {
  const Paywall4Scaffold({super.key, required this.args});

  final PaywallScaffoldArgs args;

  @override
  State<Paywall4Scaffold> createState() => _Paywall4ScaffoldState();
}

class _Paywall4ScaffoldState extends State<Paywall4Scaffold> {
  late final PaywallResolvedPackages _packages;
  late PaywallSelectedPlan _selected;
  final _busy = ValueNotifier(false);
  late final PaywallPurchaseHandler _handler;
  Timer? _countdownTimer;
  Duration _countdown = const Duration(hours: 10, minutes: 3, seconds: 34);

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
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _countdown.inSeconds <= 0) return;
      setState(() => _countdown -= const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
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

  String _countdownLabel() {
    final h = _countdown.inHours;
    final m = _countdown.inMinutes.remainder(60);
    final s = _countdown.inSeconds.remainder(60);
    return '${h}H ${m}M ${s}S';
  }

  String? _monthlyEquivalent(Package pkg) {
    final product = pkg.storeProduct;
    if (product.price <= 0) return null;
    double monthly;
    if (pkg.packageType == PackageType.annual ||
        product.subscriptionPeriod == 'P1Y') {
      monthly = product.price / 12;
    } else if (pkg.packageType == PackageType.weekly ||
        product.subscriptionPeriod == 'P1W') {
      monthly = product.price * (52 / 12);
    } else {
      monthly = product.price;
    }
    return NumberFormat.simpleCurrency(name: product.currencyCode)
        .format(monthly);
  }

  String? _strikethroughPrice(Package annual) {
    final weekly = _packages.weekly;
    final monthly = _packages.monthly;
    final product = annual.storeProduct;
    if (product.price <= 0) return null;

    if (weekly != null && weekly.storeProduct.price > 0) {
      final original = weekly.storeProduct.price * 52;
      if (original > product.price) {
        return NumberFormat.simpleCurrency(name: product.currencyCode)
            .format(original);
      }
    }
    if (monthly != null && monthly.storeProduct.price > 0) {
      final original = monthly.storeProduct.price * 12;
      if (original > product.price) {
        return NumberFormat.simpleCurrency(name: product.currencyCode)
            .format(original);
      }
    }
    return null;
  }

  List<_VerticalPlanModel> _buildPlans(AppLocalizations l10n) {
    final savings = paywallSavingsPercent(_packages.annual, _packages.weekly);
    final plans = <_VerticalPlanModel>[];

    if (_packages.monthly != null) {
      final pkg = _packages.monthly!;
      plans.add(
        _VerticalPlanModel(
          plan: PaywallSelectedPlan.monthly,
          badge: null,
          mainAmount: _monthlyEquivalent(pkg) ?? pkg.storeProduct.priceString,
          periodSuffix: '/month',
          strikethrough: null,
          totalLine: null,
          footerLabel: l10n.paywallPlanMonthly,
          showCountdown: false,
          highlightBadge: false,
        ),
      );
    }

    if (_packages.annual != null) {
      final pkg = _packages.annual!;
      plans.add(
        _VerticalPlanModel(
          plan: PaywallSelectedPlan.annual,
          badge: savings != null ? l10n.paywallSavePercent(savings) : null,
          mainAmount: _monthlyEquivalent(pkg) ?? pkg.storeProduct.priceString,
          periodSuffix: '/month',
          strikethrough: _strikethroughPrice(pkg),
          totalLine: pkg.storeProduct.priceString,
          footerLabel: l10n.paywallPlanYearly,
          showCountdown: true,
          highlightBadge: true,
        ),
      );
    }

    if (_packages.weekly != null) {
      final pkg = _packages.weekly!;
      plans.add(
        _VerticalPlanModel(
          plan: PaywallSelectedPlan.weekly,
          badge: null,
          mainAmount: pkg.storeProduct.priceString,
          periodSuffix: '/week',
          strikethrough: null,
          totalLine: null,
          footerLabel: l10n.paywallPlanWeekly,
          showCountdown: false,
          highlightBadge: false,
        ),
      );
    }

    return plans;
  }

  String _footerPriceLine(AppLocalizations l10n, Package pkg) {
    final price = pkg.storeProduct.priceString;
    return switch (_selected) {
      PaywallSelectedPlan.annual => l10n.paywallBillingJustYear(price),
      PaywallSelectedPlan.monthly => l10n.paywallBillingJustMonth(price),
      PaywallSelectedPlan.weekly => l10n.paywallBillingWeek(price),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!_packages.hasAny) {
      return PaywallNoPackagesView(
        l10n: l10n,
        handler: _handler,
        busy: _busy,
        onClose: _handleClose,
        backgroundColor: PaywallVariantPalette.p4Shell,
      );
    }

    final plans = _buildPlans(l10n);
    final selectedPkg = _packages.packageFor(_selected);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: PaywallVariantPalette.p4Shell,
        body: Stack(
          children: [
            Positioned.fill(
              child: PaywallCollageBackground(
                shell: PaywallVariantPalette.p4Shell,
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 180,
              child: _GoldWaveHeader(),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.8.h),
                    child: Row(
                      children: [
                        PaywallChromeButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: _handleClose,
                          backgroundColor: PaywallVariantPalette.p4Surface,
                        ),
                        const Spacer(),
                        PaywallChromeButton(
                          icon: Icons.card_giftcard_rounded,
                          onTap: () {},
                          backgroundColor: PaywallVariantPalette.p4Surface,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${l10n.paywallUnlockLine1} ',
                              style: GoogleFonts.inter(
                                fontSize: 10.sp,
                                color: Colors.white70,
                              ),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: PaywallVariantPalette.p4Surface,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: PaywallVariantPalette.p4Accent
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                child: Text(
                                  l10n.paywallUnlockLine2,
                                  style: GoogleFonts.inter(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w600,
                                    color: PaywallVariantPalette.p4Accent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 1.2.h),
                        Text(
                          '${l10n.paywallUnlockLine1} ${l10n.paywallUnlockLine2}',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w700,
                            color: PaywallVariantPalette.p4Accent,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          l10n.paywallFeatureCreateMusic,
                          style: GoogleFonts.inter(
                            fontSize: 10.5.sp,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 2.2.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3.w),
                    child: SizedBox(
                      height: 31.5.h,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < plans.length; i++) ...[
                              if (i > 0) SizedBox(width: 1.8.w),
                              Expanded(
                                child: _verticalPlanColumn(
                                  l10n: l10n,
                                  model: plans[i],
                                  selected: _selected == plans[i].plan,
                                  countdown: _countdownLabel(),
                                  onTap: () => setState(
                                    () => _selected = plans[i].plan,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5.w),
                    child: Text(
                      l10n.paywallHelpTitle.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 7.5.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5.w),
                    child: Container(
                      decoration: BoxDecoration(
                        color: PaywallVariantPalette.p4Card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: PaywallVariantPalette.p4Accent
                              .withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(4.w, 3.w, 3.w, 2.w),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: PaywallVariantPalette.p4Accent
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.podcasts_rounded,
                                    color: PaywallVariantPalette.p4Accent,
                                    size: 18,
                                  ),
                                ),
                                SizedBox(width: 3.w),
                                Expanded(
                                  child: Text(
                                    l10n.paywallHelpFeature3,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white.withValues(alpha: 0.45),
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 3.w),
                            child: Text(
                              l10n.paywallHelpFeature1,
                              style: GoogleFonts.inter(
                                fontSize: 9.sp,
                                color: Colors.white.withValues(alpha: 0.55),
                                height: 1.4,
                              ),
                            ),
                          ),
                          Container(
                            height: 7.h,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(18),
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  PaywallVariantPalette.p4Accent
                                      .withValues(alpha: 0.15),
                                  PaywallVariantPalette.p4Card,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.radio_rounded,
                                    color: PaywallVariantPalette.p4Accent
                                        .withValues(alpha: 0.8),
                                    size: 20,
                                  ),
                                  SizedBox(width: 2.w),
                                  Icon(
                                    Icons.headphones_rounded,
                                    color: PaywallVariantPalette.p4Accent
                                        .withValues(alpha: 0.6),
                                    size: 20,
                                  ),
                                  SizedBox(width: 2.w),
                                  Icon(
                                    Icons.download_rounded,
                                    color: PaywallVariantPalette.p4Accent
                                        .withValues(alpha: 0.8),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (selectedPkg != null)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5.w),
                      child: Text(
                        _footerPriceLine(l10n, selectedPkg),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 9.sp,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  SizedBox(height: 1.2.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5.w),
                    child: PaywallContinueButton(
                      label: l10n.paywallSubscribe,
                      gradient: PaywallVariantPalette.p4Cta,
                      textColor: const Color(0xFF1A120B),
                      busy: _busy,
                      onTap: () => _handler.subscribe(
                        package: selectedPkg,
                        l10n: l10n,
                        busy: _busy,
                      ),
                    ),
                  ),
                  SizedBox(height: 1.6.h),
                  PaywallFooterLinks(
                    l10n: l10n,
                    handler: _handler,
                    busy: _busy,
                  ),
                  SizedBox(height: 0.8.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalPlanColumn({
    required AppLocalizations l10n,
    required _VerticalPlanModel model,
    required bool selected,
    required String countdown,
    required VoidCallback onTap,
  }) {
    const radius = 18.0;
    const topBadgeHeight = 32.0;
    final innerRadius = BorderRadius.circular(radius - (selected ? 2.5 : 1));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: EdgeInsets.symmetric(
          horizontal: selected ? 0 : 1,
          vertical: selected ? 0 : 2,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: selected
                ? PaywallVariantPalette.p4Accent
                : Colors.white.withValues(alpha: 0.12),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: PaywallVariantPalette.p4Accent.withValues(alpha: 0.5),
                    blurRadius: 22,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: PaywallVariantPalette.p4Accent.withValues(alpha: 0.22),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: innerRadius,
          child: ColoredBox(
            color: PaywallVariantPalette.p4Card.withValues(alpha: 0.96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: topBadgeHeight,
                  child: model.badge != null
                      ? _topDiscountBadge(
                          label: model.badge!,
                          highlighted: selected && model.highlightBadge,
                          radius: innerRadius,
                        )
                      : null,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _splitPriceText(
                          amount: model.mainAmount,
                          suffix: model.periodSuffix,
                          emphasized: selected,
                        ),
                        if (model.strikethrough != null ||
                            model.totalLine != null) ...[
                          SizedBox(height: 0.8.h),
                          if (model.strikethrough != null)
                            Text(
                              model.strikethrough!,
                              style: GoogleFonts.inter(
                                fontSize: 7.sp,
                                color: Colors.white38,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.white38,
                              ),
                            ),
                          if (model.totalLine != null)
                            Text(
                              model.totalLine!,
                              style: GoogleFonts.inter(
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding:
                      EdgeInsets.only(bottom: model.showCountdown ? 0.8.h : 1.2.h),
                  child: Text(
                    model.footerLabel,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 7.5.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white54,
                    ),
                  ),
                ),
                if (model.showCountdown)
                  _countdownFooterBar(
                    l10n: l10n,
                    countdown: countdown,
                    radius: innerRadius,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topDiscountBadge({
    required String label,
    required bool highlighted,
    required BorderRadius radius,
  }) {
    if (highlighted) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: PaywallVariantPalette.p4Cta,
          borderRadius: BorderRadius.only(
            topLeft: radius.topLeft,
            topRight: radius.topRight,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 8.5.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A120B),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 7.5.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white60,
          ),
        ),
      ),
    );
  }

  Widget _splitPriceText({
    required String amount,
    required String suffix,
    required bool emphasized,
  }) {
    final match = RegExp(r'^([^\d]*)([\d.,]+)(.*)$').firstMatch(amount);
    final prefix = match?.group(1) ?? '';
    final number = match?.group(2) ?? amount;
    final rest = match?.group(3) ?? '';

    final color = emphasized ? Colors.white : Colors.white.withValues(alpha: 0.9);

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.inter(color: color),
        children: [
          if (prefix.isNotEmpty)
            TextSpan(
              text: prefix,
              style: GoogleFonts.inter(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          TextSpan(
            text: number,
            style: GoogleFonts.inter(
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.05,
            ),
          ),
          if (rest.isNotEmpty)
            TextSpan(
              text: rest,
              style: GoogleFonts.inter(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          TextSpan(
            text: suffix,
            style: GoogleFonts.inter(
              fontSize: 8.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _countdownFooterBar({
    required AppLocalizations l10n,
    required String countdown,
    required BorderRadius radius,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: PaywallVariantPalette.p4Cta,
        borderRadius: BorderRadius.only(
          bottomLeft: radius.bottomLeft,
          bottomRight: radius.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Offer countdown',
              style: GoogleFonts.inter(
                fontSize: 6.5.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A120B).withValues(alpha: 0.7),
              ),
            ),
            Text(
              countdown,
              style: GoogleFonts.inter(
                fontSize: 8.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A120B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalPlanModel {
  const _VerticalPlanModel({
    required this.plan,
    required this.badge,
    required this.mainAmount,
    required this.periodSuffix,
    required this.strikethrough,
    required this.totalLine,
    required this.footerLabel,
    required this.showCountdown,
    required this.highlightBadge,
  });

  final PaywallSelectedPlan plan;
  final String? badge;
  final String mainAmount;
  final String periodSuffix;
  final String? strikethrough;
  final String? totalLine;
  final String footerLabel;
  final bool showCountdown;
  final bool highlightBadge;
}

class _GoldWaveHeader extends StatelessWidget {
  const _GoldWaveHeader();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GoldWavePainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _GoldWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final paths = [
      (0.18, 0.55),
      (0.32, 0.42),
      (0.48, 0.58),
    ];

    for (var i = 0; i < paths.length; i++) {
      paint.color = PaywallVariantPalette.p4Accent
          .withValues(alpha: 0.22 - i * 0.04);
      final path = Path();
      path.moveTo(0, size.height * paths[i].$1);
      path.quadraticBezierTo(
        size.width * 0.45,
        size.height * paths[i].$2,
        size.width,
        size.height * (paths[i].$1 + 0.08),
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
