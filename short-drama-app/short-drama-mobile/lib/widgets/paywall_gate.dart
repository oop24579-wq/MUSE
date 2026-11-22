import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_provider.dart';
import '../presentation/pricing/revenuecat_paywall_view.dart';

/// Gate widget that shows RevenueCat paywall when user is not pro.
/// Uses UserProvider with RevenueCat cross-check for consistent pro status.
class PaywallGate extends StatefulWidget {
  final Widget child;

  const PaywallGate({super.key, required this.child});

  @override
  State<PaywallGate> createState() => _PaywallGateState();
}

class _PaywallGateState extends State<PaywallGate> {
  bool? _isPro;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkProStatus();
    });
  }

  Future<void> _checkProStatus() async {
    try {
      final userProvider =
          Provider.of<UserProvider>(context, listen: false);
      await userProvider.refreshUser(syncProStatus: true);
      if (mounted) {
        setState(() {
          _isPro = userProvider.isPro;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPro = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    // Non-pro: show RevenueCat paywall. When dismissed, navigates back;
    // gate rebuilds and shows paywall again if user still not pro.
    if (_isPro != true) {
      return RevenueCatPaywallView(
        onDismiss: () => Navigator.pushReplacementNamed(context, '/home'),
        onPurchaseComplete: () => Navigator.pushReplacementNamed(context, '/home'),
      );
    }

    return widget.child;
  }
}
