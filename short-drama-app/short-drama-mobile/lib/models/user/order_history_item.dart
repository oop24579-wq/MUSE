import 'subscription_model.dart';

/// Display state of one purchase-history row (SIM-B F2/F3).
enum OrderBadgeState {
  active,
  expired,
  cancelledActiveUntil,
  cancelled,
  coins,
  other,
}

/// One row of GET /user/orders, parsed for the purchase-history screen.
///
/// Wraps the [SubscriptionModel] the screen has always rendered, and adds
/// the fields the raw order carries but the screen used to ignore:
/// `kind`, `productId`, `amountCents`, `currency` and — critically —
/// `periodEnd`.
///
/// SIM-B F2: the period end used to be fabricated as createdAt + 30 days
/// for every order, so annual subscriptions showed "Expired" after a
/// month and weekly ones stayed "Active" three weeks too long. Now the
/// API's `periodEnd` is used verbatim. When the API omits it, [periodEnd]
/// stays null and NO expiry date is displayed (the honest fallback chosen
/// for the screen): the badge follows the payment status alone, and
/// [SubscriptionModel.currentPeriodEnd] is anchored at createdAt — never
/// at a fabricated +30d — so nothing downstream can render the guess as a
/// real date.
class OrderHistoryItem {
  const OrderHistoryItem({
    required this.subscription,
    required this.kind,
    required this.rawStatus,
    required this.productId,
    required this.amountCents,
    required this.currency,
    required this.periodEnd,
    required this.createdAt,
  });

  final SubscriptionModel subscription;

  /// 'vip' | 'coins' (backend `kind`); legacy rows without `kind` are
  /// classified from the package id fields.
  final String kind;

  /// The order status exactly as the API reported it ('paid', 'cancelled',
  /// …), before the SubscriptionModel 'paid' -> 'active' mapping.
  final String rawStatus;

  final String? productId;
  final int amountCents;
  final String currency;

  /// The API-provided period end for VIP orders; null when unknown.
  final DateTime? periodEnd;

  final DateTime createdAt;

  bool get isCoinOrder => kind == 'coins';

  OrderBadgeState badgeState({DateTime? at}) {
    final now = (at ?? DateTime.now()).toUtc();
    if (isCoinOrder) return OrderBadgeState.coins;
    final end = periodEnd;
    if (rawStatus == 'cancelled') {
      if (end != null && end.isAfter(now)) {
        return OrderBadgeState.cancelledActiveUntil;
      }
      if (end != null) return OrderBadgeState.expired;
      return OrderBadgeState.cancelled;
    }
    if (rawStatus == 'paid' ||
        rawStatus == 'delivered' ||
        rawStatus == 'active') {
      if (end != null) {
        return end.isAfter(now)
            ? OrderBadgeState.active
            : OrderBadgeState.expired;
      }
      // Paid, expiry unknown: report the status, invent no date.
      return OrderBadgeState.active;
    }
    if (rawStatus == 'expired') return OrderBadgeState.expired;
    return OrderBadgeState.other;
  }

  String badgeLabel({DateTime? at}) => switch (badgeState(at: at)) {
        OrderBadgeState.active => 'Active',
        OrderBadgeState.expired => 'Expired',
        OrderBadgeState.cancelledActiveUntil => 'Cancelled',
        OrderBadgeState.cancelled => 'Cancelled',
        OrderBadgeState.coins => 'Coins',
        OrderBadgeState.other => rawStatus.isEmpty
            ? 'Unknown'
            : '${rawStatus[0].toUpperCase()}${rawStatus.substring(1)}',
      };

  bool isActiveAt(DateTime at) => badgeState(at: at) == OrderBadgeState.active;

  /// The expiry line, or null when there is nothing honest to show:
  /// coin orders never expire, and a VIP order without an API periodEnd
  /// shows no date rather than a fabricated one. A cancelled order whose
  /// period is still running reads "Cancelled — active until <date>"
  /// (SIM-B F3) instead of "Expired".
  String? expiryText({DateTime? at}) {
    if (isCoinOrder) return null;
    final end = periodEnd;
    if (end == null) return null;
    final d = '${end.day}/${end.month}/${end.year}';
    return switch (badgeState(at: at)) {
      OrderBadgeState.cancelledActiveUntil => 'Cancelled — active until $d',
      OrderBadgeState.expired => 'Expired $d',
      _ => 'Expires $d',
    };
  }

