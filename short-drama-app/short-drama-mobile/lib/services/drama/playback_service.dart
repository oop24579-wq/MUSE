import 'package:dio/dio.dart';
import 'package:drama_now/models/drama/playback_model.dart';
import 'package:drama_now/services/api/api_client.dart';

/// Playback metadata + captions for the episode player.
///
/// Kept separate from [DramaService] (whose `getEpisodeVideoUrl` stays for
/// compatibility); errors are tolerated the same way — null on failure.
class PlaybackService {
  PlaybackService._();
  static final PlaybackService instance = PlaybackService._();

  ApiClient get _api => ApiClient.instance;

  /// Full playback payload: default URL, quality renditions, caption langs.
  Future<EpisodePlayback?> getPlayback(String episodeId,
      {String? lang}) async {
    try {
      final data = await _api.get(
        '/episodes/$episodeId/playback',
        query: lang != null && lang.isNotEmpty ? {'lang': lang} : null,
      );
      return EpisodePlayback.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Raw WebVTT text for [lang] (the endpoint returns `text/vtt`, NOT the
  /// JSON envelope, so this bypasses ApiClient's unwrap via its dio).
  Future<String?> fetchCaptionVtt(String episodeId, String lang) async {
    try {
      final res = await _api.dio.get<String>(
        '/episodes/$episodeId/captions/$lang',
        options: Options(responseType: ResponseType.plain),
      );
      final body = res.data;
      if (body == null || body.isEmpty) return null;
      return body;
    } catch (_) {
      return null;
    }
  }
}
