import 'package:flutter_test/flutter_test.dart';

import 'package:drama_now/models/drama/episode_model.dart';
import 'package:drama_now/models/drama/series_model.dart';

void main() {
  group('EpisodeModel.fromJson', () {
    test('parses a full payload', () {
      final ep = EpisodeModel.fromJson({
        'id': 'ep-1',
        'seriesId': 'sr-1',
        'seasonId': 'sn-1',
        'seasonNumber': 2,
        'episodeNumber': 7,
        'title': 'The Reveal',
        'description': 'Things happen',
        'thumbnailUrl': 'https://example.com/t.jpg',
        'durationSeconds': 95,
        'isFree': false,
        'coinCost': 30,
        'isVipOnly': true,
        'isUnlocked': false,
        'publishedAt': '2026-01-15T10:00:00.000Z',
        'viewCount': 1234,
        'sortOrder': 3,
      });
      expect(ep.id, 'ep-1');
      expect(ep.seriesId, 'sr-1');
      expect(ep.seasonNumber, 2);
      expect(ep.episodeNumber, 7);
      expect(ep.title, 'The Reveal');
      expect(ep.durationSeconds, 95);
      expect(ep.isFree, isFalse);
      expect(ep.coinCost, 30);
      expect(ep.isVipOnly, isTrue);
      expect(ep.isUnlocked, isFalse);
      expect(ep.isLocked, isTrue);
      expect(ep.viewCount, 1234);
      expect(ep.publishedAt, isNotNull);
    });

    test('applies defaults for a minimal payload', () {
      final ep = EpisodeModel.fromJson({
        'id': 'ep-2',
        'seriesId': 'sr-1',
        'episodeNumber': 1,
      });
      expect(ep.seasonNumber, 1);
      expect(ep.isFree, isTrue);
      expect(ep.coinCost, 0);
      expect(ep.isVipOnly, isFalse);
      // Unlocked defaults to isFree when absent.
      expect(ep.isUnlocked, isTrue);
      expect(ep.displayTitle, 'Episode 1');
      expect(ep.durationLabel, '00:00');
    });

    test('paid episode without explicit unlock reads as locked', () {
      final ep = EpisodeModel.fromJson({
        'id': 'ep-3',
        'seriesId': 'sr-1',
        'episodeNumber': 5,
        'isFree': false,
        'coinCost': 20,
      });
      expect(ep.isUnlocked, isFalse);
      expect(ep.isLocked, isTrue);
    });

    test('durationLabel formats mm:ss', () {
      final ep = EpisodeModel.fromJson({
        'id': 'ep-4',
        'seriesId': 'sr-1',
        'episodeNumber': 1,
        'durationSeconds': 84,
      });
      expect(ep.durationLabel, '01:24');
    });

    test('displayTitle prefers provided title', () {
      final ep = EpisodeModel.fromJson({
        'id': 'ep-5',
        'seriesId': 'sr-1',
        'episodeNumber': 9,
        'title': 'Finale',
      });
      expect(ep.displayTitle, 'Finale');
    });
  });

  group('SeriesModel.fromJson', () {
    test('parses nested genre and tag objects', () {
      final s = SeriesModel.fromJson({
        'id': 'sr-1',
        'slug': 'my-drama',
        'title': 'My Drama',
        'synopsis': 'A story',
        'Genre': {'name': 'Romance'},
        'SeriesTag': [
          {'tag': 'sweet'},
          {'tag': 'ceo'},
        ],
        'totalEpisodes': 40,
        'totalSeasons': 1,
        'language': 'zh',
        'dubLanguages': ['en', 'ar'],
        'viewCount': 999,
      });
      expect(s.id, 'sr-1');
      expect(s.title, 'My Drama');
      expect(s.genreName, 'Romance');
      expect(s.tags, ['sweet', 'ceo']);
      expect(s.totalEpisodes, 40);
      expect(s.dubLanguages, ['en', 'ar']);
    });

    test('parses flat genreName and string tags', () {
      final s = SeriesModel.fromJson({
        'id': 'sr-2',
        'title': 'Flat',
        'genreName': 'Revenge',
        'tags': ['urban', ''],
      });
      expect(s.genreName, 'Revenge');
      expect(s.tags, ['urban']); // empty strings dropped
      expect(s.language, 'en'); // default
      expect(s.totalSeasons, 1); // default
    });

    test('rewrites legacy media URLs onto the CDN', () {
      final s = SeriesModel.fromJson({
        'id': 'sr-3',
        'title': 'Legacy',
        'coverImageUrl':
            'https://pub-2ca1e220b7d244b9886dced560404a04.r2.dev/covers/a.jpg',
      });
      expect(
        s.coverImageUrl,
        'https://content.morningstarcode.com/covers/a.jpg',
      );
    });

    test('leaves unrelated URLs untouched', () {
      final s = SeriesModel.fromJson({
        'id': 'sr-4',
        'title': 'Plain',
        'coverImageUrl': 'https://images.unsplash.com/photo-1',
      });
      expect(s.coverImageUrl, 'https://images.unsplash.com/photo-1');
    });
  });
}
