import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists web API JWT pair and Prisma user id.
class TokenStore {
  TokenStore._();
  static final TokenStore instance = TokenStore._();

  static const _accessKey = 'api_access_token';
  static const _refreshKey = 'api_refresh_token';
  static const _webUserIdKey = 'api_web_user_id';
  static const _prevWebUserIdKey = 'api_prev_web_user_id';
  static const _pendingRelinkGuestAccessKey =
      'api_pending_relink_guest_access_token';
  static const _pendingRelinkGuestRefreshKey =
      'api_pending_relink_guest_refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _accessToken;
  String? _refreshToken;
  String? _webUserId;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get webUserId => _webUserId;

  Future<void> load() async {
    _accessToken = await _storage.read(key: _accessKey);
    _refreshToken = await _storage.read(key: _refreshKey);
    _webUserId = await _storage.read(key: _webUserIdKey);
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required String webUserId,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _webUserId = webUserId;
    await Future.wait([
      _storage.write(key: _accessKey, value: accessToken),
      _storage.write(key: _refreshKey, value: refreshToken),
      _storage.write(key: _webUserIdKey, value: webUserId),
    ]);
  }

  Future<void> clear() async {
    final previous = _webUserId;
    _accessToken = null;
    _refreshToken = null;
    _webUserId = null;
    await Future.wait([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
      _storage.delete(key: _webUserIdKey),
    ]);
    if (previous != null && previous.isNotEmpty) {
      await _storage.write(key: _prevWebUserIdKey, value: previous);
    }
  }

  /// Guest web user id pending relink after Firebase UID change.
  Future<String?> consumePendingRelinkFromUserId() async {
    final id = await _storage.read(key: _prevWebUserIdKey);
    if (id != null) {
      await _storage.delete(key: _prevWebUserIdKey);
    }
    return id;
  }

  /// FIX-2 V5: guest session tokens captured at the moment the guest
  /// identity is remembered for relink, so the backend relink call can
  /// prove ownership of the guest account. Persisted (secure storage)
  /// because the token exchange overwrites the live session tokens and
  /// the relink may happen on a later exchange.
  Future<void> setPendingRelinkGuestProof({
    String? accessToken,
    String? refreshToken,
  }) async {
    await Future.wait([
      if (accessToken != null && accessToken.isNotEmpty)
        _storage.write(key: _pendingRelinkGuestAccessKey, value: accessToken)
      else
        _storage.delete(key: _pendingRelinkGuestAccessKey),
      if (refreshToken != null && refreshToken.isNotEmpty)
        _storage.write(key: _pendingRelinkGuestRefreshKey, value: refreshToken)
      else
        _storage.delete(key: _pendingRelinkGuestRefreshKey),
    ]);
  }

  Future<String?> consumePendingRelinkGuestAccessToken() async {
    final v = await _storage.read(key: _pendingRelinkGuestAccessKey);
    if (v != null) await _storage.delete(key: _pendingRelinkGuestAccessKey);
    return v;
  }

  Future<String?> consumePendingRelinkGuestRefreshToken() async {
    final v = await _storage.read(key: _pendingRelinkGuestRefreshKey);
    if (v != null) await _storage.delete(key: _pendingRelinkGuestRefreshKey);
    return v;
  }

  Future<void> setPendingRelinkFromUserId(String? userId) async {
    if (userId == null || userId.isEmpty) {
      await _storage.delete(key: _prevWebUserIdKey);
      return;
    }
    await _storage.write(key: _prevWebUserIdKey, value: userId);
  }
}
