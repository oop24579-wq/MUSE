import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../core/app_export.dart';
import '../l10n/app_localizations.dart';
import '../models/force_update_status.dart';
import '../services/force_update_service.dart';

/// Full-screen dialog when a force or optional update is required.
class ForceUpdateDialog extends StatelessWidget {
  final ForceUpdateStatus status;
  final VoidCallback? onLater;

  const ForceUpdateDialog({
    super.key,
    required this.status,
    this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title =
        status.isMandatory ? l10n.forceUpdateTitle : l10n.optionalUpdateTitle;
    final message = status.isMandatory
        ? l10n.forceUpdateMessage
        : l10n.optionalUpdateMessage;

    return PopScope(
      canPop: !status.isMandatory,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w),
                child: Column(
                  children: [
                    SizedBox(height: 6.h),
                    Container(
                      width: 20.w,
                      height: 20.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Icon(
                        Icons.system_update_rounded,
                        size: 10.w,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      message,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => _openStore(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentBlue,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.download_rounded, size: 18),
                            SizedBox(width: 2.w),
                            Text(
                              l10n.updateNow,
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!status.isMandatory && onLater != null) ...[
                      SizedBox(height: 1.5.h),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: onLater,
                          child: Text(
                            l10n.maybeLater,
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 4.h),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  void _openStore(BuildContext context) {
    ForceUpdateService.instance.openStore(status.storeUrl);
  }

  static Future<void> show(BuildContext context, ForceUpdateStatus status) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (ctx) => ForceUpdateDialog(
          status: status,
          onLater: status.isMandatory ? null : () => Navigator.of(ctx).pop(),
        ),
        fullscreenDialog: true,
      ),
    );
  }
}
