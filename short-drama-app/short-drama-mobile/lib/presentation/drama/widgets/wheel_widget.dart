import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../models/drama/reward_models.dart';
import '../../../services/drama/drama_service.dart';
import '../../../services/haptics_service.dart';
import '../../../widgets/top_toast.dart';

/// Spin-the-wheel card. The wheel is painted with a [CustomPainter] from the
/// server-provided segment values; on Spin the server decides the outcome
/// first, then the wheel animates (~4 s, easeOutCubic) so the pointer lands
/// on the returned segment index.
class WheelWidget extends StatefulWidget {
  const WheelWidget({
    super.key,
    required this.wheel,
    required this.onWin,
    required this.onRefresh,
  });

  final WheelState wheel;

  /// Called with the coins won after the wheel stops (celebration hook).
  final void Function(int coins) onWin;

  /// Reloads the rewards state after a spin.
  final Future<void> Function() onRefresh;

  @override
  State<WheelWidget> createState() => _WheelWidgetState();
}

class _WheelWidgetState extends State<WheelWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  double _rotation = 0; // radians, cumulative
  double _spinFrom = 0;
  double _spinTo = 0;
  bool _spinning = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spinning) return;
    final segments = widget.wheel.segments;
    if (segments.isEmpty) return;
    HapticsService.instance.light();
    setState(() => _spinning = true);

    final result = await DramaService.instance.spinWheel();
    if (!mounted) return;
    if (result == null || !result.success) {
      setState(() => _spinning = false);
      showTopToastInfo(context, 'No spins available right now');
      await widget.onRefresh();
      return;
    }

    // Geometry: segment i is painted starting at the top (-90°) going
    // clockwise, so its centre sits at -90° + (i + 0.5) * seg. The pointer is
    // fixed at the top, so the final rotation must satisfy
    // rotation ≡ -(i + 0.5) * seg (mod 2π). Add 5 full turns plus a small
    // in-segment jitter so consecutive spins don't look identical.
    final seg = math.pi * 2 / segments.length;
    final index = result.segmentIndex.clamp(0, segments.length - 1);
    final jitter = (math.Random().nextDouble() - 0.5) * seg * 0.5;
    final targetMod = (-(index + 0.5) * seg + jitter) % (math.pi * 2);
    final currentMod = _rotation % (math.pi * 2);
    var delta = targetMod - currentMod;
    if (delta < 0) delta += math.pi * 2;

    _spinFrom = _rotation;
    _spinTo = _rotation + math.pi * 2 * 5 + delta;
    HapticsService.instance.medium();
    await _controller.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _rotation = _spinTo;
      _spinning = false;
    });
    widget.onWin(result.coins);
    await widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final wheel = widget.wheel;
    final hasFree = wheel.spinsLeft > 0;
    final buttonLabel = _spinning
        ? 'Spinning…'
        : hasFree
            ? 'Spin (${wheel.spinsLeft} free)'
            : 'Spin (${wheel.extraSpinCost} coins)';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkBlue : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 62.w,
            height: 62.w,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final t = _controller.isAnimating || _spinning
                        ? Curves.easeOutCubic.transform(_controller.value)
                        : 1.0;
                    final rotation = _spinning || _controller.isAnimating
                        ? _spinFrom + (_spinTo - _spinFrom) * t
                        : _rotation;
                    return Transform.rotate(
                      angle: rotation,
                      child: CustomPaint(
                        size: Size.square(62.w),
                        painter: _WheelPainter(
                          segments: wheel.segments,
                          colors: [
                            AppTheme.accentBlue,
                            const Color(0xFFFFB300),
                            AppTheme.accentSecondary,
                            AppTheme.accentBlueDark,
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Pointer at the top.
                const Icon(
                  Icons.arrow_drop_down,
                  color: Color(0xFFFFB300),
                  size: 34,
                ),
                // Hub.
                Center(
                  child: Container(
                    width: 13.w,
                    height: 13.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppTheme.cardDarkBlue : Colors.white,
                      border: Border.all(
                        color: const Color(0xFFFFB300),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.monetization_on,
                      color: const Color(0xFFFFB300),
                      size: 6.5.w,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 1.6.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _spinning ? null : _spin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 1.4.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                buttonLabel,
                style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (wheel.freeSpinsPerDay > 0) ...[
            SizedBox(height: 0.8.h),
            Text(
              '${wheel.freeSpinsPerDay} free spins every day',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.55),
                fontSize: 9.sp,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.segments, required this.colors});

  final List<int> segments;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final seg = math.pi * 2 / segments.length;
    const start = -math.pi / 2; // first segment starts at the top
    final fill = Paint()..style = PaintingStyle.fill;
    final divider = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.55);

    for (var i = 0; i < segments.length; i++) {
      fill.color = colors[i % colors.length];
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          start + i * seg,
          seg,
          false,
        )
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, divider);

      // Coin label, rotated to read outward along the segment bisector.
      final mid = start + (i + 0.5) * seg;
      final labelPos = center +
          Offset(math.cos(mid) * radius * 0.68, math.sin(mid) * radius * 0.68);
      final painter = TextPainter(
        text: TextSpan(
          text: '${segments[i]}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black45, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(labelPos.dx, labelPos.dy);
      canvas.rotate(mid + math.pi / 2);
      painter.paint(
        canvas,
        Offset(-painter.width / 2, -painter.height / 2),
      );
      canvas.restore();
    }

    // Outer rim.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0xFFFFB300);
    canvas.drawCircle(center, radius - 2.5, rim);
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.colors != colors;
}
