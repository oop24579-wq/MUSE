import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import 'package:drama_now/models/user/user_model.dart';
import 'package:drama_now/services/auth/auth_service.dart';
import 'package:drama_now/services/marketing/marketing_analytics_service.dart';
import 'package:drama_now/services/onesignal_service.dart';
import 'package:drama_now/services/revenuecat_service.dart';

/// User provider to manage app-wide user state.
class UserProvider extends ChangeNotifier {
  UserModel? _user;
  fb.User? _fbUser;
  bool _isLoading = true;
  bool _hasActiveSubscriptionRow = false;
  String? _activePlanId;

  UserModel? get user => _user;
  fb.User? get fbUser => _fbUser;

  /// Backward-compatible alias previously exposing auth user.
  fb.User? get sbUser => _fbUser;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _fbUser != null;
  bool get isAnonymous =>
      _fbUser?.isAnonymous ?? (_user?.isAnonymous ?? true);
  String? get userId => AuthService.instance.currentUserId;

  String? get activePlanId => _activePlanId;

  UserProvider() {
    _initialize();
  }

  Future<void>? _backgroundRefreshFuture;

  bool get isPro => (_user?.isPro ?? false) || _hasActiveSubscriptionRow;

  Future<void> _initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      AuthService.instance.authStateChanges.listen((fb.User? user) async {
        _fbUser = user;
        if (user != null) {
          await _loadUserData();
        } else {
          unawaited(OneSignalService.clearUserSession());
          _user = null;
          _activePlanId = null;
          _hasActiveSubscriptionRow = false;
          _isLoading = false;
          notifyListeners();
        }
      });

      AuthService.instance.authEpoch.addListener(() {
        unawaited(refreshUserInBackground());
      });

      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null) {
        _fbUser = currentUser;
        await _loadUserData();
      } else {
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error initializing UserProvider: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserData({bool syncProStatus = false, bool silent = false}) async {
    try {
      if (!silent) {
        _isLoading = true;
        notifyListeners();
      }

      _fbUser = AuthService.instance.currentUser ?? _fbUser;
      _user =
          await AuthService.instance.fetchMe() ?? AuthService.instance.webProfile;

      if (syncProStatus && _user != null) {
        try {
          await RevenueCatService.crossCheckProStatus();
          _user = await AuthService.instance.fetchMe() ?? _user;
        } catch (e) {
          debugPrint('⚠️ Error syncing pro status: $e');
        }
      }

      _hasActiveSubscriptionRow = _user?.isPro ?? false;
      _activePlanId = null;

      if (_user != null) {
        unawaited(OneSignalService.syncUserSession(
          userId: _user!.id,
          email: _fbUser?.email,
          isPro: isPro,
        ));
        MarketingAnalyticsService.instance.updateUserContext(
          isPro: isPro,
          isAnonymous: _fbUser?.isAnonymous ?? _user!.isAnonymous,
        );
      }

      if (!silent) {
        _isLoading = false;
        notifyListeners();
      } else {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshUser({bool syncProStatus = false}) async {
    _fbUser = AuthService.instance.currentUser ?? _fbUser;
    if (_fbUser != null) {
      await _loadUserData(syncProStatus: syncProStatus);
    }
  }

  Future<void> refreshUserInBackground({bool syncProStatus = false}) async {
    _fbUser = AuthService.instance.currentUser ?? _fbUser;
    if (_fbUser == null) return;
    _backgroundRefreshFuture ??=
        _loadUserData(syncProStatus: syncProStatus, silent: true);
    try {
      await _backgroundRefreshFuture;
    } finally {
      _backgroundRefreshFuture = null;
    }
  }

  Future<void> waitForBackgroundRefresh() async {
    if (_backgroundRefreshFuture != null) {
      await _backgroundRefreshFuture;
      return;
    }
    await refreshUserInBackground(syncProStatus: true);
  }

  /// Kept for call-site compatibility; profile refresh covers guest upgrades.
  void listenForMigrationComplete() {
    unawaited(refreshUserInBackground(syncProStatus: true));
  }

  Stream<UserModel?>? streamUser() {
    return null;
  }
}
