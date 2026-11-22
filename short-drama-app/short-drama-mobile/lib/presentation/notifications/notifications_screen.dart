import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../models/drama/notification_model.dart';
import '../../services/drama/drama_service.dart';
import '../../widgets/header_glass_chip.dart';
import '../app_settings/widgets/settings_opacity_tap.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  List<UserNotificationModel> _notifications = [];
  bool _loading = true;
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _load();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final notifications = await DramaService.instance.fetchNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _loading = false;
    });
    _entranceController.forward(from: 0);
  }

  Future<void> _markAllRead() async {
    await DramaService.instance.markAllNotificationsRead();
    if (!mounted) return;
    setState(() {
      _notifications = _notifications
          .map((n) => n.isUnread
              ? UserNotificationModel(
                  id: n.id,
                  userId: n.userId,
                  type: n.type,
                  title: n.title,
                  body: n.body,
                  imageUrl: n.imageUrl,
                  payload: n.payload,
                  readAt: DateTime.now(),
                  createdAt: n.createdAt,
                )
              : n)
          .toList();
    });
  }

  Future<void> _markRead(UserNotificationModel n) async {
    if (!n.isUnread) return;
    await DramaService.instance.markNotificationRead(n.id);
    if (!mounted) return;
    setState(() {
      final idx = _notifications.indexWhere((x) => x.id == n.id);
      if (idx != -1) {
        final updated = UserNotificationModel(
          id: n.id,
          userId: n.userId,
          type: n.type,
          title: n.title,
          body: n.body,
          imageUrl: n.imageUrl,
          payload: n.payload,
          readAt: DateTime.now(),
          createdAt: n.createdAt,
        );
        _notifications = List.from(_notifications)..[idx] = updated;
      }
    });
  }

  double _staggerT(int index, double controllerValue) {
    const delay = 0.04;
    const span = 0.45;
    final start = index * delay;
    final end = (start + span).clamp(0.0, 1.0);
    if (controllerValue <= start) return 0;
    if (controllerValue >= end) return 1;
    return (controllerValue - start) / (end - start);
  }

  Widget _entrance({required int index, required Widget child}) {
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (_, __) {
        final t = Curves.easeOutCubic
            .transform(_staggerT(index, _entranceController.value));
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final secondaryTextColor =
        isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;
    final hasUnread = _notifications.any((n) => n.isUnread);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leadingWidth: 56,
        leading: Padding(
          padding: EdgeInsets.only(left: 4.w),
          child: Align(
            alignment: Alignment.centerLeft,
            child: HeaderGlassIconButton(
              isDark: isDark,
              icon: Icons.close_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        centerTitle: true,
        actions: [
          if (hasUnread)
            Padding(
              padding: EdgeInsets.only(right: 4.w),
              child: TextButton(
                onPressed: _markAllRead,
                child: Text(
                  'Mark all read',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: secondaryTextColor,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState(isDark, textColor, secondaryTextColor)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _buildList(isDark, textColor, secondaryTextColor),
                ),
    );
  }

  Widget _buildEmptyState(
      bool isDark, Color textColor, Color secondaryTextColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            color: secondaryTextColor.withValues(alpha: 0.4),
            size: 11.w,
          ),
          SizedBox(height: 1.5.h),
          Text(
            'No notifications yet',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 0.6.h),
          Text(
            "We'll let you know when something new happens.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: secondaryTextColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
      bool isDark, Color textColor, Color secondaryTextColor) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 6));

    final today =
        _notifications.where((n) => n.createdAt.isAfter(todayStart)).toList();
    final thisWeek = _notifications
        .where((n) =>
            n.createdAt.isAfter(weekStart) && !n.createdAt.isAfter(todayStart))
        .toList();
    final earlier = _notifications
        .where((n) => !n.createdAt.isAfter(weekStart))
        .toList();

    final dividerColor = isDark ? AppTheme.dividerDark : AppTheme.dividerLight;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    var animIdx = 0;
    final items = <Widget>[];

    void addSection(String label, List<UserNotificationModel> list) {
      if (list.isEmpty) return;

      items.add(
        _entrance(
          index: animIdx++,
          child: _SectionLabel(
            label: label,
            secondaryTextColor: secondaryTextColor,
          ),
        ),
      );

      for (var i = 0; i < list.length; i++) {
        final n = list[i];
        final isLast = i == list.length - 1;
        items.add(
          _entrance(
            index: animIdx++,
            child: Column(
              children: [
                _NotificationRow(
                  notification: n,
                  isDark: isDark,
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                  onTap: () => _markRead(n),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 4.w,
                    endIndent: 4.w,
                    color: dividerColor.withValues(alpha: 0.4),
                  ),
              ],
            ),
          ),
        );
      }
    }

    addSection('Today', today);
    addSection('This Week', thisWeek);
    addSection('Earlier', earlier);

    return ListView(
      padding: EdgeInsets.only(top: 0.5.h, bottom: bottomPadding + 4.h),
      children: items,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.secondaryTextColor,
  });

  final String label;
  final Color secondaryTextColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 0.5.h),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: secondaryTextColor.withValues(alpha: 0.55),
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.isDark,
    required this.textColor,
    required this.secondaryTextColor,
    required this.onTap,
  });

  final UserNotificationModel notification;
  final bool isDark;
  final Color textColor;
  final Color secondaryTextColor;
  final VoidCallback onTap;

  Color _colorForType(String type) {
    switch (type) {
      case 'new_episode':
        return const Color(0xFFE50914);
      case 'radio':
        return const Color(0xFFEC4899);
      case 'promo':
        return const Color(0xFFF59E0B);
      case 'welcome':
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    final unread = notification.isUnread;
    final dotColor = _colorForType(notification.type);
    final unreadBg = unread
        ? (isDark
            ? Colors.white.withValues(alpha: 0.025)
            : Colors.black.withValues(alpha: 0.018))
        : Colors.transparent;

    return SettingsOpacityTap(
      onTap: onTap,
      child: Container(
        color: unreadBg,
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread dot — left side, vertically centered on first text line
            SizedBox(
              width: 3.w,
              child: Padding(
                padding: EdgeInsets.only(top: 0.55.h),
                child: unread
                    ? Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      )
                    : const SizedBox(width: 6, height: 6),
              ),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight:
                                unread ? FontWeight.w600 : FontWeight.w400,
                            color: unread
                                ? textColor
                                : textColor.withValues(alpha: 0.65),
                            height: 1.3,
                          ),
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        _relativeTime(notification.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: secondaryTextColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  if (notification.body != null) ...[
                    SizedBox(height: 0.35.h),
                    Text(
                      notification.body!,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: secondaryTextColor.withValues(
                            alpha: unread ? 0.85 : 0.6),
                        height: 1.45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
