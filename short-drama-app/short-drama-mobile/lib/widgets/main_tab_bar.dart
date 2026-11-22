import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

import '../core/app_export.dart';
import '../services/locale_provider.dart';
import 'main_tab_bar_icons.dart';

class MainTabBar extends StatelessWidget {
  const MainTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;

  static const List<MainTabBarIconKind> _iconKinds = [
    MainTabBarIconKind.discover,
    MainTabBarIconKind.shorts,
    MainTabBarIconKind.rewards,
    MainTabBarIconKind.myList,
    MainTabBarIconKind.profile,
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Consumer<LocaleProvider>(
      builder: (context, _, __) {
        const labels = ['Discover', 'Shorts', 'Rewards', 'My List', 'Profile'];

        final barColor = isDark ? const Color(0xFF000000) : AppTheme.surfaceLight;
        final activeColor = isDark ? Colors.white : AppTheme.textPrimaryLight;
        final inactiveColor = isDark
            ? Colors.white.withValues(alpha: 0.38)
            : AppTheme.textSecondaryLight.withValues(alpha: 0.72);

        return Container(
          color: barColor,
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: SizedBox(
            height: 7.h,
            child: Row(
              children: List.generate(_iconKinds.length, (index) {
                final selected = currentIndex == index;
                return Expanded(
                  child: InkWell(
                    onTap: () => onTap(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MainTabBarIcon(
                          kind: _iconKinds[index],
                          color: selected ? activeColor : inactiveColor,
                          isSelected: selected,
                          size: 22,
                        ),
                        SizedBox(height: 0.4.h),
                        Text(
                          labels[index].toUpperCase(),
                          style: TextStyle(
                            color: selected ? activeColor : inactiveColor,
                            fontSize: 7.sp,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
