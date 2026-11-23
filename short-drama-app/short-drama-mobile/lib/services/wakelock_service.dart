import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'luxury_settings_service.dart';

/// Platform seam for the wakelock so the gating logic is unit-testable
/// without platform channels.
abstract class WakelockGateway {
  Future<void> enable();
  Future<void> disable();
}

/// Real gateway backed by wakelock_plus. Every call fails soft: a broken
/// wakelock must never disturb playback.
class WakelockPlusGateway implements WakelockGateway {
  const WakelockPlusGateway();

  @override
  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  @override
  Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}

/// Keeps the screen on while a video is actually playing (round 5,
/// item 1), gated by the "Keep screen on while watching" setting.
///
/// Callers (episode player, Shorts feed) report play state via [sync];
/// the service applies the platform call only when the desired state
/// actually changes, so per-tick calls are cheap.
class WakelockService {
  WakelockService({
    WakelockGateway gateway = const WakelockPlusGateway(),
    LuxurySettingsService? settings,
  })  : _gateway = gateway,
        _settings = settings ?? LuxurySettingsService.instance;

  static final WakelockService instance = WakelockService();

  final WakelockGateway _gateway;
  final LuxurySettingsService _settings;

  bool _applied = false;

  /// Whether the wakelock is currently held (last applied state).
  bool get isApplied => _applied;

  /// Pure gating decision: the screen stays on only when the user
  /// setting allows it AND something is playing right now.
  static bool shouldEnable({
    required bool settingOn,
    required bool isPlaying,
  }) =>
      settingOn && isPlaying;

  /// Reconcile the platform wakelock with the latest play state.
  Future<void> sync({required bool isPlaying}) async {
    final want = shouldEnable(
      settingOn: _settings.keepScreenOn,
      isPlaying: isPlaying,
    );
    if (want == _applied) return;
    _applied = want;
    if (want) {
      await _gateway.enable();
    } else {
      await _gateway.disable();
    }
  }

  /// Force-release (dispose paths). Safe to call redundantly.
  Future<void> release() => sync(isPlaying: false);

  @visibleForTesting
  void resetAppliedForTest() => _applied = false;
}
