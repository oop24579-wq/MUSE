/// Coin amounts awarded for each day of the 7-day check-in cycle.
/// Mirrors the `claim_daily_checkin()` RPC in schema.sql.
// Fallback ladder for offline/first paint; the server's /rewards payload is
// authoritative. Rebalanced 2026-11-22 with the backend (CODE_READINESS item 4).
const List<int> kDailyCheckinRewards = [10, 20, 15, 15, 20, 10, 30];

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

/// Spin-the-wheel state from `GET /rewards` (`wheel` object).
class WheelState {
  final bool enabled;
  final int spinsLeft;
  final int freeSpinsPerDay;
  final List<int> segments;
  final int extraSpinCost;

  const WheelState({
    this.enabled = false,
    this.spinsLeft = 0,
    this.freeSpinsPerDay = 0,
    this.segments = const [],
    this.extraSpinCost = 0,
  });

  factory WheelState.fromJson(Map<String, dynamic> json) {
    final rawSegments = json['segments'];
    return WheelState(
      enabled: (json['enabled'] as bool?) ?? false,
      spinsLeft: (json['spinsLeft'] as num?)?.toInt() ?? 0,
      freeSpinsPerDay: (json['freeSpinsPerDay'] as num?)?.toInt() ?? 0,
      segments: rawSegments is List
          ? rawSegments
              .whereType<num>()
              .map((e) => e.toInt())
              .toList(growable: false)
          : const [],
      extraSpinCost: (json['extraSpinCost'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Result of `POST /rewards/wheel/spin`.
class WheelSpinResult {
  final bool success;
  final int segmentIndex;
  final int coins;
  final int balance;
  final int spinsLeft;

  const WheelSpinResult({
    required this.success,
    required this.segmentIndex,
    required this.coins,
    required this.balance,
    required this.spinsLeft,
  });

  factory WheelSpinResult.fromJson(Map<String, dynamic> json) {
    return WheelSpinResult(
      success: (json['success'] as bool?) ?? false,
      segmentIndex: (json['segmentIndex'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      spinsLeft: (json['spinsLeft'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One milestone treasure chest from `GET /rewards` (`chests` list).
class ChestState {
  final String id;
  final int threshold; // episodes to watch before it unlocks
  final int coins;
  final bool claimed;
  final bool unlocked;

  const ChestState({
    required this.id,
    this.threshold = 0,
    this.coins = 0,
    this.claimed = false,
    this.unlocked = false,
  });

  factory ChestState.fromJson(Map<String, dynamic> json) {
    return ChestState(
      id: (json['id'] ?? '') as String,
      threshold: (json['threshold'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      claimed: (json['claimed'] as bool?) ?? false,
      unlocked: (json['unlocked'] as bool?) ?? false,
    );
  }
}

/// Watch-time rewards from `GET /rewards` (`watchTime` object).
class WatchTimeState {
  final bool enabled;
  final int minutesToday;
  final int coinsPerBlock;
  final int blockMinutes;
  final int claimableCoins;
  final int claimedCoinsToday;
  final int dailyCapCoins;

  const WatchTimeState({
    this.enabled = false,
    this.minutesToday = 0,
    this.coinsPerBlock = 0,
    this.blockMinutes = 0,
    this.claimableCoins = 0,
    this.claimedCoinsToday = 0,
    this.dailyCapCoins = 0,
  });

  /// Minutes already counted toward the next (not yet claimable) block.
  int get minutesIntoCurrentBlock =>
      blockMinutes > 0 ? minutesToday % blockMinutes : 0;

  /// 0..1 progress toward completing the next block.
  double get blockProgress => blockMinutes > 0
      ? (minutesIntoCurrentBlock / blockMinutes).clamp(0.0, 1.0)
      : 0.0;

  factory WatchTimeState.fromJson(Map<String, dynamic> json) {
    return WatchTimeState(
      enabled: (json['enabled'] as bool?) ?? false,
      minutesToday: (json['minutesToday'] as num?)?.toInt() ?? 0,
      coinsPerBlock: (json['coinsPerBlock'] as num?)?.toInt() ?? 0,
      blockMinutes: (json['blockMinutes'] as num?)?.toInt() ?? 0,
      claimableCoins: (json['claimableCoins'] as num?)?.toInt() ?? 0,
      claimedCoinsToday: (json['claimedCoinsToday'] as num?)?.toInt() ?? 0,
      dailyCapCoins: (json['dailyCapCoins'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A daily mission from `GET /rewards` (`missions` list).
class DailyMission {
  final String slug;
  final String title;
  final String? description;
  final int coins;
  final int progress;
  final int target;
  final bool completed;
  final bool claimed;

  const DailyMission({
    required this.slug,
    required this.title,
    this.description,
    this.coins = 0,
    this.progress = 0,
    this.target = 1,
    this.completed = false,
    this.claimed = false,
  });

  double get progressFraction =>
      target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;

  factory DailyMission.fromJson(Map<String, dynamic> json) {
    return DailyMission(
      slug: (json['slug'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      description: json['description'] as String?,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      target: (json['target'] as num?)?.toInt() ?? 1,
      completed: (json['completed'] as bool?) ?? false,
      claimed: (json['claimed'] as bool?) ?? false,
    );
  }
}

/// A running rewards multiplier event from `GET /rewards` (`activeEvent`).
class ActiveEventState {
  final String name;
  final double multiplier;
  final DateTime? endsAt;

  const ActiveEventState({
    required this.name,
    this.multiplier = 1,
    this.endsAt,
  });

  factory ActiveEventState.fromJson(Map<String, dynamic> json) {
    return ActiveEventState(
      name: (json['name'] ?? '') as String,
      multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1,
      endsAt: json['endsAt'] != null
          ? DateTime.tryParse(json['endsAt'].toString())
          : null,
    );
  }
}

/// Aggregated rewards state for the Rewards tab.
class RewardsState {
  final int coinBalance;
  final bool claimedToday;
  final int currentDay; // day index to claim next (1..7)
  final List<CheckinDay> days;
  final List<RewardTaskModel> tasks;

  // Phase 2 additions (all defaulted so existing construction sites and the
  // Phase-1 payload shape keep working unchanged).
  final WheelState wheel;
  final List<ChestState> chests;
  final WatchTimeState watchTime;
  final List<DailyMission> missions;
  final int currentStreak;
  final int xp;
  final int level;
  final int nextLevelXp;
  final ActiveEventState? activeEvent;
  final String referralCode;

  const RewardsState({
    this.coinBalance = 0,
    this.claimedToday = false,
    this.currentDay = 1,
    this.days = const [],
    this.tasks = const [],
    this.wheel = const WheelState(),
    this.chests = const [],
    this.watchTime = const WatchTimeState(),
    this.missions = const [],
    this.currentStreak = 0,
    this.xp = 0,
    this.level = 1,
    this.nextLevelXp = 100,
    this.activeEvent,
    this.referralCode = '',
  });

  /// 0..1 progress WITHIN the current level (for the level ring).
  /// Backend level thresholds: level L starts at 100*(L-1)^2 XP and
  /// nextLevelXp = 100*L^2, so progress is measured from the level floor —
  /// previously xp/nextLevelXp showed 25% the moment level 2 was reached.
  double get levelProgress {
    final floor = 100 * (level - 1) * (level - 1);
    final span = nextLevelXp - floor;
    return span > 0 ? ((xp - floor) / span).clamp(0.0, 1.0) : 0.0;
  }
}
