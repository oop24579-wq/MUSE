import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drama_now/presentation/drama/widgets/player/auto_next_overlay.dart';
import 'package:drama_now/presentation/drama/widgets/player/lock_overlay.dart';
import 'package:drama_now/services/app_lock_service.dart';
import 'package:drama_now/services/content_protection_service.dart';
import 'package:drama_now/services/double_back_guard.dart';
import 'package:drama_now/services/luxury_settings_service.dart';
import 'package:drama_now/services/poster_palette_service.dart';
import 'package:drama_now/services/wakelock_service.dart';

class FakeWakelockGateway implements WakelockGateway {
  int enables = 0;
  int disables = 0;

  @override
  Future<void> enable() async => enables++;

  @override
  Future<void> disable() async => disables++;
}

class InMemoryPinStore implements PinStore {
  final Map<String, String> map = {};

  @override
  Future<String?> read(String key) async => map[key];

  @override
  Future<void> write(String key, String value) async => map[key] = value;

  @override
  Future<void> delete(String key) async => map.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WakelockService gating (item 1)', () {
    test('shouldEnable is setting AND playing', () {
      expect(
          WakelockService.shouldEnable(settingOn: true, isPlaying: true),
          isTrue);
      expect(
          WakelockService.shouldEnable(settingOn: true, isPlaying: false),
          isFalse);
      expect(
          WakelockService.shouldEnable(settingOn: false, isPlaying: true),
          isFalse);
      expect(
          WakelockService.shouldEnable(settingOn: false, isPlaying: false),
          isFalse);
    });

