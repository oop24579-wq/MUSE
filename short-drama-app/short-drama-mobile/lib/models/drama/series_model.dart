import 'package:flutter/material.dart';

import '../../core/media_url.dart';

/// A short-drama series (multi-episode vertical drama).
class SeriesModel {
  final String id;
  final String slug;
  final String title;
  final String? synopsis;
  final String? tagline;
  final String? coverImageUrl;
  final String? heroImageUrl;
  final String? trailerUrl;
  final String? gradientStart;
  final String? gradientEnd;
  final String? genreId;
  final String? genreName;
  final int? releaseYear;
  final int totalEpisodes;
  final int totalSeasons;
  final String language;
  final List<String> dubLanguages;
  final bool isVipOnly;
  final bool isExclusive;
  final bool isNew;
  final bool isHot;
  final bool isCompleted;
  final bool isDubbed;
  final int viewCount;
  final int likeCount;
  final double ratingAvg;
  final int ratingCount;
  final int rankScore;
  final bool isFeatured;
  final int sortOrder;
  final List<String> tags;

  const SeriesModel({
    required this.id,
    required this.slug,
    required this.title,
    this.synopsis,
    this.tagline,
    this.coverImageUrl,
    this.heroImageUrl,
    this.trailerUrl,
    this.gradientStart,
    this.gradientEnd,
    this.genreId,
    this.genreName,
    this.releaseYear,
    this.totalEpisodes = 0,
    this.totalSeasons = 1,
    this.language = 'en',
    this.dubLanguages = const [],
    this.isVipOnly = false,
    this.isExclusive = false,
    this.isNew = false,
    this.isHot = false,
    this.isCompleted = true,
    this.isDubbed = false,
    this.viewCount = 0,
    this.likeCount = 0,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.rankScore = 0,
    this.isFeatured = false,
    this.sortOrder = 0,
    this.tags = const [],
  });

  factory SeriesModel.fromJson(Map<String, dynamic> json) {
    // genre may arrive nested as `Genre: { name: ... }` from a join,
    // or as a flat `genreName` field from the web API.
    String? genreName;
    final genre = json['Genre'] ?? json['genre'];
    if (genre is Map) genreName = genre['name'] as String?;
    genreName ??= json['genreName'] as String?;

    List<String> tags = const [];
    final rawTags = json['SeriesTag'] ?? json['tags'];
    if (rawTags is List) {
      tags = rawTags
          .map((e) {
            if (e is String) return e;
            if (e is Map) return (e['tag']?.toString() ?? '');
            return e.toString();
          })
          .where((t) => t.isNotEmpty)
          .toList();
    }

    return SeriesModel(
      id: json['id'] as String,
      slug: (json['slug'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      synopsis: json['synopsis'] as String?,
      tagline: json['tagline'] as String?,
      coverImageUrl: rewriteMediaUrl(json['coverImageUrl'] as String?),
      heroImageUrl: rewriteMediaUrl(json['heroImageUrl'] as String?),
      trailerUrl: rewriteMediaUrl(json['trailerUrl'] as String?),
      gradientStart: json['gradientStart'] as String?,
      gradientEnd: json['gradientEnd'] as String?,
      genreId: json['genreId'] as String?,
      genreName: genreName,
      releaseYear: json['releaseYear'] as int?,
      totalEpisodes: (json['totalEpisodes'] as int?) ?? 0,
      totalSeasons: (json['totalSeasons'] as int?) ?? 1,
      language: (json['language'] as String?) ?? 'en',
      dubLanguages: (json['dubLanguages'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      isVipOnly: (json['isVipOnly'] as bool?) ?? false,
      isExclusive: (json['isExclusive'] as bool?) ?? false,
      isNew: (json['isNew'] as bool?) ?? false,
      isHot: (json['isHot'] as bool?) ?? false,
      isCompleted: (json['isCompleted'] as bool?) ?? true,
      isDubbed: (json['isDubbed'] as bool?) ?? false,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      rankScore: (json['rankScore'] as int?) ?? 0,
      isFeatured: (json['isFeatured'] as bool?) ?? false,
      sortOrder: (json['sortOrder'] as int?) ?? 0,
      tags: tags,
    );
  }

  /// Best image for a poster tile (falls back to hero).
  String? get posterUrl => coverImageUrl ?? heroImageUrl;

  /// Best image for a wide banner (falls back to cover).
  String? get bannerUrl => heroImageUrl ?? coverImageUrl;

  /// e.g. "60 episodes" / "Completed"
  String get episodeLabel =>
      totalEpisodes > 0 ? '$totalEpisodes EP' : (isCompleted ? 'Completed' : 'Ongoing');

  /// Compact view count, e.g. 4.8M, 231K, 950.
  String get viewCountLabel => formatCount(viewCount);

  /// Metadata line: "Romance · 60 EP"
  String get metaLine {
    final parts = <String>[];
    if (genreName != null && genreName!.isNotEmpty) parts.add(genreName!);
    if (totalEpisodes > 0) parts.add('$totalEpisodes EP');
    return parts.join(' · ');
  }

  Color? get gradientStartColor => _parseHexColor(gradientStart);
  Color? get gradientEndColor => _parseHexColor(gradientEnd);
}

/// Compact number formatting: 4_821_000 → "4.8M".
String formatCount(int value) {
  if (value >= 1000000) {
    final m = value / 1000000;
    return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    final k = value / 1000;
    return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
  }
  return '$value';
}

Color? _parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var value = hex.replaceFirst('#', '').trim();
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}
