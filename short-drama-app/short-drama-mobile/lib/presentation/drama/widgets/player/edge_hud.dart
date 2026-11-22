import 'package:flutter/material.dart';

enum EdgeHudKind { brightness, volume }

/// Vertical HUD shown while edge-dragging brightness / volume.
class EdgeHud extends StatelessWidget {
  const EdgeHud({super.key, required this.kind, required this.value});

  final EdgeHudKind kind;
  final double value; // 0..1

  @override
  Widget build(BuildContext context) {
    final pct = (value.clamp(0.0, 1.0) * 100).round();
    final icon = kind == EdgeHudKind.brightness
        ? Icons.brightness_6_rounded
        : Icons.volume_up_rounded;
    final isLeft = kind == EdgeHudKind.volume;
    return Positioned(
      top: 0,
      bottom: 0,
      left: isLeft ? 18 : null,
      right: isLeft ? null : 18,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 8),
              Container(
                width: 6,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('$pct%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
