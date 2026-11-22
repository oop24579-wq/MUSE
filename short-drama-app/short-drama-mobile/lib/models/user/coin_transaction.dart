/// One row of `GET /me/transactions` — a single coin ledger entry.
class CoinTransaction {
  final String id;
  final int amount;
  final String type;
  final String? refId;
  final int balanceAfter;
  final DateTime createdAt;

  const CoinTransaction({
    required this.id,
    required this.amount,
    required this.type,
    this.refId,
    required this.balanceAfter,
    required this.createdAt,
  });

  factory CoinTransaction.fromJson(Map<String, dynamic> json) {
    return CoinTransaction(
      id: json['id'] as String,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      type: (json['type'] as String?) ?? 'unknown',
      refId: json['refId'] as String?,
      balanceAfter: (json['balanceAfter'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now().toUtc(),
    );
  }

  bool get isCredit => amount >= 0;

  /// Human-readable label for the raw backend [type] string,
  /// e.g. `watch_reward` → `Watch reward`, `EPISODE_UNLOCK` → `Episode unlock`.
  String get typeLabel {
    final cleaned = type.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (cleaned.isEmpty) return 'Coins';
    final lower = cleaned.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }
}
