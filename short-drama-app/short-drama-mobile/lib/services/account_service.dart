import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drama_now/models/user/coin_transaction.dart';
import 'package:drama_now/models/user/user_model.dart';
import 'package:drama_now/services/api/api_client.dart';
import 'package:drama_now/services/auth/auth_service.dart';

/// Testable seam for account/profile operations (same pattern as the auth
/// layer): screens depend on [AccountServiceBase] and default to the real
/// [AccountService]; widget tests inject a fake.
abstract class AccountServiceBase {
  Future<UserModel> updateProfile({
    String? name,
    String? image,
    bool? autoplayNext,
    String? videoQuality,
    String? locale,
    bool? notificationsEnabled,
  });

  Future<({List<CoinTransaction> items, int total})> fetchTransactions({
    int limit = 50,
    int offset = 0,
  });
}

/// Account operations backed by the web `/api/v1` contracts:
/// `PATCH /auth/me` and `GET /me/transactions`.
class AccountService extends AccountServiceBase {
  AccountService._();
  static final AccountService _instance = AccountService._();
  static AccountService get instance => _instance;

  /// SharedPreferences key the app reads for the local notifications mirror
  /// (same key OneSignalService uses).
  static const String notificationsEnabledKey = 'notifications_enabled';

  @override
  Future<UserModel> updateProfile({
    String? name,
    String? image,
    bool? autoplayNext,
    String? videoQuality,
    String? locale,
    bool? notificationsEnabled,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (image != null) 'image': image,
      if (autoplayNext != null) 'autoplayNext': autoplayNext,
      if (videoQuality != null) 'videoQuality': videoQuality,
      if (locale != null) 'locale': locale,
      if (notificationsEnabled != null)
        'notificationsEnabled': notificationsEnabled,
    };
    final data = await ApiClient.instance.patch('/auth/me', data: body);
    final userJson = data['user'] as Map<String, dynamic>;
    var parsed = UserModel.fromApi(userJson);

    // Keep AuthService.webProfile (and therefore UserProvider) in sync.
    try {
      parsed = await AuthService.instance.fetchMe() ?? parsed;
    } catch (e) {
      debugPrint('⚠️ updateProfile: fetchMe sync failed: $e');
    }

    if (notificationsEnabled != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(notificationsEnabledKey, notificationsEnabled);
      } catch (_) {}
    }
    return parsed;
  }

  @override
  Future<({List<CoinTransaction> items, int total})> fetchTransactions({
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await ApiClient.instance.get(
      '/me/transactions',
      query: {'limit': limit, 'offset': offset},
    );
    final rawItems = (data['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map>()
        .map((e) => CoinTransaction.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final total = (data['total'] as num?)?.toInt() ?? items.length;
    return (items: items, total: total);
  }
}
