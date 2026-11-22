import 'package:drama_now/models/drama/cast_member.dart';
import 'package:drama_now/services/api/api_client.dart';
import 'package:drama_now/services/api/api_exception.dart';

import '../../core/media_url.dart';
import '../../models/drama/content_type.dart';
import '../../models/drama/episode_model.dart';
import '../../models/drama/short_item.dart';
import '../../models/drama/genre_model.dart';
import '../../models/drama/home_section_model.dart';
import '../../models/drama/notification_model.dart';
import '../../models/drama/reward_models.dart';
import '../../models/drama/season_model.dart';
import '../../models/drama/series_model.dart';
import '../../models/drama/watch_history_model.dart';

/// Bundle returned for the series detail screen.
class SeriesDetailData {
  final SeriesModel series;
  final List<SeasonModel> seasons;
  final List<EpisodeModel> episodes;
  final List<SeriesModel> related;
  final List<CastMember> cast;
  final bool isFavorite;
  final bool isFollowing;
  final bool isLiked;
  final int? resumeEpisodeNumber;

  /// The exact episode to resume (round 2, S3). Episode numbers repeat
  /// across seasons, so the number alone cannot identify the resume target
  /// in a multi-season series; the id can.
  final String? resumeEpisodeId;

  const SeriesDetailData({
    required this.series,
    this.seasons = const [],
    this.episodes = const [],
    this.related = const [],
    this.cast = const [],
    this.isFavorite = false,
    this.isFollowing = false,
    this.isLiked = false,
    this.resumeEpisodeNumber,
    this.resumeEpisodeId,
  });
}

/// Where the player should start for a series (round 2, S3): the resume
/// episode when it can be identified unambiguously, else the first episode.
/// The id match is exact; the number match is used only when exactly one
/// episode carries that number (multi-season series repeat numbers).
int resolvePlayerStartIndex(
  List<EpisodeModel> episodes, {
  String? resumeEpisodeId,
  int? resumeEpisodeNumber,
}) {
  if (episodes.isEmpty) return 0;
  if (resumeEpisodeId != null) {
    final byId = episodes.indexWhere((e) => e.id == resumeEpisodeId);
    if (byId >= 0) return byId;
  }
  if (resumeEpisodeNumber != null) {
    var found = -1;
    for (var i = 0; i < episodes.length; i++) {
      if (episodes[i].episodeNumber == resumeEpisodeNumber) {
        if (found >= 0) return 0; // ambiguous — do not guess
        found = i;
      }
    }
    if (found >= 0) return found;
  }
  return 0;
}

/// Central data layer for DramaNow content (web `/api/v1`).
class DramaService {
  DramaService._();
  static final DramaService instance = DramaService._();

  ApiClient get _api => ApiClient.instance;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<SeriesModel> _parseSeriesList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => SeriesModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  List<EpisodeModel> _parseEpisodeList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => EpisodeModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  List<CastMember> _parseCastList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => CastMember.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  List<SeasonModel> _seasonsFromEpisodes(
    String seriesId,
    List<EpisodeModel> episodes,
  ) {
    if (episodes.isEmpty) return const [];
    final counts = <int, int>{};
    for (final e in episodes) {
      counts[e.seasonNumber] = (counts[e.seasonNumber] ?? 0) + 1;
    }
    final numbers = counts.keys.toList()..sort();
    return [
      for (final n in numbers)
        SeasonModel(
          id: '$seriesId-s$n',
          seriesId: seriesId,
          seasonNumber: n,
          episodeCount: counts[n]!,
        ),
    ];
  }

  WatchHistoryEntry? _parseHistoryEntry(Map<String, dynamic> r) {
    final seriesRaw = r['series'];
    if (seriesRaw is! Map) return null;
    return WatchHistoryEntry(
      series: SeriesModel.fromJson(Map<String, dynamic>.from(seriesRaw)),
      episodeId: r['episodeId'] as String?,
      episodeNumber: (r['episodeNumber'] as num?)?.toInt() ?? 1,
      positionSeconds: (r['positionSeconds'] as num?)?.toInt() ?? 0,
      durationSeconds: (r['durationSeconds'] as num?)?.toInt() ?? 0,
      completed: (r['completed'] as bool?) ?? false,
      watchedAt: r['watchedAt'] != null
          ? DateTime.tryParse(r['watchedAt'].toString())
          : null,
    );
  }

