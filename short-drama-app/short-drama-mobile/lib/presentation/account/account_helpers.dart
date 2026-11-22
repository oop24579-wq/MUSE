import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user/user_model.dart';
import '../../services/guest_profile_store.dart';

/// The 6 bundled avatars offered in the avatar picker.
const List<String> kAvatarAssets = GuestProfileStore.avatarAssetPaths;

/// True when [path] is one of the bundled `assets/avatars/...` images.
bool isBundledAvatar(String? path) =>
    path != null && GuestProfileStore.avatarAssetPaths.contains(path);

/// Sign-in provider label for the profile badge chip.
/// Firebase access is guarded so widget tests (no Firebase init) fall back
/// to the [UserModel] alone.
String providerLabel(UserModel? user) {
  if (user == null || user.isAnonymous) return 'Guest';
  try {
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser != null) {
      final ids = fbUser.providerData.map((p) => p.providerId).toList();
      if (ids.contains('google.com')) return 'Google';
      if (ids.contains('apple.com')) return 'Apple';
      if (ids.contains('password')) return 'Email';
    }
  } catch (_) {
    // Firebase not initialised (tests) — fall through to the heuristic.
  }
  return user.email != null && user.email!.isNotEmpty ? 'Email' : 'Guest';
}

/// Avatar widget: bundled asset → [Image.asset]; http(s) photo → network;
/// otherwise an initials circle derived from name/email.
Widget accountAvatar({
  required UserModel? user,
  required String displayName,
  double size = 60,
}) {
  final photo = user?.photoUrl;
  Widget inner;
  if (isBundledAvatar(photo)) {
    inner = Image.asset(photo!, fit: BoxFit.cover);
  } else if (photo != null &&
      photo.isNotEmpty &&
      (photo.startsWith('http://') || photo.startsWith('https://'))) {
    inner = Image.network(
      photo,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _initials(displayName),
    );
  } else {
    inner = _initials(displayName);
  }
  return Container(
    width: size,
    height: size,
    clipBehavior: Clip.antiAlias,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0x332196F3),
    ),
    child: inner,
  );
}

Widget _initials(String displayName) {
  final letter = displayName.trim().isNotEmpty
      ? displayName.trim()[0].toUpperCase()
      : 'G';
  return Center(
    child: Text(
      letter,
      style: const TextStyle(
        color: Color(0xFF2196F3),
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// Opens the in-app Legal page when the `/legal` route is registered;
/// callers should fall back to their existing legal handling on failure.
bool tryPushLegal(BuildContext context) {
  try {
    Navigator.of(context).pushNamed('/legal');
    return true;
  } catch (_) {
    return false;
  }
}
