import '../../core/media_url.dart';

/// One playable quality rendition of an episode.
class QualityOption {
  final String label;
  final String url;

  const QualityOption({required this.label, required this.url});

  factory QualityOption.fromJson(Map<String, dynamic> json) {
    return QualityOption(
      label: (json['label'] as String?) ?? '',
      url: rewriteMediaUrl(json['url'] as String?) ?? '',
    );
  }
}

/// Whether the quality menu should be offered at all (CODE_READINESS
/// item 9): only when the playback carries at least two DISTINCT rendition
/// URLs. A menu whose every entry plays the identical file is dishonest —
/// while the backend serves a single URL for all labels, the menu hides.
bool qualityMenuVisible(List<QualityOption> qualities) {
  return qualities.map((q) => q.url).where((u) => u.isNotEmpty).toSet().length >= 2;
}

/// Result of `GET /episodes/:id/playback`.
class EpisodePlayback {
  final String? videoUrl;
  final List<QualityOption> qualities;
  final List<String> captionLanguages;

  const EpisodePlayback({
    this.videoUrl,
    this.qualities = const [],
    this.captionLanguages = const [],
  });

  factory EpisodePlayback.fromJson(Map<String, dynamic> json) {
    final rawQualities = json['qualities'];
    final qualities = <QualityOption>[];
    if (rawQualities is List) {
      for (final q in rawQualities) {
        if (q is Map) {
          final opt =
              QualityOption.fromJson(Map<String, dynamic>.from(q));
          if (opt.url.isNotEmpty && opt.label.isNotEmpty) qualities.add(opt);
        }
      }
    }
    final rawCaps = json['captionLanguages'];
    final caps = <String>[];
    if (rawCaps is List) {
      for (final c in rawCaps) {
        final s = c.toString();
        if (s.isNotEmpty) caps.add(s);
      }
    }
    return EpisodePlayback(
      videoUrl: rewriteMediaUrl(json['videoUrl'] as String?),
      qualities: qualities,
      captionLanguages: caps,
    );
  }

  /// URL for [label], or null for Auto / unknown labels.
  String? urlForLabel(String label) {
    for (final q in qualities) {
      if (q.label == label) return q.url;
    }
    return null;
  }
}
