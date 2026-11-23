import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Content-protection level (round 5, item 3).
enum ProtectionLevel {
  /// No FLAG_SECURE / capture reaction anywhere.
  off,

  /// Secure flag only while the episode player is on screen (default).
  playerOnly,

  /// Secure flag for the whole app, applied at startup.
  wholeApp,
}

/// Local, device-level preferences for the round-5 luxury features.
///
/// These are per-device settings (keep-screen-on, haptics, content
/// protection, app lock) — unlike profile settings such as autoplay or
/// video quality they are NOT synced to the backend profile; they live
/// in [SharedPreferences] only. Values are cached in memory after
/// [load] so synchronous readers (e.g. [HapticsService]) never block.
class LuxurySettingsService extends ChangeNotifier {
  LuxurySettingsService._();

  static final LuxurySettingsService instance = LuxurySettingsService._();

  /// A fresh, unshared instance (same underlying store) for tests.
  @visibleForTesting
  factory LuxurySettingsService.forTest() = LuxurySettingsService._;

  static const _kKeepScreenOn = 'luxury_keep_screen_on';
  static const _kHaptics = 'luxury_haptics';
  static const _kProtectionLevel = 'luxury_protection_level';
  static const _kAppLock = 'luxury_app_lock';

  bool _loaded = false;
  bool get isLoaded => _loaded;

  bool _keepScreenOn = true;
  bool _hapticsEnabled = true;
  ProtectionLevel _protectionLevel = ProtectionLevel.playerOnly;
  bool _appLockEnabled = false;

  /// "Keep screen on while watching" (item 1). Default ON.
  bool get keepScreenOn => _keepScreenOn;

  /// Local haptics toggle (item 13). Default ON; the remote-config kill
  /// switch in AppConfigService still applies on top of this.
  bool get hapticsEnabled => _hapticsEnabled;

  /// Content protection level (item 3). Default: player only.
  ProtectionLevel get protectionLevel => _protectionLevel;

  /// App lock master switch (item 12). Default OFF. The PIN itself lives
  /// in secure storage via AppLockService; this flag only says "on".
  bool get appLockEnabled => _appLockEnabled;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _keepScreenOn = prefs.getBool(_kKeepScreenOn) ?? true;
      _hapticsEnabled = prefs.getBool(_kHaptics) ?? true;
      _protectionLevel =
          _levelFromInt(prefs.getInt(_kProtectionLevel) ?? 1);
      _appLockEnabled = prefs.getBool(_kAppLock) ?? false;
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Defaults stay in effect; a broken store must never break startup.
      _loaded = true;
    }
  }

  static ProtectionLevel _levelFromInt(int v) => switch (v) {
        0 => ProtectionLevel.off,
        2 => ProtectionLevel.wholeApp,
        _ => ProtectionLevel.playerOnly,
      };

  static int _levelToInt(ProtectionLevel level) => switch (level) {
        ProtectionLevel.off => 0,
        ProtectionLevel.playerOnly => 1,
        ProtectionLevel.wholeApp => 2,
      };

  Future<void> setKeepScreenOn(bool value) async {
    _keepScreenOn = value;
    notifyListeners();
    await _persist((p) => p.setBool(_kKeepScreenOn, value));
  }

  Future<void> setHapticsEnabled(bool value) async {
    _hapticsEnabled = value;
    notifyListeners();
    await _persist((p) => p.setBool(_kHaptics, value));
  }

  Future<void> setProtectionLevel(ProtectionLevel level) async {
    _protectionLevel = level;
    notifyListeners();
    await _persist((p) => p.setInt(_kProtectionLevel, _levelToInt(level)));
  }

  Future<void> setAppLockEnabled(bool value) async {
    _appLockEnabled = value;
    notifyListeners();
    await _persist((p) => p.setBool(_kAppLock, value));
  }

  Future<void> _persist(
      Future<bool> Function(SharedPreferences prefs) write) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await write(prefs);
    } catch (_) {/* best-effort */}
  }
}
