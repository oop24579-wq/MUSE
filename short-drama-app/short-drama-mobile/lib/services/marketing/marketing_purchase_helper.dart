import 'package:purchases_flutter/purchases_flutter.dart';

import 'marketing_funnel_events.dart';

/// Helpers for RevenueCat purchase/checkout analytics.
abstract final class MarketingPurchaseHelper {
  static Future<void> trackCheckoutFromPackage(Package pkg) =>
      MarketingFunnelEvents.trackCheckoutStarted(
        packageId: pkg.identifier,
        planId: pkg.storeProduct.identifier,
        planName: pkg.storeProduct.title,
        value: pkg.storeProduct.price,
        currency: pkg.storeProduct.currencyCode,
      );

  static Future<void> trackCheckoutFromProduct(StoreProduct product) =>
      MarketingFunnelEvents.trackCheckoutStarted(
        packageId: product.identifier,
        planId: product.identifier,
        planName: product.title,
        value: product.price,
        currency: product.currencyCode,
      );

  static Future<void> trackPurchaseFromProduct({
    required StoreTransaction transaction,
    required StoreProduct product,
    String? packageId,
    bool isSubscription = true,
  }) =>
      MarketingFunnelEvents.trackPurchase(
        transactionId: transaction.transactionIdentifier,
        value: product.price,
        currency: product.currencyCode,
        planId: product.identifier,
        planName: product.title,
        packageId: packageId ?? product.identifier,
        isSubscription: isSubscription,
      );
}
