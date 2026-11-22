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
