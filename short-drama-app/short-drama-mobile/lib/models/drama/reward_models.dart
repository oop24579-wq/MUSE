/// Coin amounts awarded for each day of the 7-day check-in cycle.
/// Mirrors the `claim_daily_checkin()` RPC in schema.sql.
const List<int> kDailyCheckinRewards = [20, 50, 35, 30, 35, 20, 50];

/// A starter / recurring reward task (connect email, rate app, …).
///
/// `progress`, `target` and `eligible` come straight from `GET /rewards`.
/// RewardsService re-derives them from the viewer's own rows and refuses a
/// claim it did not mark eligible, so the client must render the server's
/// numbers rather than counting locally — a tile that offers a claim the
/// server will reject is just a button that always fails.
class RewardTaskModel {
  final String slug;
  final String title;
  final String? description;
  final int coins;
  final String? actionType;
  final int sortOrder;
  final bool completed;
  final int progress;
  final int target;
  final bool eligible;

  const RewardTaskModel({
    required this.slug,
    required this.title,
    this.description,
    this.coins = 0,
    this.actionType,
    this.sortOrder = 0,
    this.completed = false,
    this.progress = 0,
    this.target = 1,
    this.eligible = false,
  });

  /// True for the goal-shaped tasks ("watch 10 episodes") that render with a
  /// progress bar, as opposed to the one-shot ones ("add your email").
  bool get isMilestone => target > 1;

  factory RewardTaskModel.fromJson(
    Map<String, dynamic> json, {
    bool completed = false,
  }) {
    return RewardTaskModel(
      slug: (json['slug'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      description: json['description'] as String?,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      actionType: json['actionType'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      completed: completed,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      // A missing target must not read as "already there" — 1 keeps an
      // undecorated task claimable only once progress arrives.
      target: (json['target'] as num?)?.toInt() ?? 1,
      eligible: (json['eligible'] as bool?) ?? false,
    );
  }

  RewardTaskModel copyWith({bool? completed}) => RewardTaskModel(
        slug: slug,
        title: title,
        description: description,
        coins: coins,
        actionType: actionType,
        sortOrder: sortOrder,
        completed: completed ?? this.completed,
        progress: progress,
        target: target,
        eligible: eligible,
      );
}

/// One day tile in the daily check-in strip.
class CheckinDay {
  final int dayIndex; // 1..7
  final int coins;
  final bool claimed;
  final bool isToday;

  const CheckinDay({
    required this.dayIndex,
    required this.coins,
    this.claimed = false,
    this.isToday = false,
  });
}

/// Aggregated rewards state for the Rewards tab.
class RewardsState {
  final int coinBalance;
  final bool claimedToday;
  final int currentDay; // day index to claim next (1..7)
  final List<CheckinDay> days;
  final List<RewardTaskModel> tasks;

  const RewardsState({
    this.coinBalance = 0,
    this.claimedToday = false,
    this.currentDay = 1,
    this.days = const [],
    this.tasks = const [],
  });
}
