import 'package:flutter/services.dart';

import 'app_config_service.dart';

/// Thin wrapper over [HapticFeedback] that honours the remote-config kill
/// switch (`AppConfigService.hapticsEnabled`). Every method is a no-op when
/// haptics are disabled remotely, and platform errors are swallowed — a
/// vibration must never break a claim flow.
class HapticsService {
  HapticsService._();
  static final HapticsService instance = HapticsService._();

  bool get _enabled => AppConfigService.instance.hapticsEnabled;

  void _run(Future<void> Function() feedback) {
    if (!_enabled) return;
    try {
      feedback();
    } catch (_) {/* best-effort */}
  }

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
