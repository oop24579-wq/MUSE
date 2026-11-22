import 'package:flutter/material.dart';

enum MainTabBarIconKind {
  discover,
  shorts,
  rewards,
  myList,
  profile,
}

class MainTabBarIcon extends StatelessWidget {
  const MainTabBarIcon({
    super.key,
    required this.kind,
    required this.color,
    required this.isSelected,
    this.size = 24,
  });

  final MainTabBarIconKind kind;
  final Color color;
  final bool isSelected;
  final double size;

  static IconData _iconFor(MainTabBarIconKind kind, bool isSelected) {
    switch (kind) {
      case MainTabBarIconKind.discover:
        return isSelected ? Icons.home_rounded : Icons.home_outlined;
      case MainTabBarIconKind.shorts:
        return isSelected
            ? Icons.play_circle_fill_rounded
            : Icons.play_circle_outline_rounded;
      case MainTabBarIconKind.rewards:
        return isSelected ? Icons.card_giftcard_rounded : Icons.card_giftcard;
      case MainTabBarIconKind.myList:
        return isSelected ? Icons.bookmark_rounded : Icons.bookmark_border_rounded;
      case MainTabBarIconKind.profile:
        return isSelected ? Icons.person_rounded : Icons.person_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Icon(_iconFor(kind, isSelected), color: color, size: size);
  }
}
