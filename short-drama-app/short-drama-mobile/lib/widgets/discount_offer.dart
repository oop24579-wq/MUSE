import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:sizer/sizer.dart';

import '../core/test_flags.dart';
import '../presentation/pricing/revenuecat_paywall_view.dart';
import '../services/firebase/remote_config_service.dart';
import '../services/paywall_preload_service.dart';
import '../services/marketing/marketing_event_names.dart';
import '../services/marketing/marketing_funnel_events.dart';
import '../services/marketing/marketing_purchase_helper.dart';
import '../services/revenuecat_service.dart';
import '../services/auth/auth_service.dart';
import '../services/user_provider.dart';
import '../theme/app_theme.dart';
import 'top_toast.dart';

OverlayEntry? _activeBannerEntry;
DateTime? _lastOfferDate;

const _paywallDismissCountPrefsKey = 'discount_offer_paywall_dismiss_count';

/// Returns true when the discount dialog should run after this paywall close.
Future<bool> _recordPaywallDismissAndShouldShowDiscount() async {
  final threshold =
      RemoteConfigService.instance.discountOfferPaywallDismissThreshold;
  if (threshold <= 0) return true;

  final prefs = await SharedPreferences.getInstance();
  final nextCount = (prefs.getInt(_paywallDismissCountPrefsKey) ?? 0) + 1;
  if (nextCount < threshold) {
    await prefs.setInt(_paywallDismissCountPrefsKey, nextCount);
    return false;
  }
  await prefs.setInt(_paywallDismissCountPrefsKey, 0);
  return true;
}

Future<void> presentPaywallWithDiscount(
  BuildContext context, {
  String trigger = PaywallTrigger.home,
}) async {
  final userProvider = Provider.of<UserProvider>(context, listen: false);
  if (TestFlags.forceProForTest || userProvider.isPro) {
    return;
  }

  await MarketingFunnelEvents.trackViewPaywall(trigger: trigger);
  await PaywallPreloadService.instance.preload();

  bool purchased = false;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (ctx) => RevenueCatPaywallView(
        onDismiss: () {
          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
        },
        onPurchaseComplete: () {
          purchased = true;
          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
        },
      ),
    ),
  );

  if (!purchased && context.mounted) {
    final userAfter = Provider.of<UserProvider>(context, listen: false);
    if (TestFlags.forceProForTest || userAfter.isPro) {
      return;
    }
    if (!await _recordPaywallDismissAndShouldShowDiscount()) return;
    final delayMs = RemoteConfigService.instance.discountOfferDelayMs;
    await Future<void>.delayed(Duration(milliseconds: delayMs));
    if (context.mounted) await showDiscountOffer(context);
  }
}

