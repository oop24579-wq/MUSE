import 'package:flutter/material.dart';

import '../../models/drama/episode_model.dart';
import '../../models/drama/genre_model.dart';
import '../../models/drama/series_model.dart';
import 'category_series_screen.dart';
import 'episode_player_screen.dart';
import 'search_screen.dart';
import 'series_detail_screen.dart';

/// Centralized navigation for the drama surfaces.
class DramaNav {
  static Future<void> openSeries(BuildContext context, SeriesModel series) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SeriesDetailScreen(seriesId: series.id, initial: series),
    ));
  }

  static Future<void> openSeriesById(BuildContext context, String seriesId) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SeriesDetailScreen(seriesId: seriesId),
    ));
  }

  static Future<void> openPlayer(
    BuildContext context, {
    required SeriesModel series,
    required List<EpisodeModel> episodes,
    int startIndex = 0,
  }) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EpisodePlayerScreen(
        series: series,
        episodes: episodes,
        startIndex: startIndex,
      ),
    ));
  }

  static Future<void> openCategory(BuildContext context, GenreModel genre) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CategorySeriesScreen(genre: genre),
    ));
  }

  static Future<void> openSearch(BuildContext context) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const SearchScreen(),
    ));
  }
}
