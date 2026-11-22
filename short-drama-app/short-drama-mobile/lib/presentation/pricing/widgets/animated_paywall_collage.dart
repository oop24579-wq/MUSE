import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/media_url.dart';
import '../../../theme/app_theme.dart';

/// Animated poster collage used as the paywall background.
///
/// Renders tilted columns of drama posters that slide vertically in a
/// seamless, continuous loop — neighbouring columns drift in opposite
/// directions for an elegant parallax feel. The whole grid is rotated a few
/// degrees so the photos sit at a dynamic angle.
class AnimatedPaywallCollage extends StatefulWidget {
  const AnimatedPaywallCollage({super.key, this.imageUrls});

  /// Optional poster URLs (e.g. the user's real catalog). Falls back to a
  /// curated drama set when null/empty.
  final List<String>? imageUrls;

  static const String _coverBase = '$kMediaCdnBaseUrl/series-covers';

  static const List<String> _defaultPosters = [
    '$_coverBase/the-billionaires-runaway-bride.jpg',
    '$_coverBase/married-to-my-enemy.jpg',
    '$_coverBase/my-alpha-my-mate.jpg',
    '$_coverBase/reborn-to-take-revenge.jpg',
    '$_coverBase/the-cinderella-contract.jpg',
    '$_coverBase/her-secret-billionaire.jpg',
    '$_coverBase/sold-to-the-mafia-boss.jpg',
    '$_coverBase/the-vampire-heiress.jpg',
    '$_coverBase/the-cursed-luna.jpg',
    '$_coverBase/the-billionaires-nanny.jpg',
    '$_coverBase/divorced-then-adored.jpg',
    '$_coverBase/the-mafia-kings-obsession.jpg',
    '$_coverBase/reborn-as-the-villainess.jpg',
    '$_coverBase/the-heartless-ceos-love.jpg',
    '$_coverBase/the-werewolf-princess.jpg',
    '$_coverBase/crowned-by-the-emperor.jpg',
    '$_coverBase/secretly-the-heiress.jpg',
    '$_coverBase/trapped-with-the-ceo.jpg',
  ];

  /// Warms the image cache (memory + disk) so posters are ready the instant the
  /// paywall opens. Context-free, so it can run from a preload service/splash.
  static void precacheImages([List<String>? urls]) {
    for (final url in urls ?? _defaultPosters) {
      final rewritten = rewriteMediaUrl(url) ?? url;
      final stream =
          CachedNetworkImageProvider(rewritten).resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (_, __) => stream.removeListener(listener),
        onError: (_, __) => stream.removeListener(listener),
      );
      stream.addListener(listener);
    }
  }

  @override
  State<AnimatedPaywallCollage> createState() => _AnimatedPaywallCollageState();
}

class _AnimatedPaywallCollageState extends State<AnimatedPaywallCollage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const double _tilt = -0.14; // radians (~8°)
  static const double _columnGap = 12;

  @override
  void initState() {
    super.initState();
    // Safety net: warm the cache immediately in case the preload never ran.
    AnimatedPaywallCollage.precacheImages(widget.imageUrls);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 52),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = ((widget.imageUrls == null || widget.imageUrls!.isEmpty)
            ? AnimatedPaywallCollage._defaultPosters
            : widget.imageUrls!)
        .map((u) => rewriteMediaUrl(u) ?? u)
        .toList();

    // Split posters across three columns, offsetting the start so adjacent
    // columns never show the same poster side-by-side.
    final columns = List.generate(3, (c) {
      return [for (var i = 0; i < source.length; i++) source[(i * 3 + c) % source.length]];
    });

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: AppTheme.paywallShell),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                // Oversize so the rotated grid always covers the viewport.
                final spanW = w * 1.55;
                final spanH = h * 1.8;
                final colWidth = spanW / 3;
                final tileWidth = colWidth - _columnGap;
                final tileHeight = tileWidth * 1.42;

                return Transform.rotate(
                  angle: _tilt,
                  child: OverflowBox(
                    minWidth: 0,
                    maxWidth: double.infinity,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: SizedBox(
                      width: spanW,
                      height: spanH,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 3; i++)
                            SizedBox(
                              width: colWidth,
                              child: RepaintBoundary(
                                child: _LoopingColumn(
                                  controller: _controller,
                                  urls: columns[i],
                                  tileWidth: tileWidth,
                                  tileHeight: tileHeight,
                                  fillHeight: spanH,
                                  reverse: i.isOdd,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen paywall background: the animated collage under a smooth
/// bottom→top scrim. The scrim is solid [shell] behind the content and fades to
/// transparent at the top so the posters show through — no hard cut. Drop it in
/// as the bottom layer of a `StackFit.expand` body Stack (wrapped in
/// `Positioned.fill`, or as the first child).
class PaywallCollageBackground extends StatelessWidget {
  const PaywallCollageBackground({
    super.key,
    required this.shell,
    this.imageUrls,
  });

  final Color shell;
  final List<String>? imageUrls;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: AnimatedPaywallCollage(imageUrls: imageUrls)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                shell.withValues(alpha: 0.20),
                shell.withValues(alpha: 0.86),
                shell,
              ],
              stops: const [0.0, 0.32, 0.62, 0.9],
            ),
          ),
        ),
      ],
    );
  }
}

/// A single vertically-looping column of poster tiles. Advances exactly one
/// full set per animation cycle, so the loop is perfectly seamless.
class _LoopingColumn extends StatelessWidget {
  const _LoopingColumn({
    required this.controller,
    required this.urls,
    required this.tileWidth,
    required this.tileHeight,
    required this.fillHeight,
    required this.reverse,
  });

  final AnimationController controller;
  final List<String> urls;
  final double tileWidth;
  final double tileHeight;
  final double fillHeight;
  final bool reverse;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final unit = tileHeight + _gap;
    // Enough tiles to overfill the viewport, then duplicated for the wrap.
    final count = (fillHeight / unit).ceil() + 1;
    final setHeight = count * unit;

    final oneSet = <Widget>[
      for (var i = 0; i < count; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: _gap),
          child: _CollageTile(
            url: urls[i % urls.length],
            width: tileWidth,
            height: tileHeight,
            angle: i.isEven ? 0.02 : -0.02,
          ),
        ),
    ];

    // The strip is rasterized ONCE behind a RepaintBoundary; each frame only
    // offsets that cached layer, so scrolling stays smooth (no per-frame
    // re-paint of the rotated poster tiles).
    final strip = RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [...oneSet, ...oneSet],
      ),
    );

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: 0,
        maxHeight: double.infinity,
        child: AnimatedBuilder(
          animation: controller,
          child: strip,
          builder: (context, child) {
            final t = controller.value; // 0 → 1 → seamless wrap
            var offset = (reverse ? 1.0 - t : t) * setHeight;
            offset %= setHeight;
            return Transform.translate(
              offset: Offset(0, -offset),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

class _CollageTile extends StatelessWidget {
  const _CollageTile({
    required this.url,
    required this.width,
    required this.height,
    required this.angle,
  });

  final String url;
  final double width;
  final double height;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          height: height,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            memCacheWidth: (width * 2).round(),
            fadeInDuration: const Duration(milliseconds: 400),
            placeholder: (_, __) => ColoredBox(color: AppTheme.cardDarkBlue),
            errorWidget: (_, __, ___) => ColoredBox(color: AppTheme.cardDarkBlue),
          ),
        ),
      ),
    );
  }
}
