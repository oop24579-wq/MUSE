import 'dart:async';

import 'package:flutter/services.dart';

import 'luxury_settings_service.dart';

/// Bridge to the native `herodrama/content_protection` channel
/// (round 5, item 3).
///
/// Android: sets/clears `FLAG_SECURE` on the activity window, which
/// makes screenshots black and screen recordings show a black surface.
///
/// iOS has no FLAG_SECURE equivalent and cannot block screenshots.
/// The native side instead reports `UIScreen.isCaptured` changes and
/// screenshot-taken events; the player reacts by covering the video
/// with a privacy overlay while a capture is in progress and showing a
/// brief notice after a screenshot.
///
/// Every call fails soft (missing channel → protection silently off),
/// so widget tests and unsupported platforms are unaffected.
class ContentProtectionService {
  ContentProtectionService._() {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static final ContentProtectionService instance = ContentProtectionService._();

  static const MethodChannel _channel =
      MethodChannel('herodrama/content_protection');

  final _captureController = StreamController<bool>.broadcast();
  final _screenshotController = StreamController<void>.broadcast();

  /// iOS screen-capture (recording / AirPlay mirroring) state changes.
  Stream<bool> get captureChanges => _captureController.stream;

  /// iOS "user took a screenshot" events (the shot itself cannot be
  /// prevented on iOS — this is a notification only).
  Stream<void> get screenshotEvents => _screenshotController.stream;

  Future<dynamic> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'captureChanged':
        final args = call.arguments;
        final captured =
            args is Map ? args['captured'] == true : false;
        _captureController.add(captured);
        break;
      case 'screenshotTaken':
        _screenshotController.add(null);
        break;
    }
    return null;
  }

  /// Apply or clear the native secure flag. Returns false when the
  /// platform side is unavailable.
  Future<bool> setSecure(bool enabled) async {
    try {
      final v = await _channel.invokeMethod<bool>(
          'setSecure', {'enabled': enabled});
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Current capture state (iOS); false everywhere else / on failure.
  Future<bool> isCaptured() async {
    try {
      final v = await _channel.invokeMethod<bool>('isCaptured');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Startup application of the persisted level: whole-app protection
  /// turns the flag on immediately; the other levels start cleared
  /// (player-only protection is applied by the player itself).
  Future<void> applyAtStartup(ProtectionLevel level) async {
    await setSecure(level == ProtectionLevel.wholeApp);
  }

  /// Whether entering the player should turn protection on.
  static bool protectsPlayer(ProtectionLevel level) =>
      level != ProtectionLevel.off;

  /// Whether leaving the player should turn protection back off
  /// (whole-app protection stays on after the player closes).
  static bool releasesOnPlayerExit(ProtectionLevel level) =>
      level == ProtectionLevel.playerOnly;
}
