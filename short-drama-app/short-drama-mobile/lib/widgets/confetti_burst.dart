import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/app_config_service.dart';
import '../theme/app_theme.dart';

/// Pure-Flutter confetti burst (no assets, no packages): ~40 particles fly
/// out from the centre of the widget, arc under gravity and fade out.
///
/// Usage: place it in a `Stack` (it expands to fill its parent and ignores
/// pointers), keep a `GlobalKey<ConfettiBurstState>`, and call
/// `key.currentState?.play()` to fire one burst. Honours
/// `AppConfigService.confettiEnabled` — [ConfettiBurstState.play] is a no-op
/// when confetti is disabled remotely.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.colors, this.particleCount = 40});

  /// Particle palette; defaults to the active theme preset + coin gold.
  final List<Color>? colors;
  final int particleCount;

  @override
  State<ConfettiBurst> createState() => ConfettiBurstState();
}

class ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 1400);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  );

  final math.Random _random = math.Random();
  List<_Particle> _particles = const [];

  /// Fire one burst. No-op when confetti is disabled in remote config.
  void play() {
    if (!AppConfigService.instance.confettiEnabled) return;
    if (!mounted) return;
    final palette = widget.colors ??
        <Color>[
          AppTheme.accentBlue,
          AppTheme.accentBlueLight,
          AppTheme.accentSecondary,
          const Color(0xFFFFD54F),
          const Color(0xFFFFB300),
          Colors.white,
        ];
    setState(() {
      _particles = List<_Particle>.generate(widget.particleCount, (i) {
        final angle = _random.nextDouble() * math.pi * 2;
        final speed = 0.25 + _random.nextDouble() * 0.55; // fraction of size
        return _Particle(
          angle: angle,
          speed: speed,
          color: palette[i % palette.length],
          size: 5 + _random.nextDouble() * 6,
          rotation: _random.nextDouble() * math.pi * 2,
          spin: (_random.nextDouble() - 0.5) * 10,
          isCircle: _random.nextBool(),
          delay: _random.nextDouble() * 0.08,
        );
      });
    });
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_particles.isEmpty || _controller.isDismissed) {
            return const SizedBox.expand();
          }
          return CustomPaint(
            painter: _ConfettiPainter(
              particles: _particles,
              progress: _controller.value,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
    required this.rotation,
    required this.spin,
    required this.isCircle,
    required this.delay,
  });

  final double angle;
  final double speed; // initial velocity, as a fraction of the burst radius
  final Color color;
  final double size;
  final double rotation;
  final double spin;
  final bool isCircle;
  final double delay; // 0..~0.08 staggered start
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.progress});

  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.5;
    const gravity = 0.9; // in radius units, applied over the full animation
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      // Ease-out travel + accelerating fall.
      final travel = (1 - math.pow(1 - t, 3)) * p.speed * radius * 2;
      final fall = gravity * radius * t * t;
      final dx = math.cos(p.angle) * travel;
      final dy = math.sin(p.angle) * travel + fall;
      final pos = center + Offset(dx, dy);
      final opacity = t < 0.7 ? 1.0 : 1.0 - (t - 0.7) / 0.3;
      paint.color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.rotation + p.spin * t);
      // Squash on one axis to fake a tumbling 3D flip.
      canvas.scale(1, (math.sin(p.rotation + p.spin * t * 1.7)).abs() * 0.7 + 0.3);
      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.62),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.particles != particles;
}
