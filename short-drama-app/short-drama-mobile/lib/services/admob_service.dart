import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'firebase/remote_config_service.dart';

class AdmobService {
  static final AdmobService _instance = AdmobService._internal();
  static AdmobService get instance => _instance;
  AdmobService._internal();

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isLoadingRewarded = false;
  Completer<bool>? _loadCompleter;

  bool get isAdsEnabled => RemoteConfigService.instance.isAdEnabled;

  String get rewardedAdUnitId {
    final rc = RemoteConfigService.instance;
    return (Platform.isAndroid
            ? rc.androidRewardedAdUnitId
            : rc.iosRewardedAdUnitId)
        .trim();
  }

  bool get isRewardedReady => _rewardedAd != null;

  String get interstitialAdUnitId {
    final rc = RemoteConfigService.instance;
    if (Platform.isAndroid) {
      return rc.androidInterstitialAdUnitId.trim();
    }
    return rc.iosInterstitialAdUnitId.trim();
  }

  String get bannerAdUnitId {
    final rc = RemoteConfigService.instance;
    if (Platform.isAndroid) {
      return rc.androidBannerAdUnitId.trim();
    }
    return rc.iosBannerAdUnitId.trim();
  }

  bool get _hasAdUnitIds =>
      interstitialAdUnitId.isNotEmpty && bannerAdUnitId.isNotEmpty;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (!isAdsEnabled) {
      debugPrint('[AdMob] Ads disabled via Remote Config');
      return;
    }
    if (!RemoteConfigService.instance.isAdMobConfigReady) {
      debugPrint(
        '[AdMob] Ad unit IDs missing — set android/ios *_ad_unit_id in Firebase Remote Config',
      );
      return;
    }

    debugPrint('[AdMob] Initializing MobileAds SDK...');
    await MobileAds.instance.initialize();
    _isInitialized = true;
    debugPrint('[AdMob] SDK initialized');
    loadInterstitialAd();
    loadRewardedAd();
  }

  Future<bool> loadRewardedAd() {
    if (!isAdsEnabled || rewardedAdUnitId.isEmpty) return Future.value(false);
    if (_rewardedAd != null) return Future.value(true);
    if (_isLoadingRewarded) return Future.value(false);

    _isLoadingRewarded = true;
    final completer = Completer<bool>();
    debugPrint('[AdMob] Loading rewarded ad...');
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoadingRewarded = false;
          debugPrint('[AdMob] Rewarded ad loaded');
          if (!completer.isCompleted) completer.complete(true);
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdMob] Rewarded failed to load: ${error.message}');
          _rewardedAd = null;
          _isLoadingRewarded = false;
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
    );
    return completer.future;
  }

  /// Shows a rewarded ad and returns true only if the user earned the reward
  /// (i.e. watched long enough). Loads on demand if not preloaded.
  Future<bool> showRewardedAd({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (!isAdsEnabled || rewardedAdUnitId.isEmpty) return false;

    if (_rewardedAd == null) {
      final loaded = await loadRewardedAd().timeout(
        timeout,
        onTimeout: () => false,
      );
      if (!loaded || _rewardedAd == null) return false;
    }

    final ad = _rewardedAd!;
    _rewardedAd = null;
    var earned = false;
    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewardedAd();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdMob] Rewarded failed to show: ${error.message}');
        ad.dispose();
        loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('[AdMob] Reward earned: ${reward.amount}');
        earned = true;
      },
    );
    return completer.future;
  }

  Future<bool> loadInterstitialAd() {
    if (!isAdsEnabled || !_hasAdUnitIds) return Future.value(false);
    if (_interstitialAd != null) return Future.value(true);
    if (_isLoading && _loadCompleter != null) return _loadCompleter!.future;

    _isLoading = true;
    _loadCompleter = Completer<bool>();
    final completer = _loadCompleter!;

    debugPrint('[AdMob] Loading interstitial ad...');
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoading = false;
          debugPrint('[AdMob] Interstitial ad loaded successfully');
          if (!completer.isCompleted) completer.complete(true);
        },
        onAdFailedToLoad: (error) {
          debugPrint(
            '[AdMob] Interstitial failed to load: ${error.message} (code: ${error.code})',
          );
          _interstitialAd = null;
          _isLoading = false;
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
    );

    return completer.future;
  }

  Future<bool> showInterstitialAd({
    VoidCallback? onDismissed,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!isAdsEnabled || !_hasAdUnitIds) {
      onDismissed?.call();
      return false;
    }

    if (_interstitialAd == null) {
      debugPrint('[AdMob] Ad not ready, waiting for load...');
      final loaded = await loadInterstitialAd().timeout(
        timeout,
        onTimeout: () {
          debugPrint('[AdMob] Timed out waiting for ad to load');
          return false;
        },
      );
      if (!loaded || _interstitialAd == null) {
        debugPrint('[AdMob] Could not load ad in time, skipping');
        onDismissed?.call();
        return false;
      }
    }

    final completer = Completer<bool>();

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('[AdMob] Interstitial ad shown');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[AdMob] Interstitial ad dismissed');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        onDismissed?.call();
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdMob] Interstitial failed to show: ${error.message}');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        onDismissed?.call();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    debugPrint('[AdMob] Showing interstitial ad...');
    await _interstitialAd!.show();
    return completer.future;
  }

  bool get isInterstitialReady => _interstitialAd != null;
}
