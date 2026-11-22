import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:drama_now/services/api/api_exception.dart';
import 'package:drama_now/services/api/token_store.dart';
import 'package:drama_now/services/device_id_service.dart';
import 'package:drama_now/services/firebase/remote_config_service.dart';

typedef FirebaseReExchange = Future<bool> Function();

/// HTTP client for DramaNow `/api/v1` (Bearer JWT + envelope unwrap).
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Dio? _dio;
  FirebaseReExchange? onRefreshFailedReExchange;
  bool _refreshing = false;

  // --- Round 4: global maintenance handling ---------------------------------
  /// Invoked ONCE per maintenance episode when any request fails with
  /// 503 MAINTENANCE, so the app shell can route to the MaintenanceScreen.
  /// Set by bootstrap to a navigator push. The latch stops a burst of
  /// failing requests from stacking maintenance screens; the screen clears
  /// it via [clearMaintenanceLatch] after a successful /config re-check,
  /// so a LATER maintenance episode routes again.
  void Function()? onMaintenance;
  bool _maintenanceLatched = false;

  void clearMaintenanceLatch() => _maintenanceLatched = false;

  void _noteMaintenance(ApiException e) {
    if (e.statusCode != 503 || e.code != 'MAINTENANCE') return;
    if (_maintenanceLatched) return;
    _maintenanceLatched = true;
    final hook = onMaintenance;
    if (hook != null) {
      try {
        hook();
      } catch (_) {/* routing must never break error handling */}
    }
  }

  // Device context. The API's `mobile.context` middleware keeps
  // `users.platform` / `app_version` / `locale` and the `user_devices` row
  // current from these headers; without them every mobile account lands in the
  // panel with those columns null. Cached because the request interceptor is
  // synchronous and both lookups are async.
  String? _appVersion;
  String? _deviceId;
  Future<void>? _priming;

  /// Resolves the device headers once. Safe to call repeatedly; awaiting it
  /// during start-up means the very first request already carries them.
  Future<void> primeContext() {
    return _priming ??= _resolveContext();
  }

  Future<void> _resolveContext() async {
    try {
      _appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {/* header is optional — the server tolerates its absence */}
    try {
      _deviceId = await DeviceIdService.instance.getDeviceId();
    } catch (_) {}
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name; // android | iOS | macOS | …
  }

  Dio get dio {
    _dio ??= _createDio();
    return _dio!;
  }

  void reset() {
    _dio?.close(force: true);
    _dio = null;
  }

  Dio _createDio() {
    final baseUrl = RemoteConfigService.instance.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    final dio = Dio(
      BaseOptions(
        baseUrl: '$baseUrl/api/v1',
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = TokenStore.instance.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['X-Platform'] = _platform;
          options.headers['X-Locale'] =
              ui.PlatformDispatcher.instance.locale.languageCode;
          if (_appVersion != null) {
            options.headers['X-App-Version'] = _appVersion;
          }
          if (_deviceId != null) {
            options.headers['X-Device-Id'] = _deviceId;
          } else {
            // Not yet resolved: kick the lookup off so the next request has it
            // rather than blocking this one.
            unawaited(primeContext());
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 && !_refreshing) {
            final recovered = await _tryRefreshOrReExchange();
            if (recovered) {
              try {
                final opts = error.requestOptions;
                opts.headers['Authorization'] =
                    'Bearer ${TokenStore.instance.accessToken}';
                final clone = await dio.fetch(opts);
                return handler.resolve(clone);
              } catch (e) {
                return handler.next(error);
              }
            }
          }
          handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: false, responseBody: false, error: true),
      );
    }

    return dio;
  }

  Future<bool> _tryRefreshOrReExchange() async {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final refresh = TokenStore.instance.refreshToken;
      if (refresh != null && refresh.isNotEmpty) {
        try {
          final baseUrl =
              RemoteConfigService.instance.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
          final bare = Dio(
            BaseOptions(
              baseUrl: '$baseUrl/api/v1',
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ),
          );
          final res = await bare.post(
            '/auth/refresh',
            data: {'refreshToken': refresh},
          );
          final data = _unwrap(res.data);
          final tokens = data['tokens'] as Map<String, dynamic>?;
          final user = data['user'] as Map<String, dynamic>?;
          if (tokens != null && user != null) {
            await TokenStore.instance.save(
              accessToken: tokens['accessToken'] as String,
              refreshToken: tokens['refreshToken'] as String,
              webUserId: user['id'] as String,
            );
            return true;
          }
        } catch (e) {
          debugPrint('⚠️ Token refresh failed: $e');
        }
      }

      final reExchange = onRefreshFailedReExchange;
      if (reExchange != null) {
        return await reExchange();
      }
      return false;
    } finally {
      _refreshing = false;
    }
  }

  Map<String, dynamic> _unwrap(dynamic body) {
    if (body is! Map) {
      throw ApiException('INVALID_RESPONSE', 'Expected JSON object');
    }
    final map = Map<String, dynamic>.from(body);
    final error = map['error'];
    if (error != null) {
      if (error is Map) {
        throw ApiException(
          (error['code'] as String?) ?? 'API_ERROR',
          (error['message'] as String?) ?? 'Request failed',
        );
      }
      throw ApiException('API_ERROR', error.toString());
    }
    final data = map['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ApiException('INVALID_RESPONSE', 'Missing data envelope');
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await dio.get(path, queryParameters: query);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await dio.post(path, data: data, queryParameters: query);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Object? data,
  }) async {
    try {
      final res = await dio.patch(path, data: data);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  Future<Map<String, dynamic>> delete(String path) async {
    try {
      final res = await dio.delete(path);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  /// POST without requiring an existing Bearer token (e.g. auth/firebase).
  Future<Map<String, dynamic>> postUnauthenticated(
    String path, {
    Object? data,
  }) async {
    final baseUrl =
        RemoteConfigService.instance.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    final bare = Dio(
      BaseOptions(
        baseUrl: '$baseUrl/api/v1',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    try {
      final res = await bare.post(path, data: data);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  ApiException _fromDio(DioException e) {
    final data = e.response?.data;
    final ApiException out;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      out = ApiException(
        (err['code'] as String?) ?? 'HTTP_ERROR',
        (err['message'] as String?) ?? e.message ?? 'Request failed',
        statusCode: e.response?.statusCode,
      );
    } else {
      out = ApiException(
        'HTTP_ERROR',
        e.message ?? 'Request failed',
        statusCode: e.response?.statusCode,
      );
    }
    _noteMaintenance(out);
    return out;
  }
}
