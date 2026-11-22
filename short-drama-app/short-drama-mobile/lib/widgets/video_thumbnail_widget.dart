import 'package:flutter/material.dart';

import '../core/app_export.dart';

class VideoThumbnailWidget extends StatelessWidget {
  final String? thumbnailUrl;

  const VideoThumbnailWidget({
    Key? key,
    this.thumbnailUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return Image.network(
        thumbnailUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(context),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppTheme.accentBlue.withValues(alpha: 0.3),
                  AppTheme.cardDarkBlue.withValues(alpha: 0.8),
                ]
              : [
                  AppTheme.accentBlue.withValues(alpha: 0.15),
                  AppTheme.accentBlue.withValues(alpha: 0.05),
                ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.videocam_rounded,
          color: AppTheme.accentBlue.withValues(alpha: 0.5),
          size: 36,
        ),
      ),
    );
  }
}
