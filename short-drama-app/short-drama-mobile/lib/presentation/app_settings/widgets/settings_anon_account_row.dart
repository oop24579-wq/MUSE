import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/guest_profile_store.dart';
import '../../../services/user_provider.dart';
import '../../../widgets/top_toast.dart';
import 'settings_opacity_tap.dart';

/// Anonymous account row: icon + name, truncated ID + copy (full ID on copy).
class SettingsAnonAccountRow extends StatefulWidget {
  const SettingsAnonAccountRow({
    super.key,
    required this.textColor,
    required this.secondaryTextColor,
    required this.onTap,
  });

  final Color textColor;
  final Color secondaryTextColor;
  final VoidCallback onTap;

  @override
  State<SettingsAnonAccountRow> createState() => _SettingsAnonAccountRowState();
}

class _SettingsAnonAccountRowState extends State<SettingsAnonAccountRow> {
  String? _guestName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGuestName());
  }

  Future<void> _loadGuestName() async {
    final uid = context.read<UserProvider>().userId;
    if (uid == null) return;
    final name = await GuestProfileStore.displayNameFor(uid);
    if (mounted) setState(() => _guestName = name);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final user = userProvider.user;
        final fb = userProvider.fbUser;
        final userId = userProvider.userId ?? fb?.uid ?? '';
        final displayName = user?.displayName ??
            _guestName ??
            fb?.displayName ??
            l10n.user;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SettingsOpacityTap(
                focusDebugLabel: 'settings_anon_sign_in',
                onTap: widget.onTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 20,
                      color: widget.secondaryTextColor.withValues(alpha: 0.9),
                    ),
                    SizedBox(width: 3.w),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 32.w),
                      child: Text(
                        displayName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: widget.textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (userId.isNotEmpty) ...[
                Flexible(
                  child: Text(
                    userId,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: widget.secondaryTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
                SizedBox(width: 1.5.w),
                SettingsOpacityTap(
                  focusDebugLabel: 'settings_anon_copy_id',
                  onTap: () => _copyUserId(userId),
                  child: Icon(
                    Icons.copy_outlined,
                    color: widget.secondaryTextColor,
                    size: 18,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
