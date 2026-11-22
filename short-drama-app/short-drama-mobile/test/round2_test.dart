import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drama_now/models/drama/episode_model.dart';
import 'package:drama_now/models/drama/watch_history_model.dart';
import 'package:drama_now/presentation/drama/widgets/player/lock_overlay.dart';
import 'package:drama_now/services/drama/drama_service.dart';

EpisodeModel _ep(String id, int n, {int season = 1}) => EpisodeModel(
      id: id,
      seriesId: 's1',
      episodeNumber: n,
      seasonNumber: season,
      title: 'EP$n',
    );

void main() {
  group('S2: LockOverlay long-press arena', () {
    testWidgets('long-press on the lock button fires onUnlock', (tester) async {
      var unlocked = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [LockOverlay(onUnlock: () => unlocked = true)],
          ),
        ),
      ));
      final button = find.byIcon(Icons.lock_rounded);
      expect(button, findsOneWidget);
      final gesture = await tester.startGesture(tester.getCenter(button));
      // Hold past the 500ms long-press deadline while the pointer is down:
      // if the outer full-screen detector's (empty) long-press recognizer
      // wins the arena, the inner button's onLongPress is swallowed and
      // onUnlock never fires.
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pump();
      expect(unlocked, isTrue,
          reason: 'inner unlock long-press must win the gesture arena');
    });
  });

  group('S3: resolvePlayerStartIndex', () {
    final eps = [_ep('a', 1), _ep('b', 2), _ep('c', 3)];
    test('resumeEpisodeId wins (exact episode)', () {
      expect(resolvePlayerStartIndex(eps, resumeEpisodeId: 'c'), 2);
    });
    test('falls back to a unique episodeNumber match', () {
      expect(resolvePlayerStartIndex(eps, resumeEpisodeNumber: 2), 1);
    });
    test('ambiguous episodeNumber (multi-season) without id -> 0', () {
      final multi = [
        _ep('a', 1),
        _ep('b', 2),
        _ep('c', 1, season: 2),
        _ep('d', 2, season: 2),
      ];
      expect(resolvePlayerStartIndex(multi, resumeEpisodeNumber: 2), 0);
      expect(resolvePlayerStartIndex(multi, resumeEpisodeId: 'd'), 3);
    });
    test('no resume info / unknown id -> 0', () {
      expect(resolvePlayerStartIndex(eps), 0);
      expect(resolvePlayerStartIndex(eps, resumeEpisodeId: 'nope'), 0);
      expect(resolvePlayerStartIndex(const []), 0);
    });
  });

  group('S5: EpisodeProgress.fromJson', () {
    test('parses the per-episode progress payload', () {
      final p = EpisodeProgress.fromJson(const {
        'episodeId': 'ep9',
        'episodeNumber': 9,
        'positionSeconds': 41,
        'durationSeconds': 97,
        'completed': true,
      });
      expect(p.episodeId, 'ep9');
      expect(p.episodeNumber, 9);
      expect(p.positionSeconds, 41);
      expect(p.completed, isTrue);
    });
    test('defaults on an empty payload', () {
      final p = EpisodeProgress.fromJson(const {});
      expect(p.episodeId, '');
      expect(p.completed, isFalse);
    });
  });
}
