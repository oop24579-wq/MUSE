import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../models/drama/cast_member.dart';
import '../../models/drama/episode_model.dart';
import '../../models/drama/season_model.dart';
import '../../models/drama/series_model.dart';
import '../../providers/drama/drama_providers.dart';
import '../../services/drama/drama_service.dart';
import '../../widgets/header_glass_chip.dart';
import '../../widgets/tile_image.dart';
import '../../widgets/tile_image_shimmer.dart';
import '../../widgets/top_toast.dart';
import 'drama_navigation.dart';
import 'widgets/drama_section.dart';
import 'widgets/episode_tiles.dart';
import 'widgets/series_badge.dart';
import 'widgets/series_poster_card.dart';

class SeriesDetailScreen extends ConsumerStatefulWidget {
  const SeriesDetailScreen({super.key, required this.seriesId, this.initial});

  final String seriesId;
  final SeriesModel? initial;

  @override
  ConsumerState<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  bool? _favOverride;
  bool? _likeOverride;
  int? _likeCountOverride;
  bool _expandedSynopsis = false;
  int _selectedSeason = 1;

  @override
  void initState() {
    super.initState();
    DramaService.instance.incrementView('series', widget.seriesId);
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(seriesDetailProvider(widget.seriesId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(isDark),
      body: detailAsync.when(
        loading: () => _scaffoldWithInitial(isDark),
        error: (e, _) => _errorView(isDark),
        data: (detail) {
          if (detail == null) return _errorView(isDark);
          return _content(
            detail.series,
            detail.seasons,
            detail.episodes,
            detail.related,
            detail.cast,
            _favOverride ?? detail.isFavorite,
            _likeOverride ?? detail.isLiked,
            isDark,
            detail.resumeEpisodeNumber,
          );
        },
      ),
    );
  }

  Widget _scaffoldWithInitial(bool isDark) {
    final s = widget.initial;
    if (s == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _content(s, const [], const [], const [], const [],
        _favOverride ?? false, _likeOverride ?? false, isDark, null, true);
  }

  Widget _errorView(bool isDark) => SafeArea(
        child: Column(
          children: [
            _topBar(),
            const Expanded(
              child: Center(child: Text('Could not load this series')),
            ),
          ],
        ),
      );

  Widget _content(
    SeriesModel s,
    List<SeasonModel> seasons,
    List<EpisodeModel> episodes,
    List<SeriesModel> related,
    List<CastMember> cast,
    bool isFav,
    bool isLiked,
    bool isDark,
    int? resumeEp, [
    bool loading = false,
  ]) {
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => ref.refresh(seriesDetailProvider(widget.seriesId).future),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _hero(s, episodes, isDark),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 2.h),
                    _actionRow(s, isFav, isLiked),
                    SizedBox(height: 2.h),
                    if (s.synopsis != null && s.synopsis!.isNotEmpty)
                      _synopsis(s, textColor),
                    if (s.tags.isNotEmpty) ...[
                      SizedBox(height: 1.5.h),
                      _tagWrap(s, textColor),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 1.h),
              if (loading && episodes.isEmpty)
                _episodesSkeleton(isDark)
              else
                _episodesSection(s, seasons, episodes, resumeEp, textColor),
              if (cast.isNotEmpty) _castSection(cast, textColor),
              if (related.isNotEmpty)
                _relatedSection(related)
              else if (loading)
                _relatedSkeleton(isDark),
              SizedBox(height: 4.h),
            ],
          ),
        ),
        SafeArea(child: _topBar()),
      ],
    );
  }

  Widget _topBar() => Padding(
        padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 0),
        child: Row(
          children: [
            HeaderGlassIconButton(
              isDark: true,
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      );

  Widget _hero(SeriesModel s, List<EpisodeModel> episodes, bool isDark) {
    return Stack(
      children: [
        SizedBox(
          height: 44.h,
          width: double.infinity,
          child: TileImage(
            imageUrl: s.bannerUrl,
            fallbackIcon: Icons.movie_rounded,
            borderRadius: 0,
            isDark: isDark,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppTheme.pageBackground(isDark).withValues(alpha: 0.4),
                  AppTheme.pageBackground(isDark),
                ],
                stops: const [0.4, 0.8, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          left: 4.w,
          right: 4.w,
          bottom: 1.h,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 1.5.w,
                children: [
                  for (final b in _allBadges(s)) SeriesBadge(kind: b),
                ],
              ),
              SizedBox(height: 1.h),
              Text(
                s.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
                ),
              ),
              SizedBox(height: 0.8.h),
              Text(
                [
                  if (s.genreName != null) s.genreName!,
                  s.episodeLabel,
                  if (s.releaseYear != null) '${s.releaseYear}',
                  '★ ${s.ratingAvg.toStringAsFixed(1)}',
                ].join('  ·  '),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.5.h),
              _playButton(s, episodes),
            ],
          ),
        ),
      ],
    );
  }

  Widget _playButton(SeriesModel s, List<EpisodeModel> episodes) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: episodes.isEmpty
            ? null
            : () => DramaNav.openPlayer(context, series: s, episodes: episodes),
        icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
        label: Text(
          'Play  ·  ${episodes.length} EP',
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 1.4.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }

  Widget _actionRow(SeriesModel s, bool isFav, bool isLiked) {
    final likeCount = _likeCountOverride ?? s.likeCount;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _action(
          icon: isFav ? Icons.check_rounded : Icons.add_rounded,
          label: 'My List',
          active: isFav,
          onTap: () async {
            final add = !isFav;
            setState(() => _favOverride = add);
            await DramaService.instance.toggleFavorite(s.id, add);
            if (mounted) {
              ref.invalidate(myListProvider);
              showTopToastSuccess(
                  context, add ? 'Added to My List' : 'Removed from My List');
            }
          },
        ),
        _action(
          icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: likeCount > 0 ? _fmtK(likeCount) : 'Like',
          active: isLiked,
          activeColor: const Color(0xFFFF4D6D),
          onTap: () => _toggleLike(s, isLiked, likeCount),
        ),
        _action(
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: () => _shareSeries(s),
        ),
        _action(
          icon: Icons.download_outlined,
          label: 'Download',
          onTap: () => showTopToastInfo(context, 'Downloads are a VIP feature'),
        ),
      ],
    );
  }

  Future<void> _toggleLike(SeriesModel s, bool isLiked, int likeCount) async {
    final like = !isLiked;
    // Optimistic update.
    setState(() {
      _likeOverride = like;
      _likeCountOverride = (likeCount + (like ? 1 : -1)).clamp(0, 1 << 31);
    });
    final newCount = await DramaService.instance.toggleLike(s.id, like);
    if (!mounted) return;
    if (newCount != null) {
      setState(() => _likeCountOverride = newCount);
    } else {
      // Revert on failure.
      setState(() {
        _likeOverride = isLiked;
        _likeCountOverride = likeCount;
      });
      showTopToastError(context, 'Could not update like');
    }
  }

  Future<void> _shareSeries(SeriesModel s) async {
    final parts = <String>[
      'Watch "${s.title}" on HERO DRAMA',
      if (s.tagline != null && s.tagline!.isNotEmpty) s.tagline!,
    ];
    try {
      await SharePlus.instance.share(ShareParams(text: parts.join('\n')));
    } catch (_) {
      if (mounted) showTopToastError(context, 'Could not open share');
    }
  }

  Widget _action({
    required IconData icon,
    required String label,
    bool active = false,
    Color? activeColor,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = active
        ? (activeColor ?? AppTheme.accentBlue)
        : (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 0.5.h),
          Text(label,
              style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 8.5.sp)),
        ],
      ),
    );
  }

  Widget _synopsis(SeriesModel s, Color textColor) {
    return GestureDetector(
      onTap: () => setState(() => _expandedSynopsis = !_expandedSynopsis),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.synopsis!,
            maxLines: _expandedSynopsis ? null : 3,
            overflow: _expandedSynopsis ? null : TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.75),
              fontSize: 10.sp,
              height: 1.4,
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            _expandedSynopsis ? 'Show less' : 'Show more',
            style: TextStyle(
                color: AppTheme.accentBlue, fontSize: 9.sp, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _tagWrap(SeriesModel s, Color textColor) {
    return Wrap(
      spacing: 2.w,
      runSpacing: 1.h,
      children: [
        for (final tag in s.tags)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(tag,
                style: TextStyle(
                    color: textColor.withValues(alpha: 0.75), fontSize: 9.sp)),
          ),
      ],
    );
  }

  Widget _episodesSection(SeriesModel s, List<SeasonModel> seasons,
      List<EpisodeModel> episodes, int? resumeEp, Color textColor) {
    if (episodes.isEmpty) return const SizedBox.shrink();

    final multiSeason = seasons.length > 1;
    // Clamp the selected season to a valid value.
    final available = seasons.map((e) => e.seasonNumber).toSet();
    final selected = available.contains(_selectedSeason)
        ? _selectedSeason
        : (seasons.isNotEmpty ? seasons.first.seasonNumber : 1);

    final shown = multiSeason
        ? episodes.where((e) => e.seasonNumber == selected).toList()
        : episodes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DramaSectionHeader(
          title: 'Episodes',
          subtitle: multiSeason
              ? '${seasons.length} seasons · ${episodes.length} episodes'
              : '${episodes.length} episodes',
        ),
        if (multiSeason) _seasonSelector(seasons, selected, textColor),
        Padding(
          padding: EdgeInsets.fromLTRB(4.w, multiSeason ? 1.5.h : 0, 4.w, 0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 1,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: shown.length,
            itemBuilder: (_, i) => EpisodeGridTile(
              episode: shown[i],
              selected: resumeEp != null &&
                  shown[i].episodeNumber == resumeEp &&
                  (!multiSeason || shown[i].seasonNumber == selected),
              onTap: () => DramaNav.openPlayer(
                  context, series: s, episodes: shown, startIndex: i),
            ),
          ),
        ),
      ],
    );
  }

  Widget _seasonSelector(
      List<SeasonModel> seasons, int selected, Color textColor) {
    return SizedBox(
      height: 4.5.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        itemCount: seasons.length,
        separatorBuilder: (_, __) => SizedBox(width: 2.5.w),
        itemBuilder: (_, i) {
          final season = seasons[i];
          final active = season.seasonNumber == selected;
          return GestureDetector(
            onTap: () => setState(() => _selectedSeason = season.seasonNumber),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              decoration: BoxDecoration(
                gradient: active ? AppTheme.proBadgeGradient : null,
                color: active ? null : textColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                season.displayTitle,
                style: TextStyle(
                  color: active ? Colors.black87 : textColor,
                  fontSize: 10.5.sp,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _skeletonBox(bool isDark, {double? width, double? height, double radius = 8}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: TileImageShimmer(isDark: isDark),
      ),
    );
  }

  Widget _episodesSkeleton(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DramaSectionHeader(title: 'Episodes'),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 1,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 15,
            itemBuilder: (_, __) => _skeletonBox(isDark, radius: 10),
          ),
        ),
      ],
    );
  }

  Widget _relatedSkeleton(bool isDark) {
    final w = posterCardWidth(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 2.h),
        const DramaSectionHeader(title: 'More Like This'),
        SizedBox(
          height: posterCarouselHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            itemCount: 4,
            separatorBuilder: (_, __) => SizedBox(width: 3.w),
            itemBuilder: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBox(isDark, width: w, height: w * 4 / 3, radius: 12),
                SizedBox(height: 0.8.h),
                _skeletonBox(isDark, width: w * 0.85, height: 1.4.h, radius: 4),
                SizedBox(height: 0.5.h),
                _skeletonBox(isDark, width: w * 0.5, height: 1.2.h, radius: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _castSection(List<CastMember> cast, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 2.h),
        const DramaSectionHeader(title: 'Cast'),
        SizedBox(
          height: 14.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            itemCount: cast.length,
            separatorBuilder: (_, __) => SizedBox(width: 3.w),
            itemBuilder: (_, i) {
              final m = cast[i];
              return SizedBox(
                width: 18.w,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 7.w,
                      backgroundColor: textColor.withValues(alpha: 0.12),
                      backgroundImage: m.personImageUrl != null &&
                              m.personImageUrl!.isNotEmpty
                          ? NetworkImage(m.personImageUrl!)
                          : null,
                      child: m.personImageUrl == null ||
                              m.personImageUrl!.isEmpty
                          ? Icon(Icons.person, color: textColor.withValues(alpha: 0.5))
                          : null,
                    ),
                    SizedBox(height: 0.8.h),
                    Text(
                      m.personName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    if (m.characterName != null &&
                        m.characterName!.isNotEmpty)
                      Text(
                        m.characterName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: textColor.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _relatedSection(List<SeriesModel> related) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 2.h),
        const DramaSectionHeader(title: 'More Like This'),
        SizedBox(
          height: posterCarouselHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            itemCount: related.length,
            separatorBuilder: (_, __) => SizedBox(width: 3.w),
            itemBuilder: (_, i) => SeriesPosterCard(
              series: related[i],
              onTap: () => DramaNav.openSeries(context, related[i]),
            ),
          ),
        ),
      ],
    );
  }

  List<SeriesBadgeKind> _allBadges(SeriesModel s) {
    final list = <SeriesBadgeKind>[];
    if (s.isVipOnly) list.add(SeriesBadgeKind.vip);
    if (s.isExclusive) list.add(SeriesBadgeKind.exclusive);
    if (s.isHot) list.add(SeriesBadgeKind.hot);
    if (s.isNew) list.add(SeriesBadgeKind.newRelease);
    if (s.isDubbed) list.add(SeriesBadgeKind.dubbed);
    return list;
  }

  String _fmtK(int v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}K' : '$v';
}
