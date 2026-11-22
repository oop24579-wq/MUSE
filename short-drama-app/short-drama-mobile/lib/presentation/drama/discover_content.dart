import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../models/drama/content_type.dart';
import '../../models/drama/home_section_model.dart';
import '../../models/drama/series_model.dart';
import '../../providers/drama/drama_providers.dart';
import '../../widgets/async_refresh_builder.dart';
import '../../widgets/tile_image.dart';
import 'drama_navigation.dart';
import 'widgets/discover_filter_tabs.dart';
import 'widgets/drama_section.dart';
import 'widgets/featured_hero_card.dart';
import 'widgets/genre_grid.dart';
import 'widgets/ranking_list_tile.dart';
import 'widgets/series_poster_card.dart';

class DiscoverContent extends ConsumerWidget {
  const DiscoverContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filter = ref.watch(discoverFilterProvider);

    return Column(
      children: [
        _searchBar(context, isDark),
        SizedBox(height: 1.h),
        DiscoverFilterTabs(
          selected: filter,
          onSelected: (f) => ref.read(discoverFilterProvider.notifier).state = f,
        ),
        SizedBox(height: 1.h),
        Expanded(child: _body(context, ref, filter)),
      ],
    );
  }

  Widget _searchBar(BuildContext context, bool isDark) {
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 0),
      child: GestureDetector(
        onTap: () => DramaNav.openSearch(context),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.4.h),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDarkBlue : AppTheme.cardLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded,
                  color: textColor.withValues(alpha: 0.5), size: 20),
              SizedBox(width: 2.w),
              Text('Search dramas…',
                  style: TextStyle(
                      color: textColor.withValues(alpha: 0.5), fontSize: 11.sp)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, DiscoverFilter filter) {
    switch (filter) {
      case DiscoverFilter.popular:
        return _homeFeed(context, ref);
      case DiscoverFilter.categories:
        return _categories(context, ref);
      case DiscoverFilter.latest:
      case DiscoverFilter.ranking:
        return _list(context, ref, filter);
    }
  }

  Widget _homeFeed(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeFeedProvider);
    return AsyncRefreshBuilder(
      asyncValue: async,
      onRefresh: () => ref.refresh(homeFeedProvider.future),
      builder: (context, sections) {
        return ListView(
          padding: EdgeInsets.only(bottom: 3.h),
          children: [
            for (final section in sections) _section(context, ref, section),
          ],
        );
      },
    );
  }

  Widget _section(BuildContext context, WidgetRef ref, HomeSectionModel section) {
    switch (section.sectionType) {
      case SectionType.featuredHero:
        return _FeaturedPager(items: section.items);
      case SectionType.rankingList:
        return _rankingSection(context, section);
      case SectionType.genreGrid:
        return _inlineCategories(context, ref, section.title);
      case SectionType.verticalGrid:
        return _verticalGrid(context, section);
      case SectionType.hotGrid:
        return _hotGrid(context, section);
      case SectionType.newReleases:
      case SectionType.seriesCarousel:
      case SectionType.continueWatching:
      case SectionType.forYou:
      case SectionType.unknown:
        // for_you (round 4): the personalized section computed by the
        // backend in GET /home renders with the standard carousel shelf.
        return _carousel(context, section);
    }
  }

  /// 2-column vertical poster grid ("You'll Love").
  Widget _verticalGrid(BuildContext context, HomeSectionModel section) {
    if (section.items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DramaSectionHeader(title: section.title, subtitle: section.subtitle),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Wrap(
            spacing: 3.w,
            runSpacing: 2.h,
            children: [
              for (final s in section.items)
                SeriesPosterCard(
                  series: s,
                  width: 43.w,
                  onTap: () => DramaNav.openSeries(context, s),
                ),
            ],
          ),
        ),
        SizedBox(height: dramaSectionSpacing(context)),
      ],
    );
  }

  /// 3-row horizontally-scrolling grid ("What's Hot").
  Widget _hotGrid(BuildContext context, HomeSectionModel section) {
    if (section.items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DramaSectionHeader(title: section.title, subtitle: section.subtitle),
        SizedBox(
          height: 30.h,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 rows (cross axis is vertical here)
              mainAxisExtent: 64.w, // width of each tile
              mainAxisSpacing: 3.w,
              crossAxisSpacing: 1.2.h,
            ),
            itemCount: section.items.length,
            itemBuilder: (_, i) => _HotTile(
              rank: i + 1,
              series: section.items[i],
              onTap: () => DramaNav.openSeries(context, section.items[i]),
            ),
          ),
        ),
        SizedBox(height: dramaSectionSpacing(context)),
      ],
    );
  }

  Widget _carousel(BuildContext context, HomeSectionModel section) {
    if (section.items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DramaSectionHeader(title: section.title, subtitle: section.subtitle),
        SizedBox(
          height: posterCarouselHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            itemCount: section.items.length,
            separatorBuilder: (_, __) => SizedBox(width: 3.w),
            itemBuilder: (_, i) => SeriesPosterCard(
              series: section.items[i],
              onTap: () => DramaNav.openSeries(context, section.items[i]),
            ),
          ),
        ),
        SizedBox(height: dramaSectionSpacing(context)),
      ],
    );
  }

  Widget _rankingSection(BuildContext context, HomeSectionModel section) {
    if (section.items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DramaSectionHeader(title: section.title, subtitle: section.subtitle),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Column(
            children: [
              for (int i = 0; i < section.items.length; i++)
                RankingListTile(
                  rank: i + 1,
                  series: section.items[i],
                  onTap: () => DramaNav.openSeries(context, section.items[i]),
                ),
            ],
          ),
        ),
        SizedBox(height: dramaSectionSpacing(context)),
      ],
    );
  }

  Widget _inlineCategories(BuildContext context, WidgetRef ref, String title) {
    final genresAsync = ref.watch(dramaGenresProvider);
    return genresAsync.maybeWhen(
      data: (genres) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DramaSectionHeader(title: title),
          GenreGrid(
            genres: genres,
            onSelected: (g) => DramaNav.openCategory(context, g),
          ),
          SizedBox(height: dramaSectionSpacing(context)),
        ],
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _categories(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dramaGenresProvider);
    return AsyncRefreshBuilder(
      asyncValue: async,
      onRefresh: () => ref.refresh(dramaGenresProvider.future),
      builder: (context, genres) => ListView(
        padding: EdgeInsets.fromLTRB(0, 1.h, 0, 3.h),
        children: [
          GenreCardGrid(
            genres: genres,
            onSelected: (g) => DramaNav.openCategory(context, g),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, WidgetRef ref, DiscoverFilter filter) {
    final async = ref.watch(discoverListProvider);
    return AsyncRefreshBuilder(
      asyncValue: async,
      onRefresh: () => ref.refresh(discoverListProvider.future),
      builder: (context, series) {
        if (series.isEmpty) {
          return const Center(child: Text('Nothing here yet'));
        }
        if (filter == DiscoverFilter.ranking) {
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 3.h),
            itemCount: series.length,
            itemBuilder: (_, i) => RankingListTile(
              rank: i + 1,
              series: series[i],
              onTap: () => DramaNav.openSeries(context, series[i]),
            ),
          );
        }
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 3.h),
          child: Wrap(
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
        );
      },
    );
  }
}

