import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

String _fmt(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Progress bar with buffered indicator, drag scrubbing + time tooltip and
/// chapter tick marks at 25% / 50% / 75%.
class ChapterProgressBar extends StatefulWidget {
  const ChapterProgressBar({super.key, required this.controller});

  final VideoPlayerController controller;

  @override
  State<ChapterProgressBar> createState() => _ChapterProgressBarState();
}

class _ChapterProgressBarState extends State<ChapterProgressBar> {
  double? _dragFraction;
  bool _wasPlaying = false;

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final duration = value.duration;
    final totalMs = duration.inMilliseconds;
    if (totalMs <= 0) return const SizedBox(height: 28);

    final playedFraction = _dragFraction ??
        (value.position.inMilliseconds / totalMs).clamp(0.0, 1.0);

    double bufferedFraction = 0;
    for (final range in value.buffered) {
      final f = range.end.inMilliseconds / totalMs;
      if (f > bufferedFraction) bufferedFraction = f.clamp(0.0, 1.0);
    }

    final dragPos = Duration(
        milliseconds: (playedFraction * totalMs).round());

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void updateDrag(double dx) {
          setState(
              () => _dragFraction = (dx / width).clamp(0.0, 1.0));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) {
            _wasPlaying = widget.controller.value.isPlaying;
            widget.controller.pause();
            updateDrag(d.localPosition.dx);
          },
          onHorizontalDragUpdate: (d) => updateDrag(d.localPosition.dx),
          onHorizontalDragEnd: (_) async {
            final target = dragPos;
            setState(() => _dragFraction = null);
            await widget.controller.seekTo(target);
            if (_wasPlaying) await widget.controller.play();
          },
          onTapDown: (d) {
            final f = (d.localPosition.dx / width).clamp(0.0, 1.0);
            widget.controller
                .seekTo(Duration(milliseconds: (f * totalMs).round()));
          },
          child: SizedBox(
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Track + buffered + played + chapters + thumb
                Positioned(
                  left: 0,
                  right: 0,
                  top: 12,
                  child: SizedBox(
                    height: 4,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: bufferedFraction,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white30,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: playedFraction.toDouble(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5252),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        for (final f in const [0.25, 0.5, 0.75])
                          Positioned(
                            left: width * f - 1,
                            top: -2,
                            child: Container(
                              width: 2,
                              height: 8,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        Positioned(
                          left: width * playedFraction - 6,
                          top: -4,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5252),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Tooltip while scrubbing
                if (_dragFraction != null)
                  Positioned(
                    left: (width * playedFraction - 44)
                        .clamp(0.0, width - 88),
                    top: -22,
                    child: Container(
                      width: 88,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_fmt(dragPos)} / ${_fmt(duration)}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
