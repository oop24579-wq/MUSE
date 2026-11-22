import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../models/drama/content_type.dart';
import '../../providers/drama/drama_providers.dart';
import '../../widgets/async_refresh_builder.dart';
import 'drama_navigation.dart';
import 'widgets/continue_watching_card.dart';
import 'widgets/series_poster_card.dart';

class MyListContent extends ConsumerStatefulWidget {
  const MyListContent({super.key});

  @override
  ConsumerState<MyListContent> createState() => _MyListContentState();
}

class _MyListContentState extends ConsumerState<MyListContent> {
  MyListTab _tab = MyListTab.recentlyWatched;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        SizedBox(height: 1.h),
        _tabs(isDark),
        SizedBox(height: 1.h),
        Expanded(
          child: _tab == MyListTab.recentlyWatched
              ? _recentlyWatched()
              : _collection(),
        ),
      ],
    );
  }

  Widget _tabs(bool isDark) {
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    Widget tab(String label, MyListTab value) {
      final active = _tab == value;
      return GestureDetector(
        onTap: () => setState(() => _tab = value),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                    color: active ? textColor : textColor.withValues(alpha: 0.5),
                    fontSize: active ? 12.5.sp : 12.sp,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    letterSpacing: 0.3)),
            SizedBox(height: 0.5.h),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: active ? 8.w : 0,
              decoration: BoxDecoration(
                gradient: AppTheme.proBadgeGradient,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Row(
        children: [
          tab('Recently Watched', MyListTab.recentlyWatched),
          SizedBox(width: 6.w),
          tab('My Collection', MyListTab.collection),
        ],
      ),
    );
  }

  Widget _recentlyWatched() {
    final async = ref.watch(watchHistoryProvider);
    return AsyncRefreshBuilder(
      asyncValue: async,
      onRefresh: () => ref.refresh(watchHistoryProvider.future),
      builder: (context, entries) {
        if (entries.isEmpty) {
          return _empty('Nothing watched yet', 'Start a drama to see it here');
        }
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 3.h),
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.start,
              spacing: 3.w,
              runSpacing: 2.h,
              children: [
                for (final e in entries)
                  ContinueWatchingCard(
                    entry: e,
                    width: 44.w,
                    onTap: () => DramaNav.openSeries(context, e.series),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _collection() {
    final async = ref.watch(myListProvider);
    return AsyncRefreshBuilder(
      asyncValue: async,
      onRefresh: () => ref.refresh(myListProvider.future),
      builder: (context, series) {
        if (series.isEmpty) {
          return _empty('Your collection is empty', 'Tap "My List" on any drama to save it');
        }
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 3.h),
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.start,
              spacing: 2.w,
              runSpacing: 2.h,
              children: [
                for (final s in series)
                  SeriesPosterCard(
                    series: s,
                    width: 28.5.w,
                    onTap: () => DramaNav.openSeries(context, s),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _empty(String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    return ListView(
      children: [
        SizedBox(height: 20.h),
        Icon(Icons.bookmark_border_rounded,
            size: 56, color: textColor.withValues(alpha: 0.3)),
        SizedBox(height: 2.h),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: textColor, fontSize: 12.sp, fontWeight: FontWeight.w700)),
        SizedBox(height: 1.h),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: textColor.withValues(alpha: 0.5), fontSize: 10.sp)),
      ],
    );
  }
}