/// Compact horizontal tile used inside the "What's Hot" 3-row grid.
class _HotTile extends StatelessWidget {
  const _HotTile({required this.rank, required this.series, this.onTap});

  final int rank;
  final SeriesModel series;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          SizedBox(
            width: 6.w,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w900,
                height: 1,
                color: rank <= 3
                    ? AppTheme.accentBlue
                    : textColor.withValues(alpha: 0.35),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: TileImage(
                imageUrl: series.posterUrl,
                fallbackIcon: Icons.movie_rounded,
                isDark: isDark,
              ),
            ),
          ),
          SizedBox(width: 2.5.w),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  series.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 0.4.h),
                Row(
                  children: [
                    Icon(Icons.play_arrow_rounded,
                        size: 12, color: textColor.withValues(alpha: 0.5)),
                    SizedBox(width: 0.5.w),
                    Text(
                      series.viewCountLabel,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.5),
                        fontSize: 8.5.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedPager extends StatefulWidget {
  const _FeaturedPager({required this.items});
  final List<SeriesModel> items;

  @override
  State<_FeaturedPager> createState() => _FeaturedPagerState();
}

class _FeaturedPagerState extends State<_FeaturedPager> {
  final _controller = PageController(viewportFraction: 0.9);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(height: 1.h),
        SizedBox(
          height: 26.h,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (p) => setState(() => _page = p),
            itemCount: widget.items.length,
            itemBuilder: (_, i) => Padding(
              padding: EdgeInsets.symmetric(horizontal: 1.5.w),
              child: FeaturedHeroCard(
                series: widget.items[i],
                onTap: () => DramaNav.openSeries(context, widget.items[i]),
              ),
            ),
          ),
        ),
        SizedBox(height: 1.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < widget.items.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page
                      ? AppTheme.accentBlue
                      : AppTheme.accentBlue.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
        SizedBox(height: 2.h),
      ],
    );
  }
}
