import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:drama_now/services/auth/auth_service.dart';
import 'package:drama_now/core/test_flags.dart';
import 'package:drama_now/services/firebase/remote_config_service.dart';
import 'package:drama_now/services/paywall_preload_service.dart';

/// Service for managing RevenueCat subscriptions and entitlements.
/// Subscription rows are written by the web RevenueCat webhook using Prisma `User.id`.
class RevenueCatService {
  static bool _isConfigured = false;
  static String? _linkedAppUserId;

  static const String _debugRevenueCatApiKey = 'test_BHQcYdcAUoviVPPYESXaPHkqQzW';

  static bool get _useRevenueCatTestKey =>
      kDebugMode || TestFlags.useRevenueCatTestKey;

  static String mapStoreProductToPlanId(String productId) {
    final lower = productId.toLowerCase();
    if (lower.contains('max')) {
      if (lower.contains('week')) return 'max-weekly';
      if (lower.contains('month') || lower.contains('monthly')) {
        return 'max-monthly';
      }
      if (lower.contains('year') ||
          lower.contains('annual') ||
          lower.contains('yearly')) {
        return 'max-yearly';
      }
    }
    if (lower.contains('plus')) {
      if (lower.contains('week')) return 'plus-weekly';
      if (lower.contains('month') || lower.contains('monthly')) {
        return 'plus-monthly';
      }
      if (lower.contains('year') ||
          lower.contains('annual') ||
          lower.contains('yearly')) {
        return 'plus-yearly';
      }
    }
    if (lower.contains('week')) return 'weekly';
    if (lower.contains('month') || lower.contains('monthly')) {
      return 'monthly';
    }
    if (lower.contains('year') ||
        lower.contains('annual') ||
        lower.contains('yearly')) {
      return 'yearly';
    }
    return 'weekly';
  }

  static Future<void> initialize() async {
    try {
      final rc = RemoteConfigService.instance;
      final entitlement = rc.revenueCatProEntitlementId.trim();
      if (entitlement.isEmpty) {
        debugPrint(
          '⚠️ RevenueCat: set revenuecat_pro_entitlement_id in Remote Config',
        );
        return;
      }

      final String apiKey;
      if (_useRevenueCatTestKey) {
        apiKey = _debugRevenueCatApiKey;
        debugPrint(
          '🧪 RevenueCat: using test API key'
          '${kDebugMode ? ' (debug build)' : ' (TestFlags.useRevenueCatTestKey)'}',
        );
      } else {
        if (!rc.isRevenueCatConfigReady) {
          debugPrint(
            '⚠️ RevenueCat: set revenuecat_* keys in Firebase Remote Config',
          );
          return;
        }
        apiKey = Platform.isIOS
            ? rc.revenueCatIosApiKey.trim()
            : rc.revenueCatAndroidApiKey.trim();
      }

      await Purchases.configure(PurchasesConfiguration(apiKey));
      _isConfigured = true;
      debugPrint('✅ RevenueCat configured');
    } on PlatformException catch (e) {
      _isConfigured = false;
      debugPrint('❌ RevenueCat PlatformException: ${e.message}');
    } catch (e) {
      _isConfigured = false;
      debugPrint('❌ Failed to initialize RevenueCat: $e');
    }
  }

  static bool get isConfigured => _isConfigured;

