import 'package:drama_now/services/api/api_client.dart';

/// Remote app configuration from `GET /api/v1/config` (public).
///
/// Loaded once at startup (fire-and-forget from bootstrap). Every getter
/// falls back to a safe default when the config has not loaded yet or the
/// request failed, so the player behaves exactly as before offline.
class AppConfigService {
  AppConfigService._();
  static final AppConfigService instance = AppConfigService._();

  Map<String, dynamic> _features = const {};
  Map<String, dynamic> _player = const {};
  Map<String, dynamic> _visual = const {};
  Map<String, dynamic> _economy = const {};
  bool _maintenanceMode = false;
  String _premiumPlaybackMode = '';
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final data = await ApiClient.instance.get('/config');
      _maintenanceMode = (data['maintenanceMode'] as bool?) ?? false;
      _premiumPlaybackMode =
          (data['premiumPlaybackMode'] as String?) ?? '';
      final features = data['features'];
      if (features is Map) {
        _features = Map<String, dynamic>.from(features);
      }
      final player = data['player'];
      if (player is Map) _player = Map<String, dynamic>.from(player);
      final visual = data['visual'];
      if (visual is Map) _visual = Map<String, dynamic>.from(visual);
      final economy = data['economy'];
      if (economy is Map) _economy = Map<String, dynamic>.from(economy);
      _loaded = true;
    } catch (_) {
      // Keep defaults: all features ON.
    }
  }

  /// Feature flag lookup; defaults to ON when unknown / not loaded.
  bool feature(String key) {
    final v = _features[key];
    if (v is bool) return v;
    return true;
  }

  bool get captionsEnabled => feature('captions');
  bool get maintenanceMode => _maintenanceMode;

  /// `premium_playback_mode` from `GET /config` (`disabled` |
  /// `premium_content` | `all_playback`); '' when not loaded yet.
  String get premiumPlaybackMode => _premiumPlaybackMode;

  int get skipIntroWindowSeconds =>
      (_player['skipIntroWindowSeconds'] as num?)?.toInt() ?? 90;
  int get skipIntroToSeconds =>
      (_player['skipIntroToSeconds'] as num?)?.toInt() ?? 75;
  int get autoNextCountdownSeconds =>
      (_player['autoNextCountdownSeconds'] as num?)?.toInt() ?? 5;

  int get defaultThemePreset =>
      (_visual['defaultThemePreset'] as num?)?.toInt() ?? 6;
  bool get confettiEnabled => (_visual['confettiEnabled'] as bool?) ?? true;
  bool get hapticsEnabled => (_visual['hapticsEnabled'] as bool?) ?? true;

  String? get accentColorOverride {
    final v = _visual['accentColorOverride'];
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  int get episodeUnlockCoinCost =>
      (_economy['episodeUnlockCoinCost'] as num?)?.toInt() ?? 0;
  int get wheelFreeSpinsPerDay =>
      (_economy['wheelFreeSpinsPerDay'] as num?)?.toInt() ?? 0;
}
