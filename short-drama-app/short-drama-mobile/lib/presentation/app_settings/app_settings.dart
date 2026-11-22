import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_export.dart';
import '../../services/user_provider.dart';
import 'package:drama_now/services/auth/auth_service.dart';
import '../../services/language_service.dart';
import '../../services/locale_provider.dart';
import '../../services/revenuecat_service.dart';
import '../../services/rating_service.dart';
import '../../services/legal_url_launcher.dart';
import '../../services/theme_provider.dart';
import '../../services/onesignal_service.dart';
import '../../services/player_tutorial.dart';
import './widgets/email_auth_bottom_sheet.dart';
import './widgets/language_selection_bottom_sheet.dart';
import './widgets/settings_anon_account_row.dart';
import './widgets/settings_opacity_tap.dart';
import './widgets/notification_settings_bottom_sheet.dart';
import './widgets/sign_in_options_bottom_sheet.dart';
import './widgets/settings_menu_card.dart';
import './widgets/settings_promo_banner.dart';
import './widgets/settings_social_contact_card.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/header_glass_chip.dart';
import '../../widgets/top_toast.dart';

class AppSettings extends StatefulWidget {
  final bool hideAppBar; // When true, hides AppBar for PageView usage

  const AppSettings({Key? key, this.hideAppBar = false}) : super(key: key);

