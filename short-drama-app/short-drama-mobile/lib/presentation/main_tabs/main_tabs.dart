import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_export.dart';
import '../../core/tab_router.dart';
import '../../widgets/app_header.dart';
import '../../widgets/main_tab_bar.dart';
import '../drama/discover_content.dart';
import '../drama/shorts_content.dart';
import '../drama/rewards_content.dart';
import '../drama/my_list_content.dart';
import '../drama/profile_content.dart';

/// Main 5-tab shell: Discover, Shorts, Rewards, My List, Profile.
///
/// Uses [IndexedStack] so tab widgets stay mounted and Riverpod caches survive
/// tab switches without refetching.
class MainTabs extends StatefulWidget {
  const MainTabs({super.key});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  DateTime? _lastBackPressedAt;

  /// Drives the collapsing app header on the Home tab.
  /// 1.0 = header fully shown, 0.0 = header fully hidden (only the tabs remain).
  late final AnimationController _headerController;

  /// Distance from the very top before we allow the header to hide, so a tiny
  /// scroll near the top does not flicker the header away.
  static const double _hideThreshold = 8;

  static const _exitConfirmWindow = Duration(seconds: 2);

  List<Widget> get _tabs => [
        const DiscoverContent(),
        const ShortsContent(),
        const RewardsContent(),
        const MyListContent(),
        ProfileContent(
          onGoToRewards: () => _onTabTapped(2),
          onGoToMyList: () => _onTabTapped(3),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 1,
    );
    // Let pushed screens (e.g. the player after a failed unlock) jump to a
    // tab — see TabRouter.
    TabRouter.register(_onTabTapped);
  }

  @override
  void dispose() {
    TabRouter.unregister(_onTabTapped);
    _headerController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
      _revealHeader();
    }
  }

  bool _onHomeScroll(ScrollNotification notification) {
    // Only react to the Home tab's own vertical scrolling.
    if (_currentIndex != 0) return false;
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      final pixels = notification.metrics.pixels;

      if (pixels <= _hideThreshold) {
        _revealHeader();
      } else if (delta > 0.5) {
        _hideHeader();
      } else if (delta < -0.5) {
        _revealHeader();
      }
    }
    return false;
  }

  void _hideHeader() {
    if (_headerController.status != AnimationStatus.reverse &&
        _headerController.value != 0) {
      _headerController.reverse();
    }
  }

  void _revealHeader() {
    if (_headerController.status != AnimationStatus.forward &&
        _headerController.value != 1) {
      _headerController.forward();
    }
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      _onTabTapped(0);
      return false;
    }
    final now = DateTime.now();
    if (_lastBackPressedAt == null ||
        now.difference(_lastBackPressedAt!) > _exitConfirmWindow) {
      _lastBackPressedAt = now;
      return false;
    }
    SystemNavigator.pop();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onWillPop();
      },
      child: Scaffold(
        backgroundColor: AppTheme.pageBackground(isDark),
        body: Column(
          children: [
            _CollapsingHeader(controller: _headerController),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onHomeScroll,
                child: IndexedStack(
                  index: _currentIndex,
                  children: _tabs,
                ),
              ),
            ),
            MainTabBar(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}

/// The `RadioPod` app header row that smoothly collapses and fades as the Home
/// feed is scrolled down, letting the tab chips rise into its place. The top
/// status-bar inset is always preserved so content never slides under the notch.
class _CollapsingHeader extends StatefulWidget {
  const _CollapsingHeader({required this.controller});

  final AnimationController controller;

  @override
  State<_CollapsingHeader> createState() => _CollapsingHeaderState();
}

class _CollapsingHeaderState extends State<_CollapsingHeader> {
  late final CurvedAnimation curved;

  @override
  void initState() {
    super.initState();
    curved = CurvedAnimation(
      parent: widget.controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      color: AppTheme.pageBackground(isDark),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topInset),
          AnimatedBuilder(
            animation: curved,
            builder: (context, child) {
              final t = curved.value;
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: t,
                  child: Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: child,
                  ),
                ),
              );
            },
            child: const AppHeader(includeTopSafeArea: false),
          ),
        ],
      ),
    );
  }
}