Future<void> showDiscountOffer(BuildContext context) async {
  final config = RemoteConfigService.instance;

  if (!config.discountOfferEnabled) return;

  final userProvider = Provider.of<UserProvider>(context, listen: false);
  if (TestFlags.forceProForTest || userProvider.isPro) return;

  final frequencySec = config.discountOfferFrequencySeconds;
  if (frequencySec > 0 && _lastOfferDate != null) {
    if (DateTime.now().difference(_lastOfferDate!).inSeconds < frequencySec) {
      return;
    }
  }

  // Fetch original yearly price (for crossed-out display)
  String yearlyPriceString = '';
  double yearlyPriceValue = 0;
  try {
    final offering = await RevenueCatService.getOfferingWithPaywall();
    if (offering == null || !context.mounted) return;
    for (final p in offering.availablePackages) {
      if (p.packageType == PackageType.annual) {
        yearlyPriceString = p.storeProduct.priceString;
        yearlyPriceValue = p.storeProduct.price;
        break;
      }
    }
  } catch (_) {
    return;
  }
  if (yearlyPriceString.isEmpty || !context.mounted) return;

  // Fetch discount product from RevenueCat
  StoreProduct? discountProduct;
  String discountPriceString = '';
  try {
    discountProduct =
        await RevenueCatService.getDiscountProduct(config.discountOfferProductId);
    if (discountProduct != null) {
      discountPriceString = discountProduct.priceString;
    }
  } catch (_) {}

  // Fallback: calculate half price if discount product not found
  if (discountPriceString.isEmpty) {
    discountPriceString = _discountedPrice(yearlyPriceString, yearlyPriceValue);
  }

  if (!context.mounted) return;

  _lastOfferDate = DateTime.now();
  await MarketingFunnelEvents.trackViewPaywall(trigger: PaywallTrigger.discountOffer);

  final discountText = config.discountOfferDiscountText;
  final timerSeconds = config.discountOfferTimerSeconds;
  final showBanner = config.discountOfferShowBanner;
  final timer = _OfferTimer(totalSeconds: timerSeconds);

  final result = await showGeneralDialog<_DialogResult>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (_, __, ___) => _DiscountDialog(
      timer: timer,
      yearlyPriceString: yearlyPriceString,
      discountPriceString: discountPriceString,
      discountText: discountText,
      discountProduct: discountProduct,
    ),
    transitionBuilder: (_, animation, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      );
    },
  );

  if (!context.mounted) {
    timer.dispose();
    return;
  }

  if (result == _DialogResult.claimed) {
    timer.dispose();
  } else if (showBanner && timer.remainingSeconds > 0) {
    _showDiscountBanner(context, timer, discountText, discountProduct);
  } else {
    timer.dispose();
  }
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

enum _DialogResult { claimed, dismissed }

class _OfferTimer {
  final int totalSeconds;
  late int remainingSeconds;
  Timer? _periodic;
  final _listeners = <VoidCallback>{};

  _OfferTimer({this.totalSeconds = 600}) {
    remainingSeconds = totalSeconds;
  }

  String get formatted {
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get progress => totalSeconds > 0 ? remainingSeconds / totalSeconds : 0;

  void addListener(VoidCallback cb) {
    _listeners.add(cb);
    _startIfNeeded();
  }

  void removeListener(VoidCallback cb) => _listeners.remove(cb);

  void _startIfNeeded() {
    if (_periodic != null) return;
    _periodic = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingSeconds > 0) {
        remainingSeconds--;
      } else {
        _periodic?.cancel();
        _periodic = null;
      }
      for (final cb in List.of(_listeners)) {
        cb();
      }
    });
  }

  void dispose() {
    _periodic?.cancel();
    _periodic = null;
    _listeners.clear();
  }
}

String _discountedPrice(String originalPriceString, double originalPrice) {
  final half = originalPrice / 2;
  final regex = RegExp(r'[\d]+([.,]\d+)?');
  final match = regex.firstMatch(originalPriceString);
  if (match == null) return originalPriceString;
  final numberStr = match.group(0)!;
  final usesComma = numberStr.contains(',') && !numberStr.contains('.');
  String formatted;
  if (usesComma) {
    formatted = half.toStringAsFixed(2).replaceAll('.', ',');
  } else if (numberStr.contains('.')) {
    formatted = half.toStringAsFixed(2);
  } else {
    formatted = half.round().toString();
  }
  return originalPriceString.replaceFirst(numberStr, formatted);
}

// ---------------------------------------------------------------------------
// Dialog
// ---------------------------------------------------------------------------

class _DiscountDialog extends StatefulWidget {
  final _OfferTimer timer;
  final String yearlyPriceString;
  final String discountPriceString;
  final String discountText;
  final StoreProduct? discountProduct;

  const _DiscountDialog({
    required this.timer,
    required this.yearlyPriceString,
    required this.discountPriceString,
    required this.discountText,
    required this.discountProduct,
  });

  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog>
    with TickerProviderStateMixin {
  late final AnimationController _shimmer;
  late final AnimationController _pulse;
  late final Animation<double> _pulseScale;
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    widget.timer.addListener(_tick);

    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (widget.timer.remainingSeconds <= 0 && !_purchasing) {
      Navigator.of(context).pop(_DialogResult.dismissed);
    }
  }

