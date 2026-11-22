/// Subscription / order history item.
class SubscriptionModel {
  final String id;
  final String userId;
  final String paymentProvider;
  final String planId;
  final String status;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final String? email;
  final String? paymentMethod;
  final String? revenueCatTransactionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SubscriptionModel({
    required this.id,
    required this.userId,
    required this.paymentProvider,
    required this.planId,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
    this.email,
    this.paymentMethod,
    this.revenueCatTransactionId,
    required this.createdAt,
    required this.updatedAt,
  });

  static const _activeStatuses = {'active', 'trialing', 'past_due'};

  bool get isEffectivelyActive {
    if (!_activeStatuses.contains(status)) return false;
    return currentPeriodEnd.toUtc().isAfter(DateTime.now().toUtc());
  }

  bool get isActive => isEffectivelyActive;

  String? get expirationDate => currentPeriodEnd.toUtc().toIso8601String();

  String? get periodType {
    final p = planId.toLowerCase();
    if (p.contains('weekly')) return 'weekly';
    if (p.contains('monthly')) return 'monthly';
    if (p.contains('yearly')) return 'yearly';
    return null;
  }

  String get transactionId => revenueCatTransactionId ?? id;

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    DateTime parseTs(dynamic v) {
      if (v == null) {
        return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      }
      if (v is DateTime) return v.toUtc();
      return DateTime.parse(v.toString()).toUtc();
    }

    final createdRaw = json['createdAt'] ?? json['created_at'];
    final updatedRaw = json['updatedAt'] ?? json['updated_at'];

    return SubscriptionModel(
      id: json['id'] as String,
      userId: (json['userId'] ?? json['user_id']) as String,
      paymentProvider:
          (json['paymentProvider'] ?? json['payment_provider'] ?? 'revenuecat')
              as String,
      planId: (json['planId'] ?? json['plan_id'] ?? '') as String,
      status: (json['status'] ?? '') as String,
      currentPeriodStart: parseTs(
          json['currentPeriodStart'] ?? json['current_period_start']),
      currentPeriodEnd:
          parseTs(json['currentPeriodEnd'] ?? json['current_period_end']),
      cancelAtPeriodEnd: (json['cancelAtPeriodEnd'] ??
              json['cancel_at_period_end'] ??
              false) as bool,
      email: json['email'] as String?,
      paymentMethod:
          (json['paymentMethod'] ?? json['payment_method']) as String?,
      revenueCatTransactionId:
          (json['revenueCatTransactionId'] ??
                  json['revenue_cat_transaction_id'])
              as String?,
      createdAt: createdRaw != null
          ? parseTs(createdRaw)
          : DateTime.now().toUtc(),
      updatedAt: updatedRaw != null
          ? parseTs(updatedRaw)
          : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toRowJson() {
    final m = <String, dynamic>{
      'userId': userId,
      'paymentProvider': paymentProvider,
      'planId': planId,
      'status': status,
      'currentPeriodStart': currentPeriodStart.toUtc().toIso8601String(),
      'currentPeriodEnd': currentPeriodEnd.toUtc().toIso8601String(),
      'cancelAtPeriodEnd': cancelAtPeriodEnd,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    if (email != null) m['email'] = email;
    if (paymentMethod != null) m['paymentMethod'] = paymentMethod;
    if (revenueCatTransactionId != null) {
      m['revenueCatTransactionId'] = revenueCatTransactionId;
    }
    return m;
  }
}
