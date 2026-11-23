import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_export.dart';
import '../../core/tab_router.dart';
import '../../services/app_lock_service.dart';
import '../../services/double_back_guard.dart';
import '../../services/drama/drama_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/main_tab_bar.dart';
import '../../widgets/top_toast.dart';
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

  /// Double-back-to-exit window logic (round 5, item 5b).
  final DoubleBackGuard _exitGuard = DoubleBackGuard();

  /// Section titles shown by the collapsed smart header (item 4).
  static const _tabTitles = [
    'Discover',
    'Shorts',
    'Rewards',
    'My List',
    'Profile',
  ];

  /// Progress (0..1) of the most recent in-progress Continue Watching
  /// entry, shown as a thin bar in the collapsed header. Null = no
  /// in-progress entry → the bar is hidden (never faked).
  double? _cwProgress;

  /// Drives the collapsing app header on the Home tab.
  /// 1.0 = header fully shown, 0.0 = header fully hidden (only the tabs remain).
  late final AnimationController _headerController;

  /// Distance from the very top before we allow the header to hide, so a tiny
  /// scroll near the top does not flicker the header away.
  static const double _hideThreshold = 8;

  List<Widget> get _tabs => [
        const DiscoverContent(),
        // Round 4: the Shorts feed plays video — it needs to know when its
        // tab is not the visible one so clips pause (IndexedStack keeps
        // every tab mounted).
        ShortsContent(isTabActive: _currentIndex == 1),
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
    // Round 5 (item 12): reaching the home shell arms the app lock —
    // this is the first "content" surface after splash routing, so an
    // enabled lock gates here, never during the splash/consent chain.
    AppLockService.instance.arm();
    _loadContinueWatching();
  }

  /// Latest in-progress Continue Watching entry → header progress bar.
  Future<void> _loadContinueWatching() async {
    try {
      final history = await DramaService.instance.fetchWatchHistory(limit: 5);
      if (!mounted) return;
      double? progress;
      for (final e in history) {
        if (!e.completed && e.episodeProgress > 0) {
          progress = e.episodeProgress;
          break;
        }
      }
      if (progress != _cwProgress) setState(() => _cwProgress = progress);
    } catch (_) {
      // Header decoration only; failures keep the previous value.
    }
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
      _exitGuard.reset();
      if (index == 0) _loadContinueWatching();
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
    // Round 5 (item 5b): first press arms the guard and tells the
    // user; a second press inside the window actually exits.
    if (_exitGuard.registerPress(DateTime.now())) {
      SystemNavigator.pop();
    } else if (mounted) {
      showTopToastInfo(context, 'Press back again to exit');
    }
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
            _CollapsingHeader(
              controller: _headerController,
              title: _tabTitles[_currentIndex],
              progress: _cwProgress,
            ),
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
///
/// Round 5 (item 4 — "smart header"): instead of vanishing completely,
/// the header collapses INTO a slim frosted bar that keeps the current
/// section title visible plus a thin Continue Watching progress bar
/// (hidden when there is no in-progress entry).
class _CollapsingHeader extends StatefulWidget {
  const _CollapsingHeader({
    required this.controller,
    required this.title,
    required this.progress,
  });

  final AnimationController controller;

  /// Contextual section title for the collapsed slim bar.
  final String title;

  /// Continue Watching progress 0..1, or null to hide the bar.
  final double? progress;

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
          // Slim smart bar: grows in exactly as the full header leaves.
          AnimatedBuilder(
            animation: curved,
            builder: (context, _) {
              final t = curved.value;
              final height = (1 - t) * 38.0;
              if (height < 1) return const SizedBox.shrink();
              return ClipRect(
                child: SizedBox(
                  height: height,
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: _SlimSmartBar(
                      title: widget.title,
                      progress: widget.progress,
                      isDark: isDark,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The collapsed form of the smart header: frosted slim bar with the
/// current section title and an optional watch-progress hairline.
class _SlimSmartBar extends StatelessWidget {
  const _SlimSmartBar({
    required this.title,
    required this.progress,
    required this.isDark,
  });

  final String title;
  final double? progress;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.pageBackground(isDark);
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          color: bg.withValues(alpha: 0.78),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
              if (progress != null)
                LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  minHeight: 2,
                  backgroundColor: textColor.withValues(alpha: 0.12),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
