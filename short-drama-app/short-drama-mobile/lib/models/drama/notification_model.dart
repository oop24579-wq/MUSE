class UserNotificationModel {
  const UserNotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.createdAt,
    this.body,
    this.imageUrl,
    this.payload,
    this.readAt,
  });

  final String id;
  final String userId;

  /// Notification type identifier:
  /// 'new_episode' | 'series_update' | 'reward' | 'vip_promo' | 'system' | 'welcome'
  final String type;
  final String title;
  final String? body;
  final String? imageUrl;
  final Map<String, dynamic>? payload;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  String? get contentId =>
      payload != null ? payload!['contentId'] as String? : null;

  String? get contentType =>
      payload != null ? payload!['contentType'] as String? : null;

  factory UserNotificationModel.fromJson(Map<String, dynamic> j) {
    return UserNotificationModel(
      id: j['id'] as String,
      userId: j['userId'] as String,
      type: j['type'] as String,
      title: j['title'] as String,
      body: j['body'] as String?,
      imageUrl: j['imageUrl'] as String?,
      payload: j['payload'] as Map<String, dynamic>?,
      readAt: j['readAt'] != null ? DateTime.parse(j['readAt'] as String) : null,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }
}