  static Future<bool> hasProEntitlement() async {
    if (!_isConfigured) return false;
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey(proEntitlementId);
    } catch (e) {
      return false;
    }
  }

  static Future<CustomerInfo> getCustomerInfo() async {
    if (!_isConfigured) throw Exception('RevenueCat not configured');
    return await Purchases.getCustomerInfo();
  }

  static Future<CustomerInfo> restorePurchases() async {
    if (!_isConfigured) throw Exception('RevenueCat not configured');
    await linkPurchasesToAuth();
    final info = await Purchases.restorePurchases();
    await crossCheckProStatus();
    return info;
  }

  static Future<void> login(String userId) async {
    if (!_isConfigured) return;
    try {
      if (_linkedAppUserId != userId) {
        await Purchases.logIn(userId);
        _linkedAppUserId = userId;
        debugPrint('✅ RevenueCat login successful for: $userId');
      }
      await crossCheckProStatus();
    } catch (e) {
      debugPrint('❌ RevenueCat login failed: $e');
    }
  }

  /// Links RevenueCat to the web Prisma user id (`app_user_id`).
  static Future<bool> linkPurchasesToAuth([String? webUserId]) async {
    if (!_isConfigured) return false;
    try {
      final authenticated = await AuthService.instance.ensureAuthenticated();
      if (!authenticated) {
        debugPrint('⚠️ linkPurchasesToAuth: ensureAuthenticated failed');
        return false;
      }
      final uid = webUserId ?? AuthService.instance.currentUserId;
      if (uid == null) {
        debugPrint('⚠️ linkPurchasesToAuth: no web user id');
        return false;
      }
      if (_linkedAppUserId == uid) return true;
      await Purchases.logIn(uid);
      _linkedAppUserId = uid;
      debugPrint('✅ RevenueCat linked to web user id: $uid');
      return true;
    } catch (e) {
      debugPrint('❌ linkPurchasesToAuth failed: $e');
      return false;
    }
  }

  static Future<void> logout() async {
    if (!_isConfigured) return;
    try {
      await Purchases.logOut();
      _linkedAppUserId = null;
      PaywallPreloadService.instance.setCachedOffering(null);
      debugPrint('✅ RevenueCat logout successful');
    } catch (e) {
      debugPrint('❌ RevenueCat logout failed: $e');
    }
  }

  static Future<void> logOut() => logout();

  static Future<Offering?> getOfferingWithPaywall({
    bool forceRefresh = false,
    bool useCache = true,
  }) async {
    if (!_isConfigured) return null;

    if (!forceRefresh && useCache) {
      final cached = PaywallPreloadService.instance.cachedOffering;
      if (cached != null) return cached;
    }

    try {
      await linkPurchasesToAuth();
      final Offerings offerings = await Purchases.getOfferings();

      Offering? offering;
      if (offerings.current != null) {
        offering = offerings.current;
      } else if (offerings.all.isNotEmpty) {
        offering = offerings.all.values.first;
      }

      if (offering != null) {
        PaywallPreloadService.instance.setCachedOffering(offering);
      }
      return offering;
    } catch (e) {
      return PaywallPreloadService.instance.cachedOffering;
    }
  }

  static String get proEntitlementId =>
      RemoteConfigService.instance.revenueCatProEntitlementId.trim();

  static Future<void> syncSubscriptionOwnershipFromRevenueCat([
    CustomerInfo? customerInfo,
  ]) async {
    // Webhook owns subscription rows; client only refreshes profile.
    await crossCheckProStatus();
  }

  static Future<StoreProduct?> getDiscountProduct(String identifier) async {
    if (!_isConfigured) return null;
    try {
      await linkPurchasesToAuth();
      final offerings = await Purchases.getOfferings();

      final offering = offerings.all[identifier];
      if (offering != null && offering.availablePackages.isNotEmpty) {
        return offering.availablePackages.first.storeProduct;
      }

      for (final o in offerings.all.values) {
        for (final pkg in o.availablePackages) {
          if (pkg.storeProduct.identifier.contains(identifier)) {
            return pkg.storeProduct;
          }
        }
      }

      final products = await Purchases.getProducts([identifier]);
      if (products.isNotEmpty) return products.first;

      return null;
    } catch (e) {
      debugPrint('❌ Failed to get discount product ($identifier): $e');
      return null;
    }
  }

  static Future<void> syncProStatus() async {
    try {
      await crossCheckProStatus();
    } catch (e) {
      debugPrint('❌ Error syncing pro status: $e');
    }
  }

  /// Effective Pro = RevenueCat entitlement OR web profile `isPro`.
  static Future<bool> crossCheckProStatus() async {
    if (!_isConfigured) return false;
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) {
        debugPrint('⚠️ Cannot check pro status: No user ID');
        return false;
      }

      CustomerInfo? customerInfo;
      try {
        customerInfo = await Purchases.getCustomerInfo();
      } catch (e) {
        debugPrint('⚠️ RevenueCat getCustomerInfo failed: $e');
        final profile = await AuthService.instance.fetchMe();
        return profile?.isPro ?? false;
      }

      final revenueCatHasPro =
          customerInfo.entitlements.active.containsKey(proEntitlementId);
      final profile = await AuthService.instance.fetchMe();
      final profilePro = profile?.isPro ?? false;
      final effective = revenueCatHasPro || profilePro;
      debugPrint(
        '🔍 Pro status RC=$revenueCatHasPro profile=$profilePro → $effective',
      );
      return effective;
    } catch (e) {
      debugPrint('❌ Error cross-checking pro status: $e');
      return false;
    }
  }

  /// After purchase: webhook writes Subscription; client refreshes Pro from RC + /me.
  static Future<void> saveSubscriptionAfterPurchase(
    CustomerInfo customerInfo,
    StoreTransaction? storeTransaction,
  ) async {
    try {
      debugPrint('💾 Purchase complete — Subscription INSERT is server/webhook only.');
      if (!await linkPurchasesToAuth()) {
        debugPrint('⚠️ Post-purchase sync: linkPurchasesToAuth failed');
      }
      await crossCheckProStatus();
      // Brief poll for webhook profile update
      for (var attempt = 0; attempt < 8; attempt++) {
        final profile = await AuthService.instance.fetchMe();
        if (profile?.isPro == true) {
          debugPrint('✅ Profile isPro after purchase (attempt ${attempt + 1})');
          return;
        }
        await Future<void>.delayed(Duration(milliseconds: 400 + (attempt * 150)));
      }
      await crossCheckProStatus();
    } catch (e, stackTrace) {
      debugPrint('❌ Error post-purchase sync: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
