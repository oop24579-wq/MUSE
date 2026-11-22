import 'package:flutter/material.dart';

/// One-time coach-mark overlay teaching the player's luxury gestures
/// (CODE_READINESS item 8 / Critic-1 suspect S7). Shown on the first player
/// open and again when replayed from Settings. Simple stacked hints — no
/// external packages, dismiss via "Got it".
class PlayerTutorialOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const PlayerTutorialOverlay({super.key, required this.onDismiss});

  static const List<(IconData, String, String)> hints = [
    (
      Icons.swipe_vertical_rounded,
      'Swipe up or down',
      'Jump to the next or previous episode',
    ),
    (
      Icons.fast_forward_rounded,
      'Double-tap the sides',
      'Skip 10 seconds forward or back',
    ),
    (
      Icons.speed_rounded,
      'Press and hold',
      'Play at 2x speed while holding',
    ),
    (
      Icons.brightness_6_rounded,
      'Drag the edges',
      'Left edge: brightness - right edge: volume',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.78),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Player gestures',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A few tricks to watch like a pro:',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 28),
                for (final (icon, title, subtitle) in hints) ...[
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onDismiss,
                  child: const Text('Got it'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
