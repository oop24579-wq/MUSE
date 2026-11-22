import '../../core/media_url.dart';

/// One item of the vertical Shorts feed (round 4): a single episode
/// presented as a short clip. Mirrors the backend GET /shorts item shape —
/// episodeJson fields plus the series-level extras.
///
/// [videoUrl] is the stored media reference; the playable stream is always
/// resolved through GET /episodes/:id/playback (DramaService
/// .getEpisodeVideoUrl) so entitlement rules apply exactly as in the full
/// player. [isUnlocked] mirrors the playback gate server-side.
class ShortItem {
  const ShortItem({
    required this.episodeId,
    required this.seriesId,
    required this.seriesTitle,
    required this.episodeNumber,
    required this.title,
    this.posterUrl,
    this.thumbnailUrl,
    this.videoUrl,
    this.durationSeconds = 0,
    this.likeCount = 0,
    this.isFree = true,
    this.isVipOnly = false,
    this.isUnlocked = true,
  });

  final String episodeId;
  final String seriesId;
  final String seriesTitle;
  final int episodeNumber;
  final String title;
  final String? posterUrl;
  final String? thumbnailUrl;
  final String? videoUrl;
  final int durationSeconds;
  final int likeCount;
  final bool isFree;
  final bool isVipOnly;
  final bool isUnlocked;

  factory ShortItem.fromJson(Map<String, dynamic> json) {
    return ShortItem(
      episodeId: (json['id'] ?? '') as String,
      seriesId: (json['seriesId'] ?? '') as String,
      seriesTitle: (json['seriesTitle'] ?? '') as String,
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? '',
      posterUrl: rewriteMediaUrl(json['posterUrl'] as String?),
      thumbnailUrl: rewriteMediaUrl(json['thumbnailUrl'] as String?),
      videoUrl: rewriteMediaUrl(json['videoUrl'] as String?),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      isFree: (json['isFree'] as bool?) ?? true,
      isVipOnly: (json['isVipOnly'] as bool?) ?? false,
      isUnlocked: (json['isUnlocked'] as bool?) ?? true,
    );
  }

  /// e.g. "Episode 3 · Series Title" caption line.
  String get captionTitle =>
      title.isNotEmpty ? title : 'Episode $episodeNumber';
}

/// One page of the Shorts feed.
class ShortsPage {
  const ShortsPage({required this.items, this.nextCursor});

  final List<ShortItem> items;

  /// Opaque cursor for the next page; null when the feed is exhausted.
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}

/// Parses the GET /shorts `data` payload. Top-level and pure so the mapping
/// is unit-testable without the HTTP layer.
ShortsPage parseShortsPage(Map<String, dynamic> data) {
  final raw = data['items'];
  final items = <ShortItem>[];
  if (raw is List) {
    for (final r in raw) {
      if (r is Map) {
        final item = ShortItem.fromJson(Map<String, dynamic>.from(r));
        if (item.episodeId.isNotEmpty) items.add(item);
      }
    }
  }
  final cursor = data['nextCursor'];
  return ShortsPage(
    items: items,
    nextCursor: (cursor is String && cursor.isNotEmpty) ? cursor : null,
  );
}
