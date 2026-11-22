import 'package:flutter/material.dart';

import './revenuecat_paywall_view.dart';

/// Pricing route - shows RevenueCat paywall directly
class PricingPage extends StatelessWidget {
  const PricingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RevenueCatPaywallView(
      onDismiss: () => Navigator.pushReplacementNamed(context, '/home'),
      onPurchaseComplete: () => Navigator.pushReplacementNamed(context, '/home'),
    );
  }
}
