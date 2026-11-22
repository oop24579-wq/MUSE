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
}
