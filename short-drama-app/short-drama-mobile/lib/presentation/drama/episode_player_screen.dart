import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sizer/sizer.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_export.dart';
import '../../models/drama/episode_model.dart';
import '../../models/drama/series_model.dart';
import '../../providers/drama/drama_providers.dart';
import '../../services/drama/drama_entitlement_service.dart';
import '../../services/drama/drama_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/header_glass_chip.dart';
import '../../widgets/tile_image.dart';
import '../../widgets/top_toast.dart';
import 'widgets/coin_balance_header.dart';
import 'widgets/episode_tiles.dart';
import 'widgets/lang_flags.dart';

class EpisodePlayerScreen extends ConsumerStatefulWidget {
  const EpisodePlayerScreen({
    super.key,
    required this.series,
    required this.episodes,
    this.startIndex = 0,
  });

  final SeriesModel series;
  final List<EpisodeModel> episodes;
  final int startIndex;

  @override
  ConsumerState<EpisodePlayerScreen> createState() =>
      _EpisodePlayerScreenState();
}

class _EpisodePlayerScreenState extends ConsumerState<EpisodePlayerScreen> {
  late List<EpisodeModel> _episodes;
  late int _index;
  VideoPlayerController? _controller;
  bool _initializing = false;
  bool _controlsVisible = true;
  bool _locked = false;
  EpisodeAccess _access = EpisodeAccess.playable;

  /// Selected dub language (null = original track).
  String? _selectedLang;

  EpisodeModel get _current => _episodes[_index];
  bool get _isVip => context.read<UserProvider>().isPro;

  /// Languages offered for this series (original + any dubs).
  List<String?> get _languages => [null, ...widget.series.dubLanguages];
  bool get _hasDubs => widget.series.dubLanguages.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _episodes = List.of(widget.episodes);
    _index = widget.startIndex.clamp(0, _episodes.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({Duration? seekTo}) async {
    _disposeController();
    final episode = _current;
    final access = DramaEntitlementService.instance.accessFor(episode, _isVip);
    setState(() {
      _access = access;
      _locked = access != EpisodeAccess.playable;
      _initializing = access == EpisodeAccess.playable;
    });

    if (access != EpisodeAccess.playable) return;

    // The stream URL is fetched from a server-side entitlement check (for the
    // selected language); it is never present in the episode list.
    final url = await DramaService.instance
        .getEpisodeVideoUrl(episode.id, lang: _selectedLang);
    if (!mounted) return;
    if (url == null || url.isEmpty) {
      setState(() {
        _initializing = false;
        _locked = true;
      });
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    try {
      await controller.initialize();
      controller.setLooping(false);
      controller.addListener(_onTick);
      if (seekTo != null && seekTo > Duration.zero) {
        await controller.seekTo(seekTo);
      }
      await controller.play();
      if (mounted) setState(() => _initializing = false);
      DramaService.instance.incrementView('episode', episode.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _locked = true;
        });
      }
    }
  }

  Future<void> _switchLanguage(String? lang) async {
    if (lang == _selectedLang) return;
    final pos = _controller?.value.position;
    setState(() => _selectedLang = lang);
    await _load(seekTo: pos);
  }

