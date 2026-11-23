import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Extracts a series poster's dominant color so the detail screen can
/// tint its hero gradient (round 5, item 10).
///
/// Results are cached in memory per series id. Every failure (no URL,
/// network error, undecodable image) resolves to null and the caller
/// falls back to the plain theme background — the palette is pure
/// decoration and must never break the screen.
class PosterPaletteService {
  PosterPaletteService({PaletteExtractor? extractor})
      : _extractor = extractor ?? _defaultExtractor;

  static final PosterPaletteService instance = PosterPaletteService();

  final PaletteExtractor _extractor;
  final Map<String, Color> _cache = {};
  final Set<String> _misses = {};

  static Future<Color?> _defaultExtractor(ImageProvider provider) async {
    final palette = await PaletteGenerator.fromImageProvider(
      provider,
      maximumColorCount: 12,
    );
    return palette.dominantColor?.color ?? palette.vibrantColor?.color;
  }

  /// Dominant color for [seriesId]'s poster, or null when unavailable.
  Future<Color?> colorFor({
    required String seriesId,
    required String? posterUrl,
  }) async {
    final cached = _cache[seriesId];
    if (cached != null) return cached;
    if (_misses.contains(seriesId)) return null;
    if (posterUrl == null || posterUrl.isEmpty) {
      _misses.add(seriesId);
      return null;
    }
    try {
      final color =
          await _extractor(CachedNetworkImageProvider(posterUrl));
      if (color == null) {
        _misses.add(seriesId);
        return null;
      }
      _cache[seriesId] = color;
      return color;
    } catch (_) {
      _misses.add(seriesId);
      return null;
    }
  }

  /// Test hook: forget all cached results.
  void clearCacheForTest() {
    _cache.clear();
    _misses.clear();
  }
}

/// Extracts a representative color from an image provider.
typedef PaletteExtractor = Future<Color?> Function(ImageProvider provider);
