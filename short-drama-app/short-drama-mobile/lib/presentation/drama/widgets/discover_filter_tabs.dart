import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../models/drama/content_type.dart';

/// The top filter tabs on Discover: Popular · New · Ranking · Categories.
class DiscoverFilterTabs extends StatelessWidget {
  const DiscoverFilterTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final DiscoverFilter selected;
  final ValueChanged<DiscoverFilter> onSelected;

  static const _labels = {
    DiscoverFilter.popular: 'Popular',
    DiscoverFilter.latest: 'New',
    DiscoverFilter.ranking: 'Ranking',
    DiscoverFilter.categories: 'Categories',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Row(
        children: [
          for (final filter in DiscoverFilter.values)
            _Tab(
              label: _labels[filter]!,
              active: filter == selected,
              textColor: textColor,
              onTap: () => onSelected(filter),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.active,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(right: 5.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: active ? textColor : textColor.withValues(alpha: 0.5),
                fontSize: active ? 13.sp : 12.sp,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: 0.5.h),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: active ? 6.w : 0,
              decoration: BoxDecoration(
                gradient: AppTheme.proBadgeGradient,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
