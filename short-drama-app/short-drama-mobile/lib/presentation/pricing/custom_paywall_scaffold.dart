import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

import '../../l10n/app_localizations.dart';
import '../../services/legal_url_launcher.dart';
import '../../services/marketing/marketing_funnel_events.dart';
import '../../services/marketing/marketing_purchase_helper.dart';
import '../../services/revenuecat_service.dart';
import '../../services/user_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/top_toast.dart';
import 'widgets/animated_paywall_collage.dart';

/// Custom subscription paywall with bento hero collage.
class CustomPaywallScaffold extends StatefulWidget {
  final Offering offering;
  final VoidCallback? onDismiss;
  final VoidCallback? onProUnlocked;

  final Future<void> Function(CustomerInfo customerInfo, StoreTransaction txn)
      onPurchaseCompleted;

  const CustomPaywallScaffold({
    super.key,
    required this.offering,
    this.onDismiss,
    this.onProUnlocked,
    required this.onPurchaseCompleted,
  });

  @override
  State<CustomPaywallScaffold> createState() => _CustomPaywallScaffoldState();
}

enum _SelectedPlan { annual, monthly, weekly }

class _ResolvedPackages {
  final Package? annual;
  final Package? monthly;
  final Package? weekly;

  const _ResolvedPackages({this.annual, this.monthly, this.weekly});

  factory _ResolvedPackages.from(Offering offering) {
    Package? annual;
    Package? monthly;
    Package? weekly;
    for (final p in offering.availablePackages) {
      if (p.packageType == PackageType.annual) annual = p;
      if (p.packageType == PackageType.monthly) monthly = p;
      if (p.packageType == PackageType.weekly) weekly = p;
    }
    annual ??= _byPeriod(offering, 'P1Y');
    monthly ??= _byPeriod(offering, 'P1M');
    weekly ??= _byPeriod(offering, 'P1W');
    return _ResolvedPackages(
      annual: annual,
      monthly: monthly,
      weekly: weekly,
    );
  }

  bool get hasAny => annual != null || monthly != null || weekly != null;

  static Package? _byPeriod(Offering offering, String isoPeriod) {
    for (final p in offering.availablePackages) {
      if (p.storeProduct.subscriptionPeriod == isoPeriod) return p;
    }
    return null;
  }
}

