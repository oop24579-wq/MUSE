// This file contains usage examples for RevenueCat integration.
// Paste snippets into widgets that already import `flutter/material.dart`,
// `revenuecat_service.dart`, `revenuecat_paywall_view.dart`, and `presentRevenueCatPaywall`.

/// Example: Check Pro (async)
///
/// ```
/// bool hasPro = await RevenueCatService.hasProEntitlement();
/// ```
///
/// Example: Navigate to custom paywall
///
/// ```
/// Navigator.push(
///   context,
///   MaterialPageRoute<void>(
///     builder: (context) => RevenueCatPaywallView(
///       onDismiss: () => Navigator.pop(context),
///       onPurchaseComplete: () => Navigator.pop(context),
///     ),
///   ),
/// );
/// ```
///
/// Example: Push paywall helper
///
/// ```
/// await presentRevenueCatPaywall(context);
/// ```
///
/// Example: Restore purchases
///
/// ```
/// await RevenueCatService.restorePurchases();
/// ```
