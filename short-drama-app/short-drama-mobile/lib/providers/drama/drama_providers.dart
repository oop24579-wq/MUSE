import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../models/drama/content_type.dart';
import '../../models/drama/genre_model.dart';
import '../../models/drama/home_section_model.dart';
import '../../models/drama/reward_models.dart';
import '../../models/drama/series_model.dart';
import '../../models/drama/watch_history_model.dart';
import '../../services/drama/drama_service.dart';

DramaService get _service => DramaService.instance;

// ---------------------------------------------------------------------------
// Catalog
// ---------------------------------------------------------------------------

final dramaGenresProvider = FutureProvider<List<GenreModel>>((ref) {
  return _service.fetchGenres();
});

final homeFeedProvider = FutureProvider<List<HomeSectionModel>>((ref) {
  return _service.fetchHomeSections();
});

/// Selected top-filter tab on Discover.
final discoverFilterProvider =
    StateProvider<DiscoverFilter>((ref) => DiscoverFilter.popular);

/// Series list for the currently-selected Discover filter.
final discoverListProvider = FutureProvider<List<SeriesModel>>((ref) {
  final filter = ref.watch(discoverFilterProvider);
  return _service.fetchDiscover(filter);
});

/// "For You" feed for the Shorts tab.
final forYouProvider = FutureProvider<List<SeriesModel>>((ref) {
  return _service.fetchForYou();
});

final categorySeriesProvider =
    FutureProvider.family<List<SeriesModel>, String>((ref, genreId) {
  return _service.fetchSeriesByGenre(genreId);
});

final seriesDetailProvider =
    FutureProvider.family<SeriesDetailData?, String>((ref, seriesId) {
  return _service.fetchSeriesDetail(seriesId);
});

// ---------------------------------------------------------------------------
// Library
// ---------------------------------------------------------------------------

final myListProvider = FutureProvider<List<SeriesModel>>((ref) {
  return _service.fetchFavorites();
});

final watchHistoryProvider = FutureProvider<List<WatchHistoryEntry>>((ref) {
  return _service.fetchWatchHistory();
});

final continueWatchingProvider = FutureProvider<List<WatchHistoryEntry>>((ref) {
  return _service.fetchContinueWatching();
});

// ---------------------------------------------------------------------------
// Rewards
// ---------------------------------------------------------------------------

final rewardsProvider = FutureProvider<RewardsState>((ref) {
  return _service.fetchRewardsState();
});

final coinBalanceProvider = FutureProvider<int>((ref) {
  return _service.fetchCoinBalance();
});

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<SeriesModel>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return _service.searchSeries(query);
});

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

final notificationCountProvider = FutureProvider<int>((ref) {
  return _service.fetchUnreadNotificationCount();
});