    test('sync applies platform calls only on transitions', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = LuxurySettingsService.forTest();
      await settings.load();
      final gateway = FakeWakelockGateway();
      final service = WakelockService(gateway: gateway, settings: settings);

      await service.sync(isPlaying: false);
      expect(gateway.enables, 0);
      expect(gateway.disables, 0);

      await service.sync(isPlaying: true);
      expect(gateway.enables, 1);
      expect(service.isApplied, isTrue);

      // Per-tick repeats are no-ops.
      await service.sync(isPlaying: true);
      await service.sync(isPlaying: true);
      expect(gateway.enables, 1);

      await service.sync(isPlaying: false);
      expect(gateway.disables, 1);
      expect(service.isApplied, isFalse);
    });

    test('setting off → wakelock never engages', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = LuxurySettingsService.forTest();
      await settings.load();
      await settings.setKeepScreenOn(false);
      final gateway = FakeWakelockGateway();
      final service = WakelockService(gateway: gateway, settings: settings);

      await service.sync(isPlaying: true);
      expect(gateway.enables, 0);
      expect(service.isApplied, isFalse);
    });
  });

  group('DoubleBackGuard (item 5b)', () {
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);

    test('first press arms, second inside window exits', () {
      final guard = DoubleBackGuard();
      expect(guard.registerPress(t0), isFalse);
      expect(guard.isArmed, isTrue);
      expect(
          guard.registerPress(t0.add(const Duration(seconds: 1))), isTrue);
      expect(guard.isArmed, isFalse);
    });

    test('press after the window re-arms instead of exiting', () {
      final guard = DoubleBackGuard();
      expect(guard.registerPress(t0), isFalse);
      expect(
          guard.registerPress(t0.add(const Duration(seconds: 3))), isFalse);
      expect(
          guard.registerPress(t0.add(const Duration(seconds: 4))), isTrue);
    });

    test('reset forgets an armed press', () {
      final guard = DoubleBackGuard();
      guard.registerPress(t0);
      guard.reset();
      expect(
          guard.registerPress(t0.add(const Duration(seconds: 1))), isFalse);
    });
  });

  group('Next-episode decision (item 8)', () {
    test('locked next → no countdown, no advance', () {
      expect(
        decideNextEpisodeAction(
          hasNext: true,
          nextPlayable: false,
          bingeOn: false,
          bingeFeatureOn: true,
          autoNextFeatureOn: true,
        ),
        NextEpisodeAction.none,
      );
      expect(
        decideNextEpisodeAction(
          hasNext: true,
          nextPlayable: false,
          bingeOn: true,
          bingeFeatureOn: true,
          autoNextFeatureOn: true,
        ),
        NextEpisodeAction.none,
      );
    });

    test('no next → none', () {
      expect(
        decideNextEpisodeAction(
          hasNext: false,
          nextPlayable: true,
          bingeOn: false,
          bingeFeatureOn: true,
          autoNextFeatureOn: true,
        ),
        NextEpisodeAction.none,
      );
    });

    test('binge on → immediate play; otherwise countdown; feature off → play',
        () {
      expect(
        decideNextEpisodeAction(
          hasNext: true,
          nextPlayable: true,
          bingeOn: true,
          bingeFeatureOn: true,
          autoNextFeatureOn: true,
        ),
        NextEpisodeAction.playNow,
      );
      expect(
        decideNextEpisodeAction(
          hasNext: true,
          nextPlayable: true,
          bingeOn: false,
          bingeFeatureOn: true,
          autoNextFeatureOn: true,
        ),
        NextEpisodeAction.countdown,
      );
      expect(
        decideNextEpisodeAction(
          hasNext: true,
          nextPlayable: true,
          bingeOn: false,
          bingeFeatureOn: true,
          autoNextFeatureOn: false,
        ),
        NextEpisodeAction.playNow,
      );
    });
  });

  group('Content protection level helpers (item 3)', () {
    test('player protection matrix', () {
      expect(ContentProtectionService.protectsPlayer(ProtectionLevel.off),
          isFalse);
      expect(
          ContentProtectionService.protectsPlayer(ProtectionLevel.playerOnly),
          isTrue);
      expect(
          ContentProtectionService.protectsPlayer(ProtectionLevel.wholeApp),
          isTrue);
      expect(ContentProtectionService.releasesOnPlayerExit(ProtectionLevel.off),
          isFalse);
      expect(
          ContentProtectionService.releasesOnPlayerExit(
              ProtectionLevel.playerOnly),
          isTrue);
      expect(
          ContentProtectionService.releasesOnPlayerExit(
              ProtectionLevel.wholeApp),
          isFalse);
    });
  });

  group('LuxurySettingsService persistence (items 1/3/12/13)', () {
    test('defaults: screen-on on, haptics on, protection player-only, '
        'app lock off', () async {
      SharedPreferences.setMockInitialValues({});
      final s = LuxurySettingsService.forTest();
      await s.load();
      expect(s.keepScreenOn, isTrue);
      expect(s.hapticsEnabled, isTrue);
      expect(s.protectionLevel, ProtectionLevel.playerOnly);
      expect(s.appLockEnabled, isFalse);
    });

    test('values persist across instances via the store', () async {
      SharedPreferences.setMockInitialValues({});
      final a = LuxurySettingsService.forTest();
      await a.load();
      await a.setKeepScreenOn(false);
      await a.setHapticsEnabled(false);
      await a.setProtectionLevel(ProtectionLevel.wholeApp);
      await a.setAppLockEnabled(true);

      final b = LuxurySettingsService.forTest();
      await b.load();
      expect(b.keepScreenOn, isFalse);
      expect(b.hapticsEnabled, isFalse);
      expect(b.protectionLevel, ProtectionLevel.wholeApp);
      expect(b.appLockEnabled, isTrue);
    });
  });

  group('AppLockService (item 12)', () {
    test('PIN format: 4–6 digits only', () {
      expect(AppLockService.isValidPinFormat('1234'), isTrue);
      expect(AppLockService.isValidPinFormat('123456'), isTrue);
      expect(AppLockService.isValidPinFormat('123'), isFalse);
      expect(AppLockService.isValidPinFormat('1234567'), isFalse);
      expect(AppLockService.isValidPinFormat('12a4'), isFalse);
      expect(AppLockService.isValidPinFormat(''), isFalse);
    });

    test('create + verify round trip; wrong PIN fails', () async {
      final service = AppLockService(store: InMemoryPinStore());
      expect(await service.hasPin(), isFalse);
      expect(await service.createPin('2468'), isTrue);
      expect(await service.hasPin(), isTrue);
      expect(await service.verifyPin('2468'), isTrue);
      expect(await service.verifyPin('0000'), isFalse);
      // The store must never hold the plaintext PIN.
      final store = InMemoryPinStore();
      final service2 = AppLockService(store: store);
      await service2.createPin('1357');
      expect(store.map.values.any((v) => v == '1357'), isFalse);
    });

    test('createPin rejects bad format', () async {
      final service = AppLockService(store: InMemoryPinStore());
      expect(await service.createPin('12'), isFalse);
      expect(await service.hasPin(), isFalse);
    });

    test('hash is salted: same PIN, different salts → different hashes',
        () {
      expect(AppLockService.hashPin('1234', 'aa'),
          isNot(AppLockService.hashPin('1234', 'bb')));
      expect(AppLockService.hashPin('1234', 'aa'),
          AppLockService.hashPin('1234', 'aa'));
    });

    test('shouldRelock: only enabled + PIN + >30s in background', () {
      final bg = DateTime(2026, 1, 1, 12, 0, 0);
      bool call(Duration after, {bool enabled = true, bool hasPin = true}) =>
          AppLockService.shouldRelock(
            backgroundedAt: bg,
            now: bg.add(after),
            enabled: enabled,
            hasPin: hasPin,
          );
      expect(call(const Duration(seconds: 29)), isFalse);
      expect(call(const Duration(seconds: 30)), isFalse);
      expect(call(const Duration(seconds: 31)), isTrue);
      expect(call(const Duration(minutes: 5), enabled: false), isFalse);
      expect(call(const Duration(minutes: 5), hasPin: false), isFalse);
      expect(
        AppLockService.shouldRelock(
          backgroundedAt: null,
          now: bg,
          enabled: true,
          hasPin: true,
        ),
        isFalse,
      );
    });

    test('arm locks; resume after 31s re-locks; 10s does not', () async {
      SharedPreferences.setMockInitialValues({'luxury_app_lock': true});
      final settings = LuxurySettingsService.forTest();
      await settings.load();
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final service = AppLockService(
        store: InMemoryPinStore(),
        settings: settings,
        clock: () => now,
      );
      await service.createPin('1234');

      await service.arm();
      expect(service.isArmed, isTrue);
      expect(service.isLocked, isTrue);

      service.unlock();
      expect(service.isLocked, isFalse);

      service.onBackground();
      now = now.add(const Duration(seconds: 10));
      expect(await service.onResume(), isFalse);
      expect(service.isLocked, isFalse);

      service.onBackground();
      now = now.add(const Duration(seconds: 31));
      expect(await service.onResume(), isTrue);
      expect(service.isLocked, isTrue);
    });
  });

  group('PosterPaletteService (item 10)', () {
    test('extracts once and caches per series', () async {
      var calls = 0;
      final service = PosterPaletteService(extractor: (provider) async {
        calls++;
        return const Color(0xFF336699);
      });
      final a = await service.colorFor(
          seriesId: 's1', posterUrl: 'https://x/p.jpg');
      final b = await service.colorFor(
          seriesId: 's1', posterUrl: 'https://x/p.jpg');
      expect(a, const Color(0xFF336699));
      expect(b, const Color(0xFF336699));
      expect(calls, 1);
    });

    test('failure and empty URL resolve to null (theme fallback)', () async {
      var calls = 0;
      final service = PosterPaletteService(extractor: (provider) async {
        calls++;
        throw StateError('boom');
      });
      expect(
          await service.colorFor(
              seriesId: 's2', posterUrl: 'https://x/p.jpg'),
          isNull);
      // Misses are cached too — no retry storm on rebuilds.
      expect(
          await service.colorFor(
              seriesId: 's2', posterUrl: 'https://x/p.jpg'),
          isNull);
      expect(calls, 1);
      expect(await service.colorFor(seriesId: 's3', posterUrl: null), isNull);
      expect(await service.colorFor(seriesId: 's4', posterUrl: ''), isNull);
      expect(calls, 1);
    });
  });

  group('Countdown + lock overlays (items 7/8)', () {
    testWidgets('AutoNextOverlay shows label/count and fires callbacks',
        (tester) async {
      var next = 0;
      var cancel = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AutoNextOverlay(
              nextLabel: 'EP 2 · The Reckoning',
              progress: 0.6,
              secondsLeft: 3,
              onNext: () => next++,
              onCancel: () => cancel++,
            ),
          ),
        ),
      );
      expect(find.text('Up next'), findsOneWidget);
      expect(find.text('EP 2 · The Reckoning'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.text('Play next'));
      expect(next, 1);
      await tester.tap(find.text('Cancel'));
      expect(cancel, 1);
    });

    testWidgets('LockOverlay: long-press on the lock unlocks; taps do not',
        (tester) async {
      var unlocks = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [LockOverlay(onUnlock: () => unlocks++)],
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.lock_rounded));
      await tester.pump();
      expect(unlocks, 0);
      await tester.longPress(find.byIcon(Icons.lock_rounded));
      await tester.pump();
      expect(unlocks, 1);
    });
  });
}
