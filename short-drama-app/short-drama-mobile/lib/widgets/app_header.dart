import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

import '../core/app_export.dart';
import '../core/test_flags.dart';
import '../presentation/app_settings/app_settings.dart';
import '../presentation/drama/widgets/coin_balance_header.dart';
import '../presentation/notifications/notifications_screen.dart';
import '../services/drama/drama_service.dart';
import '../services/marketing/marketing_event_names.dart';
import '../services/user_provider.dart';
import '../widgets/discount_offer.dart';
import 'header_glass_chip.dart';

class AppHeader extends StatefulWidget {
  const AppHeader({super.key, this.includeTopSafeArea = true});

  /// When false, the top status-bar inset is not reserved here (the caller is
  /// expected to provide a persistent spacer). Used by the collapsing header
  /// in the main tab shell.
  final bool includeTopSafeArea;

  static EdgeInsets pagePadding(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h);

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final count = await DramaService.instance.fetchUnreadNotificationCount();
    if (mounted) setState(() => _notificationCount = count);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeHeight = 14.sp + 3.w;
    final userProvider = context.watch<UserProvider>();
    final isPro = TestFlags.forceProForTest || userProvider.isPro;
    final coins = userProvider.user?.coinBalance ?? 0;

    final content = Padding(
      padding: AppHeader.pagePadding(context),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 7.w,
                height: 7.w,
                fit: BoxFit.cover,
              ),
            ),
            const Spacer(),
            IntrinsicWidth(
              child: HeaderGlassChip(
                isDark: isDark,
                height: badgeHeight,
                borderRadius: BorderRadius.circular(badgeHeight / 2),
                padding: EdgeInsets.symmetric(horizontal: 2.5.w),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CoinGlyph(size: 14),
                    SizedBox(width: 1.w),
                    Text(
                      '$coins',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppTheme.textPrimaryDark
                            : AppTheme.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 2.w),
            if (!isPro) ...[
              HeaderGlassProChip(
                isDark: isDark,
                height: badgeHeight,
                onTap: () async {
                  await presentPaywallWithDiscount(
                    context,
                    trigger: PaywallTrigger.header,
                  );
                  if (!context.mounted) return;
                  await context.read<UserProvider>().refreshUser(
                        syncProStatus: true,
                      );
                },
              ),
              SizedBox(width: 2.w),
            ],
            Stack(
              clipBehavior: Clip.none,
              children: [
                HeaderGlassIconButton(
                  isDark: isDark,
                  badgeHeight: badgeHeight,
                  icon: Icons.notifications_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ).then((_) => _loadNotifications());
                  },
                ),
                if (_notificationCount > 0)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: CircleAvatar(
                      radius: 7,
                      backgroundColor: AppTheme.accentBlue,
                      child: Text(
                        _notificationCount > 9 ? '9+' : '$_notificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 2.w),
            HeaderGlassIconButton(
              isDark: isDark,
              badgeHeight: badgeHeight,
              icon: Icons.settings_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppSettings()),
                );
              },
            ),
          ],
        ),
    );

    if (!widget.includeTopSafeArea) return content;
    return SafeArea(bottom: false, child: content);
  }
}
