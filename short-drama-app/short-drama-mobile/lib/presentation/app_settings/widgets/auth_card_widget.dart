import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class AuthCardWidget extends StatelessWidget {
  final VoidCallback onGoogleSignIn;
  final VoidCallback onAppleSignIn;
  final VoidCallback onEmailSignIn;

  const AuthCardWidget({
    Key? key,
    required this.onGoogleSignIn,
    required this.onAppleSignIn,
    required this.onEmailSignIn,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.getElevationShadow(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CustomIconWidget(
                  iconName: 'person',
                  color: AppTheme.primary,
                  size: 6.w,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sign In / Sign Up',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 4.5.w,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    
                    Text(
                      'Save your edits and sync across devices',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 3.2.w,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 2.5.h),
          
          // Auth Icons Row - Centered
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIconButton(
                icon: 'language',
                onTap: onGoogleSignIn,
              ),
              SizedBox(width: 3.w),
              _buildIconButton(
                icon: 'apple',
                onTap: onAppleSignIn,
              ),
              SizedBox(width: 3.w),
              _buildIconButton(
                icon: 'email',
                onTap: onEmailSignIn,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required String icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.divider.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: CustomIconWidget(
            iconName: icon,
            color: AppTheme.textPrimary,
            size: 6.w,
          ),
        ),
      ),
    );
  }
}

