import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../theme/app_theme.dart';

/// Grouped settings rows inside a rounded card (app theme surfaces).
class SettingsMenuCard extends StatelessWidget {
  const SettingsMenuCard({
    super.key,
    this.header,
    required this.children,
    required this.isDark,
    required this.secondaryTextColor,
  });

  final Widget? header;
  final List<Widget> children;
  final bool isDark;
  final Color secondaryTextColor;

  @override
  Widget build(BuildContext context) {
    final surface = AppTheme.elevatedPanelBackground(isDark);
    final dividerColor = isDark ? AppTheme.dividerDark : AppTheme.dividerLight;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: secondaryTextColor.withValues(alpha: isDark ? 0.09 : 0.11),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 1.2.h),
              child: header!,
            ),
            Divider(
              height: 1,
              thickness: 1,
              indent: 4.w,
              endIndent: 4.w,
              color: dividerColor.withValues(alpha: 0.45),
            ),
          ],
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 4.w,
                endIndent: 4.w,
                color: dividerColor.withValues(alpha: 0.45),
              ),
          ],
        ],
      ),
    );
  }
}
