import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/app_export.dart';
import 'tile_image_shimmer.dart';

enum TileImageStyle {
  /// Full-bleed photo art (podcasts, playlists) — cover fit.
  cover,

  /// Square logo tile (radio stations) — contain fit with padding.
  logo,

  /// Wide landscape tile (4:3 width:height) for horizontal carousels.
  landscape,
}

class TileImage extends StatelessWidget {
  const TileImage({
    super.key,
    required this.imageUrl,
    this.style = TileImageStyle.cover,
    this.borderRadius = 12,
    this.fallbackIcon = Icons.radio,
    this.isDark,
  });

  final String? imageUrl;
  final TileImageStyle style;
  final double borderRadius;
  final IconData fallbackIcon;
  final bool? isDark;

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppTheme.cardDarkBlue : AppTheme.cardLight;
    final iconColor = dark
        ? Colors.white.withValues(alpha: 0.45)
        : AppTheme.textSecondaryLight.withValues(alpha: 0.7);

    if (imageUrl == null || imageUrl!.isEmpty) {
      return _Fallback(surface: surface, icon: fallbackIcon, iconColor: iconColor);
    }

    if (style == TileImageStyle.logo) {
      return ColoredBox(
        color: surface,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (_, __) => const TileImageShimmer(),
            errorWidget: (_, __, ___) =>
                _Fallback(surface: Colors.transparent, icon: fallbackIcon, iconColor: iconColor),
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      fadeInDuration: const Duration(milliseconds: 200),
      // Decode at list-tile size — full JPEGs make Discover feel multi-second slow.
      memCacheWidth: 480,
      filterQuality: FilterQuality.low,
      placeholder: (_, __) => const TileImageShimmer(),
      errorWidget: (_, __, ___) =>
          _Fallback(surface: surface, icon: fallbackIcon, iconColor: iconColor),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({
    required this.surface,
    required this.icon,
    required this.iconColor,
  });

  final Color surface;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: surface,
      child: Center(child: Icon(icon, color: iconColor, size: 28)),
    );
  }
}

/// Frosted center logo overlay for playlist cards.
class TileCenterLogo extends StatelessWidget {
  const TileCenterLogo({
    super.key,
    required this.logoUrl,
    required this.size,
  });

  final String logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.18),
      child: CachedNetworkImage(
        imageUrl: logoUrl,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
