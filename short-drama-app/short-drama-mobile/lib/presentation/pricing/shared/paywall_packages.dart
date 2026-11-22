import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

enum PaywallSelectedPlan { annual, monthly, weekly }

class PaywallResolvedPackages {
  final Package? annual;
  final Package? monthly;
  final Package? weekly;

  const PaywallResolvedPackages({this.annual, this.monthly, this.weekly});

  factory PaywallResolvedPackages.from(Offering offering) {
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
    return PaywallResolvedPackages(
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

  PaywallSelectedPlan defaultPlan() {
    if (annual != null) return PaywallSelectedPlan.annual;
    if (monthly != null) return PaywallSelectedPlan.monthly;
    return PaywallSelectedPlan.weekly;
  }

  Package? packageFor(PaywallSelectedPlan plan) {
    switch (plan) {
      case PaywallSelectedPlan.annual:
        return annual ?? monthly ?? weekly;
      case PaywallSelectedPlan.monthly:
        return monthly ?? annual ?? weekly;
      case PaywallSelectedPlan.weekly:
        return weekly ?? monthly ?? annual;
    }
  }
}

int? paywallSavingsPercent(Package? annual, Package? weekly) {
  if (annual == null || weekly == null) return null;
  final wp = weekly.storeProduct.price;
  final ap = annual.storeProduct.price;
  if (wp <= 0) return null;
  final yearlyIfWeekly = wp * 52;
  if (yearlyIfWeekly <= ap) return null;
  return (((yearlyIfWeekly - ap) / yearlyIfWeekly) * 100).round();
}

String? paywallAnnualPerWeekPrice(Package annual) {
  final product = annual.storeProduct;
  if (product.price <= 0) return null;
  final weekly = product.price / 52;
  return NumberFormat.simpleCurrency(name: product.currencyCode).format(weekly);
}

String? paywallMonthlyPerWeekPrice(Package monthly) {
  final product = monthly.storeProduct;
  if (product.price <= 0) return null;
  final weekly = product.price / (52 / 12);
  return NumberFormat.simpleCurrency(name: product.currencyCode).format(weekly);
}
