import 'package:flutter/material.dart';

import '../custom_paywall_scaffold.dart';
import '../paywall_router.dart';

/// Paywall 1 — original bento hero layout (theme follows [AppTheme.kColorPreset]).
class Paywall1Scaffold extends StatelessWidget {
  const Paywall1Scaffold({super.key, required this.args});

  final PaywallScaffoldArgs args;

  @override
  Widget build(BuildContext context) {
    return CustomPaywallScaffold(
      offering: args.offering,
      onDismiss: args.onDismiss,
      onProUnlocked: args.onProUnlocked,
      onPurchaseCompleted: args.onPurchaseCompleted,
    );
  }
}
