import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../presentation/pricing/widgets/animated_paywall_collage.dart';
import 'revenuecat_service.dart';

/// Preloads RevenueCat offerings during splash / onboarding so the paywall
/// opens instantly instead of waiting on network calls.
class PaywallPreloadService {
  PaywallPreloadService._();
  static final PaywallPreloadService instance = PaywallPreloadService._();

  Offering? _cachedOffering;
  bool _isPreloading = false;
  Future<void>? _preloadFuture;

  Offering? get cachedOffering => _cachedOffering;
  bool get hasCachedOffering => _cachedOffering != null;

  void setCachedOffering(Offering? offering) {
    _cachedOffering = offering;
  }

  /// Fetches and caches the current offering. Safe to call multiple times.
  Future<void> preload({bool forceRefresh = false}) {
    if (!forceRefresh && _cachedOffering != null) {
      return Future.value();
    }
    _preloadFuture ??= _doPreload(forceRefresh: forceRefresh);
    return _preloadFuture!.whenComplete(() => _preloadFuture = null);
  }

  Future<void> _doPreload({required bool forceRefresh}) async {
    if (_isPreloading) return;
    _isPreloading = true;
    // Warm the animated paywall background posters ahead of open.
    AnimatedPaywallCollage.precacheImages();
    try {
      final offering = await RevenueCatService.getOfferingWithPaywall(
        forceRefresh: forceRefresh,
        useCache: false,
      );
      if (offering != null) {
        _cachedOffering = offering;
        debugPrint('✅ Paywall offering preloaded');
      }
    } catch (e) {
      debugPrint('⚠️ PaywallPreloadService: $e');
    } finally {
      _isPreloading = false;
    }
  }

  /// Refreshes the cache in the background without blocking callers.
  void refreshInBackground() {
    preload(forceRefresh: true).ignore();
  }
}