  UserNotificationModel _notificationFromJson(Map<String, dynamic> j) {
    DateTime? readAt;
    if (j['readAt'] != null) {
      readAt = DateTime.tryParse(j['readAt'].toString());
    } else if (j['read'] == true) {
      readAt = DateTime.tryParse(j['createdAt']?.toString() ?? '') ??
          DateTime.now().toUtc();
    }
    return UserNotificationModel(
      id: (j['id'] ?? '') as String,
      userId: (j['userId'] as String?) ?? '',
      type: (j['type'] as String?) ?? 'system',
      title: (j['title'] as String?) ?? '',
      body: j['body'] as String?,
      imageUrl: rewriteMediaUrl(j['imageUrl'] as String?),
      payload: j['payload'] is Map
          ? Map<String, dynamic>.from(j['payload'] as Map)
          : null,
      readAt: readAt,
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  // ---------------------------------------------------------------------------
  // Genres
  // ---------------------------------------------------------------------------

  Future<List<GenreModel>> fetchGenres() async {
    try {
      final data = await _api.get('/categories');
      final raw = data['genres'];
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => GenreModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Series
  // ---------------------------------------------------------------------------

  Future<List<SeriesModel>> fetchSeriesByGenre(String genreId,
      {int limit = 60}) async {
    try {
      final data = await _api.get(
        '/genres/$genreId/series',
        query: {'limit': limit},
      );
      return _parseSeriesList(data['series']);
    } catch (_) {
      return [];
    }
  }

  /// Discover tab lists: Popular / New / Ranking.
  Future<List<SeriesModel>> fetchDiscover(DiscoverFilter filter,
      {int limit = 60}) async {
    try {
      final filterName = switch (filter) {
        DiscoverFilter.popular || DiscoverFilter.categories => 'popular',
        DiscoverFilter.latest => 'latest',
        DiscoverFilter.ranking => 'ranking',
      };
      final data = await _api.get(
        '/discover',
        query: {'filter': filterName, 'limit': limit},
      );
      return _parseSeriesList(data['series']);
    } catch (_) {
      return [];
    }
  }

  /// A curated "For You" feed for the Shorts tab.
  Future<List<SeriesModel>> fetchForYou({int limit = 40}) async {
    try {
      final data = await _api.get('/for-you', query: {'limit': limit});
      return _parseSeriesList(data['series']);
    } catch (_) {
      return [];
    }
  }

  /// Round 4: one page of the vertical Shorts feed (GET /shorts, cursor
  /// pagination). An empty page on any failure — the tab shows its empty
  /// state instead of an error.
  Future<ShortsPage> fetchShorts({String? cursor, int limit = 20}) async {
    try {
      final data = await _api.get('/shorts', query: {
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      });
      return parseShortsPage(data);
    } catch (_) {
      return const ShortsPage(items: []);
    }
  }

  Future<List<SeriesModel>> searchSeries(String query, {int limit = 40}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final data = await _api.get(
        '/search',
        query: {'q': q, 'limit': limit},
      );
      return _parseSeriesList(data['series']);
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Home feed
  // ---------------------------------------------------------------------------

  Future<List<HomeSectionModel>> fetchHomeSections(
      {String locale = 'en'}) async {
    try {
      final data = await _api.get('/home', query: {'locale': locale});
      final sections = data['sections'];
      if (sections is! List) return [];

      return sections
          .whereType<Map>()
          .map((s) {
            final map = Map<String, dynamic>.from(s);
            final items = _parseSeriesList(map['series']);
            return HomeSectionModel.fromJson(map, items: items);
          })
          .where((s) => !s.isEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Episodes
  // ---------------------------------------------------------------------------

  Future<List<EpisodeModel>> fetchEpisodes(String seriesId) async {
    try {
      final data = await _api.get('/series/$seriesId/episodes');
      return _parseEpisodeList(data['episodes']);
    } catch (_) {
      return [];
    }
  }

  /// Derives seasons from the series episode list (no dedicated seasons endpoint).
  Future<List<SeasonModel>> fetchSeasons(String seriesId) async {
    try {
      final episodes = await fetchEpisodes(seriesId);
      return _seasonsFromEpisodes(seriesId, episodes);
    } catch (_) {
      return [];
    }
  }

  /// Finds [episodeId] in the episodes list for [seriesId] when provided.
  Future<EpisodeModel?> fetchEpisode(
    String episodeId, {
    String? seriesId,
  }) async {
    try {
      if (seriesId == null || seriesId.isEmpty) return null;
      final episodes = await fetchEpisodes(seriesId);
      for (final e in episodes) {
        if (e.id == episodeId) return e;
      }
    } catch (_) {}
    return null;
  }

  /// Fetches the playable stream URL for an episode in [lang] (null = original
  /// track). Returns null when the caller is not entitled (server enforces
  /// VIP / coin unlock).
  Future<String?> getEpisodeVideoUrl(String episodeId, {String? lang}) async {
    try {
      final data = await _api.get(
        '/episodes/$episodeId/playback',
        query: lang != null && lang.isNotEmpty ? {'lang': lang} : null,
      );
      return rewriteMediaUrl(data['videoUrl'] as String?);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Series detail
  // ---------------------------------------------------------------------------

  Future<SeriesDetailData?> fetchSeriesDetail(String seriesId) async {
    try {
      final detail = await _api.get('/series/$seriesId');
      final seriesRaw = detail['series'];
      if (seriesRaw is! Map) return null;
      final series =
          SeriesModel.fromJson(Map<String, dynamic>.from(seriesRaw));

      final episodes = await fetchEpisodes(seriesId);
      final seasons = _seasonsFromEpisodes(seriesId, episodes);
      final cast = _parseCastList(detail['cast']);
      final related = _parseSeriesList(detail['related']);

      return SeriesDetailData(
        series: series,
        seasons: seasons,
        episodes: episodes,
        related: related,
        cast: cast,
        isFavorite: (detail['isFavorite'] as bool?) ?? false,
        isFollowing: (detail['isFollowing'] as bool?) ?? false,
        isLiked: (detail['isLiked'] as bool?) ?? false,
        resumeEpisodeNumber:
            (detail['resumeEpisodeNumber'] as num?)?.toInt(),
        resumeEpisodeId: detail['resumeEpisodeId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Like / unlike a series. Returns the new like count (or null on failure).
  Future<int?> toggleLike(String seriesId, bool like) async {
    try {
      final data = await _api.post(
        '/series/$seriesId/like',
        data: {'like': like},
      );
      if (data['success'] == true) {
        return (data['likeCount'] as num?)?.toInt();
      }
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------------------
  // My List (favorites) + follow
  // ---------------------------------------------------------------------------

  Future<List<SeriesModel>> fetchFavorites() async {
    try {
      final data = await _api.get('/me/library/my-list');
      return _parseSeriesList(data['series']);
    } catch (_) {
      return [];
    }
  }

  Future<bool> toggleFavorite(String seriesId, bool add) async {
    try {
      final data = await _api.post(
        '/series/$seriesId/favorite',
        data: {'add': add},
      );
      if (data['success'] == true) return add;
    } catch (_) {}
    return false;
  }

  Future<bool> toggleFollow(String seriesId, bool follow) async {
    try {
      final data = await _api.post(
        '/series/$seriesId/follow',
        data: {'follow': follow},
      );
      if (data['success'] == true) return follow;
    } catch (_) {}
    return false;
  }

  // ---------------------------------------------------------------------------
  // Watch history / continue watching
  // ---------------------------------------------------------------------------

  Future<List<WatchHistoryEntry>> fetchWatchHistory({int limit = 40}) async {
    try {
      final data = await _api.get(
        '/me/library/history',
        query: {'limit': limit},
      );
      final history = data['history'];
      if (history is! List) return [];
      final entries = <WatchHistoryEntry>[];
      for (final r in history) {
        if (r is! Map) continue;
        final entry = _parseHistoryEntry(Map<String, dynamic>.from(r));
        if (entry != null) entries.add(entry);
      }
      return entries;
    } catch (_) {
      return [];
    }
  }

  Future<List<WatchHistoryEntry>> fetchContinueWatching(
      {int limit = 12}) async {
    try {
      final data = await _api.get(
        '/me/library/continue',
        query: {'limit': limit},
      );
      final history = data['history'];
      if (history is! List) return [];
      final entries = <WatchHistoryEntry>[];
      for (final r in history) {
        if (r is! Map) continue;
        final entry = _parseHistoryEntry(Map<String, dynamic>.from(r));
        if (entry != null) entries.add(entry);
      }
      return entries;
    } catch (_) {
      return [];
    }
  }

  /// Per-episode progress for one series (round 2, S5): watched checkmarks
  /// and per-episode resume positions. Empty on any failure — callers fall
  /// back to the one-row-per-series history.
  Future<List<EpisodeProgress>> fetchSeriesEpisodeProgress(
      String seriesId) async {
    try {
      final data = await _api.get('/me/library/history/series/$seriesId');
      final rows = data['episodes'];
      if (rows is! List) return [];
      return rows
          .whereType<Map>()
          .map((r) => EpisodeProgress.fromJson(Map<String, dynamic>.from(r)))
          .where((p) => p.episodeId.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> recordWatch({
    required String seriesId,
    String? episodeId,
    required int episodeNumber,
    int positionSeconds = 0,
    int durationSeconds = 0,
    bool completed = false,
  }) async {
    try {
      await _api.post('/me/watch-history', data: {
        'seriesId': seriesId,
        'episodeId': episodeId,
        'episodeNumber': episodeNumber,
        'positionSeconds': positionSeconds,
        'durationSeconds': durationSeconds,
        'completed': completed,
      });
    } catch (_) {/* best-effort */}
  }

  Future<void> incrementView(String type, String id) async {
    try {
      await _api.post('/content/view', data: {'type': type, 'id': id});
    } catch (_) {/* best-effort */}
  }

  // ---------------------------------------------------------------------------
  // Coins & rewards
  // ---------------------------------------------------------------------------

  Future<int> fetchCoinBalance() async {
    try {
      final data = await _api.get('/me/coins');
      return (data['balance'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<RewardsState> fetchRewardsState() async {
    try {
      final data = await _api.get('/rewards');
      final daysRaw = data['days'];
      final tasksRaw = data['tasks'];

      final days = <CheckinDay>[];
      if (daysRaw is List) {
        for (final d in daysRaw) {
          if (d is! Map) continue;
          final m = Map<String, dynamic>.from(d);
          days.add(CheckinDay(
            dayIndex: (m['dayIndex'] as num?)?.toInt() ?? 0,
            coins: (m['coins'] as num?)?.toInt() ?? 0,
            claimed: (m['claimed'] as bool?) ?? false,
            isToday: (m['isToday'] as bool?) ?? false,
          ));
        }
      }

      final tasks = <RewardTaskModel>[];
      if (tasksRaw is List) {
        for (final t in tasksRaw) {
          if (t is! Map) continue;
          final m = Map<String, dynamic>.from(t);
          tasks.add(RewardTaskModel.fromJson(
            m,
            completed: (m['completed'] as bool?) ?? false,
          ));
        }
      }

      // Phase 2 sections — every block is optional; a Phase-1-shaped payload
      // (or a partially built backend) just leaves the defaults in place.
      var wheel = const WheelState();
      final wheelRaw = data['wheel'];
      if (wheelRaw is Map) {
        wheel = WheelState.fromJson(Map<String, dynamic>.from(wheelRaw));
      }

      final chests = <ChestState>[];
      final chestsRaw = data['chests'];
      if (chestsRaw is List) {
        for (final c in chestsRaw) {
          if (c is! Map) continue;
          chests.add(ChestState.fromJson(Map<String, dynamic>.from(c)));
        }
      }

      var watchTime = const WatchTimeState();
      final watchTimeRaw = data['watchTime'];
      if (watchTimeRaw is Map) {
        watchTime =
            WatchTimeState.fromJson(Map<String, dynamic>.from(watchTimeRaw));
      }

      final missions = <DailyMission>[];
      final missionsRaw = data['missions'];
      if (missionsRaw is List) {
        for (final m in missionsRaw) {
          if (m is! Map) continue;
          missions.add(DailyMission.fromJson(Map<String, dynamic>.from(m)));
        }
      }

      ActiveEventState? activeEvent;
      final eventRaw = data['activeEvent'];
      if (eventRaw is Map) {
        activeEvent =
            ActiveEventState.fromJson(Map<String, dynamic>.from(eventRaw));
      }

      return RewardsState(
        coinBalance: (data['coinBalance'] as num?)?.toInt() ?? 0,
        claimedToday: (data['claimedToday'] as bool?) ?? false,
        currentDay: (data['currentDay'] as num?)?.toInt() ?? 1,
        days: days,
        tasks: tasks,
        wheel: wheel,
        chests: chests,
        watchTime: watchTime,
        missions: missions,
        currentStreak: (data['currentStreak'] as num?)?.toInt() ?? 0,
        xp: (data['xp'] as num?)?.toInt() ?? 0,
        level: (data['level'] as num?)?.toInt() ?? 1,
        nextLevelXp: (data['nextLevelXp'] as num?)?.toInt() ?? 100,
        activeEvent: activeEvent,
        referralCode: (data['referralCode'] as String?) ?? '',
        graceAvailable: (data['graceAvailable'] as bool?) ?? false,
        streakAtRisk: (data['streakAtRisk'] as bool?) ?? false,
        daysSinceLastClaim: (data['daysSinceLastClaim'] as num?)?.toInt(),
        referralApplyBy: data['referralApplyBy'] != null
            ? DateTime.tryParse(data['referralApplyBy'].toString())
            : null,
        hasReferred: (data['hasReferred'] as bool?) ?? false,
      );
    } catch (_) {
      return const RewardsState();
    }
  }

  /// Returns coins awarded, or null on failure / already claimed.
  Future<int?> claimDailyCheckin() async {
    try {
      final data = await _api.post('/rewards/checkin');
      if (data['success'] == true) {
        return (data['coins'] as num?)?.toInt();
      }
    } catch (_) {}
    return null;
  }

  /// Credits coins after a rewarded ad. Returns the coins granted, or null if
  /// the daily limit was hit or the call failed.
  Future<int?> claimAdReward(int amount) async {
    try {
      final data = await _api.post('/rewards/ad', data: {'amount': amount});
      if (data['success'] == true) {
        return (data['coins'] as num?)?.toInt();
      }
    } catch (_) {}
    return null;
  }

  Future<int?> completeRewardTask(String slug) async {
    try {
      final data = await _api.post('/rewards/tasks/$slug/complete');
      if (data['success'] == true) {
        return (data['coins'] as num?)?.toInt();
      }
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------------------
  // Phase 2 economy: wheel, chests, watch-time, missions, referrals, shares
  // ---------------------------------------------------------------------------

  /// Spin the rewards wheel. The server decides the outcome — the returned
  /// [WheelSpinResult.segmentIndex] is where the client animation must land.
  /// Returns null on failure (no spins left, insufficient coins, network).
  Future<WheelSpinResult?> spinWheel() async {
    try {
      final data = await _api.post('/rewards/wheel/spin');
      if (data['success'] == true) {
        return WheelSpinResult.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Claim an unlocked treasure chest. Returns coins awarded, or null.
  Future<int?> claimChest(String id) async {
    try {
      final data = await _api.post('/rewards/chests/$id/claim');
      if (data['success'] == true) {
        return (data['coins'] as num?)?.toInt();
      }
    } catch (_) {}
    return null;
  }

  /// Claim coins earned from today's watch time. Returns coins, or null.
  Future<int?> claimWatchTime() async {
    try {
      final data = await _api.post('/rewards/watch-time/claim');
      if (data['success'] == true) {
        return (data['coins'] as num?)?.toInt();
      }
    } catch (_) {}
    return null;
  }

  /// Claim a completed daily mission. Returns coins awarded, or null.
  Future<int?> claimMission(String slug) async {
    try {
      final data = await _api.post('/rewards/missions/$slug/claim');
      if (data['success'] == true) {
        return (data['coins'] as num?)?.toInt();
      }
    } catch (_) {}
    return null;
  }

  /// Apply someone else's referral code. Returns the bonus coins, or null.
  Future<int?> applyReferral(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;
    try {
      final data = await _api.post('/auth/referral', data: {'code': trimmed});
      if (data['success'] == true) {
        return (data['coins'] as num?)?.toInt();
      }
    } catch (_) {}
    return null;
  }

  /// Fire-and-forget share ping so the server can credit share missions.
  Future<void> shareSeries(String seriesId) async {
    try {
      await _api.post('/content/share', data: {'seriesId': seriesId});
    } catch (_) {/* best-effort */}
  }

  /// Attempt to unlock an episode with coins. Returns the unlock result map.
  Future<Map<String, dynamic>> unlockEpisode(String episodeId) async {
    try {
      final data = await _api.post('/episodes/$episodeId/unlock');
      return data;
    } on ApiException catch (e) {
      return {'success': false, 'code': e.code, 'message': e.message};
    } catch (_) {
      return {'success': false, 'message': 'error'};
    }
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  Future<int> fetchUnreadNotificationCount() async {
    try {
      final data = await _api.get('/notifications');
      return (data['unread'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<UserNotificationModel>> fetchNotifications() async {
    try {
      final data = await _api.get('/notifications');
      final items = data['items'];
      if (items is! List) return [];
      return items
          .whereType<Map>()
          .map((e) => _notificationFromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await _api.post('/notifications/read', data: {
        'ids': [id],
      });
    } catch (_) {/* best-effort */}
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await _api.post('/notifications/read');
    } catch (_) {/* best-effort */}
  }
}
