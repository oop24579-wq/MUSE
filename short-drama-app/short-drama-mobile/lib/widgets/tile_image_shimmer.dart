import 'package:flutter/material.dart';

/// Shimmer placeholder for square tile images (AI cover avatars, genre tiles).
class TileImageShimmer extends StatefulWidget {
  const TileImageShimmer({super.key, this.isDark = true});

  final bool isDark;

  @override
  State<TileImageShimmer> createState() => _TileImageShimmerState();
}

class _TileImageShimmerState extends State<TileImageShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isDark
        ? const Color(0xFF2A2D3A)
        : const Color(0xFFE5E7EB);
    final highlightColor = widget.isDark
        ? const Color(0xFF3A3D4A)
        : const Color(0xFFF3F4F6);

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
            end: Alignment(1.0 + 2.0 * _controller.value, 0),
            colors: [baseColor, highlightColor, baseColor],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}