  @override
  State<AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<AppSettings>
    with TickerProviderStateMixin {
  final ValueNotifier<bool> _signInSheetGoogleBusy = ValueNotifier(false);
  final ValueNotifier<bool> _signInSheetAppleBusy = ValueNotifier(false);
  final ValueNotifier<bool> _deleteAccountBusy = ValueNotifier(false);
  late final AnimationController _settingsListEntranceController;

  @override
  void initState() {
    super.initState();
    _settingsListEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _settingsListEntranceController.forward();
    });
  }

  @override
  void dispose() {
    _signInSheetGoogleBusy.dispose();
    _signInSheetAppleBusy.dispose();
    _settingsListEntranceController.dispose();
    super.dispose();
  }

  Future<void> _showSignInOptionsSheet() async {
    await SignInOptionsBottomSheet.show(
      context,
      googleLoadingListenable: _signInSheetGoogleBusy,
      appleLoadingListenable: _signInSheetAppleBusy,
      onGoogle: _handleGoogleSignIn,
      onApple: _handleAppleSignIn,
      onEmail: () {
        Navigator.of(context).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final isDark =
              Theme.of(context).brightness == Brightness.dark;
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: AppTheme.elevatedPanelBackground(isDark),
            shape: AppTheme.settingsSheetShape,
            builder: (context) => const EmailAuthBottomSheet(),
          );
        });
      },
    ).whenComplete(() {
      _signInSheetGoogleBusy.value = false;
      _signInSheetAppleBusy.value = false;
    });
  }

  /// 0→1 progress for the [index]th list row while [_settingsListEntranceController] runs.
  double _settingsListStaggerT(int index, double controllerValue) {
    const delay = 0.048;
    const span = 0.40;
    final start = index * delay;
    final end = (start + span).clamp(0.0, 1.0);
    if (controllerValue <= start) return 0;
    if (controllerValue >= end) return 1;
    return (controllerValue - start) / (end - start);
  }

  Widget _settingsListEntrance({
    required int index,
    required Widget child,
  }) {
    const slidePx = 14.0;
    return AnimatedBuilder(
      animation: _settingsListEntranceController,
      builder: (context, _) {
        final linear = _settingsListStaggerT(
          index,
          _settingsListEntranceController.value,
        );
        final t = Curves.easeOutCubic.transform(linear);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, slidePx * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Listen to locale changes to rebuild when language changes
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight;
        
        final bodyContent = _buildBodyContent(context);
        
        // When used in PageView (hideAppBar=true), return just the body content
        // The Scaffold in MainTabs sets backgroundColor, so we don't need to wrap in Container
        // The Scaffold body automatically accounts for bottomNavigationBar height
        if (widget.hideAppBar) {
          return bodyContent;
        }
    
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
          AppLocalizations.of(context)!.settings,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppTheme.textPrimaryDark
                : AppTheme.textPrimaryLight,
          ),
        ),
        centerTitle: true,
      ),
      body: bodyContent,
    );
      },
    );
  }
  
  Widget _buildBodyContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
    final textColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final secondaryTextColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final topSpacer = (constraints.maxHeight * 0.022).clamp(6.0, 18.0);
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final bottomNavBarHeight = (2.h * 2) + 24.0;

        return SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomNavBarHeight + bottomPadding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: EdgeInsets.only(top: topSpacer),
                child: Column(
                  children: [
                    _settingsListEntrance(
                      index: 0,
                      child: SettingsPromoBanner(isDark: isDark),
                    ),
                    SizedBox(height: 2.h),
                    Consumer<UserProvider>(
                      builder: (context, userProvider, _) {
                        var listAnimIndex = 1;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _settingsListEntrance(
                              index: listAnimIndex++,
                              child: SettingsMenuCard(
                                isDark: isDark,
                                secondaryTextColor: secondaryTextColor,
                                children: [
                                  _buildLanguageRow(isDark, textColor,
                                      secondaryTextColor),
                                  _buildSettingsRow(
                                    icon: isDark
                                        ? Icons.light_mode_outlined
                                        : Icons.dark_mode_outlined,
                                    title: isDark
                                        ? l10n.lightMode
                                        : l10n.darkMode,
                                    isDark: isDark,
                                    textColor: textColor,
                                    secondaryTextColor: secondaryTextColor,
                                    onTap: () => context
                                        .read<ThemeProvider>()
                                        .toggleTheme(),
                                  ),
                                  _buildSettingsRow(
                                    icon: OneSignalService.isEnabled
                                        ? Icons.notifications_active_outlined
                                        : Icons.notifications_off_outlined,
                                    title: l10n.notifications,
                                    isDark: isDark,
                                    textColor: textColor,
                                    secondaryTextColor: secondaryTextColor,
                                    onTap: () async {
                                      await NotificationSettingsBottomSheet
                                          .show(context);
                                      if (mounted) setState(() {});
                                    },
                                  ),
                                  _buildSettingsRow(
                                    icon: Icons.gesture_rounded,
                                    title: l10n.playerTutorialRow,
                                    isDark: isDark,
                                    textColor: textColor,
                                    secondaryTextColor: secondaryTextColor,
                                    onTap: () async {
                                      await PlayerTutorial.requestReplay();
                                      if (mounted) {
                                        showTopToastSuccess(
                                          context,
                                          l10n.playerTutorialReplayHint,
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 2.h),
                            _settingsListEntrance(
                              index: listAnimIndex++,
                              child: SettingsMenuCard(
                                isDark: isDark,
                                secondaryTextColor: secondaryTextColor,
                                children: [
                                  _buildSettingsRow(
                                    icon: Icons.help_outline,
                                    title: l10n.settingsFaqDialogTitle,
                                    isDark: isDark,
                                    textColor: textColor,
                                    secondaryTextColor: secondaryTextColor,
                                    onTap: () => _showFaqDialog(isDark,
                                        surfaceColor, textColor,
                                        secondaryTextColor),
                                  ),
                                  _buildSettingsRow(
                                    icon: Icons.star_outline,
                                    title: l10n.rateUs,
                                    isDark: isDark,
                                    textColor: textColor,
                                    secondaryTextColor: secondaryTextColor,
                                    onTap: () =>
                                        RatingService().openStoreListing(),
                                  ),
                                  _buildSettingsRow(
                                    icon: Icons.support_agent_outlined,
                                    title: l10n.support,
                                    isDark: isDark,
                                    textColor: textColor,
                                    secondaryTextColor: secondaryTextColor,
                                    onTap: () async {
                                      try {
                                        final Uri emailUri = Uri(
                                          scheme: 'mailto',
                                          path: 'support@domain.com',
                                        );
                                        await launchUrl(emailUri);
                                      } catch (e) {
                                        if (mounted) {
                                          showTopToastError(
                                            context,
                                            'Could not open email. Please contact support@domain.com',
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 2.h),
                            _settingsListEntrance(
                              index: listAnimIndex++,
                              child: SettingsMenuCard(
                                isDark: isDark,
                                secondaryTextColor: secondaryTextColor,
                                children: [
                                  _buildSettingsRow(
                                    icon: Icons.restore,
                                    title: l10n.restorePurchase,
                                    isDark: isDark,
                                    textColor: textColor,
                                    secondaryTextColor: secondaryTextColor,
                                    onTap: () async {
                                      try {
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => const Center(
                                            child:
                                                CircularProgressIndicator(),
                                          ),
                                        );
                                        final userProvider =
                                            Provider.of<UserProvider>(context,
                                                listen: false);
                                        userProvider
                                            .listenForMigrationComplete();
                                        await RevenueCatService
                                            .restorePurchases();
                                        await userProvider.refreshUser(
                                            syncProStatus: true);
                                        if (mounted) {
                                          Navigator.pop(context);
                                          showTopToastSuccess(
                                            context,
                                            l10n
                                                .settingsPurchasesRestoredSuccess,
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          Navigator.pop(context);
                                          showTopToastError(
                                            context,
                                            l10n.settingsRestorePurchasesError(
                                                e.toString()),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  _buildSettingsRow(
                                    icon: Icons.subscriptions,
                                    title: l10n.manageSubscriptions,
                                    isDark: isDark,
                                    textColor: textColor,
                                    secondaryTextColor: secondaryTextColor,
                                    onTap: () async {
                                      try {
                                        final String url;
                                        if (Platform.isIOS) {
                                          url =
                                              'https://apps.apple.com/account/subscriptions';
                                        } else {
                                          url =
                                              'https://play.google.com/store/account/subscriptions';
                                        }
                                        await launchUrl(
                                          Uri.parse(url),
                                          mode: LaunchMode.externalApplication,
                                        );
                                      } catch (e) {
                                        if (mounted) {
                                          showTopToastError(
                                            context,
                                            l10n.couldNotOpenSubscriptionPage,
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 2.h),
                            _settingsListEntrance(
                              index: listAnimIndex++,
                              child: SettingsMenuCard(
                                isDark: isDark,
                                secondaryTextColor: secondaryTextColor,
                                children: [
                                  _buildSettingsRow(
                                    icon: Icons.privacy_tip_outlined,
                                    title: l10n.privacyPolicy,
                                    isDark: isDark,
                                    textColor: textColor,
                                    secondaryTextColor: secondaryTextColor,
                                    onTap: () =>
                                        LegalUrlLauncher.openPrivacy(context),
                                  ),
                                  _buildSettingsRow(
                                    icon: Icons.description_outlined,
                                    title: l10n.termsOfUse,
                                    isDark: isDark,
                                    textColor: textColor,
                                    secondaryTextColor: secondaryTextColor,
                                    onTap: () =>
                                        LegalUrlLauncher.openTerms(context),
                                  ),
                                ],
                              ),
                            ),
                            if (userProvider.isAnonymous) ...[
                              SizedBox(height: 2.h),
                              _settingsListEntrance(
                                index: listAnimIndex++,
                                child: SettingsMenuCard(
                                  isDark: isDark,
                                  secondaryTextColor: secondaryTextColor,
                                  children: [
                                    SettingsAnonAccountRow(
                                      textColor: textColor,
                                      secondaryTextColor: secondaryTextColor,
                                      onTap: _showSignInOptionsSheet,
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              SizedBox(height: 2.h),
                              _settingsListEntrance(
                                index: listAnimIndex++,
                                child: SettingsMenuCard(
                                  isDark: isDark,
                                  secondaryTextColor: secondaryTextColor,
                                  children: [
                                    _buildSignedUserIdRow(
                                      isDark: isDark,
                                      textColor: textColor,
                                      secondaryTextColor: secondaryTextColor,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            SizedBox(height: 2.h),
                            _settingsListEntrance(
                              index: listAnimIndex++,
                              child: SettingsSocialContactCard(
                                isDark: isDark,
                                textColor: textColor,
                                secondaryTextColor: secondaryTextColor,
                              ),
                            ),
                            SizedBox(height: 4.h),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _settingsRowIcon(Color secondaryTextColor, IconData icon) {
    return Icon(
      icon,
      size: 20,
      color: secondaryTextColor.withValues(alpha: 0.9),
    );
  }

  Widget _buildMenuCardHeader({
    required IconData icon,
    required String title,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: secondaryTextColor),
        SizedBox(width: 2.w),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  Widget _compactSettingsSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      width: 46,
      height: 28,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          activeTrackColor: AppTheme.accentBlue.withValues(alpha: 0.5),
          activeThumbColor: AppTheme.accentBlue,
        ),
      ),
    );
  }

  Widget _settingsRowLayout({
    required IconData icon,
    required String title,
    required Color textColor,
    required Color secondaryTextColor,
    required Widget trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Center(
            child: _settingsRowIcon(secondaryTextColor, icon),
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: textColor,
              height: 1.25,
            ),
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _buildSettingsSwitchRow({
    required IconData icon,
    required String title,
    required Color textColor,
    required Color secondaryTextColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      alignment: Alignment.center,
      child: _settingsRowLayout(
        icon: icon,
        title: title,
        textColor: textColor,
        secondaryTextColor: secondaryTextColor,
        trailing: _compactSettingsSwitch(
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String title,
    required bool isDark,
    required Color textColor,
    required Color secondaryTextColor,
    required VoidCallback onTap,
    Widget? trailing,
    String? focusDebugLabel,
  }) {
    return SettingsOpacityTap(
      focusDebugLabel: focusDebugLabel ?? 'settings_menu_$title',
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        alignment: Alignment.center,
        child: _settingsRowLayout(
          icon: icon,
          title: title,
          textColor: textColor,
          secondaryTextColor: secondaryTextColor,
          trailing: trailing ??
              Icon(
                Icons.chevron_right_rounded,
                color: secondaryTextColor,
                size: 20,
              ),
        ),
      ),
    );
  }

  Widget _buildSignedUserIdRow({
    required bool isDark,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final l10n = AppLocalizations.of(context)!;
        final userId = userProvider.userId ?? l10n.notSignedIn;
        final isSigned = userId != l10n.notSignedIn;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              child: Row(
                children: [
                  _settingsRowIcon(secondaryTextColor, Icons.badge_outlined),
                  SizedBox(width: 3.w),
                  Text(
                    l10n.userId,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: isSigned ? () => _copyUserId(userId) : null,
                    child: Text(
                      userId.length > 12
                          ? userId.substring(0, 12)
                          : userId,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                  SizedBox(width: 1.w),
                  GestureDetector(
                    onTap: isSigned ? () => _copyUserId(userId) : null,
                    child: Icon(
                      Icons.copy_outlined,
                      color: isSigned
                          ? secondaryTextColor
                          : secondaryTextColor.withValues(alpha: 0.3),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            if (isSigned) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: (isDark ? AppTheme.dividerDark : AppTheme.dividerLight)
                      .withValues(alpha: 0.45),
                ),
              ),
              SettingsOpacityTap(
                focusDebugLabel: 'settings_sign_out',
                onTap: () async {
                  await AuthService.instance.signOut();
                  if (context.mounted) {
                    showTopToastSuccess(context, l10n.signedOutSuccessfully);
                  }
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: AppTheme.accentBlue,
                        size: 20,
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        l10n.signOut,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
                child: Center(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _deleteAccountBusy,
                    builder: (context, busy, _) {
                      return OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => _showDeleteAccountDialog(
                                  isDark: isDark,
                                  surfaceColor: isDark
                                      ? AppTheme.surfaceDark
                                      : AppTheme.surfaceLight,
                                  textColor: textColor,
                                  secondaryTextColor: secondaryTextColor,
                                ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE53935),
                          disabledForegroundColor:
                              const Color(0xFFE53935).withValues(alpha: 0.5),
                          side: BorderSide(
                            color: const Color(0xFFE53935)
                                .withValues(alpha: 0.55),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 1.2.h,
                          ),
                        ),
                        child: busy
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: const Color(0xFFE53935)
                                      .withValues(alpha: 0.7),
                                ),
                              )
                            : Text(
                                l10n.deleteAccount,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLanguageRow(
    bool isDark,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        final currentLanguage = localeProvider.locale?.languageCode ?? 'en';
        final languageName =
            LanguageService.instance.getLanguageName(currentLanguage);

        return _buildSettingsRow(
          icon: Icons.language_outlined,
          title: l10n.language,
          isDark: isDark,
          textColor: textColor,
          secondaryTextColor: secondaryTextColor,
          focusDebugLabel: 'settings_language',
          onTap: () => LanguageSelectionBottomSheet.show(
            context,
            onLocaleChanged: () {
              if (mounted) setState(() {});
            },
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                languageName,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: secondaryTextColor,
                ),
              ),
              SizedBox(width: 1.w),
              Icon(
                Icons.chevron_right_rounded,
                color: secondaryTextColor,
                size: 20,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFaqDialog(bool isDark, Color surfaceColor, Color textColor,
      Color secondaryTextColor) {
    final l10n = AppLocalizations.of(context)!;
    final faqItems = <Map<String, String>>[
      {
        'question': l10n.settingsFaqQ1,
        'answer': l10n.settingsFaqA1,
      },
      {
        'question': l10n.settingsFaqQ2,
        'answer': l10n.settingsFaqA2,
      },
      {
        'question': l10n.settingsFaqQ3,
        'answer': l10n.settingsFaqA3,
      },
      {
        'question': l10n.settingsFaqQ4,
        'answer': l10n.settingsFaqA4,
      },
      {
        'question': l10n.settingsFaqQ5,
        'answer': l10n.settingsFaqA5,
      },
      {
        'question': l10n.settingsFaqQ6,
        'answer': l10n.settingsFaqA6,
      },
      {
        'question': l10n.settingsFaqQ7,
        'answer': l10n.settingsFaqA7,
      },
      {
        'question': l10n.settingsFaqQ8,
        'answer': l10n.settingsFaqA8,
      },
      {
        'question': l10n.settingsFaqQ9,
        'answer': l10n.settingsFaqA9,
      },
      {
        'question': l10n.settingsFaqQ10,
        'answer': l10n.settingsFaqA10,
      },
      {
        'question': l10n.settingsFaqQ11,
        'answer': l10n.settingsFaqA11,
      },
    ];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        insetPadding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(5.w, 3.h, 2.w, 1.h),
              child: Row(
                children: [
                  Text(
                    l10n.settingsFaqDialogTitle,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: secondaryTextColor, size: 22),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(5.w, 0, 5.w, 3.h),
                child: _FaqExpansionList(
                  faqItems: faqItems,
                  isDark: isDark,
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyUserId(String userId) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: userId));
    showBottomToast(
      context,
      l10n.userIdCopiedToClipboard,
      icon: Icons.check_circle_outline,
      aboveBottomNav: 32,
    );
  }

  Future<void> _showDeleteAccountDialog({
    required bool isDark,
    required Color surfaceColor,
    required Color textColor,
    required Color secondaryTextColor,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        insetPadding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
        child: Padding(
          padding: EdgeInsets.fromLTRB(5.w, 2.5.h, 5.w, 2.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: const Color(0xFFE53935),
                size: 9.w,
              ),
              SizedBox(height: 1.5.h),
              Text(
                l10n.deleteAccountTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              SizedBox(height: 1.5.h),
              Text(
                l10n.deleteAccountWarning,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                  color: secondaryTextColor,
                ),
              ),
              SizedBox(height: 2.5.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 1.4.h),
                  ),
                  child: Text(
                    l10n.deleteAccountConfirm,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 1.h),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: TextButton.styleFrom(
                    foregroundColor: secondaryTextColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 1.2.h),
                  ),
                  child: Text(
                    l10n.deleteAccountCancel,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    await _performAccountDeletion();
  }

  Future<void> _performAccountDeletion() async {
    if (_deleteAccountBusy.value) return;
    _deleteAccountBusy.value = true;
    final l10n = AppLocalizations.of(context)!;
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final success = await AuthService.instance.deleteAccount(
        profile: userProvider.user,
      );
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.initial,
          (route) => false,
        );
      } else {
        showTopToastError(context, l10n.deleteAccountFailed);
      }
    } catch (e) {
      if (mounted) {
        showTopToastError(context, l10n.deleteAccountFailed);
      }
    } finally {
      _deleteAccountBusy.value = false;
    }
  }
  

  Future<void> _handleGoogleSignIn() async {
    if (_signInSheetGoogleBusy.value) return;
    _signInSheetGoogleBusy.value = true;
    try {
      final success = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      if (success) {
        showTopToastSuccess(context, l10n.successfullySignedInWithGoogle);
        await Provider.of<UserProvider>(context, listen: false)
            .refreshUser(syncProStatus: true);
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else {
        showTopToastError(context, l10n.googleSignInCancelledOrFailed);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        showTopToastError(
          context,
          AuthService.instance.getAuthErrorMessage(e),
        );
      }
    } finally {
      _signInSheetGoogleBusy.value = false;
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (_signInSheetAppleBusy.value) return;
    if (!Platform.isIOS && !Platform.isMacOS) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        showTopToastError(context, l10n.appleSignInOnlyAvailableOnIOS);
      }
      return;
    }
    _signInSheetAppleBusy.value = true;
    try {
      final success = await AuthService.instance.signInWithApple();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      if (success) {
        showTopToastSuccess(context, l10n.successfullySignedInWithApple);
        await Provider.of<UserProvider>(context, listen: false)
            .refreshUser(syncProStatus: true);
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else {
        showTopToastError(context, l10n.appleSignInCancelledOrFailed);
      }
    } catch (e) {
      if (mounted) {
        showTopToastError(
          context,
          AuthService.instance.getAuthErrorMessage(e),
        );
      }
    } finally {
      _signInSheetAppleBusy.value = false;
    }
  }
}

class _FaqExpansionList extends StatefulWidget {
  final List<Map<String, String>> faqItems;
  final bool isDark;
  final Color textColor;
  final Color secondaryTextColor;

  const _FaqExpansionList({
    required this.faqItems,
    required this.isDark,
    required this.textColor,
    required this.secondaryTextColor,
  });

  @override
  State<_FaqExpansionList> createState() => _FaqExpansionListState();
}

class _FaqExpansionListState extends State<_FaqExpansionList> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final dividerColor =
        widget.isDark ? AppTheme.dividerDark : AppTheme.dividerLight;

    return Column(
      children: List.generate(widget.faqItems.length, (index) {
        final item = widget.faqItems[index];
        final isExpanded = _expandedIndex == index;
        final isLast = index == widget.faqItems.length - 1;

        return Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _expandedIndex = isExpanded ? null : index;
                });
              },
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 2.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item['question']!,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: widget.textColor,
                        ),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: widget.secondaryTextColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: EdgeInsets.only(bottom: 2.h, right: 10.w),
                child: Text(
                  item['answer']!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: widget.secondaryTextColor,
                    height: 1.5,
                  ),
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
            if (!isLast)
              Divider(
                height: 1,
                thickness: 1,
                color: dividerColor.withValues(alpha: 0.3),
              ),
          ],
        );
      }),
    );
  }
}
