import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:drama_now/models/user/user_model.dart';
import 'package:drama_now/services/api/api_client.dart';
import 'package:drama_now/services/api/token_store.dart';
import 'package:drama_now/services/consent_sync_service.dart';
import 'package:drama_now/services/device_id_service.dart';
import 'package:drama_now/services/guest_profile_store.dart';
import 'package:drama_now/services/marketing/marketing_analytics_service.dart';
import 'package:drama_now/services/marketing/marketing_funnel_events.dart';
import 'package:drama_now/services/onesignal_service.dart';
import 'package:drama_now/services/revenuecat_service.dart';

/// Firebase Auth + web JWT exchange.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  static AuthService get instance => _instance;

  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<User?>? _authStateSubscription;
  bool _initialized = false;
  bool _handlingAuthChange = false;
  UserModel? _webProfile;
  String? _pendingRelinkFromUserId;

  /// Bumped after successful exchange so UI can rebuild.
  final ValueNotifier<int> authEpoch = ValueNotifier<int>(0);

  UserModel? get webProfile => _webProfile;

  String? consumePendingRelinkFromUserId() {
    final id = _pendingRelinkFromUserId;
    _pendingRelinkFromUserId = null;
    return id;
  }

  void _rememberGuestForRelink() {
    final oldWebId = TokenStore.instance.webUserId;
    if (oldWebId == null || oldWebId.isEmpty) return;
    _pendingRelinkFromUserId = oldWebId;
    unawaited(TokenStore.instance.setPendingRelinkFromUserId(oldWebId));
    // FIX-2 V5: capture the guest session's tokens NOW — they are still
    // the live TokenStore tokens at this moment, and the upcoming token
    // exchange will overwrite them with the signed-in account's tokens.
    // The backend relink endpoint requires one of these as proof of
    // ownership of the guest account.
    unawaited(TokenStore.instance.setPendingRelinkGuestProof(
      accessToken: TokenStore.instance.accessToken,
      refreshToken: TokenStore.instance.refreshToken,
    ));
  }

  User? get currentUser => _auth.currentUser;
  String? get currentUserId =>
      TokenStore.instance.webUserId ?? _auth.currentUser?.uid;
  String? get firebaseUid => _auth.currentUser?.uid;
  bool get isAuthenticated => _auth.currentUser != null;
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await TokenStore.instance.load();
    await ApiClient.instance.primeContext();
    ApiClient.instance.onRefreshFailedReExchange =
        () => exchangeFirebaseToken(forceRefresh: true);

    User? previous = _auth.currentUser;
    if (previous != null) {
      await _onFirebaseUser(previous);
    }

    _authStateSubscription = _auth.authStateChanges().listen((user) async {
      if (_handlingAuthChange) return;
      if (user != null) {
        final wasAnonymous = previous?.isAnonymous ?? false;
        final previousFirebaseUid = previous?.uid;
        if (!user.isAnonymous &&
            wasAnonymous &&
            previousFirebaseUid != null &&
            previousFirebaseUid != user.uid) {
          _rememberGuestForRelink();
        }
        previous = user;
        await _onFirebaseUser(user);
      } else {
        previous = null;
        _webProfile = null;
        await TokenStore.instance.clear();
        ApiClient.instance.reset();
        authEpoch.value++;
      }
    });

    debugPrint('✅ Auth Service (Firebase + web exchange) initialized');
  }

  Future<void> dispose() async {
    await _authStateSubscription?.cancel();
    _authStateSubscription = null;
  }

  Future<bool> ensureAuthenticated() async {
    if (_auth.currentUser != null) {
      if (TokenStore.instance.accessToken == null) {
        return exchangeFirebaseToken();
      }
      return true;
    }
    final cred = await signInAnonymously();
    return cred != null;
  }

  Future<UserCredential?> signInAnonymously() async {
    try {
      debugPrint('🔐 Signing in anonymously with Firebase...');
      _handlingAuthChange = true;
      final cred = await _auth.signInAnonymously();
      await _onFirebaseUser(cred.user!);
      return cred;
    } catch (e) {
      debugPrint('❌ Anonymous sign-in error: $e');
      return null;
    } finally {
      _handlingAuthChange = false;
    }
  }

  Future<bool> exchangeFirebaseToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final idToken = await user.getIdToken(forceRefresh);
      if (idToken == null || idToken.isEmpty) return false;

      String? deviceId;
      try {
        deviceId = await DeviceIdService.instance.getDeviceId();
      } catch (_) {}

      final data = await ApiClient.instance.postUnauthenticated(
        '/auth/firebase',
        data: {
          'idToken': idToken,
          if (deviceId != null) 'deviceId': deviceId,
        },
      );

      // FIX-2 V5: snapshot the pre-exchange session (the guest session,
      // when a relink is pending) before save() overwrites it — used as
      // a fallback proof source if no persisted proof was captured.
      final preSaveWebUserId = TokenStore.instance.webUserId;
      final preSaveAccessToken = TokenStore.instance.accessToken;
      final preSaveRefreshToken = TokenStore.instance.refreshToken;

      final tokens = data['tokens'] as Map<String, dynamic>;
      final profileJson = data['user'] as Map<String, dynamic>;
      final webUserId = profileJson['id'] as String;

      await TokenStore.instance.save(
        accessToken: tokens['accessToken'] as String,
        refreshToken: tokens['refreshToken'] as String,
        webUserId: webUserId,
      );

      _webProfile = UserModel.fromApi(profileJson, firebaseUid: user.uid);

      final pending = consumePendingRelinkFromUserId() ??
          await TokenStore.instance.consumePendingRelinkFromUserId();
      if (pending != null &&
          pending.isNotEmpty &&
          pending != webUserId &&
          !user.isAnonymous) {
        try {
          // FIX-2 V5: present the guest account's own credential as
          // ownership proof (persisted proof captured in
          // _rememberGuestForRelink, falling back to the pre-exchange
          // session snapshot when it belongs to the pending guest).
          var guestAccess =
              await TokenStore.instance.consumePendingRelinkGuestAccessToken();
          var guestRefresh = await TokenStore.instance
              .consumePendingRelinkGuestRefreshToken();
          if ((guestAccess == null || guestAccess.isEmpty) &&
              preSaveWebUserId == pending) {
            guestAccess = preSaveAccessToken;
          }
          if ((guestRefresh == null || guestRefresh.isEmpty) &&
              preSaveWebUserId == pending) {
            guestRefresh = preSaveRefreshToken;
          }
          await ApiClient.instance.post(
            '/auth/relink',
            data: {
              'guestUserId': pending,
              if (guestAccess != null && guestAccess.isNotEmpty)
                'guestAccessToken': guestAccess,
              if (guestRefresh != null && guestRefresh.isNotEmpty)
                'guestRefreshToken': guestRefresh,
            },
          );
          debugPrint('✅ Relinked guest $pending → $webUserId');
          // Refresh profile after merge
          await fetchMe();
        } catch (e) {
          debugPrint('⚠️ Relink failed: $e');
        }
      }

      try {
        await RevenueCatService.linkPurchasesToAuth(webUserId);
      } catch (e) {
        debugPrint('⚠️ RevenueCat login failed: $e');
      }

      // Round 4: sync the on-device consent record (if one exists) to the
      // account — best-effort, never blocks the exchange.
      unawaited(ConsentSyncService.syncIfPossible());

      unawaited(OneSignalService.syncUserSession(
        userId: webUserId,
        email: user.email,
        isPro: _webProfile?.isPro ?? false,
      ));
      MarketingAnalyticsService.instance.updateUserContext(
        isPro: _webProfile?.isPro ?? false,
        isAnonymous: user.isAnonymous,
      );

      if (user.isAnonymous) {
        await GuestProfileStore.displayNameFor(webUserId);
        await GuestProfileStore.avatarPathFor(webUserId);
      }

      authEpoch.value++;
      return true;
    } catch (e) {
      debugPrint('❌ Firebase token exchange failed: $e');
      return false;
    }
  }

  Future<void> _onFirebaseUser(User user) async {
    await exchangeFirebaseToken(forceRefresh: true);
  }

  /// Link current anonymous session when possible; otherwise sign in and relink web data.
  Future<UserCredential> _upgradeOrSignIn(AuthCredential credential) async {
    final current = _auth.currentUser;
    final wasAnonymous = current?.isAnonymous ?? false;

    if (wasAnonymous && current != null) {
      try {
        return await current.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use' ||
            e.code == 'provider-already-linked') {
          _rememberGuestForRelink();
          // Drop anonymous Firebase user so we can sign in as the real account.
          try {
            await current.delete();
          } catch (_) {
            await _auth.signOut();
          }
          return _auth.signInWithCredential(credential);
        }
        rethrow;
      }
    }
    return _auth.signInWithCredential(credential);
  }

  /// Google via Firebase Auth native provider (uses `google-services.json` /
  /// `GoogleService-Info.plist` — no hardcoded Web client ID).
  Future<UserCredential> _upgradeOrSignInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile');

    final current = _auth.currentUser;
    final wasAnonymous = current?.isAnonymous ?? false;

    if (wasAnonymous && current != null) {
      try {
        return await current.linkWithProvider(provider);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use' ||
            e.code == 'provider-already-linked') {
          _rememberGuestForRelink();
          try {
            await current.delete();
          } catch (_) {
            await _auth.signOut();
          }
          return _auth.signInWithProvider(provider);
        }
        rethrow;
      }
    }
    return _auth.signInWithProvider(provider);
  }

  Future<bool> signInWithGoogle() async {
    try {
      debugPrint('🔐 Google sign-in via Firebase Auth provider...');
      _handlingAuthChange = true;

      final wasAnonymous = _auth.currentUser?.isAnonymous ?? false;
      final cred = await _upgradeOrSignInWithGoogle();
      await _onFirebaseUser(cred.user!);

      if (wasAnonymous) {
        await MarketingFunnelEvents.trackSignUp('google');
        await MarketingFunnelEvents.trackAccountLinked('google');
      } else {
        await MarketingFunnelEvents.trackLogin('google');
      }
      debugPrint(
        '✅ Google sign-in OK uid=${cred.user?.uid} guest=${cred.user?.isAnonymous}',
      );
      return true;
    } on FirebaseAuthException catch (e) {
      // User closed the account picker / cancelled.
      if (e.code == 'web-context-cancelled' ||
          e.code == 'canceled' ||
          e.code == 'ERROR_CANCELLED' ||
          e.code == 'sign_in_canceled') {
        debugPrint('⚠️ Google sign-in cancelled');
        return false;
      }
      debugPrint('❌ Google sign-in error: $e');
      return false;
    } catch (e) {
      debugPrint('❌ Google sign-in error: $e');
      return false;
    } finally {
      _handlingAuthChange = false;
    }
  }

  Future<bool> signInWithApple() async {
    try {
      _handlingAuthChange = true;
      final wasAnonymous = _auth.currentUser?.isAnonymous ?? false;

      final rawNonce = _generateNonce();
      final nonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      final cred = await _upgradeOrSignIn(oauthCredential);
      await _onFirebaseUser(cred.user!);

      if (wasAnonymous) {
        await MarketingFunnelEvents.trackSignUp('apple');
        await MarketingFunnelEvents.trackAccountLinked('apple');
      } else {
        await MarketingFunnelEvents.trackLogin('apple');
      }
      return true;
    } catch (e) {
      debugPrint('❌ Apple sign-in error: $e');
      return false;
    } finally {
      _handlingAuthChange = false;
    }
  }

  Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      _handlingAuthChange = true;
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );

      final cred = await _upgradeOrSignIn(credential);

      if (displayName != null && displayName.isNotEmpty) {
        await cred.user?.updateDisplayName(displayName);
        await cred.user?.reload();
      }

      await _onFirebaseUser(_auth.currentUser ?? cred.user!);
      await MarketingFunnelEvents.trackSignUp('email');
      return cred;
    } catch (e) {
      debugPrint('❌ Email sign-up error: $e');
      rethrow;
    } finally {
      _handlingAuthChange = false;
    }
  }

  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _handlingAuthChange = true;
      final current = _auth.currentUser;
      final wasAnonymous = current?.isAnonymous ?? false;
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );

      UserCredential cred;
      if (wasAnonymous && current != null) {
        // Prefer linking when this email isn't taken; otherwise switch + relink.
        try {
          cred = await current.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use' ||
              e.code == 'credential-already-in-use' ||
              e.code == 'provider-already-linked') {
            _rememberGuestForRelink();
            try {
              await current.delete();
            } catch (_) {
              await _auth.signOut();
            }
            cred = await _auth.signInWithEmailAndPassword(
              email: email.trim(),
              password: password,
            );
          } else if (e.code == 'invalid-credential' ||
              e.code == 'wrong-password') {
            // Email exists with different password — standard sign-in path.
            _rememberGuestForRelink();
            try {
              await current.delete();
            } catch (_) {
              await _auth.signOut();
            }
            cred = await _auth.signInWithEmailAndPassword(
              email: email.trim(),
              password: password,
            );
          } else {
            rethrow;
          }
        }
      } else {
        cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      }

      await _onFirebaseUser(cred.user!);
      await MarketingFunnelEvents.trackLogin('email');
      return cred;
    } catch (e) {
      debugPrint('❌ Email sign-in error: $e');
      rethrow;
    } finally {
      _handlingAuthChange = false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } catch (e) {
      debugPrint('❌ Password reset error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await RevenueCatService.logOut();
    } catch (_) {}
    await OneSignalService.clearUserSession();
    await TokenStore.instance.clear();
    ApiClient.instance.reset();
    _webProfile = null;
    await _auth.signOut();
    await signInAnonymously();
  }

  Future<bool> deleteAccount({String? password, UserModel? profile}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      try {
        await ApiClient.instance.delete('/auth/account');
      } catch (e) {
        debugPrint('⚠️ Web account delete failed: $e');
      }

      if (!user.isAnonymous &&
          password != null &&
          password.isNotEmpty &&
          user.email != null) {
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(cred);
      }

      await user.delete();
      await TokenStore.instance.clear();
      ApiClient.instance.reset();
      _webProfile = null;
      await signInAnonymously();
      return true;
    } catch (e) {
      debugPrint('❌ Delete account error: $e');
      return false;
    }
  }

  Future<UserModel?> fetchMe() async {
    try {
      final data = await ApiClient.instance.get('/auth/me');
      final userJson = data['user'] as Map<String, dynamic>;
      _webProfile = UserModel.fromApi(
        userJson,
        firebaseUid: _auth.currentUser?.uid,
      );
      return _webProfile;
    } catch (e) {
      debugPrint('⚠️ fetchMe failed: $e');
      return _webProfile;
    }
  }

  String getAuthErrorMessage(Object error) {
    if (error is PlatformException) {
      // Google Play Services ApiException: 10 = DEVELOPER_ERROR
      if (error.code == 'sign_in_failed' &&
          (error.message?.contains('10') ?? false)) {
        return 'Google Sign-In misconfigured (error 10). '
            'Use Web client ID from google-services.json and add this '
            'machine’s debug SHA-1 in Firebase Console → Project settings → Your apps.';
      }
      return error.message ?? error.code;
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Invalid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
          return 'No account found for this email.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'An account already exists for this email.';
        case 'weak-password':
          return 'Password is too weak.';
        case 'too-many-requests':
          return 'Too many attempts. Try again later.';
        case 'network-request-failed':
          return 'Network error. Check your connection.';
        case 'requires-recent-login':
          return 'Please sign in again to continue.';
        default:
          return error.message ?? 'Authentication failed.';
      }
    }
    return error.toString();
  }

  // ── Session restore / explicit sign-in gate (login flow) ──────────────
  // Added for the gated-auth flow: a fresh install must reach the login
  // screen with NO session instead of silently becoming a guest (see
  // bootstrap.dart). The methods below are additive; the existing
  // anonymous-first behaviour of [signOut]/[ensureAuthenticated] is
  // unchanged for their current callers.

  /// True when a web refresh token survived from a previous session.
  bool get hasStoredSession {
    final refresh = TokenStore.instance.refreshToken;
    return refresh != null && refresh.isNotEmpty;
  }

  /// Attempts to restore a previous web session.
  ///
  /// Returns false when there is no stored session. Otherwise asks the
  /// backend for the profile via [fetchMe] — [ApiClient] transparently
  /// refreshes the access token on a 401 (and falls back to a Firebase
  /// re-exchange), so an expired access token still restores. On failure
  /// the stored tokens are cleared so the next launch doesn't retry a
  /// dead session.
  Future<bool> restoreSession() async {
    if (!hasStoredSession) return false;
    try {
      // fetchMe() swallows API errors and returns the cached profile
      // (null on a cold start), so capture whether THIS call produced a
      // fresh profile by clearing the cache first.
      _webProfile = null;
      final profile = await fetchMe();
      if (profile != null) return true;
    } catch (e) {
      debugPrint('⚠️ restoreSession failed: $e');
    }
    await TokenStore.instance.clear();
    ApiClient.instance.reset();
    _webProfile = null;
    return false;
  }

  /// Explicit guest entry from the login screen ("Continue as Guest").
  Future<bool> signInAsGuest() async {
    try {
      final cred = await signInAnonymously();
      if (cred == null) return false;
      // signInAnonymously already exchanges via _onFirebaseUser; make
      // sure the web session exists before reporting success.
      if (TokenStore.instance.accessToken == null) {
        return await exchangeFirebaseToken();
      }
      return true;
    } catch (e) {
      debugPrint('❌ Guest sign-in error: $e');
      return false;
    }
  }

  /// Full sign-out that lands the user on the login screen.
  ///
  /// Unlike [signOut] (which immediately re-signs-in anonymously for its
  /// existing in-app callers), this revokes the session server-side and
  /// leaves the app with NO session at all.
  Future<void> signOutToLogin() async {
    // Best-effort server-side revocation of the whole refresh family.
    try {
      final refresh = TokenStore.instance.refreshToken;
      await ApiClient.instance.post(
        '/auth/logout',
        data: {
          if (refresh != null && refresh.isNotEmpty)
            'refreshToken': refresh,
        },
      );
    } catch (e) {
      debugPrint('⚠️ /auth/logout failed (continuing local sign-out): $e');
    }
    try {
      await RevenueCatService.logOut();
    } catch (_) {}
    try {
      await OneSignalService.clearUserSession();
    } catch (_) {}
    await TokenStore.instance.clear();
    ApiClient.instance.reset();
    _webProfile = null;
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('⚠️ Firebase signOut failed: $e');
    }
    // Deliberately NO anonymous re-sign-in here — the login gate owns
    // the next session.
    authEpoch.value++;
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }
}
