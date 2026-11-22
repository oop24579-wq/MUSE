import '../../core/media_url.dart';

/// A single episode of a series. Reads from the `EpisodeList` view. The stream URL is not present here;
///
/// `isUnlocked` reports whether it is playable.
class EpisodeModel {
  final String id;
  final String seriesId;
  final String? seasonId;
  final int seasonNumber;
  final int episodeNumber;
  final String? title;
  final String? description;
  final String? videoUrl; // not exposed by EpisodeList; fetched via get_episode_video()
  final String? thumbnailUrl;
  final int? durationSeconds;
  final bool isFree;
  final int coinCost;
  final bool isVipOnly;
  final bool isUnlocked;
  final DateTime? publishedAt;
  final int viewCount;
  final int sortOrder;

  const EpisodeModel({
    required this.id,
    required this.seriesId,
    this.seasonId,
    this.seasonNumber = 1,
    required this.episodeNumber,
    this.title,
    this.description,
    this.videoUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    this.isFree = true,
    this.coinCost = 0,
    this.isVipOnly = false,
    this.isUnlocked = true,
    this.publishedAt,
    this.viewCount = 0,
    this.sortOrder = 0,
  });

  factory EpisodeModel.fromJson(Map<String, dynamic> json) {
    return EpisodeModel(
      id: json['id'] as String,
      seriesId: json['seriesId'] as String,
      seasonId: json['seasonId'] as String?,
      seasonNumber: (json['seasonNumber'] as int?) ?? 1,
      episodeNumber: (json['episodeNumber'] as int?) ?? 0,
      title: json['title'] as String?,
      description: json['description'] as String?,
      videoUrl: rewriteMediaUrl(json['videoUrl'] as String?),
      thumbnailUrl: rewriteMediaUrl(json['thumbnailUrl'] as String?),
      durationSeconds: json['durationSeconds'] as int?,
      isFree: (json['isFree'] as bool?) ?? true,
      coinCost: (json['coinCost'] as int?) ?? 0,
      isVipOnly: (json['isVipOnly'] as bool?) ?? false,
      isUnlocked: (json['isUnlocked'] as bool?) ?? ((json['isFree'] as bool?) ?? true),
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'] as String)
          : null,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sortOrder'] as int?) ?? 0,
    );
  }

  /// Whether the episode is locked for the current user.
  bool get isLocked => !isUnlocked;

  /// A displayable title, falling back to "Episode N".
  String get displayTitle =>
      (title != null && title!.isNotEmpty) ? title! : 'Episode $episodeNumber';

  /// e.g. "01:24"
  String get durationLabel {
    final total = durationSeconds ?? 0;
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  EpisodeModel copyWith({bool? isUnlocked, String? videoUrl}) => EpisodeModel(
        id: id,
        seriesId: seriesId,
        seasonId: seasonId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        title: title,
        description: description,
        videoUrl: rewriteMediaUrl(videoUrl) ?? this.videoUrl,
        thumbnailUrl: thumbnailUrl,
        durationSeconds: durationSeconds,
        isFree: isFree,
        coinCost: coinCost,
        isVipOnly: isVipOnly,
        isUnlocked: isUnlocked ?? this.isUnlocked,
        publishedAt: publishedAt,
        viewCount: viewCount,
        sortOrder: sortOrder,
      );
}
