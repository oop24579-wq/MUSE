/// A season of a drama series. Episodes belong to a season.
class SeasonModel {
  final String id;
  final String seriesId;
  final int seasonNumber;
  final String? title;
  final int episodeCount;

  const SeasonModel({
    required this.id,
    required this.seriesId,
    required this.seasonNumber,
    this.title,
    this.episodeCount = 0,
  });

  factory SeasonModel.fromJson(Map<String, dynamic> json) {
    return SeasonModel(
      id: json['id'] as String,
      seriesId: json['seriesId'] as String,
      seasonNumber: (json['seasonNumber'] as int?) ?? 1,
      title: json['title'] as String?,
      episodeCount: (json['episodeCount'] as int?) ?? 0,
    );
  }

  /// e.g. "Season 1"
  String get displayTitle =>
      (title != null && title!.isNotEmpty) ? title! : 'Season $seasonNumber';
}
