import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/onesignal_service.dart';

class NotificationSettingsBottomSheet extends StatefulWidget {
  const NotificationSettingsBottomSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppTheme.elevatedPanelBackground(isDark),
      shape: AppTheme.settingsSheetShape,
      builder: (_) => const NotificationSettingsBottomSheet(),
    );
  }

  @override
  State<NotificationSettingsBottomSheet> createState() =>
      _NotificationSettingsBottomSheetState();
}

class _NotificationSettingsBottomSheetState
    extends State<NotificationSettingsBottomSheet> {
  bool _enabled = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadEnabledState();
  }

  Future<void> _loadEnabledState() async {
    await OneSignalService.ready;
    if (!mounted) return;
    setState(() => _enabled = OneSignalService.isEnabled);
  }

  Future<void> _toggle(bool value) async {
    if (_loading) return;
    setState(() => _loading = true);
    if (value) {
      final granted = await OneSignalService.enable();
      if (mounted) {
        setState(() {
          _enabled = granted;
          _loading = false;
        });
      }
    } else {
      await OneSignalService.disable();
      if (mounted) {
        setState(() {
          _enabled = false;
          _loading = false;
        });
      }
    }
  }

  Widget _compactSwitch({
    required bool value,
    required ValueChanged<bool>? onChanged,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor =
        isDark ? AppTheme.dividerDark : AppTheme.dividerLight;
    final primaryText =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final secondaryText =
        isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;
    final rowBackground = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: AppTheme.settingsSheetDecoration(
          isDark: isDark,
          secondaryTextColor: secondaryText,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(5.w, 0, 5.w, 2.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 1.2.h),
                Container(
                  width: 12.w,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dividerColor.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  l10n.notifications,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: primaryText,
                  ),
                ),
                SizedBox(height: 0.6.h),
                Text(
                  l10n.notificationSettingsDescription,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: secondaryText,
                  ),
                ),
                SizedBox(height: 2.h),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _loading ? null : () => _toggle(!_enabled),
                    child: Ink(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 1.4.h,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: rowBackground,
                        border: Border.all(
                          color: dividerColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            _enabled
                                ? Icons.notifications_active_outlined
                                : Icons.notifications_off_outlined,
                            color: primaryText.withValues(alpha: 0.9),
                            size: 22,
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.pushNotifications,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: primaryText,
                                  ),
                                ),
                                SizedBox(height: 0.3.h),
                                Text(
                                  _enabled
                                      ? l10n.notificationsEnabled
                                      : l10n.notificationsDisabledShort,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_loading)
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primaryText.withValues(alpha: 0.7),
                              ),
                            )
                          else
                            _compactSwitch(
                              value: _enabled,
                              onChanged: _toggle,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
