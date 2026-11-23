import 'package:flutter/services.dart';

import 'app_config_service.dart';
import 'luxury_settings_service.dart';

/// Thin wrapper over [HapticFeedback] that honours the remote-config kill
/// switch (`AppConfigService.hapticsEnabled`) AND the user's local
/// "Haptic feedback" setting (round 5, item 13). Every method is a no-op
/// when haptics are disabled by either, and platform errors are
/// swallowed — a vibration must never break a claim flow.
///
/// All round-5 haptic call sites (like, favorite, unlock, player screen
/// lock, countdown actions, episode swipe) route through here so the
/// two switches govern every buzz in the app.
class HapticsService {
  HapticsService._();
  static final HapticsService instance = HapticsService._();

  bool get _enabled =>
      AppConfigService.instance.hapticsEnabled &&
      LuxurySettingsService.instance.hapticsEnabled;

  void _run(Future<void> Function() feedback) {
    if (!_enabled) return;
    try {
      feedback();
    } catch (_) {/* best-effort */}
  }

  /// Subtle tick for selections (like / favorite / toggles).
  void selection() => _run(HapticFeedback.selectionClick);

  void light() => _run(HapticFeedback.lightImpact);

  void medium() => _run(HapticFeedback.mediumImpact);

  void heavy() => _run(HapticFeedback.heavyImpact);

  /// Celebratory double-tap used after a successful coin claim.
  void success() {
    if (!_enabled) return;
    _run(HapticFeedback.mediumImpact);
    Future<void>.delayed(const Duration(milliseconds: 90), () {
      _run(HapticFeedback.lightImpact);
    });
  }
}