  Future<void> _handleClaim() async {
    final product = widget.discountProduct;
    if (product == null || _purchasing) return;

    setState(() => _purchasing = true);
    try {
      if (!await RevenueCatService.linkPurchasesToAuth()) {
        if (mounted) {
          showTopToastError(context, 'Purchase setup failed. Please try again.');
        }
        return;
      }

      await MarketingPurchaseHelper.trackCheckoutFromProduct(product);
      final result = await Purchases.purchase(
        PurchaseParams.storeProduct(product),
      );

      if (!mounted) return;

      await MarketingPurchaseHelper.trackPurchaseFromProduct(
        transaction: result.storeTransaction,
        product: product,
        isSubscription: true,
      );
      await RevenueCatService.saveSubscriptionAfterPurchase(
        result.customerInfo,
        result.storeTransaction,
      );

      final userId = AuthService.instance.currentUserId;
      if (userId != null && mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.refreshUser(syncProStatus: true);
      }

      if (mounted) {
        showTopToastSuccess(
          context,
          'Purchase successful! Pro features unlocked.',
          useOverlay: true,
        );
        Navigator.of(context).pop(_DialogResult.claimed);
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return;
      showTopToastError(context, 'Purchase failed: ${e.message ?? code}');
    } catch (e) {
      if (!mounted) return;
      showTopToastError(context, 'Purchase failed: $e');
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  void dispose() {
    widget.timer.removeListener(_tick);
    _shimmer.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrgent = widget.timer.remainingSeconds < 60;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const IgnorePointer(
            child: SizedBox.expand(),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 3.h),
              child: _card(isUrgent, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(bool isUrgent, bool isDark) {
    final textSecondary = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

    return Container(
      constraints: BoxConstraints(maxWidth: 90.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1E2240), Color(0xFF151A2E), Color(0xFF1A1232)]
              : const [Color(0xFFF8F9FF), Color(0xFFFFFFFF), Color(0xFFF5F0FF)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 2.5.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: _closeBtn(isDark),
          ),
          SizedBox(height: 0.5.h),
          _timerRing(isUrgent, isDark),
          SizedBox(height: 2.h),
          _offerBadge(isDark),
          SizedBox(height: 1.5.h),
          _bigDiscount(),
          SizedBox(height: 0.3.h),
          Text(
            'YEARLY PRO PLAN',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: textSecondary,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 2.h),
          _priceSection(isDark),
          SizedBox(height: 2.h),
          _features(isDark),
          SizedBox(height: 2.5.h),
          _claimButton(),
          SizedBox(height: 1.2.h),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(_DialogResult.dismissed),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No thanks',
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  color: textSecondary.withValues(alpha: 0.7),
                  decoration: TextDecoration.underline,
                  decorationColor: textSecondary.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Card sub-widgets ----

  Widget _closeBtn(bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(_DialogResult.dismissed),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.close,
          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
          size: 18,
        ),
      ),
    );
  }

  Widget _timerRing(bool isUrgent, bool isDark) {
    final color = isUrgent ? AppTheme.error : AppTheme.accentBlue;
    final textPrimary = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 3,
              color: color.withValues(alpha: isDark ? 0.12 : 0.15),
            ),
          ),
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: widget.timer.progress,
              strokeWidth: 3,
              color: color,
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            widget.timer.formatted,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: isUrgent ? AppTheme.error : textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _offerBadge(bool isDark) {
    final goldColor = isDark ? const Color(0xFFFFD700) : const Color(0xFFD4A017);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: [
            goldColor.withValues(alpha: isDark ? 0.18 : 0.12),
            const Color(0xFFFFA500).withValues(alpha: isDark ? 0.12 : 0.08),
          ],
        ),
        border: Border.all(
          color: goldColor.withValues(alpha: isDark ? 0.35 : 0.40),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: goldColor, size: 15),
          const SizedBox(width: 6),
          Text(
            'SPECIAL OFFER',
            style: GoogleFonts.inter(
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w700,
              color: goldColor,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigDiscount() {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, child) {
        final t = _shimmer.value;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFFFFD700),
                Color(0xFFFFA500),
                Color(0xFFFF6B3D),
                Color(0xFFFFD700),
              ],
              stops: [
                (t - 0.3).clamp(0.0, 1.0),
                t.clamp(0.0, 1.0),
                (t + 0.3).clamp(0.0, 1.0),
                1.0,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds);
          },
          child: child!,
        );
      },
      child: Text(
        '${widget.discountText} OFF',
        style: GoogleFonts.inter(
          fontSize: 34.sp,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _priceSection(bool isDark) {
    final textSecondary = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.yearlyPriceString,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: textSecondary.withValues(alpha: 0.5),
              decoration: TextDecoration.lineThrough,
              decorationColor: AppTheme.error.withValues(alpha: 0.6),
              decorationThickness: 2,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.arrow_forward_rounded,
              color: AppTheme.accentBlue,
              size: 18,
            ),
          ),
          Flexible(
            child: Text(
              widget.discountPriceString,
              style: GoogleFonts.inter(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTheme.accentBlue : AppTheme.accentBlueDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _features(bool isDark) {
    final textPrimary = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    const labels = [
      'Unlimited music creation',
      'All AI voices & styles',
      'No ads · Priority support',
    ];
    const checkSize = 19.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(labels.length, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: i < labels.length - 1 ? 0.8.h : 0),
              child: SizedBox(
                height: checkSize,
                width: checkSize,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accentBlue.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: AppTheme.accentBlue,
                    size: 13,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(labels.length, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: i < labels.length - 1 ? 0.8.h : 0),
              child: SizedBox(
                height: checkSize,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    labels[i],
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _claimButton() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Transform.scale(
          scale: _purchasing ? 1.0 : _pulseScale.value,
          child: Container(
            width: double.infinity,
            height: 6.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: _purchasing
                    ? [AppTheme.accentBlue.withValues(alpha: 0.5), AppTheme.accentBlueLight.withValues(alpha: 0.5)]
                    : [AppTheme.accentBlue, AppTheme.accentBlueLight],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: _purchasing ? null : AppTheme.blueGlow(opacity: 0.25),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _purchasing ? null : _handleClaim,
                child: Center(
                  child: _purchasing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'CLAIM ${widget.discountText} OFF',
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Banner
// ---------------------------------------------------------------------------

void _showDiscountBanner(
  BuildContext context,
  _OfferTimer timer,
  String discountText,
  StoreProduct? discountProduct,
) {
  _activeBannerEntry?.remove();
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;

  void removeEntry() {
    entry.remove();
    _activeBannerEntry = null;
    timer.dispose();
  }

  entry = OverlayEntry(
    builder: (_) => _DiscountBanner(
      timer: timer,
      discountText: discountText,
      discountProduct: discountProduct,
      onPurchased: removeEntry,
      onExpired: removeEntry,
      onDismiss: removeEntry,
    ),
  );

  _activeBannerEntry = entry;
  overlay.insert(entry);
}

class _DiscountBanner extends StatefulWidget {
  final _OfferTimer timer;
  final String discountText;
  final StoreProduct? discountProduct;
  final VoidCallback onPurchased;
  final VoidCallback onExpired;
  final VoidCallback onDismiss;

  const _DiscountBanner({
    required this.timer,
    required this.discountText,
    required this.discountProduct,
    required this.onPurchased,
    required this.onExpired,
    required this.onDismiss,
  });

  @override
  State<_DiscountBanner> createState() => _DiscountBannerState();
}

class _DiscountBannerState extends State<_DiscountBanner>
    with TickerProviderStateMixin {
  late final AnimationController _anim;
  late final AnimationController _shimmer;
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    widget.timer.addListener(_tick);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (widget.timer.remainingSeconds <= 0 && !_purchasing) {
      _anim.reverse().then((_) {
        if (mounted) widget.onExpired();
      });
    }
  }

  Future<void> _handleTap() async {
    final product = widget.discountProduct;
    if (product == null || _purchasing) return;

    setState(() => _purchasing = true);
    try {
      if (!await RevenueCatService.linkPurchasesToAuth()) return;

      await MarketingPurchaseHelper.trackCheckoutFromProduct(product);
      final result = await Purchases.purchase(
        PurchaseParams.storeProduct(product),
      );

      if (!mounted) return;

      await MarketingPurchaseHelper.trackPurchaseFromProduct(
        transaction: result.storeTransaction,
        product: product,
        isSubscription: true,
      );
      await RevenueCatService.saveSubscriptionAfterPurchase(
        result.customerInfo,
        result.storeTransaction,
      );

      final userId = AuthService.instance.currentUserId;
      if (userId != null && mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.refreshUser(syncProStatus: true);
      }

      if (mounted) {
        showTopToastSuccess(
          context,
          'Purchase successful! Pro features unlocked.',
          useOverlay: true,
        );
        widget.onPurchased();
      }
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return;
      if (mounted) showTopToastError(context, 'Purchase failed: ${e.message ?? code}');
    } catch (e) {
      if (mounted) showTopToastError(context, 'Purchase failed: $e');
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  void _handleDismiss() {
    _anim.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    widget.timer.removeListener(_tick);
    _anim.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final isUrgent = widget.timer.remainingSeconds < 60;

    return Positioned(
      bottom: bottom + 10.h,
      right: 16,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.2, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
          ),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _handleTap,
              child: _ShimmerWrap(
                animation: _shimmer,
                borderRadius: 16,
                child: _bannerBody(isUrgent),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const double _bannerSize = 80;

  Widget _bannerBody(bool isUrgent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timerColor = isUrgent ? AppTheme.error : AppTheme.accentBlue;
    final discountTextColor = isDark ? Colors.white : AppTheme.textPrimaryLight;
    final closeColor = isDark
        ? AppTheme.textSecondaryDark.withValues(alpha: 0.5)
        : AppTheme.textSecondaryLight.withValues(alpha: 0.5);

    return SizedBox(
      width: _bannerSize,
      height: _bannerSize,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF221A14), Color(0xFF14100C)]
                : const [Color(0xFFFDF9F2), Color(0xFFFFFFFF)],
          ),
          border: isDark
              ? null
              : Border.all(color: AppTheme.accentSecondary.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppTheme.accentSecondary.withValues(alpha: isDark ? 0.10 : 0.06),
              blurRadius: 24,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 5,
              right: 5,
              child: GestureDetector(
                onTap: _handleDismiss,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.close, color: closeColor, size: 14),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: isDark ? const Color(0xFFFFD700) : const Color(0xFFD4A017),
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.discountText,
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w900,
                      color: discountTextColor,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.timer.formatted,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                      color: timerColor,
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
}

// ---------------------------------------------------------------------------
// Simple shimmer overlay – a translucent light band sweeps left-to-right
// ---------------------------------------------------------------------------

class _ShimmerWrap extends StatelessWidget {
  final Animation<double> animation;
  final double borderRadius;
  final Widget child;

  const _ShimmerWrap({
    required this.animation,
    required this.borderRadius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, staticChild) {
        final t = animation.value;
        final offset = t * 3 - 1;
        return Stack(
          children: [
            staticChild!,
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: CustomPaint(
                    painter: _ShimmerPainter(offset: offset),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double offset;
  _ShimmerPainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width * offset;
    final bandWidth = size.width * 0.4;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0x00FFFFFF),
          Color(0x1AFFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: Offset(center, center * size.height / size.width),
          width: bandWidth,
          height: bandWidth,
        ),
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.offset != offset;
}
