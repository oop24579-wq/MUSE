/// App user profile (sourced from web `/api/v1/auth/me` / Firebase exchange).
class UserModel {
  final String id; // Prisma / web user id
  final String uid; // Firebase Auth UID
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? deviceId;
  final String? subscriptionExpirationDate;
  final bool isAnonymous;
  final bool isPro;
  final int coinBalance;
  final bool autoplayNext;
  final String videoQuality;
  final bool notificationsEnabled;
  final String? locale;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.deviceId,
    this.subscriptionExpirationDate,
    this.isAnonymous = true,
    this.isPro = false,
    this.coinBalance = 0,
    this.autoplayNext = true,
    this.videoQuality = 'auto',
    this.notificationsEnabled = true,
    this.locale,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isVip => isPro;

  /// Map from web `MobileUserProfile` JSON.
  factory UserModel.fromApi(
    Map<String, dynamic> json, {
    String? firebaseUid,
  }) {
    final createdAt = json['createdAt'] as String?;
    final linkedAt = json['linkedAt'] as String?;
    final now = DateTime.now().toUtc();
    return UserModel(
      id: json['id'] as String,
      uid: firebaseUid ?? (json['firebaseUid'] as String?) ?? (json['id'] as String),
      email: json['email'] as String?,
      displayName: (json['name'] ?? json['displayName']) as String?,
      photoUrl: (json['image'] ?? json['photoUrl']) as String?,
      deviceId: json['deviceId'] as String?,
      subscriptionExpirationDate: json['subscriptionExpirationDate'] as String?,
      isAnonymous: (json['isGuest'] as bool?) ??
          (json['isAnonymous'] as bool?) ??
          true,
      isPro: (json['isPro'] as bool?) ?? false,
      coinBalance: (json['coinBalance'] as num?)?.toInt() ?? 0,
      autoplayNext: (json['autoplayNext'] as bool?) ?? true,
      videoQuality: (json['videoQuality'] as String?) ?? 'auto',
      notificationsEnabled: (json['notificationsEnabled'] as bool?) ?? true,
      locale: json['locale'] as String?,
      createdAt: createdAt != null ? DateTime.parse(createdAt) : now,
      updatedAt: linkedAt != null ? DateTime.parse(linkedAt) : now,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('isGuest') || json.containsKey('name')) {
      return UserModel.fromApi(json);
    }
    final displayName = json['displayName'] ?? json['display_name'];
    final photoUrl = json['photoUrl'] ?? json['photo_url'];
    final deviceId = json['deviceId'] ?? json['device_id'];
    final subscriptionExpirationDate =
        json['subscriptionExpirationDate'] ?? json['subscription_expiration_date'];
    final isAnonymous = json['isAnonymous'] ?? json['is_anonymous'];
    final isPro = json['isPro'] ?? json['is_pro'];
    final coinBalance = json['coinBalance'] ?? json['coin_balance'];
    final autoplayNext = json['autoplayNext'] ?? json['autoplay_next'];
    final videoQuality = json['videoQuality'] ?? json['video_quality'];
    final notificationsEnabled =
        json['notificationsEnabled'] ?? json['notifications_enabled'];
    final createdAt = json['created_at'] ?? json['createdAt'];
    final updatedAt = json['updated_at'] ?? json['updatedAt'];

    return UserModel(
      id: json['id'] as String,
      uid: (json['uid'] as String?) ?? (json['id'] as String),
      email: json['email'] as String?,
      displayName: displayName as String?,
      photoUrl: photoUrl as String?,
      deviceId: deviceId as String?,
      subscriptionExpirationDate: subscriptionExpirationDate as String?,
      isAnonymous: (isAnonymous as bool?) ?? true,
      isPro: (isPro as bool?) ?? false,
      coinBalance: (coinBalance as int?) ?? 0,
      autoplayNext: (autoplayNext as bool?) ?? true,
      videoQuality: (videoQuality as String?) ?? 'auto',
      notificationsEnabled: (notificationsEnabled as bool?) ?? true,
      locale: json['locale'] as String?,
      createdAt: DateTime.parse(createdAt as String),
      updatedAt: DateTime.parse(updatedAt as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      if (deviceId != null) 'deviceId': deviceId,
      'isAnonymous': isAnonymous,
      'isPro': isPro,
    };
  }

  UserModel copyWith({
    String? id,
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? deviceId,
    String? subscriptionExpirationDate,
    bool? isAnonymous,
    bool? isPro,
    int? coinBalance,
    bool? autoplayNext,
    String? videoQuality,
    bool? notificationsEnabled,
    String? locale,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      deviceId: deviceId ?? this.deviceId,
      subscriptionExpirationDate:
          subscriptionExpirationDate ?? this.subscriptionExpirationDate,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isPro: isPro ?? this.isPro,
      coinBalance: coinBalance ?? this.coinBalance,
      autoplayNext: autoplayNext ?? this.autoplayNext,
      videoQuality: videoQuality ?? this.videoQuality,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      locale: locale ?? this.locale,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, uid: $uid, email: $email, isPro: $isPro, coins: $coinBalance)';
  }
}
