import 'package:shared_preferences/shared_preferences.dart';

/// One-time player gesture tutorial state (CODE_READINESS item 8,
/// Critic-1 suspect S7: the luxury player gestures were undiscoverable).
///
/// The coach-mark overlay shows on the first player open; the Settings row
/// "Player tutorial" sets the replay flag so it shows once more on the next
/// player open.
class PlayerTutorial {
  PlayerTutorial._();

  static const String seenKey = 'player_tutorial_seen';
  static const String replayKey = 'player_tutorial_replay';

  /// Pure decision (unit-testable): show when never seen, or when a replay
  /// was requested from Settings.
  static bool shouldShow({required bool seen, required bool replayRequested}) {
    return !seen || replayRequested;
  }

  static Future<bool> shouldShowOnPlayerOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return shouldShow(
        seen: prefs.getBool(seenKey) ?? false,
        replayRequested: prefs.getBool(replayKey) ?? false,
      );
    } catch (_) {
      return false; // Never block playback on a prefs failure.
    }
  }

  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(seenKey, true);
      await prefs.setBool(replayKey, false);
    } catch (_) {}
  }

  /// Called by the Settings row: the tutorial replays on next player open.
  static Future<void> requestReplay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(replayKey, true);
    } catch (_) {}
  }
}
