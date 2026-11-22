import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drama_now/models/drama/playback_model.dart';
import 'package:drama_now/presentation/drama/widgets/player_tutorial_overlay.dart';
import 'package:drama_now/services/paywall_frequency.dart';
import 'package:drama_now/services/player_tutorial.dart';

void main() {
  group('PaywallFrequency.shouldShow (item 7: launch paywall cap)', () {
    final now = DateTime(2026, 11, 22, 12, 0);

    test('cap disabled -> always show', () {
      expect(
        PaywallFrequency.shouldShow(
          now: now,
          lastShownAt: now.subtract(const Duration(hours: 1)),
          dailyCapEnabled: false,
        ),
        isTrue,
      );
    });

    test('cap on, never shown -> show', () {
      expect(
        PaywallFrequency.shouldShow(
            now: now, lastShownAt: null, dailyCapEnabled: true),
        isTrue,
      );
    });

    test('cap on, shown 23h ago -> suppress', () {
      expect(
        PaywallFrequency.shouldShow(
          now: now,
          lastShownAt: now.subtract(const Duration(hours: 23)),
          dailyCapEnabled: true,
        ),
        isFalse,
      );
    });

    test('cap on, shown 24h ago -> show again', () {
      expect(
        PaywallFrequency.shouldShow(
          now: now,
          lastShownAt: now.subtract(const Duration(hours: 24)),
          dailyCapEnabled: true,
        ),
        isTrue,
      );
    });

    test('stored state: shown just now suppresses the launch paywall', () async {
      SharedPreferences.setMockInitialValues({
        PaywallFrequency.lastShownKey:
            DateTime.now().millisecondsSinceEpoch,
        PaywallFrequency.everShownKey: true,
      });
      // AppConfigService not loaded -> paywallDailyCap defaults ON.
      expect(await PaywallFrequency.shouldShowLaunchPaywall(), isFalse);
      expect(PaywallFrequency.cachedEverShown, isTrue);
    });

    test('stored state: nothing stored -> launch paywall shows', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await PaywallFrequency.shouldShowLaunchPaywall(), isTrue);
    });
  });

  group('qualityMenuVisible (item 9: honest quality selector)', () {
    QualityOption q(String label, String url) =>
        QualityOption(label: label, url: url);

    test('empty list -> hidden', () {
      expect(qualityMenuVisible(const []), isFalse);
    });

    test('single quality -> hidden', () {
      expect(qualityMenuVisible([q('720p', 'https://x/v.mp4')]), isFalse);
    });

    test('four labels, one identical URL (current backend) -> hidden', () {
      const url = 'https://cdn.example/ep1.mp4';
      expect(
        qualityMenuVisible([
          q('1080p', url),
          q('720p', url),
          q('480p', url),
          q('360p', url),
        ]),
        isFalse,
      );
    });

    test('two distinct URLs -> visible', () {
      expect(
        qualityMenuVisible(
            [q('1080p', 'https://x/hi.mp4'), q('360p', 'https://x/lo.mp4')]),
        isTrue,
      );
    });
  });

  group('PlayerTutorial.shouldShow (item 8: gesture coach marks)', () {
    test('first open (never seen) -> show', () {
      expect(
        PlayerTutorial.shouldShow(seen: false, replayRequested: false),
        isTrue,
      );
    });

    test('seen, no replay -> hide', () {
      expect(
        PlayerTutorial.shouldShow(seen: true, replayRequested: false),
        isFalse,
      );
    });

    test('seen, replay requested from Settings -> show', () {
      expect(
        PlayerTutorial.shouldShow(seen: true, replayRequested: true),
        isTrue,
      );
    });

    test('prefs round-trip: requestReplay makes it show once more', () async {
      SharedPreferences.setMockInitialValues({
        PlayerTutorial.seenKey: true,
        PlayerTutorial.replayKey: false,
      });
      expect(await PlayerTutorial.shouldShowOnPlayerOpen(), isFalse);
      await PlayerTutorial.requestReplay();
      expect(await PlayerTutorial.shouldShowOnPlayerOpen(), isTrue);
      await PlayerTutorial.markSeen();
      expect(await PlayerTutorial.shouldShowOnPlayerOpen(), isFalse);
    });
  });

  group('PlayerTutorialOverlay widget', () {
    testWidgets('shows all four gesture hints and dismisses via Got it',
        (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                PlayerTutorialOverlay(onDismiss: () => dismissed = true),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Player gestures'), findsOneWidget);
      expect(find.text('Swipe up or down'), findsOneWidget);
      expect(find.text('Double-tap the sides'), findsOneWidget);
      expect(find.text('Press and hold'), findsOneWidget);
      expect(find.text('Drag the edges'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      expect(dismissed, isTrue);
    });
  });
}
