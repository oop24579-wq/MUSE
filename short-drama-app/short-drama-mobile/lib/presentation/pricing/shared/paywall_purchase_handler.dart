import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/marketing/marketing_funnel_events.dart';
import '../../../services/marketing/marketing_purchase_helper.dart';
import '../../../services/revenuecat_service.dart';
import '../../../services/user_provider.dart';
import '../../../widgets/top_toast.dart';

class PaywallPurchaseHandler {
  PaywallPurchaseHandler({
    required this.context,
    required this.onPurchaseCompleted,
    this.onProUnlocked,
  });

  final BuildContext context;
  final Future<void> Function(CustomerInfo customerInfo, StoreTransaction txn)
      onPurchaseCompleted;
  final VoidCallback? onProUnlocked;

  Future<void> subscribe({
    required Package? package,
    required AppLocalizations l10n,
    required ValueNotifier<bool> busy,
  }) async {
    if (package == null) {
      if (context.mounted) showTopToastInfo(context, l10n.paywallNoPackages);
      return;
    }
    busy.value = true;
    try {
      if (!await RevenueCatService.linkPurchasesToAuth()) {
        if (context.mounted) {
          showTopToastError(context, l10n.paywallPurchaseFailed);
        }
        return;
      }
      await MarketingPurchaseHelper.trackCheckoutFromPackage(package);
      final result = await Purchases.purchase(PurchaseParams.package(package));
      if (!context.mounted) return;
      await MarketingPurchaseHelper.trackPurchaseFromProduct(
        transaction: result.storeTransaction,
        product: package.storeProduct,
        packageId: package.identifier,
        isSubscription: true,
      );
      await onPurchaseCompleted(
        result.customerInfo,
        result.storeTransaction,
      );
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return;
      MarketingFunnelEvents.trackError(
        'purchase_failed',
        extra: {'code': code.name},
      );
      showTopToastError(
        context,
        '${l10n.paywallPurchaseFailed}: ${e.message ?? code}',
      );
    } catch (e) {
      if (!context.mounted) return;
      MarketingFunnelEvents.trackError(
        'purchase_failed',
        extra: {'message': e.toString()},
      );
      showTopToastError(context, '${l10n.paywallPurchaseFailed}: $e');
    } finally {
      busy.value = false;
    }
  }

  Future<void> restore({
    required AppLocalizations l10n,
    required ValueNotifier<bool> busy,
  }) async {
    busy.value = true;
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.listenForMigrationComplete();
      final info = await RevenueCatService.restorePurchases();
      if (!context.mounted) return;
      await userProvider.refreshUser(syncProStatus: true);
      final entitled = info.entitlements.active
          .containsKey(RevenueCatService.proEntitlementId);
      if (!context.mounted) return;
      await MarketingFunnelEvents.trackRestorePurchases(success: entitled);
      if (entitled) {
        showTopToastSuccess(context, l10n.paywallRestoreSuccess);
      } else {
        showTopToastInfo(context, l10n.paywallRestoreNone);
      }
      if (entitled) onProUnlocked?.call();
    } catch (e) {
      if (!context.mounted) return;
      showTopToastError(context, '${l10n.paywallRestoreFailed}: $e');
    } finally {
      busy.value = false;
    }
  }
}