class _CustomPaywallScaffoldState extends State<CustomPaywallScaffold>
    with TickerProviderStateMixin {
  static const BorderRadius _planCardRadius =
      BorderRadius.all(Radius.circular(14));

  static const _featureIcons = [
    Icons.rocket_launch_rounded,
    Icons.mic_rounded,
    Icons.block_rounded,
  ];

  static const _socialProofAvatars = [
    'assets/images/paywall/avatar/avatar_1.jpg',
    'assets/images/paywall/avatar/avatar_2.jpg',
    'assets/images/paywall/avatar/avatar_3.jpg',
    'assets/images/paywall/avatar/avatar_4.jpg',
    'assets/images/paywall/avatar/avatar_5.jpg',
  ];

  static const _visibleAvatarCount = 3;
  static const _avatarDiameter = 18.0;
  static const _avatarBorderWidth = 1.2;
  static const _avatarOverlap = 6.0;

  static double get _avatarVisualSize =>
      _avatarDiameter + _avatarBorderWidth * 2;

  static double get _avatarStep => _avatarDiameter - _avatarOverlap;

  late _ResolvedPackages _packages;
  late _SelectedPlan _selectedPlan;
  bool _busy = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late AnimationController _avatarSlideController;
  bool _closeButtonVisible = false;
  Timer? _closeRevealTimer;
  Timer? _avatarCycleTimer;
  int _avatarWindowStart = 0;

  @override
  void initState() {
    super.initState();
    _packages = _ResolvedPackages.from(widget.offering);
    if (_packages.annual != null) {
      _selectedPlan = _SelectedPlan.annual;
    } else if (_packages.monthly != null) {
      _selectedPlan = _SelectedPlan.monthly;
    } else {
      _selectedPlan = _SelectedPlan.weekly;
    }
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.975, end: 1.025).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _avatarSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _closeRevealTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _closeButtonVisible = true);
    });

    _avatarCycleTimer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      _advanceSocialProofAvatars();
    });
  }

  Future<void> _advanceSocialProofAvatars() async {
    if (!mounted || _avatarSlideController.isAnimating) return;
    await _avatarSlideController.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _avatarWindowStart =
          (_avatarWindowStart + 1) % _socialProofAvatars.length;
    });
    _avatarSlideController.value = 0;
  }

  String _socialProofAvatarAt(int offset) {
    final index =
        (_avatarWindowStart + offset) % _socialProofAvatars.length;
    return _socialProofAvatars[index];
  }

  double get _socialProofAvatarRowWidth =>
      _avatarVisualSize + (_visibleAvatarCount - 1) * _avatarStep;

  @override
  void dispose() {
    _closeRevealTimer?.cancel();
    _avatarCycleTimer?.cancel();
    _avatarSlideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  int? _savingsPercent() {
    final a = _packages.annual;
    final w = _packages.weekly;
    if (a == null || w == null) return null;
    final wp = w.storeProduct.price;
    final ap = a.storeProduct.price;
    if (wp <= 0) return null;
    final yearlyIfWeekly = wp * 52;
    if (yearlyIfWeekly <= ap) return null;
    return (((yearlyIfWeekly - ap) / yearlyIfWeekly) * 100).round();
  }

  String? _annualPerWeekPrice(Package annual) {
    final product = annual.storeProduct;
    if (product.price <= 0) return null;
    final weekly = product.price / 52;
    return NumberFormat.simpleCurrency(name: product.currencyCode).format(weekly);
  }

  String? _monthlyPerWeekPrice(Package monthly) {
    final product = monthly.storeProduct;
    if (product.price <= 0) return null;
    final weekly = product.price / (52 / 12);
    return NumberFormat.simpleCurrency(name: product.currencyCode).format(weekly);
  }

  Package? _selectedPackage() {
    switch (_selectedPlan) {
      case _SelectedPlan.annual:
        return _packages.annual ??
            _packages.monthly ??
            _packages.weekly;
      case _SelectedPlan.monthly:
        return _packages.monthly ??
            _packages.annual ??
            _packages.weekly;
      case _SelectedPlan.weekly:
        return _packages.weekly ??
            _packages.monthly ??
            _packages.annual;
    }
  }

  Future<void> _subscribe(AppLocalizations l10n) async {
    final pkg = _selectedPackage();
    if (pkg == null) {
      if (mounted) showTopToastInfo(context, l10n.paywallNoPackages);
      return;
    }
    setState(() => _busy = true);
    try {
      if (!await RevenueCatService.linkPurchasesToAuth()) {
        if (mounted) showTopToastError(context, l10n.paywallPurchaseFailed);
        return;
      }
      await MarketingPurchaseHelper.trackCheckoutFromPackage(pkg);
      final result = await Purchases.purchase(PurchaseParams.package(pkg));
      if (!mounted) return;
      await MarketingPurchaseHelper.trackPurchaseFromProduct(
        transaction: result.storeTransaction,
        product: pkg.storeProduct,
        packageId: pkg.identifier,
        isSubscription: true,
      );
      await widget.onPurchaseCompleted(
        result.customerInfo,
        result.storeTransaction,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return;
      MarketingFunnelEvents.trackError('purchase_failed', extra: {'code': code.name});
      showTopToastError(context, '${l10n.paywallPurchaseFailed}: ${e.message ?? code}');
    } catch (e) {
      if (!mounted) return;
      MarketingFunnelEvents.trackError('purchase_failed', extra: {'message': e.toString()});
      showTopToastError(context, '${l10n.paywallPurchaseFailed}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(AppLocalizations l10n) async {
    setState(() => _busy = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.listenForMigrationComplete();
      final info = await RevenueCatService.restorePurchases();
      if (!mounted) return;
      await userProvider.refreshUser(syncProStatus: true);
      final entitled = info.entitlements.active
          .containsKey(RevenueCatService.proEntitlementId);
      if (!mounted) return;
      await MarketingFunnelEvents.trackRestorePurchases(success: entitled);
      if (entitled) {
        showTopToastSuccess(context, l10n.paywallRestoreSuccess);
      } else {
        showTopToastInfo(context, l10n.paywallRestoreNone);
      }
      if (entitled) widget.onProUnlocked?.call();
    } catch (e) {
      if (!mounted) return;
      showTopToastError(context, '${l10n.paywallRestoreFailed}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static Color get _chromeButtonBg =>
      Colors.black.withValues(alpha: 0.48);

  void _showProHelp(AppLocalizations l10n) {
    final features = [
      (Icons.rocket_launch_rounded, l10n.paywallHelpFeature1),
      (Icons.mic_rounded, l10n.paywallHelpFeature2),
      (Icons.music_note_rounded, l10n.paywallHelpFeature3),
      (Icons.block_rounded, l10n.paywallHelpFeature4),
    ];

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 9.w),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDarkBlue,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.dividerDark.withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(5.w, 2.h, 4.w, 2.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.paywallHelpTitle,
                        style: GoogleFonts.inter(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryDark,
                        ),
                      ),
                    ),
                    _flatIconButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.pop(ctx),
                      size: 32,
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: AppTheme.dividerDark.withValues(alpha: 0.45),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 2.4.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...features.map((f) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 1.4.h),
                        child: _helpFeatureRow(icon: f.$1, label: f.$2),
                      );
                    }),
                    SizedBox(
                      width: double.infinity,
                      height: 5.h,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: AppTheme.accentBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          l10n.paywallHelpGotIt,
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helpFeatureRow({required IconData icon, required String label}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppTheme.cardDarkBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.accentBlue, size: 15),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimaryDark,
              height: 1.3,
            ),
          ),
        ),
        Icon(
          Icons.check_rounded,
          color: AppTheme.success,
          size: 18,
        ),
      ],
    );
  }

  Widget _flatIconButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 38,
  }) {
    return Material(
      color: _chromeButtonBg,
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

  Widget _helpChip({
    required String label,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: _chromeButtonBg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  void _handleClose() {
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final savings = _savingsPercent();
    final hasAnyPackage = _packages.hasAny;
    final appName = l10n.appTitle;

    return Theme(
      data: AppTheme.darkTheme,
      child: Builder(
        builder: (context) {
          if (!hasAnyPackage) {
            return PopScope(
              canPop: false,
              child: Scaffold(
                backgroundColor: AppTheme.paywallShell,
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
                        _footerLinks(l10n),
                        SizedBox(height: 2.h),
                        TextButton(
                          onPressed: _busy ? null : _handleClose,
                          child: Text(l10n.paywallGotIt),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return PopScope(
            canPop: false,
            child: Scaffold(
              backgroundColor: AppTheme.paywallShell,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: PaywallCollageBackground(
                      shell: AppTheme.paywallShell,
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 0.6.h,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 38,
                                height: 38,
                                child: AnimatedOpacity(
                                  opacity: _closeButtonVisible ? 1 : 0,
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOut,
                                  child: IgnorePointer(
                                    ignoring: !_closeButtonVisible || _busy,
                                    child: _flatIconButton(
                                      icon: Icons.close,
                                      onTap: _handleClose,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              _helpChip(
                                label: l10n.paywallWhatAreSongs,
                                onTap: _busy ? null : () => _showProHelp(l10n),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 5.w,
                              right: 5.w,
                              bottom:
                                  1.h + MediaQuery.paddingOf(context).bottom,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Spacer(),
                                Text(
                                  l10n.paywallHeadline(appName),
                                  textAlign: TextAlign.left,
                                  style: GoogleFonts.inter(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimaryDark,
                                    height: 1.15,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(3, (i) {
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            bottom: i < 2 ? 1.h : 0,
                                          ),
                                          child: _featureIcon(_featureIcons[i]),
                                        );
                                      }),
                                    ),
                                    SizedBox(width: 2.5.w),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _featureLabel(
                                          l10n.paywallFeatureCreateMusic,
                                        ),
                                        SizedBox(height: 1.h),
                                        _featureLabel(
                                          l10n.paywallFeatureIdeasToSongs,
                                        ),
                                        SizedBox(height: 1.h),
                                        _featureLabel(l10n.paywallFeatureNoAds),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2.5.h),
                                if (_packages.annual != null) ...[
                                  _socialProofBadge(l10n),
                                  SizedBox(height: 0.6.h),
                                  _planCard(
                                    l10n: l10n,
                                    title: l10n.paywallPlanYearly,
                                    subtitleLine: l10n.paywallBillingJustYear(
                                      _packages.annual!.storeProduct.priceString,
                                    ),
                                    rightPrice: _annualPerWeekPrice(
                                      _packages.annual!,
                                    ),
                                    rightSubtitle: l10n.paywallPerWeekLabel,
                                    selected:
                                        _selectedPlan == _SelectedPlan.annual,
                                    isAnnual: true,
                                    savingsPercent: savings,
                                    onTap: () => setState(
                                      () => _selectedPlan = _SelectedPlan.annual,
                                    ),
                                  ),
                                ],
                                if (_packages.annual != null &&
                                    _packages.monthly != null)
                                  SizedBox(height: 1.2.h),
                                if (_packages.monthly != null)
                                  _planCard(
                                    l10n: l10n,
                                    title: l10n.paywallPlanMonthly,
                                    subtitleLine: l10n.paywallBillingJustMonth(
                                      _packages
                                          .monthly!.storeProduct.priceString,
                                    ),
                                    rightPrice: _monthlyPerWeekPrice(
                                      _packages.monthly!,
                                    ),
                                    rightSubtitle: l10n.paywallPerWeekLabel,
                                    selected:
                                        _selectedPlan == _SelectedPlan.monthly,
                                    isAnnual: false,
                                    savingsPercent: null,
                                    onTap: () => setState(
                                      () =>
                                          _selectedPlan = _SelectedPlan.monthly,
                                    ),
                                  ),
                                if ((_packages.annual != null ||
                                        _packages.monthly != null) &&
                                    _packages.weekly != null)
                                  SizedBox(height: 1.2.h),
                                if (_packages.weekly != null)
                                  _planCard(
                                    l10n: l10n,
                                    title: l10n.paywallPlanWeekly,
                                    subtitleLine: null,
                                    rightPrice: _packages
                                        .weekly!.storeProduct.priceString,
                                    rightSubtitle: l10n.paywallPerWeekLabel,
                                    selected:
                                        _selectedPlan == _SelectedPlan.weekly,
                                    isAnnual: false,
                                    savingsPercent: null,
                                    onTap: () => setState(
                                      () => _selectedPlan = _SelectedPlan.weekly,
                                    ),
                                  ),
                                SizedBox(height: 1.6.h),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: AppTheme.success,
                                      size: 14.sp,
                                    ),
                                    SizedBox(width: 1.5.w),
                                    Text(
                                      l10n.paywallCancelAnytime,
                                      style: GoogleFonts.inter(
                                        fontSize: 8.5.sp,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textPrimaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2.h),
                                _continueButton(l10n),
                                SizedBox(height: 2.h),
                                _footerLinks(l10n),
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
        },
      ),
    );
  }

  Widget _featureIcon(IconData icon) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.accentBlue.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppTheme.accentBlueLight, size: 15),
      ),
    );
  }

  Widget _featureLabel(String label) {
    return SizedBox(
      height: 28,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryDark,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _socialProofAvatarBubble(String assetPath) {
    return SizedBox(
      width: _avatarVisualSize,
      height: _avatarVisualSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: _avatarBorderWidth,
          ),
        ),
        child: ClipOval(
          child: Image.asset(
            assetPath,
            width: _avatarDiameter,
            height: _avatarDiameter,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }

  Widget _animatedSocialProofAvatars() {
    return SizedBox(
      width: _socialProofAvatarRowWidth,
      height: _avatarVisualSize,
      child: AnimatedBuilder(
        animation: _avatarSlideController,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_avatarSlideController.value);
          final isAnimating = t > 0;
          final avatarCount =
              isAnimating ? _visibleAvatarCount + 1 : _visibleAvatarCount;
          final trackWidth =
              _avatarVisualSize + (avatarCount - 1) * _avatarStep;

          double opacityForIndex(int index) {
            if (!isAnimating) return 1;
            if (index == 0) {
              return (1 - (t * 2.4)).clamp(0.0, 1.0);
            }
            if (index == avatarCount - 1) {
              return ((t - 0.12) / 0.88).clamp(0.0, 1.0);
            }
            return 1;
          }

          return Align(
            alignment: Alignment.centerRight,
            child: Transform.translate(
              offset: Offset(-t * _avatarStep, 0),
              child: SizedBox(
                width: trackWidth,
                height: _avatarVisualSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: List.generate(avatarCount, (index) {
                    final opacity = opacityForIndex(index);
                    if (opacity <= 0) {
                      return const SizedBox.shrink();
                    }

                    return Positioned(
                      left: index * _avatarStep,
                      child: Opacity(
                        opacity: opacity,
                        child: _socialProofAvatarBubble(
                          _socialProofAvatarAt(index),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _socialProofBadge(AppLocalizations l10n) {
    const arrowH = 8.0;
    const overlap = 2.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppTheme.socialProofGradient,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.7.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _animatedSocialProofAvatars(),
                    SizedBox(width: 2.w),
                    Text(
                      l10n.paywallSocialProof,
                      style: GoogleFonts.inter(
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 22,
              bottom: -(arrowH - overlap),
              child: CustomPaint(
                size: const Size(14, arrowH),
                painter: _PaywallBadgeArrowPainter(
                  gradient: AppTheme.socialProofGradient,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: arrowH),
      ],
    );
  }

  Widget _planCard({
    required AppLocalizations l10n,
    required String title,
    required String? subtitleLine,
    required String? rightPrice,
    required String? rightSubtitle,
    required bool selected,
    required bool isAnnual,
    required int? savingsPercent,
    required VoidCallback onTap,
  }) {
    final titleColor = selected
        ? AppTheme.textPrimaryDark
        : AppTheme.textSecondaryDark;
    final showSaveBadge =
        isAnnual && savingsPercent != null && savingsPercent > 0;

    Widget card = Material(
      color: Colors.transparent,
      borderRadius: _planCardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: _planCardRadius,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: _planCardRadius,
            color: AppTheme.cardDarkBlue,
            border: selected
                ? Border.all(color: AppTheme.accentBlue, width: 2)
                : Border.all(
                    color: AppTheme.dividerDark.withValues(alpha: 0.6),
                    width: 1,
                  ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: titleColor,
                  size: 20,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      if (subtitleLine != null) ...[
                        SizedBox(height: 0.3.h),
                        Text(
                          subtitleLine,
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: titleColor.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (rightPrice != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rightPrice,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      if (rightSubtitle != null) ...[
                        SizedBox(height: 0.15.h),
                        Text(
                          rightSubtitle,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.inter(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w500,
                            color: titleColor.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!showSaveBadge) return card;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            right: 10,
            top: -11,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppTheme.proGradient,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text(
                  l10n.paywallSavePercent(savingsPercent),
                  style: GoogleFonts.inter(
                    fontSize: 9.2.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.05,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _continueButton(AppLocalizations l10n) {
    const radius = BorderRadius.all(Radius.circular(999));
    const borderWidth = 2.0;

    final innerDecoration = BoxDecoration(
      borderRadius: radius,
      gradient: AppTheme.proGradient,
    );

    final outerDecoration = BoxDecoration(
      borderRadius: radius,
      gradient: LinearGradient(
        colors: [
          AppTheme.accentBlueLight.withValues(alpha: 0.95),
          AppTheme.accentBlue.withValues(alpha: 0.95),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
    );

    final child = SizedBox(
      width: double.infinity,
      height: 6.4.h,
      child: Center(
        child: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(
                l10n.paywallContinue,
                style: GoogleFonts.inter(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );

    Widget button = DecoratedBox(
      decoration: outerDecoration,
      child: Padding(
        padding: const EdgeInsets.all(borderWidth),
        child: DecoratedBox(
          decoration: innerDecoration,
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              splashColor: Colors.white.withValues(alpha: 0.12),
              highlightColor: Colors.white.withValues(alpha: 0.06),
              onTap: _busy ? null : () => _subscribe(l10n),
              child: child,
            ),
          ),
        ),
      ),
    );

    if (_busy) return button;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Transform.scale(
          scale: _pulseScale.value,
          alignment: Alignment.center,
          child: button,
        );
      },
    );
  }

  Widget _footerLinks(AppLocalizations l10n) {
    final linkStyle = GoogleFonts.inter(
      fontSize: 8.sp,
      fontWeight: FontWeight.w500,
      color: AppTheme.textSecondaryDark,
      decoration: TextDecoration.underline,
      decorationColor: AppTheme.textSecondaryDark.withValues(alpha: 0.75),
    );
    final separatorStyle = GoogleFonts.inter(
      fontSize: 7.5.sp,
      color: AppTheme.textSecondaryDark.withValues(alpha: 0.8),
    );

    Widget tap(String label, VoidCallback onTap) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _busy ? null : onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 1.w, vertical: 0.4.h),
          child: Text(label, style: linkStyle),
        ),
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
        tap(l10n.paywallRestore, () => _restore(l10n)),
      ],
    );
  }
}

/// Downward speech-bubble tail under the social-proof pill.
class _PaywallBadgeArrowPainter extends CustomPainter {
  _PaywallBadgeArrowPainter({required this.gradient});

  final Gradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, -1.5)
      ..lineTo(size.width, -1.5)
      ..lineTo(size.width * 0.35, size.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(-22, -28, 180, 36),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _PaywallBadgeArrowPainter oldDelegate) =>
      oldDelegate.gradient != gradient;
}
