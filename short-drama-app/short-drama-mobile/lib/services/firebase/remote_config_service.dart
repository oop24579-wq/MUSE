import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Remote Config service — runtime values from Firebase Console.
/// In-app SDK defaults are empty/zero/false only (not product fallbacks).
class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  static RemoteConfigService get instance => _instance;

  RemoteConfigService._internal();

  late final FirebaseRemoteConfig _remoteConfig;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  static const List<String> _allStringKeys = [
    'premium_playback_mode',
    'api_base_url',
    'app_url',
    'turnstile_site_key',
    'onesignal_app_id',
    'ready_to_start_headline',
    'home_default_locale',
    'terms_url',
    'privacy_url',
    'discount_offer_product_id',
    'discount_offer_discount_text',
    'android_interstitial_ad_unit_id',
    'ios_interstitial_ad_unit_id',
    'android_banner_ad_unit_id',
    'ios_banner_ad_unit_id',
    'revenuecat_ios_api_key',
    'revenuecat_android_api_key',
    'revenuecat_pro_entitlement_id',
    'ios_store_url',
    'android_store_url',
  ];

  static const List<String> _allBoolKeys = [
    'show_ready_to_start',
    'discount_offer_enabled',
    'discount_offer_show_banner',
    'is_ad_enabled',
    'ios_force_update_enabled',
    'android_force_update_enabled',
    'captcha_enabled',
    'feature_offline_downloads',
    'feature_premium_stations',
    'feature_premium_podcasts',
    'feature_high_quality_streams',
    'premium_show_pro_badges',
    'podcast_auto_download_pro_only',
  ];

  static const List<String> _allIntKeys = [
    'discount_offer_timer_seconds',
    'discount_offer_delay_ms',
    'discount_offer_frequency_seconds',
    'discount_offer_paywall_dismiss_threshold',
    'max_radio_presets',
    'podcast_refresh_interval_hours',
    'ios_min_build_number',
    'ios_latest_build_number',
    'android_min_build_number',
    'android_latest_build_number',
  ];

  static Map<String, dynamic> get _emptyDefaults => {
        for (final key in _allStringKeys) key: '',
        for (final key in _allBoolKeys) key: false,
        for (final key in _allIntKeys) key: 0,
      };

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('⚙️ Initializing Remote Config Service...');

      _remoteConfig = FirebaseRemoteConfig.instance;

      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );

      await _remoteConfig.setDefaults(_emptyDefaults);
      await _remoteConfig.fetchAndActivate();

      _initialized = true;
      debugPrint('✅ Remote Config Service initialized');
      _logAllValues();
      logMissingConfigKeys();
    } catch (e) {
      debugPrint('❌ Remote Config Service initialization error: $e');
    }
  }

  // ==================== BACKEND / INTEGRATIONS ====================

  /// DEBUG ONLY — local API under test. Set to '' (or delete) before shipping.
  static const String _debugApiBaseUrl =
      '';

  /// Base URL for the DramaNow web API (e.g. https://example.com). Trailing slash optional.
  String get apiBaseUrl {
    if (kDebugMode && _debugApiBaseUrl.isNotEmpty) return _debugApiBaseUrl;
    return _getString('api_base_url');
  }

  String get appUrl => _getString('app_url');

  String get turnstileSiteKey => _getString('turnstile_site_key');

  bool get isCaptchaEnabled => _getBool('captcha_enabled');

  String get oneSignalAppId => _getString('onesignal_app_id');

  bool get isBackendConfigReady => apiBaseUrl.isNotEmpty;

  bool get isRevenueCatConfigReady {
    final entitlement = revenueCatProEntitlementId.trim();
    if (entitlement.isEmpty) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return revenueCatIosApiKey.trim().isNotEmpty;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return revenueCatAndroidApiKey.trim().isNotEmpty;
    }
    return false;
  }

  bool get isAdMobConfigReady {
    if (!isAdEnabled) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidInterstitialAdUnitId.trim().isNotEmpty &&
          androidBannerAdUnitId.trim().isNotEmpty;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return iosInterstitialAdUnitId.trim().isNotEmpty &&
          iosBannerAdUnitId.trim().isNotEmpty;
    }
    return false;
  }

  void logMissingConfigKeys() {
    if (!kDebugMode) return;
    const required = ['api_base_url'];
    final missing = <String>[
      for (final key in required)
        if (_getString(key).isEmpty) key,
    ];
    if (missing.isEmpty) return;
    debugPrint(
      '⚠️ Remote Config keys unset (set in Firebase Console): ${missing.join(', ')}',
    );
  }

  // ==================== ONBOARDING & LEGAL ====================

  bool get showReadyToStart => _getBool('show_ready_to_start');

  String get readyToStartHeadline => _getString('ready_to_start_headline');

  String get homeDefaultLocale {
    final locale = _getString('home_default_locale').trim();
    return locale.isNotEmpty ? locale : 'en';
  }

  String get termsUrl => _getString('terms_url');

  String get privacyUrl => _getString('privacy_url');

  // ==================== RADIOPOD FEATURE FLAGS ====================

  bool get featureOfflineDownloads => _getBool('feature_offline_downloads');

  bool get featurePremiumStations => _getBool('feature_premium_stations');

  bool get featurePremiumPodcasts => _getBool('feature_premium_podcasts');

  bool get premiumShowProBadges => _getBool('premium_show_pro_badges');

  /// `disabled` | `premium_content` | `all_playback`
  String get premiumPlaybackMode => _getString('premium_playback_mode');

  bool get featureHighQualityStreams => _getBool('feature_high_quality_streams');

  int get maxRadioPresets {
    final n = _getInt('max_radio_presets');
    return n > 0 ? n : 24;
  }

  bool get podcastAutoDownloadProOnly =>
      _getBool('podcast_auto_download_pro_only');

  int get podcastRefreshIntervalHours {
    final h = _getInt('podcast_refresh_interval_hours');
    return h > 0 ? h : 6;
  }

  // ==================== DISCOUNT OFFER ====================

  bool get discountOfferEnabled => _getBool('discount_offer_enabled');

  int get discountOfferTimerSeconds => _getInt('discount_offer_timer_seconds');

  int get discountOfferDelayMs => _getInt('discount_offer_delay_ms');

  int get discountOfferFrequencySeconds =>
      _getInt('discount_offer_frequency_seconds');

  int get discountOfferPaywallDismissThreshold =>
      _getInt('discount_offer_paywall_dismiss_threshold');

  String get discountOfferProductId => _getString('discount_offer_product_id');

  String get discountOfferDiscountText =>
      _getString('discount_offer_discount_text');

  bool get discountOfferShowBanner => _getBool('discount_offer_show_banner');

  // ==================== ADMOB ====================

  bool get isAdEnabled => _getBool('is_ad_enabled');

  String get androidInterstitialAdUnitId =>
      _getString('android_interstitial_ad_unit_id');

  String get iosInterstitialAdUnitId =>
      _getString('ios_interstitial_ad_unit_id');

  String get androidBannerAdUnitId => _getString('android_banner_ad_unit_id');

  String get iosBannerAdUnitId => _getString('ios_banner_ad_unit_id');

  String get androidRewardedAdUnitId =>
      _getString('android_rewarded_ad_unit_id');

  String get iosRewardedAdUnitId => _getString('ios_rewarded_ad_unit_id');

  /// Coins granted for watching a rewarded ad (defaults to 20).
  int get rewardAdCoins {
    final n = _getInt('reward_ad_coins');
    return n > 0 ? n : 20;
  }

  // ==================== REVENUECAT ====================

  String get revenueCatIosApiKey => _getString('revenuecat_ios_api_key');

  String get revenueCatAndroidApiKey =>
      _getString('revenuecat_android_api_key');

  String get revenueCatProEntitlementId =>
      _getString('revenuecat_pro_entitlement_id');

  // ==================== FORCE UPDATE — iOS ====================

  bool get iosForceUpdateEnabled => _getBool('ios_force_update_enabled');

  int get iosMinBuildNumber => _getInt('ios_min_build_number');

  int get iosLatestBuildNumber => _getInt('ios_latest_build_number');

  String get iosStoreUrl => _getString('ios_store_url');

  // ==================== FORCE UPDATE — Android ====================

  bool get androidForceUpdateEnabled => _getBool('android_force_update_enabled');

  int get androidMinBuildNumber => _getInt('android_min_build_number');

  int get androidLatestBuildNumber => _getInt('android_latest_build_number');

  String get androidStoreUrl => _getString('android_store_url');

  /// Legacy template top-up products — always empty/disabled in HERO DRAMA
  /// (coin packs are sold through RevenueCat, not Remote Config).
  List<String> get topUpProductIdList => const [];

  int get proDailySongLimit => 0;

  // ==================== HELPERS ====================

  bool _getBool(String key) {
    if (!_initialized) return false;
    try {
      return _remoteConfig.getBool(key);
    } catch (e) {
      return false;
    }
  }

  int _getInt(String key) {
    if (!_initialized) return 0;
    try {
      return _remoteConfig.getInt(key);
    } catch (e) {
      return 0;
    }
  }

  String _getString(String key) {
    if (!_initialized) return '';
    try {
      return _remoteConfig.getString(key);
    } catch (e) {
      return '';
    }
  }

  Future<void> fetchConfig() async {
    try {
      await _remoteConfig.fetchAndActivate();
      debugPrint('✅ Remote config fetched and activated');
      _logAllValues();
      logMissingConfigKeys();
    } catch (e) {
      debugPrint('❌ Error fetching remote config: $e');
    }
  }

  String _sourceLabel(String key) {
    final source = _remoteConfig.getValue(key).source;
    switch (source) {
      case ValueSource.valueRemote:
        return 'REMOTE';
      case ValueSource.valueDefault:
        return 'DEFAULT';
      case ValueSource.valueStatic:
        return 'STATIC';
    }
  }

  void _logAllValues() {
    if (!kDebugMode) return;

    const sections = <String, List<String>>{
      'Backend / integrations': [
        'api_base_url',
        'app_url',
        'turnstile_site_key',
        'captcha_enabled',
        'onesignal_app_id',
      ],
      'Onboarding & legal': [
        'show_ready_to_start',
        'ready_to_start_headline',
        'home_default_locale',
        'terms_url',
        'privacy_url',
      ],
      'RadioPod features': [
        'feature_offline_downloads',
        'feature_premium_stations',
        'feature_premium_podcasts',
        'feature_high_quality_streams',
        'premium_playback_mode',
        'premium_show_pro_badges',
        'max_radio_presets',
        'podcast_auto_download_pro_only',
        'podcast_refresh_interval_hours',
      ],
      'Discount offer': [
        'discount_offer_enabled',
        'discount_offer_timer_seconds',
        'discount_offer_delay_ms',
        'discount_offer_frequency_seconds',
        'discount_offer_paywall_dismiss_threshold',
        'discount_offer_product_id',
        'discount_offer_discount_text',
        'discount_offer_show_banner',
      ],
      'AdMob': [
        'is_ad_enabled',
        'android_interstitial_ad_unit_id',
        'ios_interstitial_ad_unit_id',
        'android_banner_ad_unit_id',
        'ios_banner_ad_unit_id',
        'android_rewarded_ad_unit_id',
        'ios_rewarded_ad_unit_id',
        'reward_ad_coins',
      ],
      'RevenueCat': [
        'revenuecat_ios_api_key',
        'revenuecat_android_api_key',
        'revenuecat_pro_entitlement_id',
      ],
      'Force update — iOS': [
        'ios_force_update_enabled',
        'ios_min_build_number',
        'ios_latest_build_number',
        'ios_store_url',
      ],
      'Force update — Android': [
        'android_force_update_enabled',
        'android_min_build_number',
        'android_latest_build_number',
        'android_store_url',
      ],
    };

    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════');
    debugPrint('║ 📋 REMOTE CONFIG VALUES (DramaNow)');
    debugPrint('╠══════════════════════════════════════════════════');

    for (final entry in sections.entries) {
      debugPrint('║ ── ${entry.key} ──');
      for (final key in entry.value) {
        final value = _remoteConfig.getValue(key).asString();
        final source = _sourceLabel(key);
        final display = _maskSensitiveValue(key, value);
        debugPrint('║ [$source] $key = $display');
      }
    }

    debugPrint('╚══════════════════════════════════════════════════');
    debugPrint('');
  }

  String _maskSensitiveValue(String key, String value) {
    final isSensitive = key.contains('api_key') ||
        key.contains('anon_key') ||
        key == 'onesignal_app_id';
    if (!isSensitive || value.isEmpty || value.length <= 12) return value;
    return '${value.substring(0, 8)}...${value.substring(value.length - 4)}';
  }
}
