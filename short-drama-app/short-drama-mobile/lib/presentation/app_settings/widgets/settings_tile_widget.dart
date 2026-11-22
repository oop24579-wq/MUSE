import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class SettingsTileWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? iconName;
  final bool showDivider;

  const SettingsTileWidget({
    Key? key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconName,
    this.showDivider = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: iconName != null
              ? Container(
                  width: 10.w,
                  height: 10.w,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: CustomIconWidget(
                      iconName: iconName!,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                )
              : null,
          title: Text(
            title,
            style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                )
              : null,
          trailing: trailing ??
              (onTap != null
                  ? CustomIconWidget(
                      iconName: 'chevron_right',
                      color: AppTheme.textSecondary,
                      size: 20,
                    )
                  : null),
          onTap: onTap,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.divider.withValues(alpha: 0.3),
            indent: iconName != null ? 18.w : 4.w,
            endIndent: 4.w,
          ),
      ],
    );
  }
}
