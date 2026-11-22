import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../l10n/app_localizations.dart';

class SignInOptionsBottomSheet extends StatelessWidget {
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onEmail;
  final ValueListenable<bool> googleLoadingListenable;
  final ValueListenable<bool> appleLoadingListenable;

  const SignInOptionsBottomSheet({
    Key? key,
    required this.onGoogle,
    required this.onApple,
    required this.onEmail,
    required this.googleLoadingListenable,
    required this.appleLoadingListenable,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onGoogle,
    required VoidCallback onApple,
    required VoidCallback onEmail,
    required ValueListenable<bool> googleLoadingListenable,
    required ValueListenable<bool> appleLoadingListenable,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppTheme.elevatedPanelBackground(isDark),
      shape: AppTheme.settingsSheetShape,
      builder: (sheetContext) => SignInOptionsBottomSheet(
        onGoogle: onGoogle,
        onApple: onApple,
        onEmail: onEmail,
        googleLoadingListenable: googleLoadingListenable,
        appleLoadingListenable: appleLoadingListenable,
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
    final showApple = Platform.isIOS || Platform.isMacOS;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: AppTheme.settingsSheetDecoration(
          isDark: isDark,
          secondaryTextColor: secondaryText,
        ),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(5.w, 0, 5.w, 2.h),
          child: SafeArea(
            top: false,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                googleLoadingListenable,
                appleLoadingListenable,
              ]),
              builder: (context, _) {
                final isGoogleLoading = googleLoadingListenable.value;
                final isAppleLoading = appleLoadingListenable.value;
                final busy = isGoogleLoading || isAppleLoading;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        margin: EdgeInsets.only(top: 1.2.h),
                        width: 12.w,
                        height: 4,
                        decoration: BoxDecoration(
                          color: dividerColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      l10n.signInSignUp,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                    SizedBox(height: 0.6.h),
                    Text(
                      l10n.signInOrCreateNewAccount,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: secondaryText,
                      ),
                    ),
                    SizedBox(height: 2.5.h),

                    // Google
                    _ScalePressPillButton(
                      enabled: !busy,
                      onTap: onGoogle,
                      child: _PillBody(
                        color: isDark
                            ? AppTheme.cardDarkBlue
                            : const Color(0xFFF3F4F6),
                        border: Border.all(
                          color: isDark
                              ? AppTheme.dividerDark.withValues(alpha: 0.6)
                              : dividerColor.withValues(alpha: 0.55),
                          width: 1,
                        ),
                        icon: isGoogleLoading
                            ? _pillLoader(primaryText)
                            : SvgPicture.string(
                                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
                                '<path d="$_kGoogleBrandPath"/>'
                                '</svg>',
                                width: 14,
                                height: 14,
                                colorFilter: ColorFilter.mode(
                                    primaryText, BlendMode.srcIn),
                              ),
                        label: l10n.continueWithGoogle,
                        labelColor: primaryText,
                      ),
                    ),

                    if (showApple) ...[
                      SizedBox(height: 1.5.h),
                      _ScalePressPillButton(
                        enabled: !busy,
                        onTap: onApple,
                        child: _PillBody(
                          color: isDark ? Colors.white : Colors.black,
                          icon: isAppleLoading
                              ? _pillLoader(
                                  isDark ? Colors.black : Colors.white)
                              : SvgPicture.string(
                                  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
                                  '<path d="$_kAppleBrandPath"/>'
                                  '</svg>',
                                  width: 16,
                                  height: 16,
                                  colorFilter: ColorFilter.mode(
                                      isDark ? Colors.black : Colors.white,
                                      BlendMode.srcIn),
                                ),
                          label: l10n.continueWithApple,
                          labelColor: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    ],

                    SizedBox(height: 1.5.h),
                    // Email
                    _ScalePressPillButton(
                      enabled: !busy,
                      onTap: onEmail,
                      child: _PillBody(
                        color: isDark
                            ? AppTheme.accentBlue.withValues(alpha: 0.08)
                            : AppTheme.surfaceLight,
                        border: Border.all(
                          color: isDark
                              ? AppTheme.accentBlue.withValues(alpha: 0.4)
                              : dividerColor.withValues(alpha: 0.9),
                          width: 1.2,
                        ),
                        icon: SvgPicture.string(
                                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
                                '<path d="$_kEmailPath"/>'
                                '</svg>',
                                width: 16,
                                height: 16,
                                colorFilter: ColorFilter.mode(
                                    AppTheme.accentBlue, BlendMode.srcIn),
                              ),
                        label: l10n.continueWithEmail,
                        labelColor: primaryText,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ScalePressPillButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  const _ScalePressPillButton({
    required this.child,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<_ScalePressPillButton> createState() => _ScalePressPillButtonState();
}

class _ScalePressPillButtonState extends State<_ScalePressPillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:
          widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp:
          widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel:
          widget.enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

Widget _pillLoader(Color color) => SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );

class _PillBody extends StatelessWidget {
  const _PillBody({
    required this.color,
    this.border,
    required this.icon,
    required this.label,
    required this.labelColor,
  });

  final Color color;
  final BoxBorder? border;
  final Widget icon;
  final String label;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
        border: border,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 24, height: 24, child: Center(child: icon)),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

const _kGoogleBrandPath =
    'M12.48 10.92v3.28h7.84c-.24 1.84-.853 3.187-1.8 4.133-1.08 1.08-2.76 2.267-6.04 2.267-4.813 0-8.573-3.88-8.573-8.693s3.76-8.693 8.573-8.693c2.6 0 4.507 1.027 5.907 2.347l2.307-2.307C18.747 1.44 16.133 0 12.48 0 5.867 0 .307 5.387.307 12s5.56 12 12.173 12c3.573 0 6.267-1.173 8.373-3.36 2.16-2.16 2.84-5.213 2.84-7.667 0-.76-.053-1.467-.173-2.053H12.48z';

const _kAppleBrandPath =
    'M14.94 5.19A4.38 4.38 0 0 0 16 2a4.44 4.44 0 0 0-2.87 1.49 4.15 4.15 0 0 0-1.06 3.01 3.68 3.68 0 0 0 2.87-1.31zm1.58 1.7c-1.59-.09-2.94.9-3.69.9s-1.93-.86-3.19-.84a4.72 4.72 0 0 0-3.96 2.42c-1.69 2.93-.43 7.27 1.22 9.65.8 1.18 1.76 2.48 3.03 2.44 1.21-.05 1.67-.79 3.14-.79s1.88.79 3.16.76c1.31-.02 2.13-1.19 2.93-2.37a10.9 10.9 0 0 0 1.33-2.72 4.3 4.3 0 0 1-2.57-3.92 4.37 4.37 0 0 1 2.08-3.67 4.48 4.48 0 0 0-3.48-1.86z';

const _kEmailPath =
    'M1.5 8.67v8.58a3 3 0 0 0 3 3h15a3 3 0 0 0 3-3V8.67l-8.928 5.493a3 3 0 0 1-3.144 0L1.5 8.67ZM22.5 6.908V6.75a3 3 0 0 0-3-3h-15a3 3 0 0 0-3 3v.158l9.714 5.978a1.5 1.5 0 0 0 1.572 0L22.5 6.908Z';
