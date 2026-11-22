import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class SubscriptionBenefitsWidget extends StatelessWidget {
  const SubscriptionBenefitsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why Choose Pro?',
            style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 2.h),
          _buildBenefitCard(
            'Professional Quality',
            'Record studio-quality audio with advanced processing and noise reduction',
            'high_quality',
            AppTheme.primary,
          ),
          SizedBox(height: 2.h),
          _buildBenefitCard(
            'Never Lose Your Work',
            'Automatic cloud backup ensures your recordings are always safe',
            'cloud_done',
            AppTheme.success,
          ),
          SizedBox(height: 2.h),
          _buildBenefitCard(
            'Work Anywhere',
            'Access your recordings from any device with seamless synchronization',
            'devices',
            AppTheme.warning,
          ),
          SizedBox(height: 2.h),
          _buildBenefitCard(
            'Save Time & Money',
            'Professional features that would cost hundreds in separate tools',
            'savings',
            AppTheme.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitCard(String title, String description, String iconName, Color color) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12.w,
            height: 12.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: CustomIconWidget(
                iconName: iconName,
                color: color,
                size: 6.w,
              ),
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  description,
                  style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
