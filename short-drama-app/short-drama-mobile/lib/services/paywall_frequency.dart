import 'package:shared_preferences/shared_preferences.dart';

import 'app_config_service.dart';

/// Launch-paywall frequency capping (CODE_READINESS item 7).
///
/// The VIP paywall used to greet non-Pro users on EVERY cold start. With the
/// server flag `paywall_daily_cap` (GET /config, default ON — including when
/// the config request fails) the launch paywall shows at most once per 24h;
/// repeat cold starts within the window go straight to the content.
/// Explicit paywall opens (tapping a VIP episode, the Premium banner, …)
/// are NOT capped — this only governs the cold-start gate.
class PaywallFrequency {
  PaywallFrequency._();

  static const String lastShownKey = 'paywall_last_shown_at';
  static const String everShownKey = 'paywall_ever_shown';
  static const Duration window = Duration(hours: 24);

  static bool _cachedEverShown = false;

  /// Whether any paywall has been shown before (in-memory cache, populated
  /// by [ensureLoaded]). Paywall scaffolds use this to skip the 2-second
  /// close-button reveal delay on repeat shows.
  static bool get cachedEverShown => _cachedEverShown;

  /// Pure gating decision (unit-testable).
  static bool shouldShow({
    required DateTime now,
    required DateTime? lastShownAt,
    required bool dailyCapEnabled,
  }) {
    if (!dailyCapEnabled) return true;
    if (lastShownAt == null) return true;
    return now.difference(lastShownAt) >= window;
  }

  static Future<void> ensureLoaded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedEverShown = prefs.getBool(everShownKey) ?? false;
    } catch (_) {
      // Prefs unavailable: treat as first show (delay applies, cap allows).
    }
  }

  /// Cold-start decision using stored state + the server config flag.
  static Future<bool> shouldShowLaunchPaywall() async {
    await ensureLoaded();
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(lastShownKey);
      final last = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
      return shouldShow(
        now: DateTime.now(),
        lastShownAt: last,
        dailyCapEnabled: AppConfigService.instance.paywallDailyCap,
      );
    } catch (_) {
      return true; // On any storage error, fall back to showing (old behavior).
    }
  }

  static Future<void> markShown() async {
    _cachedEverShown = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          lastShownKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setBool(everShownKey, true);
    } catch (_) {
      // Non-fatal: worst case the paywall shows again next cold start.
    }
  }
}
