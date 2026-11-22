import 'series_model.dart';

/// A "Recently Watched" / "Continue Watching" entry: a series plus where the
/// user left off. Built by the data service from `WatchHistory` + `Series`.
class WatchHistoryEntry {
  final SeriesModel series;
  final String? episodeId;
  final int episodeNumber;
  final int positionSeconds;
  final int durationSeconds;
  final bool completed;
  final DateTime? watchedAt;

  const WatchHistoryEntry({
    required this.series,
    this.episodeId,
    this.episodeNumber = 1,
    this.positionSeconds = 0,
    this.durationSeconds = 0,
    this.completed = false,
    this.watchedAt,
  });

  /// Playback progress 0.0–1.0 for the current episode.
  double get episodeProgress {
    if (durationSeconds <= 0) return 0;
    return (positionSeconds / durationSeconds).clamp(0.0, 1.0);
  }

  /// e.g. "Ep 3 / 60"
  String get progressLabel {
    final total = series.totalEpisodes;
    return total > 0 ? 'Ep $episodeNumber / $total' : 'Ep $episodeNumber';
  }
}

/// Per-episode watch progress for ONE series (round 2, S5).
///
/// Built from `GET /me/library/history/series/:seriesId`. The classic
/// watch-history payload keeps only the latest episode per series, which
/// made watched checkmarks / per-episode resume positions impossible; this
/// is the per-episode companion the player merges in.
class EpisodeProgress {
  final String episodeId;
  final int episodeNumber;
  final int positionSeconds;
  final int durationSeconds;
  final bool completed;

  const EpisodeProgress({
    required this.episodeId,
    this.episodeNumber = 1,
    this.positionSeconds = 0,
    this.durationSeconds = 0,
    this.completed = false,
  });

  factory EpisodeProgress.fromJson(Map<String, dynamic> json) {
    return EpisodeProgress(
      episodeId: (json['episodeId'] as String?) ?? '',
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 1,
      positionSeconds: (json['positionSeconds'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as bool?) ?? false,
    );
  }
}
