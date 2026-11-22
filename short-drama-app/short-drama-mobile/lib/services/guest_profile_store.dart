import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Stable display name + bundled avatar for anonymous users (mirrors web:
/// `display_name` + `avatar_url` on the auth user, backed by [SharedPreferences]).
class GuestProfileStore {
  GuestProfileStore._();

  static const _prefsNameKey = 'guest_profile_name_v1';
  static const _prefsAvatarKey = 'guest_profile_avatar_v1';

  static const avatarAssetPaths = <String>[
    'assets/avatars/electronic_avatar.png',
    'assets/avatars/hip_hop_avatar.png',
    'assets/avatars/jazz_soul_avatar.png',
    'assets/avatars/metal_avatar.png',
    'assets/avatars/pop_avatar.png',
    'assets/avatars/rock_avatar.png',
  ];

  /// Stored anonymous avatars use the same bundled paths as the app assets
  /// (used as guest avatar).
  static bool isBundledAssetAvatar(String? url) =>
      url != null &&
      url.startsWith('assets/') &&
      (url.endsWith('.png') || url.endsWith('.jpg') || url.endsWith('.webp'));

  static Future<void> clearFor(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_prefsNameKey}_$userId');
    await prefs.remove('${_prefsAvatarKey}_$userId');
  }

  static Future<String> displayNameFor(String? userId) async {
    final key = '${_prefsNameKey}_$userId';
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(key);
    if (existing != null && existing.isNotEmpty) {
      if (existing.startsWith('Guest')) {
        final upgraded = _newAnonName();
        await prefs.setString(key, upgraded);
        return upgraded;
      }
      return existing;
    }

    final name = _newAnonName();
    await prefs.setString(key, name);
    return name;
  }

  static Future<String> avatarPathFor(String? userId) async {
    final key = '${_prefsAvatarKey}_$userId';
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(key);
    if (idx != null && idx >= 0 && idx < avatarAssetPaths.length) {
      return avatarAssetPaths[idx];
    }
    final h = userId?.hashCode ?? Random().nextInt(1 << 30);
    final i = h.abs() % avatarAssetPaths.length;
    await prefs.setInt(key, i);
    return avatarAssetPaths[i];
  }

  static String _newAnonName() {
    final n = 100000 + Random.secure().nextInt(900000);
    return 'anon$n';
  }
}
