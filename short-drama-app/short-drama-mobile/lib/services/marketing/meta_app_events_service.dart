import 'dart:io';

import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';

import 'marketing_event_names.dart';

/// Thin wrapper around Meta [FacebookAppEvents] SDK (v0.24.x API).
class MetaAppEventsService {
  static final MetaAppEventsService _instance = MetaAppEventsService._();
  static MetaAppEventsService get instance => _instance;

  MetaAppEventsService._();

  final FacebookAppEvents _meta = FacebookAppEvents();
  bool _initialized = false;
  bool _collectionEnabled = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _meta.setAutoLogAppEventsEnabled(false);
      debugPrint('✅ Meta App Events initialized (collection disabled until consent)');
    } catch (e) {
      debugPrint('❌ Meta App Events init error: $e');
    }
  }

  Future<void> setCollectionEnabled(bool enabled) async {
    _collectionEnabled = enabled;
    try {
      await _meta.setAutoLogAppEventsEnabled(enabled);
      if (enabled) {
        await _meta.activateApp();
      }
    } catch (e) {
      debugPrint('❌ Meta setCollectionEnabled error: $e');
    }
  }

  Future<void> setAdvertiserTracking({required bool enabled}) async {
    if (!Platform.isIOS) return;
    try {
      await _meta.setAdvertiserTracking(enabled: enabled, collectId: true);
    } catch (e) {
      debugPrint('❌ Meta setAdvertiserTracking error: $e');
    }
  }

  Future<void> setUserId(String? userId) async {
    if (!_collectionEnabled) return;
    try {
      if (userId == null || userId.isEmpty) {
        await _meta.clearUserID();
      } else {
        await _meta.setUserID(userId);
      }
    } catch (e) {
      debugPrint('❌ Meta setUserID error: $e');
    }
  }

  Future<void> setUserData({
    String? email,
    String? firstName,
    String? lastName,
  }) async {
    if (!_collectionEnabled) return;
    try {
      await _meta.setUserData(
        email: email,
        firstName: firstName,
        lastName: lastName,
      );
    } catch (e) {
      debugPrint('❌ Meta setUserData error: $e');
    }
  }

  Future<void> clearUser() async {
    try {
      await _meta.clearUserID();
      await _meta.clearUserData();
    } catch (e) {
      debugPrint('❌ Meta clearUser error: $e');
    }
  }

  Future<void> trackEvent(
    String eventName, {
    Map<String, Object?>? params,
    bool isSubscriptionPurchase = false,
  }) async {
    if (!_collectionEnabled) return;

    final p = _stringifyParams(params);

    try {
      switch (eventName) {
        case MarketingEventNames.signUp:
          await _meta.logCompletedRegistration(
            registrationMethod: p['method'] as String?,
          );
          break;

        case MarketingEventNames.login:
          await _meta.logEvent(name: eventName, parameters: p);
          break;

        case MarketingEventNames.purchase:
          await _logPurchase(p, isSubscription: isSubscriptionPurchase);
          break;

        case MarketingEventNames.beginCheckout:
          await _meta.logInitiatedCheckout(
            totalPrice: _toDouble(p['value']),
            currency: p['currency'] as String?,
            contentType: p['plan_name'] as String? ?? 'subscription',
            contentId: p['plan_id'] as String? ?? p['package_id'] as String?,
            numItems: 1,
          );
          break;

        case MarketingEventNames.viewPaywall:
          await _meta.logViewContent(
            id: p['trigger'] as String? ?? 'paywall',
            type: 'paywall',
            currency: p['currency'] as String?,
            price: _toDouble(p['value']),
          );
          break;

        case MarketingEventNames.onboardingCompleted:
          await _meta.logEvent(name: eventName, parameters: p);
          break;

        case MarketingEventNames.quickActionUsed:
          await _meta.logEvent(name: eventName, parameters: p);
          break;

        default:
          await _meta.logEvent(
            name: eventName,
            parameters: p,
            valueToSum: _toDouble(p['value']),
          );
      }

      if (kDebugMode) {
        debugPrint('📱 Meta event: $eventName $p');
      }
    } catch (e) {
      debugPrint('❌ Meta trackEvent error ($eventName): $e');
    }
  }

  Future<void> _logPurchase(
    Map<String, dynamic> p, {
    required bool isSubscription,
  }) async {
    final amount = _toDouble(p['value']) ?? 0;
    final currency = p['currency'] as String? ?? 'USD';
    final orderId = p['transaction_id'] as String? ?? '';

    if (isSubscription && orderId.isNotEmpty) {
      await _meta.logSubscribe(
        price: amount,
        currency: currency,
        orderId: orderId,
      );
    } else {
      await _meta.logPurchase(amount: amount, currency: currency, parameters: p);
    }
  }

  Future<void> flush() async {
    try {
      await _meta.flush();
    } catch (e) {
      debugPrint('❌ Meta flush error: $e');
    }
  }

  Map<String, dynamic> _stringifyParams(Map<String, Object?>? params) {
    if (params == null) return {};
    return params.map((k, v) {
      if (v == null) return MapEntry(k, null);
      if (v is String || v is num || v is bool) return MapEntry(k, v);
      return MapEntry(k, v.toString());
    });
  }

  double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