  bool _completedRecorded = false;
  void _onTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position.inSeconds;
    final dur = c.value.duration.inSeconds;
    final atEnd = dur > 0 && pos >= dur - 1;
    if (atEnd && !_completedRecorded) {
      _completedRecorded = true;
      _record(completed: true);
      _playNext();
    }
    if (mounted) setState(() {}); // update scrubber
  }

  Future<void> _record({bool completed = false}) async {
    final c = _controller;
    await DramaService.instance.recordWatch(
      seriesId: widget.series.id,
      episodeId: _current.id,
      episodeNumber: _current.episodeNumber,
      positionSeconds: c?.value.position.inSeconds ?? 0,
      durationSeconds: c?.value.duration.inSeconds ?? (_current.durationSeconds ?? 0),
      completed: completed,
    );
  }

  void _playNext() {
    if (_index < _episodes.length - 1) {
      _completedRecorded = false;
      setState(() => _index++);
      _load();
    }
  }

  void _playAt(int index) {
    if (index == _index) return;
    _record();
    _completedRecorded = false;
    setState(() => _index = index);
    _load();
    Navigator.of(context).maybePop(); // close episode sheet if open
  }

  /// Drops the cached series detail so every screen showing this series
  /// re-reads its lock state from the API.
  ///
  /// The player owns a private copy of the episode list (`List.of` in
  /// initState), so updating `_episodes` fixes playback here and nothing else:
  /// the detail screen behind this route keeps serving the episodes that
  /// `seriesDetailProvider` cached before the purchase, which is why a
  /// just-unlocked episode looked locked again until the app was restarted.
  void _invalidateSeriesCaches() {
    ref.invalidate(seriesDetailProvider(widget.series.id));
  }

  Future<void> _handleUnlock() async {
    if (_access == EpisodeAccess.vipRequired) {
      final nowVip = await DramaEntitlementService.instance
          .presentPaywall(context, trigger: 'drama_episode');
      if (nowVip && mounted) {
        // VIP unlocks the whole series, so the cached list is stale for every
        // episode, not just this one.
        _invalidateSeriesCaches();
        _load();
      }
      return;
    }
    // Coin unlock
    final res = await DramaService.instance.unlockEpisode(_current.id);
    if (res['success'] == true) {
      if (mounted) {
        showTopToastSuccess(context, 'Episode unlocked');
        context.read<UserProvider>().refreshUserInBackground();
      }
      // Refetch so the episode carries the server's own `isUnlocked`. The
      // series id is required — fetchEpisode looks the episode up inside its
      // series list and returns null without one, which used to leave the
      // stale (still locked) model in place after a successful, already-paid
      // unlock. Falling back to flipping the flag locally keeps playback
      // working when the refetch itself fails.
      final fresh = await DramaService.instance
          .fetchEpisode(_current.id, seriesId: widget.series.id);
      if (!mounted) return;
      _episodes[_index] = fresh ?? _current.copyWith(isUnlocked: true);
      _invalidateSeriesCaches();
      _load();
    } else {
      final msg = res['message'] == 'insufficient_coins'
          ? 'Not enough coins'
          : 'Could not unlock episode';
      if (mounted) showTopToastError(context, msg);
    }
  }

  void _disposeController() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _record();
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _controlsVisible = !_controlsVisible),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video / poster
            if (c != null && c.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio == 0 ? 9 / 16 : c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              )
            else
              _PosterBackdrop(url: _current.thumbnailUrl ?? widget.series.posterUrl),

            if (_initializing)
              const Center(child: CircularProgressIndicator(color: Colors.white)),

            if (_locked) _lockOverlay(),

            if (_controlsVisible && !_locked) _controls(c),
          ],
        ),
      ),
    );
  }

  Widget _lockOverlay() {
    final vip = _access == EpisodeAccess.vipRequired;
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(vip ? Icons.workspace_premium_rounded : Icons.lock_rounded,
              color: vip ? const Color(0xFFFFC107) : Colors.white, size: 56),
          SizedBox(height: 2.h),
          Text(
            vip ? 'VIP episode' : 'Unlock this episode',
            style: TextStyle(
                color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 1.h),
          Text(
            vip
                ? 'Subscribe to VIP to watch this and every episode.'
                : 'Spend ${_current.coinCost} coins to unlock this episode, or go VIP for unlimited access.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 10.5.sp),
          ),
          SizedBox(height: 3.h),
          FilledButton(
            onPressed: _handleUnlock,
            style: FilledButton.styleFrom(
              backgroundColor: vip ? const Color(0xFFFFB300) : Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 1.5.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!vip) ...[const CoinGlyph(size: 18), SizedBox(width: 2.w)],
                Text(
                  vip ? 'Go VIP' : 'Unlock for ${_current.coinCost}',
                  style: TextStyle(
                      color: Colors.black87,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Back', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _controls(VideoPlayerController? c) {
    return SafeArea(
      child: Stack(
        children: [
          // Top bar
          Positioned(
            top: 0,
            left: 4.w,
            right: 4.w,
            child: Row(
              children: [
                HeaderGlassIconButton(
                  isDark: true,
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.series.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700)),
                      Text('Episode ${_current.episodeNumber}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Center play/pause
          if (c != null && c.value.isInitialized)
            Center(
              child: IconButton(
                iconSize: 64,
                icon: Icon(
                  c.value.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                onPressed: () => setState(
                    () => c.value.isPlaying ? c.pause() : c.play()),
              ),
            ),

          // Right action rail
          Positioned(
            right: 3.w,
            bottom: 14.h,
            child: Column(
              children: [
                if (_hasDubs) ...[
                  _RailButton(
                    icon: Icons.translate_rounded,
                    label: _selectedLang == null
                        ? 'Dub'
                        : _selectedLang!.toUpperCase(),
                    onTap: _showLanguageSheet,
                  ),
                  SizedBox(height: 2.h),
                ],
                _RailButton(
                  icon: Icons.list_rounded,
                  label: 'Episodes',
                  onTap: _showEpisodeSheet,
                ),
                SizedBox(height: 2.h),
                _RailButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: _shareEpisode,
                ),
                SizedBox(height: 2.h),
                _RailButton(
                  icon: _index < _episodes.length - 1
                      ? Icons.skip_next_rounded
                      : Icons.replay_rounded,
                  label: _index < _episodes.length - 1 ? 'Next' : 'Replay',
                  onTap: () {
                    if (_index < _episodes.length - 1) {
                      _playNext();
                    } else {
                      c?.seekTo(Duration.zero);
                      c?.play();
                    }
                  },
                ),
              ],
            ),
          ),

          // Bottom scrubber
          if (c != null && c.value.isInitialized)
            Positioned(
              left: 4.w,
              right: 4.w,
              bottom: 3.h,
              child: Row(
                children: [
                  Text(_fmt(c.value.position),
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  Expanded(
                    child: VideoProgressIndicator(
                      c,
                      allowScrubbing: true,
                      padding: EdgeInsets.symmetric(horizontal: 2.w),
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFFFF5252),
                        bufferedColor: Colors.white30,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ),
                  Text(_fmt(c.value.duration),
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showLanguageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(4.w, 3.h, 4.w, 2.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Audio & Dubbing',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 2.h),
                for (final lang in _languages)
                  _LangRow(
                    label: lang == null ? 'Original' : langName(lang),
                    flag: lang == null ? '' : flagFor(lang),
                    selected: lang == _selectedLang,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _switchLanguage(lang);
                    },
                  ),
                SizedBox(height: 1.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareEpisode() async {
    final ep = _current;
    final label = widget.series.totalSeasons > 1
        ? 'S${ep.seasonNumber} · Episode ${ep.episodeNumber}'
        : 'Episode ${ep.episodeNumber}';
    try {
      await SharePlus.instance.share(ShareParams(
        text: 'Watch "${widget.series.title}" ($label) on HERO DRAMA',
      ));
    } catch (_) {
      if (mounted) showTopToastError(context, 'Could not open share');
    }
  }

  void _showEpisodeSheet() {
    const rangeSize = 30;
    final total = _episodes.length;
    bool inList = false;
    int rangeStart = (_index ~/ rangeSize) * rangeSize;
    final isVip = _isVip;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          final ranges = <int>[for (var i = 0; i < total; i += rangeSize) i];
          final end = (rangeStart + rangeSize).clamp(0, total);

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 82.h),
              child: Padding(
                padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 1.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 12.w,
                        height: 0.5.h,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    SizedBox(height: 2.h),

                    // VIP activate banner
                    if (!isVip) ...[
                      _vipBanner(ctx),
                      SizedBox(height: 2.h),
                    ],

                    // Series header
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 12.w,
                            height: 16.w,
                            child: TileImage(
                              imageUrl: widget.series.posterUrl,
                              fallbackIcon: Icons.movie_rounded,
                              isDark: true,
                            ),
                          ),
                        ),
                        SizedBox(width: 3.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(widget.series.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5.sp,
                                      fontWeight: FontWeight.w600)),
                              SizedBox(height: 0.4.h),
                              Text('Total $total Episodes',
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 9.5.sp)),
                            ],
                          ),
                        ),
                        SizedBox(width: 4.w),
                        _myListButton(inList, () async {
                          inList = !inList;
                          setSheet(() {});
                          await DramaService.instance
                              .toggleFavorite(widget.series.id, inList);
                          if (mounted) {
                            showTopToastSuccess(
                                context,
                                inList
                                    ? 'Added to My List'
                                    : 'Removed from My List');
                          }
                        }),
                      ],
                    ),
                    SizedBox(height: 2.h),

                    // Range chips (only when there are many episodes)
                    if (ranges.length > 1) ...[
                      SizedBox(
                        height: 3.5.h,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: ranges.length,
                          separatorBuilder: (_, __) => SizedBox(width: 3.w),
                          itemBuilder: (_, i) {
                            final start = ranges[i];
                            final rEnd = (start + rangeSize).clamp(0, total);
                            final active = start == rangeStart;
                            return GestureDetector(
                              onTap: () => setSheet(() => rangeStart = start),
                              child: Container(
                                alignment: Alignment.center,
                                padding: EdgeInsets.symmetric(horizontal: 3.5.w),
                                child: Text(
                                  '${start + 1}-$rEnd',
                                  style: TextStyle(
                                    color: active
                                        ? const Color(0xFFFF4D6D)
                                        : Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11.sp,
                                    fontWeight: active
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 1.5.h),
                    ],

                    // 6-column episode grid
                    Flexible(
                      child: GridView.builder(
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          childAspectRatio: 1,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: end - rangeStart,
                        itemBuilder: (_, i) {
                          final gi = rangeStart + i;
                          return EpisodeGridTile(
                            episode: _episodes[gi],
                            selected: gi == _index,
                            onTap: () => _playAt(gi),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _vipBanner(BuildContext ctx) {
    return GestureDetector(
      onTap: () async {
        Navigator.of(ctx).maybePop();
        final nowVip = await DramaEntitlementService.instance
            .presentPaywall(context, trigger: 'episodes_sheet');
        if (nowVip) _load(seekTo: _controller?.value.position);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.6.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Activate VIP to unlock all episodes',
                style: TextStyle(
                  color: const Color(0xFF5A3D00),
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 0.7.h),
              decoration: BoxDecoration(
                color: const Color(0xFF7A5200),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Activate',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _myListButton(bool inList, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.9.h),
        decoration: BoxDecoration(
          color: inList
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFFF4D6D),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(inList ? Icons.check_rounded : Icons.add_rounded,
                color: Colors.white, size: 16),
            SizedBox(width: 1.w),
            Text('My List',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _PosterBackdrop extends StatelessWidget {
  const _PosterBackdrop({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const ColoredBox(color: Colors.black);
    }
    return Image.network(url!, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black));
  }
}

class _LangRow extends StatelessWidget {
  const _LangRow({
    required this.label,
    required this.flag,
    required this.selected,
    this.onTap,
  });

  final String label;
  final String flag;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(bottom: 1.h),
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentBlue.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: AppTheme.accentBlue, width: 1.2)
              : null,
        ),
        child: Row(
          children: [
            if (flag.isNotEmpty) ...[
              Text(flag, style: const TextStyle(fontSize: 20)),
              SizedBox(width: 3.w),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.5.sp,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  color: AppTheme.accentBlue, size: 20),
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 12.w,
            height: 12.w,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          SizedBox(height: 0.5.h),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 9)),
        ],
      ),
    );
  }
}
