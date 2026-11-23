import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'luxury_settings_service.dart';

/// Storage seam for the PIN material so the lock logic is unit-testable
/// without platform channels. Production uses [SecurePinStore].
abstract class PinStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// flutter_secure_storage-backed [PinStore]. All operations fail soft:
/// a broken keystore reads as "no PIN" and writes report failure via
/// the service's return values.
class SecurePinStore implements PinStore {
  const SecurePinStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}

/// App lock (round 5, item 12): optional PIN (4–6 digits) + biometric
/// gate in front of the app's content.
///
/// The PIN is never stored in plaintext — only a per-PIN random salt
/// and `sha256(salt:pin)` in secure storage. "Forgot PIN" is handled by
/// the gate UI: it signs the user out and calls [resetLock], wiping
/// the PIN and disabling the lock so the user can set it up again
/// after signing back in.
///
/// Lock timing rule: the gate locks at cold start (once armed by the
/// home shell) and again when the app returns from the background
/// after more than [resumeThreshold].
class AppLockService extends ChangeNotifier {
  AppLockService({
    PinStore store = const SecurePinStore(),
    LuxurySettingsService? settings,
    DateTime Function()? clock,
  })  : _store = store,
        _settings = settings ?? LuxurySettingsService.instance,
        _clock = clock ?? DateTime.now;

  static final AppLockService instance = AppLockService();

  static const _kSalt = 'applock_pin_salt';
  static const _kHash = 'applock_pin_hash';

  /// Background time after which a resume re-locks the app.
  static const resumeThreshold = Duration(seconds: 30);

  final PinStore _store;
  final LuxurySettingsService _settings;
  final DateTime Function() _clock;

  bool _armed = false;
  bool _locked = false;
  DateTime? _backgroundedAt;

  /// Whether the home shell has been reached at least once. The gate
  /// stays inert before that so the splash → consent → login chain is
  /// never blocked (the lock sits after splash routing, before content).
  bool get isArmed => _armed;

  /// Whether the lock gate is currently covering the app.
  bool get isLocked => _locked;

  bool get _enabled => _settings.appLockEnabled;

  // --- PIN management -------------------------------------------------------

  static bool isValidPinFormat(String pin) =>
      RegExp(r'^\d{4,6}$').hasMatch(pin);

  /// Salted SHA-256 of [pin]. Exposed for tests.
  static String hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<bool> hasPin() async {
    final hash = await _store.read(_kHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Create (or replace) the PIN. Returns false on bad format or when
  /// the store refuses the write.
  Future<bool> createPin(String pin) async {
    if (!isValidPinFormat(pin)) return false;
    final salt = _newSalt();
    await _store.write(_kSalt, salt);
    await _store.write(_kHash, hashPin(pin, salt));
    // Read back: secure storage can silently fail on some devices, and
    // enabling a lock whose PIN was never persisted would lock the
    // user out permanently.
    return hasPin();
  }

  Future<bool> verifyPin(String pin) async {
    if (!isValidPinFormat(pin)) return false;
    final salt = await _store.read(_kSalt);
    final hash = await _store.read(_kHash);
    if (salt == null || hash == null) return false;
    return hashPin(pin, salt) == hash;
  }

  Future<void> clearPin() async {
    await _store.delete(_kSalt);
    await _store.delete(_kHash);
  }

  /// "Forgot PIN" reset: wipe the PIN and turn the setting off.
  Future<void> resetLock() async {
    await clearPin();
    await _settings.setAppLockEnabled(false);
    _locked = false;
    notifyListeners();
  }

  String _newSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // --- Lock state machine ---------------------------------------------------

  /// Called by the home shell when it first mounts. Arms the gate and
  /// locks immediately when the lock is enabled and a PIN exists.
  Future<void> arm() async {
    _armed = true;
    if (_enabled && await hasPin()) {
      _locked = true;
      notifyListeners();
    }
  }

  /// Mark the gate as successfully passed (PIN or biometric).
  void unlock() {
    if (!_locked) return;
    _locked = false;
    notifyListeners();
  }

  /// Record the moment the app went to background.
  void onBackground() {
    _backgroundedAt = _clock();
  }

  /// On resume: re-lock when the background stay exceeded the
  /// threshold. Returns whether the gate is locked afterwards.
  Future<bool> onResume() async {
    final at = _backgroundedAt;
    _backgroundedAt = null;
    if (shouldRelock(
      backgroundedAt: at,
      now: _clock(),
      enabled: _enabled && _armed,
      hasPin: await hasPin(),
    )) {
      _locked = true;
      notifyListeners();
    }
    return _locked;
  }

  /// Pure relock decision (unit-tested).
  static bool shouldRelock({
    required DateTime? backgroundedAt,
    required DateTime now,
    required bool enabled,
    required bool hasPin,
  }) {
    if (!enabled || !hasPin || backgroundedAt == null) return false;
    return now.difference(backgroundedAt) > resumeThreshold;
  }
}
