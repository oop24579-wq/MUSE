import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class ThemePreviewWidget extends StatelessWidget {
  final String themeName;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color primaryColor;
  final bool isSelected;
  final VoidCallback onTap;

  const ThemePreviewWidget({
    Key? key,
    required this.themeName,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.primaryColor,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : AppTheme.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? AppTheme.getElevationShadow(4)
              : AppTheme.getElevationShadow(2),
        ),
        child: Column(
          children: [
            // Theme preview mockup
            Container(
              height: 12.h,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppTheme.divider.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  // Mock app bar
                  Container(
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 2.w),
                        Container(
                          width: 6.w,
                          height: 2.h,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: Container(
                            height: 1.5.h,
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.textPrimary.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        SizedBox(width: 2.w),
                      ],
                    ),
                  ),
                  // Mock content
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(2.w),
                      child: Column(
                        children: [
                          Container(
                            height: 2.h,
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          SizedBox(height: 1.h),
                          Row(
                            children: [
                              Container(
                                width: 8.w,
                                height: 1.5.h,
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              SizedBox(width: 2.w),
                              Expanded(
                                child: Container(
                                  height: 1.h,
                                  decoration: BoxDecoration(
                                    color: AppTheme.textSecondary
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 1.5.h),
            // Theme name
            Text(
              themeName,
              style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                color: isSelected ? primaryColor : AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSelected) ...[
              SizedBox(height: 0.5.h),
              CustomIconWidget(
                iconName: 'check_circle',
                color: primaryColor,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
