import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../models/user/user_model.dart';
import '../../services/auth/auth_service.dart';
import '../../services/legal_url_launcher.dart';
import '../../services/user_provider.dart';
import '../../widgets/top_toast.dart';
import '../account/account_helpers.dart';
import '../account/coin_history_screen.dart';
import '../account/edit_profile_screen.dart';
import '../app_settings/widgets/email_auth_bottom_sheet.dart';
import '../app_settings/widgets/sign_in_options_bottom_sheet.dart';
import 'widgets/coin_balance_header.dart';

/// Profile tab — the account hub.
class ProfileContent extends ConsumerStatefulWidget {
  const ProfileContent({super.key, this.onGoToRewards, this.onGoToMyList});

  /// Callbacks to switch the parent MainTabs to another tab.
  final VoidCallback? onGoToRewards;
  final VoidCallback? onGoToMyList;

  @override
  ConsumerState<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<ProfileContent> {
  final ValueNotifier<bool> _googleBusy = ValueNotifier(false);
  final ValueNotifier<bool> _appleBusy = ValueNotifier(false);

  @override
  void dispose() {
    _googleBusy.dispose();
    _appleBusy.dispose();
    super.dispose();
  }

  // ── Link account (guests) ──────────────────────────────────────────────
  Future<void> _showLinkAccountSheet() async {
    await SignInOptionsBottomSheet.show(
      context,
      googleLoadingListenable: _googleBusy,
      appleLoadingListenable: _appleBusy,
      onGoogle: _handleGoogle,
      onApple: _handleApple,
      onEmail: () {
        Navigator.of(context).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: AppTheme.elevatedPanelBackground(isDark),
            shape: AppTheme.settingsSheetShape,
            builder: (_) => const EmailAuthBottomSheet(),
          );
        });
      },
    ).whenComplete(() {
      _googleBusy.value = false;
      _appleBusy.value = false;
    });
  }

  Future<void> _handleGoogle() async {
    if (_googleBusy.value) return;
    _googleBusy.value = true;
    try {
      final ok = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      if (ok) {
        showTopToastSuccess(context, 'Account linked');
        await Provider.of<UserProvider>(context, listen: false).refreshUser(syncProStatus: true);
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      } else {
        showTopToastError(context, 'Google sign-in cancelled or failed');
      }
    } catch (e) {
      if (mounted) {
        showTopToastError(
            context, AuthService.instance.getAuthErrorMessage(e));
      }
    } finally {
      _googleBusy.value = false;
    }
  }

  Future<void> _handleApple() async {
    if (_appleBusy.value) return;
    if (!Platform.isIOS && !Platform.isMacOS) {
      showTopToastError(context, 'Apple sign-in is only available on iOS');
      return;
    }
    _appleBusy.value = true;
    try {
      final ok = await AuthService.instance.signInWithApple();
      if (!mounted) return;
      if (ok) {
        showTopToastSuccess(context, 'Account linked');
        await Provider.of<UserProvider>(context, listen: false).refreshUser(syncProStatus: true);
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      } else {
        showTopToastError(context, 'Apple sign-in cancelled or failed');
      }
    } catch (e) {
      if (mounted) {
        showTopToastError(
            context, AuthService.instance.getAuthErrorMessage(e));
      }
    } finally {
      _appleBusy.value = false;
    }
  }

  // ── Navigation helpers ─────────────────────────────────────────────────
  Future<void> _openEditProfile(UserModel user) async {
    final updated = await Navigator.of(context).push<UserModel>(
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
    );
    if (updated != null && mounted) {
      await Provider.of<UserProvider>(context, listen: false).refreshUser();
    }
  }

  void _openCoinHistory(int balance) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CoinHistoryScreen(balance: balance)),
    );
  }

  void _openLegal() {
    if (!tryPushLegal(context)) {
      // '/legal' route not registered yet — fall back to the configured
      // legal URLs so the row is never dead.
      LegalUrlLauncher.openPrivacy(context);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AuthService.instance.signOutToLogin();
    } catch (e) {
      if (mounted) {
        showTopToastError(
            context, AuthService.instance.getAuthErrorMessage(e));
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;
    final isVip = userProvider.isPro;
    final isGuest = userProvider.isAnonymous;
    final coins = user?.coinBalance ?? 0;

    final name = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : (isGuest ? 'Guest' : (user?.email ?? 'Member'));
    final provider = providerLabel(user);

    String? vipExpiry;
    if (isVip && user?.subscriptionExpirationDate != null) {
      final parsed = DateTime.tryParse(user!.subscriptionExpirationDate!);
      if (parsed != null) {
        vipExpiry = 'VIP until ${DateFormat.yMMMd().format(parsed.toLocal())}';
      }
    }

    return ListView(
      padding: EdgeInsets.only(top: 2.h, bottom: 4.h),
      children: [
        // ── Identity header ──────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Row(
            children: [
              accountAvatar(user: user, displayName: name),
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
                    SizedBox(height: 0.4.h),
                    Text(
                      isGuest ? 'Guest account' : (user?.email ?? ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: textColor.withValues(alpha: 0.6),
                          fontSize: 10.sp),
                    ),
                    SizedBox(height: 0.6.h),
                    Wrap(
                      spacing: 2.w,
                      runSpacing: 0.5.h,
                      children: [
                        _chip(
                          label: provider,
                          textColor: textColor,
                          filled: false,
                        ),
                        _chip(
                          label: isVip ? 'VIP MEMBER' : 'Free member',
                          textColor: textColor,
                          filled: isVip,
                        ),
                        if (vipExpiry != null)
                          _chip(
                              label: vipExpiry,
                              textColor: textColor,
                              filled: false),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 2.h),

        if (!isVip)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: _UpgradeBanner(
              onTap: () => Navigator.pushNamed(context, '/pricing'),
            ),
          ),
        SizedBox(height: 1.5.h),

        // ── Stat row (preserved) ─────────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.monetization_on_rounded,
                  value: '$coins',
                  label: 'Coins',
                  onTap: () => _openCoinHistory(coins),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: _StatTile(
                  icon: Icons.bookmark_rounded,
                  value: 'My List',
                  label: 'Collection',
                  onTap: widget.onGoToMyList,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 2.h),

        // ── Account menu ─────────────────────────────────────────────────
        _menuCard(context, textColor, isDark, [
          if (user != null)
            _MenuItem(Icons.edit_rounded, 'Edit profile',
                () => _openEditProfile(user)),
          _MenuItem(Icons.monetization_on_rounded, 'My coins ($coins)',
              () => _openCoinHistory(coins)),
          _MenuItem(Icons.workspace_premium_rounded, 'Subscription', () {
            if (isVip) {
              showTopToastInfo(context,
                  'Subscriptions are managed in the App Store / Google Play');
            }
            Navigator.pushNamed(context, '/pricing');
          }),
          if (isGuest)
            _MenuItem(Icons.link_rounded, 'Link account', _showLinkAccountSheet),
          _MenuItem(Icons.card_giftcard_rounded, 'Rewards & coins',
              widget.onGoToRewards),
          _MenuItem(Icons.bookmark_border_rounded, 'My List',
              widget.onGoToMyList),
          _MenuItem(Icons.settings_rounded, 'Settings',
              () => Navigator.pushNamed(context, '/app-settings')),
          _MenuItem(Icons.privacy_tip_outlined, 'Account & privacy',
              () => Navigator.pushNamed(context, '/app-settings')),
          _MenuItem(Icons.description_outlined, 'Legal', _openLegal),
        ]),
        SizedBox(height: 2.h),

        // ── Log out ──────────────────────────────────────────────────────
        if (!isGuest)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: OutlinedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentBlue,
                padding: EdgeInsets.symmetric(vertical: 1.4.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _chip(
      {required String label, required Color textColor, required bool filled}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.3.h),
      decoration: BoxDecoration(
        gradient: filled
            ? const LinearGradient(
                colors: [Color(0xFFFFD54F), Color(0xFFFFB300)])
            : null,
        color: filled ? null : textColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: filled ? Colors.black87 : textColor.withValues(alpha: 0.7),
          fontSize: 8.5.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
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
