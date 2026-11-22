/// Public media CDN (Cloudflare R2 custom domain). No trailing slash.
///
/// Override at build time:
/// `--dart-define=MEDIA_CDN_BASE_URL=https://cdn.example.com`
const String kMediaCdnBaseUrl = String.fromEnvironment(
  'MEDIA_CDN_BASE_URL',
  defaultValue: 'https://content.morningstarcode.com',
);

/// Legacy hosts that time out or are retired — rewrite to [kMediaCdnBaseUrl].
const List<String> _legacyMediaBases = [
  'https://pub-2ca1e220b7d244b9886dced560404a04.r2.dev',
  'https://qizakxlszexaxdkhftte.supabase.co/storage/v1/object/public',
];

/// Rewrites known legacy storage URLs onto the fast custom CDN.
///
/// Leaves unrelated URLs (Unsplash, Google samples, etc.) untouched.
String? rewriteMediaUrl(String? url) {
  if (url == null || url.isEmpty) return url;
  for (final base in _legacyMediaBases) {
    if (url.startsWith(base)) {
      final path = url.substring(base.length);
      final normalized = path.startsWith('/') ? path : '/$path';
      return '$kMediaCdnBaseUrl$normalized';
    }
  }
  return url;
}

/// Build `{CDN}/{bucket}/{key}`.
String mediaUrl(String bucket, String key) {
  final cleanKey = key.startsWith('/') ? key.substring(1) : key;
  return '$kMediaCdnBaseUrl/$bucket/$cleanKey';
}
