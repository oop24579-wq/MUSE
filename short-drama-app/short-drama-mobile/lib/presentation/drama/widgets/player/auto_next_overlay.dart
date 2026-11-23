import 'package:flutter/material.dart';

/// What the player should do when an episode ends (round 5, item 8).
enum NextEpisodeAction {
  /// Stay on the ended state (no next episode, or it is locked — the
  /// existing locked UX is reached manually, never by auto-advance).
  none,

  /// Advance immediately (binge mode, or the countdown feature is off).
  playNow,

  /// Show the countdown overlay; advance when it elapses.
  countdown,
}

/// Pure end-of-episode decision, extracted for unit tests.
NextEpisodeAction decideNextEpisodeAction({
  required bool hasNext,
  required bool nextPlayable,
  required bool bingeOn,
  required bool bingeFeatureOn,
  required bool autoNextFeatureOn,
}) {
  if (!hasNext || !nextPlayable) return NextEpisodeAction.none;
  if (bingeFeatureOn && bingeOn) return NextEpisodeAction.playNow;
  if (autoNextFeatureOn) return NextEpisodeAction.countdown;
  return NextEpisodeAction.playNow;
}

/// Full-screen "Up next" overlay with an animated countdown ring.
class AutoNextOverlay extends StatelessWidget {
  const AutoNextOverlay({
    super.key,
    required this.nextLabel,
    required this.progress,
    required this.secondsLeft,
    required this.onNext,
    required this.onCancel,
    this.posterUrl,
  });

  /// e.g. "EP 12 · <title>"
  final String nextLabel;

  /// Optional thumbnail of the next episode / series poster (round 5).
  final String? posterUrl;

  /// 0..1 countdown progress remaining.
  final double progress;
  final int secondsLeft;
  final VoidCallback onNext;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCancel,
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Up next',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            if (posterUrl != null && posterUrl!.isNotEmpty) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  posterUrl!,
                  width: 84,
                  height: 112,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              nextLabel,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 84,
              height: 84,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 5,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                  Text('$secondsLeft',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 14),
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text('Play next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
