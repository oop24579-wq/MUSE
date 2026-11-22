import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/legal_url_launcher.dart';
import '../../services/paywall_preload_service.dart';
import '../../services/revenuecat_service.dart';
import '../../services/user_provider.dart';
import '../../services/marketing/marketing_event_names.dart';
import '../../services/marketing/marketing_funnel_events.dart';
import '../../services/auth/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/top_toast.dart';
import 'paywall_router.dart';

/// In-app pricing screen: custom RadioPod paywall UI via RevenueCat.
class RevenueCatPaywallView extends StatefulWidget {
  final VoidCallback? onDismiss;
  final VoidCallback? onPurchaseComplete;
  final String? paywallTrigger;

  const RevenueCatPaywallView({
    super.key,
    this.onDismiss,
    this.onPurchaseComplete,
    this.paywallTrigger,
  });

  @override
  State<RevenueCatPaywallView> createState() => _RevenueCatPaywallViewState();
}

class _RevenueCatPaywallViewState extends State<RevenueCatPaywallView> {
  Offering? _offering;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.paywallTrigger != null) {
      MarketingFunnelEvents.trackViewPaywall(trigger: widget.paywallTrigger!);
    }
    final cached = PaywallPreloadService.instance.cachedOffering;
    if (cached != null) {
      _offering = cached;
      _isLoading = false;
      _refreshOfferingInBackground();
    } else {
      _loadOffering();
    }
  }

  Future<void> _refreshOfferingInBackground() async {
    try {
      final offering = await RevenueCatService.getOfferingWithPaywall(
        forceRefresh: true,
        useCache: false,
      );
      if (mounted && offering != null) {
        setState(() => _offering = offering);
      }
    } catch (_) {}
  }

  Future<void> _loadOffering() async {
    try {
      final offering = await RevenueCatService.getOfferingWithPaywall();
      if (!mounted) return;
      setState(() {
        _offering = offering;
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = '$e';
      });
    }
  }

  Future<void> _persistPurchase(
    CustomerInfo customerInfo,
    StoreTransaction storeTransaction,
  ) async {
    debugPrint('✅ Purchase completed!');
    debugPrint('   Active entitlements: ${customerInfo.entitlements.active.keys.toList()}');
    debugPrint('   Transaction ID: ${storeTransaction.transactionIdentifier}');

    try {
      await RevenueCatService.saveSubscriptionAfterPurchase(
        customerInfo,
        storeTransaction,
      );

      final userId = AuthService.instance.currentUserId;
      if (userId != null) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.refreshUser(syncProStatus: true);
        debugPrint('✅ Pro status synced for user: $userId');
      } else {
        debugPrint('⚠️ No user ID to refresh pro status');
      }

      if (mounted) {
        showTopToastSuccess(context, 'Purchase successful! Pro features unlocked.', useOverlay: true);
        widget.onPurchaseComplete?.call();
        if (widget.onPurchaseComplete == null && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error handling purchase completion: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        showTopToastError(context, 'Purchase completed but error saving data: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Theme(
        data: AppTheme.darkTheme,
        child: Scaffold(
          backgroundColor: AppTheme.paywallShell,
          body: Center(
            child: CircularProgressIndicator(
              color: AppTheme.accentBlue,
            ),
          ),
        ),
      );
    }

    if (_loadError != null || _offering == null) {
      final l10n = AppLocalizations.of(context);
      final message = _loadError ?? l10n?.paywallNoPackages ?? '';
      return Theme(
        data: AppTheme.darkTheme,
        child: Scaffold(
        backgroundColor: AppTheme.paywallShell,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _loadError = null;
                        });
                        _loadOffering();
                      },
                      child: Text(l10n?.paywallRetry ?? 'Retry'),
                    ),
                    TextButton(
                      onPressed: () {
                        if (widget.onDismiss != null) {
                          widget.onDismiss!();
                        } else if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Text(l10n?.paywallClose ?? 'Close'),
                    ),
                    TextButton(
                      onPressed: () => LegalUrlLauncher.openTerms(context),
                      child: Text(l10n?.paywallTerms ?? 'Terms of Use'),
                    ),
                    TextButton(
                      onPressed: () => LegalUrlLauncher.openPrivacy(context),
                      child: Text(l10n?.paywallPrivacy ?? 'Privacy Policy'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    }

    return PaywallRouter(
      offering: _offering!,
      onDismiss: widget.onDismiss,
      onProUnlocked: widget.onPurchaseComplete,
      onPurchaseCompleted: _persistPurchase,
    );
  }
}

/// Presents the custom paywall as a full-screen route (RevenueCat purchases only; no Paywall UI SDK).
/// Returns `true` when the user completed a purchase.
Future<bool> presentRevenueCatPaywall(BuildContext context) async {
  await PaywallPreloadService.instance.preload();

  var purchased = false;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (ctx) => RevenueCatPaywallView(
        paywallTrigger: PaywallTrigger.generationWaiting,
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
  return purchased;
}