  /// e.g. $49.99 / €4.99 / EGP 99. Null when the order carries no price.
  String? get priceLabel {
    if (amountCents <= 0) return null;
    final major = amountCents / 100;
    final amount = amountCents % 100 == 0
        ? major.toStringAsFixed(0)
        : major.toStringAsFixed(2);
    const symbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'CNY': '¥',
      'KRW': '₩',
      'EGP': 'E£',
    };
    final symbol = symbols[currency.toUpperCase()];
    return symbol != null
        ? '$symbol$amount'
        : '${currency.toUpperCase()} $amount';
  }

  /// Human-readable product name from the product/plan id.
  String get productLabel {
    if (isCoinOrder) {
      final m = RegExp(r'(\d+)\s*$').firstMatch(productId ?? '');
      return m != null ? '${m.group(1)} Coins' : 'Coin pack';
    }
    final p = (productId ?? subscription.planId).toLowerCase();
    if (p.contains('yearly') || p.contains('annual')) return 'VIP Yearly';
    if (p.contains('weekly')) return 'VIP Weekly';
    if (p.contains('monthly')) return 'VIP Monthly';
    if (p.contains('vip') || kind == 'vip') return 'VIP Subscription';
    return productId ?? subscription.planId;
  }
}

/// Parses one raw GET /user/orders entry. Pure and top-level so the
/// mapping is unit-testable without the HTTP layer or the screen.
OrderHistoryItem parseOrderHistoryItem(
  Map<String, dynamic> o, {
  required String userId,
  DateTime? now,
}) {
  final fallbackNow = (now ?? DateTime.now()).toUtc();
  final created =
      DateTime.tryParse(o['createdAt']?.toString() ?? '')?.toUtc() ??
          fallbackNow;
  final rawStatus = (o['paymentStatus'] ?? o['status'] ?? 'pending').toString();
  final productId =
      (o['productId'] ?? o['subscriptionPlanId'] ?? o['coinPackageId'])
          ?.toString();
  final planId = (o['subscriptionPlanId'] ??
          o['type'] ??
          o['coinPackageId'] ??
          productId ??
          'order')
      .toString();
  final kindRaw = (o['kind'] ?? '').toString();
  final isCoins =
      kindRaw == 'coins' || (kindRaw.isEmpty && o['coinPackageId'] != null);
  final periodEnd =
      DateTime.tryParse(o['periodEnd']?.toString() ?? '')?.toUtc();
  final mappedStatus =
      (rawStatus == 'paid' || rawStatus == 'delivered') ? 'active' : rawStatus;

  final subscription = SubscriptionModel(
    id: (o['id'] ?? '').toString(),
    userId: (o['userId'] as String?) ?? userId,
    paymentProvider:
        (o['paymentMethod'] ?? o['paymentProvider'] ?? 'revenuecat').toString(),
    planId: planId,
    status: mappedStatus,
    currentPeriodStart: created,
    // The API periodEnd verbatim; createdAt (NOT +30d) when absent — see
    // the class doc for why no date may be fabricated here.
    currentPeriodEnd: periodEnd ?? created,
    cancelAtPeriodEnd: rawStatus == 'cancelled',
    revenueCatTransactionId: o['revenueCatTransactionId'] as String?,
    createdAt: created,
    updatedAt: created,
  );

  return OrderHistoryItem(
    subscription: subscription,
    kind: isCoins ? 'coins' : (kindRaw.isEmpty ? 'vip' : kindRaw),
    rawStatus: rawStatus,
    productId: productId,
    amountCents: (o['amountCents'] as num?)?.toInt() ?? 0,
    currency: (o['currency'] ?? 'USD').toString(),
    periodEnd: periodEnd,
    createdAt: created,
  );
}
