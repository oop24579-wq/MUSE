import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'paywall_config.dart';
import 'variants/paywall_1_scaffold.dart';
import 'variants/paywall_2_scaffold.dart';
import 'variants/paywall_3_scaffold.dart';
import 'variants/paywall_4_scaffold.dart';
import 'variants/paywall_5_scaffold.dart';
import 'variants/paywall_6_scaffold.dart';
import 'variants/paywall_7_scaffold.dart';

/// Routes to the active paywall layout ([PaywallConfig.kPaywallVariant]).
class PaywallRouter extends StatelessWidget {
  const PaywallRouter({
    super.key,
    required this.offering,
    this.onDismiss,
    this.onProUnlocked,
    required this.onPurchaseCompleted,
  });

  final Offering offering;
  final VoidCallback? onDismiss;
  final VoidCallback? onProUnlocked;
  final Future<void> Function(CustomerInfo customerInfo, StoreTransaction txn)
      onPurchaseCompleted;

  @override
  Widget build(BuildContext context) {
    final args = PaywallScaffoldArgs(
      offering: offering,
      onDismiss: onDismiss,
      onProUnlocked: onProUnlocked,
      onPurchaseCompleted: onPurchaseCompleted,
    );

    return switch (PaywallConfig.active) {
      PaywallVariant.paywall1 => Paywall1Scaffold(args: args),
      PaywallVariant.paywall2 => Paywall2Scaffold(args: args),
      PaywallVariant.paywall3 => Paywall3Scaffold(args: args),
      PaywallVariant.paywall4 => Paywall4Scaffold(args: args),
      PaywallVariant.paywall5 => Paywall5Scaffold(args: args),
      PaywallVariant.paywall6 => Paywall6Scaffold(args: args),
      PaywallVariant.paywall7 => Paywall7Scaffold(args: args),
    };
  }
}

class PaywallScaffoldArgs {
  const PaywallScaffoldArgs({
    required this.offering,
    this.onDismiss,
    this.onProUnlocked,
    required this.onPurchaseCompleted,
  });

  final Offering offering;
  final VoidCallback? onDismiss;
  final VoidCallback? onProUnlocked;
  final Future<void> Function(CustomerInfo customerInfo, StoreTransaction txn)
      onPurchaseCompleted;
}
