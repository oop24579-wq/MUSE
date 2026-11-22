import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' show WatchContext;
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/user_provider.dart';
import 'widgets/coin_balance_header.dart';

class ProfileContent extends ConsumerWidget {
  const ProfileContent({super.key, this.onGoToRewards, this.onGoToMyList});

  /// Callbacks to switch the parent MainTabs to another tab.
  final VoidCallback? onGoToRewards;
  final VoidCallback? onGoToMyList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;
    final isVip = userProvider.isPro;
    final coins = user?.coinBalance ?? 0;

    final name = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : (userProvider.isAnonymous ? 'Guest' : (user?.email ?? 'Member'));

    return ListView(
      padding: EdgeInsets.only(top: 2.h, bottom: 4.h),
      children: [
        // Identity header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Row(
            children: [
              Builder(builder: (_) {
                final isAnon = userProvider.isAnonymous;
                final hasPhoto = !isAnon &&
                    user?.photoUrl != null &&
                    user!.photoUrl!.isNotEmpty;
                Widget initial() => Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'G',
                        style: TextStyle(
                            color: AppTheme.accentBlue,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800),
                      ),
                    );
                Widget inner;
                if (isAnon) {
                  // Anonymous user → app icon.
                  inner = Image.asset('assets/images/app_icon.png',
                      fit: BoxFit.cover);
                } else if (hasPhoto) {
                  inner = Image.network(user!.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => initial());
                } else {
                  inner = initial();
                }
                return Container(
                  width: 60,
                  height: 60,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accentBlue.withValues(alpha: 0.2),
                  ),
                  child: inner,
                );
              }),
              SizedBox(width: 4.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: textColor,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 0.5.h),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.3.h),
                      decoration: BoxDecoration(
                        gradient: isVip
                            ? const LinearGradient(
                                colors: [Color(0xFFFFD54F), Color(0xFFFFB300)])
                            : null,
                        color: isVip ? null : textColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isVip ? 'VIP MEMBER' : 'Free member',
                        style: TextStyle(
                          color: isVip ? Colors.black87 : textColor.withValues(alpha: 0.7),
                          fontSize: 8.5.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 2.h),

        // Coins + upgrade
        if (!isVip)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: _UpgradeBanner(
              onTap: () => Navigator.pushNamed(context, AppRoutes.pricing),
            ),
          ),
        SizedBox(height: 1.5.h),

        // Stat row
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.monetization_on_rounded,
                  value: '$coins',
                  label: 'Coins',
                  onTap: onGoToRewards,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: _StatTile(
                  icon: Icons.bookmark_rounded,
                  value: 'My List',
                  label: 'Collection',
                  onTap: onGoToMyList,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 2.h),

        // Menu
        _menuCard(context, textColor, isDark, [
          _MenuItem(Icons.card_giftcard_rounded, 'Rewards & coins', onGoToRewards),
          _MenuItem(Icons.bookmark_border_rounded, 'My List', onGoToMyList),
          _MenuItem(Icons.settings_rounded, 'Settings',
              () => Navigator.pushNamed(context, AppRoutes.appSettings)),
          _MenuItem(Icons.workspace_premium_rounded, 'Go VIP',
              () => Navigator.pushNamed(context, AppRoutes.pricing)),
        ]),
      ],
    );
  }

  Widget _menuCard(
      BuildContext context, Color textColor, bool isDark, List<_MenuItem> items) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkBlue : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            ListTile(
              leading: Icon(items[i].icon, color: textColor.withValues(alpha: 0.8)),
              title: Text(items[i].label,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600)),
              trailing: Icon(Icons.chevron_right_rounded,
                  color: textColor.withValues(alpha: 0.4)),
              onTap: items[i].onTap,
            ),
            if (i != items.length - 1)
              Divider(
                  height: 1,
                  indent: 4.w,
                  endIndent: 4.w,
                  color: textColor.withValues(alpha: 0.06)),
          ],
        ],
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.icon, required this.value, required this.label, this.onTap});
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 1.6.h),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDarkBlue : AppTheme.cardLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.accentBlue, size: 22),
            SizedBox(height: 0.6.h),
            Text(value,
                style: TextStyle(
                    color: textColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: TextStyle(
                    color: textColor.withValues(alpha: 0.5), fontSize: 8.5.sp)),
          ],
        ),
      ),
    );
  }
}

class _UpgradeBanner extends StatelessWidget {
  const _UpgradeBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF2A1512), Color(0xFF4A241A)],
          ),
          border:
              Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const CoinGlyph(size: 30),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Go VIP',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800)),
                  Text('Unlimited episodes, ad-free, HD',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 9.sp)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
