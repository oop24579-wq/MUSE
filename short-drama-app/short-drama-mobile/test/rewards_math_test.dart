import 'package:flutter_test/flutter_test.dart';

import 'package:drama_now/models/drama/reward_models.dart';

void main() {
  group('RewardsState.levelProgress', () {
    test('level 1 starts at 0 progress', () {
      const s = RewardsState(level: 1, xp: 0, nextLevelXp: 100);
      expect(s.levelProgress, 0.0);
    });

    test('halfway through level 1', () {
      const s = RewardsState(level: 1, xp: 50, nextLevelXp: 100);
      expect(s.levelProgress, 0.5);
    });

    test('reaching level 2 shows 0, not 25%', () {
      // Level 2 floor = 100*(2-1)^2 = 100; next = 100*2^2 = 400.
      const s = RewardsState(level: 2, xp: 100, nextLevelXp: 400);
      expect(s.levelProgress, 0.0);
    });

    test('mid level 2', () {
      const s = RewardsState(level: 2, xp: 250, nextLevelXp: 400);
      expect(s.levelProgress, 0.5);
    });

    test('clamps above the next threshold', () {
      const s = RewardsState(level: 1, xp: 500, nextLevelXp: 100);
      expect(s.levelProgress, 1.0);
    });
  });

  group('WatchTimeState block math', () {
    test('minutes into current block wraps by block size', () {
      const w = WatchTimeState(minutesToday: 47, blockMinutes: 15);
      expect(w.minutesIntoCurrentBlock, 2);
      expect(w.blockProgress, closeTo(2 / 15, 1e-9));
    });

    test('zero block size is safe', () {
      const w = WatchTimeState(minutesToday: 10, blockMinutes: 0);
      expect(w.minutesIntoCurrentBlock, 0);
      expect(w.blockProgress, 0.0);
    });

    test('exact block boundary starts a fresh block', () {
      const w = WatchTimeState(minutesToday: 30, blockMinutes: 15);
      expect(w.minutesIntoCurrentBlock, 0);
      expect(w.blockProgress, 0.0);
    });
  });

  group('DailyMission.progressFraction', () {
    test('partial progress', () {
      const m = DailyMission(slug: 'watch3', title: 'Watch', progress: 1, target: 4);
      expect(m.progressFraction, 0.25);
    });

    test('over-target clamps to 1', () {
      const m = DailyMission(slug: 'x', title: 'X', progress: 10, target: 3);
      expect(m.progressFraction, 1.0);
    });

    test('zero target is safe', () {
      const m = DailyMission(slug: 'x', title: 'X', progress: 0, target: 0);
      expect(m.progressFraction, 0.0);
    });
  });

  group('RewardTaskModel', () {
    test('isMilestone reflects target > 1', () {
      const oneShot = RewardTaskModel(slug: 'a', title: 'A', target: 1);
      const goal = RewardTaskModel(slug: 'b', title: 'B', target: 10);
      expect(oneShot.isMilestone, isFalse);
      expect(goal.isMilestone, isTrue);
    });

    test('fromJson defaults target to 1 when missing', () {
      final t = RewardTaskModel.fromJson({'slug': 's', 'title': 'T'});
      expect(t.target, 1);
      expect(t.eligible, isFalse);
      expect(t.completed, isFalse);
    });

    test('copyWith flips completed only', () {
      const t = RewardTaskModel(slug: 's', title: 'T', coins: 15);
      final done = t.copyWith(completed: true);
      expect(done.completed, isTrue);
      expect(done.coins, 15);
      expect(done.slug, 's');
    });
  });

  group('kDailyCheckinRewards', () {
    test('has a full 7-day ladder of positive amounts', () {
      expect(kDailyCheckinRewards, hasLength(7));
      expect(kDailyCheckinRewards.every((c) => c > 0), isTrue);
    });
  });

  group('WheelState.fromJson', () {
    test('parses segments and drops non-numeric entries', () {
      final w = WheelState.fromJson({
        'enabled': true,
        'spinsLeft': 2,
        'segments': [10, 20, 'bad', 50.0],
        'extraSpinCost': 25,
      });
      expect(w.enabled, isTrue);
      expect(w.spinsLeft, 2);
      expect(w.segments, [10, 20, 50]);
      expect(w.extraSpinCost, 25);
    });
  });
}
