import 'package:flutter/services.dart';

/// Guarded bridge to the native `hero_drama/media_controls` channel
/// (brightness / volume / PiP).
///
/// The native side may not exist on a given platform/build — every call
/// catches [MissingPluginException] / [PlatformException] and reports
/// failure so the player can fall back gracefully.
class PlayerPlatformService {
  PlayerPlatformService._();
  static final PlayerPlatformService instance = PlayerPlatformService._();

  static const MethodChannel _channel =
      MethodChannel('hero_drama/media_controls');

  void Function(bool inPip)? _pipListener;
  bool _handlerRegistered = false;

  /// Registers the listener for native `pipModeChanged` events
  /// (Android MainActivity reports PiP transitions on this channel).
  /// Pass null to unregister. Registration happens once; the latest
  /// listener wins, which matches the single-player-at-a-time reality.
  void setPipModeListener(void Function(bool inPip)? listener) {
    _pipListener = listener;
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pipModeChanged') {
        final args = call.arguments;
        _pipListener?.call(args is Map && args['inPip'] == true);
      }
      return null;
    });
  }

  Future<double?> getBrightness() async {
    try {
      final v = await _channel.invokeMethod<num>('getBrightness');
      return v?.toDouble();
    } catch (_) {
      return null;
    }
  }

  Future<bool> setBrightness(double value) async {
    try {
      await _channel.invokeMethod<void>(
          'setBrightness', {'value': value.clamp(0.0, 1.0)});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<double?> getVolume() async {
    try {
      final v = await _channel.invokeMethod<num>('getVolume');
      return v?.toDouble();
    } catch (_) {
      return null;
    }
  }

  Future<bool> setVolume(double value) async {
    try {
      await _channel
          .invokeMethod<void>('setVolume', {'value': value.clamp(0.0, 1.0)});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns true when PiP was entered.
  Future<bool> enterPip() async {
    try {
      final v = await _channel.invokeMethod<bool>('enterPip');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Reports the current playback state to the native side (round 5,
  /// item 6): Android's MainActivity uses it in `onUserLeaveHint` to
  /// decide whether leaving the app should drop the video into
  /// Picture-in-Picture, and with which aspect ratio. Fire-and-forget;
  /// failures are meaningless on platforms without the native handler.
  Future<void> setPlaybackState({
    required bool playing,
    required double aspectRatio,
  }) async {
    try {
      await _channel.invokeMethod<void>('setPlaybackState', {
        'playing': playing,
        'aspectRatio': aspectRatio,
      });
    } catch (_) {}
  }
}
