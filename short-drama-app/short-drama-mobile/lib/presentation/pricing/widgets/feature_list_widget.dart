import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class FeatureListWidget extends StatelessWidget {
  const FeatureListWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomIconWidget(
                iconName: 'star',
                color: AppTheme.warning,
                size: 5.w,
              ),
              SizedBox(width: 3.w),
              Text(
                'Pro Features',
                style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildFeatureItem(
            'Unlimited Recordings',
            'Record as much as you want without any time limits',
            'mic',
          ),
          _buildFeatureItem(
            'Cloud Synchronization',
            'Automatic backup and sync across all your devices',
            'cloud_sync',
          ),
          _buildFeatureItem(
            'Advanced Audio Processing',
            'Noise reduction, echo cancellation, and audio enhancement',
            'tune',
          ),
          _buildFeatureItem(
            'Multiple Export Formats',
            'Export to MP3, WAV, FLAC, and more professional formats',
            'file_download',
          ),
          _buildFeatureItem(
            'Custom Categories',
            'Organize your recordings with unlimited custom categories',
            'folder',
          ),
          _buildFeatureItem(
            'Auto-Backup',
            'Automatic backup to prevent data loss',
            'backup',
          ),
          _buildFeatureItem(
            'Priority Support',
            'Get help faster with priority customer support',
            'support_agent',
          ),
          _buildFeatureItem(
            'Advanced Analytics',
            'Detailed insights about your recording patterns and usage',
            'analytics',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description, String iconName) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10.w,
            height: 10.w,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: CustomIconWidget(
                iconName: iconName,
                color: AppTheme.primary,
                size: 5.w,
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
                  style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  description,
                  style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
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
