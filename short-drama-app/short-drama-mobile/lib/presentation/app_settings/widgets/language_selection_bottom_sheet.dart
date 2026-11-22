import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/language_service.dart';
import '../../../services/locale_provider.dart';
import '../../../widgets/top_toast.dart';

class LanguageSelectionBottomSheet extends StatelessWidget {
  final VoidCallback? onLocaleChanged;

  const LanguageSelectionBottomSheet({
    super.key,
    this.onLocaleChanged,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onLocaleChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppTheme.elevatedPanelBackground(isDark),
      shape: AppTheme.settingsSheetShape,
      builder: (sheetContext) => LanguageSelectionBottomSheet(
        onLocaleChanged: onLocaleChanged,
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
    final supportedLanguages = LanguageService.instance.getSupportedLanguages();

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
                  l10n.selectLanguage,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: primaryText,
                  ),
                ),
                SizedBox(height: 2.h),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: supportedLanguages.length,
                    separatorBuilder: (_, __) => SizedBox(height: 0.8.h),
                    itemBuilder: (context, index) {
                      final languageCode =
                          supportedLanguages.keys.elementAt(index);
                      final languageName = supportedLanguages[languageCode]!;
                      final flag = LanguageService.instance
                          .getLanguageFlag(languageCode);

                      return Consumer<LocaleProvider>(
                        builder: (context, localeProvider, _) {
                          final isSelected =
                              localeProvider.locale?.languageCode ==
                                  languageCode;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _selectLanguage(
                                context,
                                languageCode: languageCode,
                                languageName: languageName,
                              ),
                              child: Ink(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4.w,
                                  vertical: 1.4.h,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: isSelected
                                      ? AppTheme.accentBlue.withValues(
                                          alpha: isDark ? 0.18 : 0.12,
                                        )
                                      : (isDark
                                          ? AppTheme.cardDarkBlue
                                              .withValues(alpha: 0.45)
                                          : AppTheme.surfaceLight),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.accentBlue
                                            .withValues(alpha: 0.45)
                                        : dividerColor.withValues(
                                            alpha: isDark ? 0.12 : 0.18,
                                          ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      flag,
                                      style: TextStyle(fontSize: 22.sp),
                                    ),
                                    SizedBox(width: 3.5.w),
                                    Expanded(
                                      child: Text(
                                        languageName,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: primaryText,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: AppTheme.accentBlue,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectLanguage(
    BuildContext context, {
    required String languageCode,
    required String languageName,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final localeProvider =
          Provider.of<LocaleProvider>(context, listen: false);
      await localeProvider.setLocale(languageCode);
      if (!context.mounted) return;
      Navigator.pop(context);
      await Future.delayed(const Duration(milliseconds: 150));
      onLocaleChanged?.call();
      if (!context.mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final updatedL10n = AppLocalizations.of(context);
        if (updatedL10n != null) {
          showTopToastInfo(
            context,
            updatedL10n.languageChanged(languageName),
            duration: const Duration(seconds: 2),
          );
        }
      });
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      showTopToastError(context, l10n.failedToChangeLanguage(e.toString()));
    }
  }
}
