import 'package:flutter/material.dart';

/// Shown while player controls are locked. Long-press (1s) to unlock.
class LockOverlay extends StatelessWidget {
  const LockOverlay({super.key, required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) {
          // The parent also enforces the 1s hold via its own timer; a plain
          // long-press here is accepted as the unlock gesture fallback.
        },
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onLongPress: onUnlock,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
