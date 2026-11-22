import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../models/drama/short_item.dart';
import '../../services/app_config_service.dart';
import '../../services/drama/drama_service.dart';
import '../../widgets/tile_image.dart';
import '../../widgets/top_toast.dart';
import 'drama_navigation.dart';

/// Round 4: the Shorts tab is a real vertical feed — full-screen clips
/// (one per episode) from GET /shorts with cursor pagination, replacing
/// the old poster grid fed by /for-you.
///
/// Playback resolves through the same entitlement-checked playback
/// endpoint as the full player (locked episodes show their poster + lock
/// state and never fetch a stream). Only the visible page plays; page
/// changes and tab switches pause. Behind the `shorts` feature flag
/// (GET /config features.shorts, default ON).
class ShortsContent extends ConsumerStatefulWidget {
  const ShortsContent({super.key, this.isTabActive = true});

  /// MainTabs passes its tab index through so clips pause when the user
  /// switches to another tab (IndexedStack keeps this widget mounted).
  final bool isTabActive;

  @override
  ConsumerState<ShortsContent> createState() => _ShortsContentState();
}

class _ShortsContentState extends ConsumerState<ShortsContent> {
  final PageController _pageController = PageController();
  final List<ShortItem> _items = [];
  String? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  int _currentIndex = 0;

  bool get _flagOff => !AppConfigService.instance.shortsEnabled;

  @override
  void initState() {
    super.initState();
    if (!_flagOff) _loadFirst();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadFirst() async {
    setState(() => _loading = true);
    final page = await DramaService.instance.fetchShorts(limit: 20);
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(page.items);
      _nextCursor = page.nextCursor;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    _loadingMore = true;
    final page = await DramaService.instance.fetchShorts(cursor: cursor);
    if (!mounted) return;
    setState(() {
      _items.addAll(page.items);
      _nextCursor = page.nextCursor;
    });
    _loadingMore = false;
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    if (index >= _items.length - 3) _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    if (_flagOff) {
      return const Center(child: Text('Shorts are unavailable right now'));
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nothing to watch yet'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _loadFirst, child: const Text('Retry')),
          ],
        ),
      );
    }
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: _onPageChanged,
      itemCount: _items.length,
      itemBuilder: (context, i) => _ShortPage(
        item: _items[i],
        active: widget.isTabActive && i == _currentIndex,
      ),
    );
  }
}

/// A single full-screen clip page. Owns its [VideoPlayerController]:
/// created lazily when the page becomes active, paused when it stops
/// being active, disposed with the page.
class _ShortPage extends StatefulWidget {
  const _ShortPage({required this.item, required this.active});

  final ShortItem item;
  final bool active;

  @override
  State<_ShortPage> createState() => _ShortPageState();
}

class _ShortPageState extends State<_ShortPage> {
  VideoPlayerController? _controller;
  bool _resolving = false;
  bool _failed = false;
  bool _muted = false;
  bool _liked = false;
  late int _likeCount = widget.item.likeCount;

  @override
  void initState() {
    super.initState();
    if (widget.active) _ensureController();
  }

  @override
  void didUpdateWidget(_ShortPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _ensureController();
      _controller?.play();
    } else if (!widget.active && oldWidget.active) {
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _ensureController() async {
    if (_controller != null || _resolving || _failed) return;
    // Locked episodes never fetch a stream — the poster + lock state is
    // the honest rendering (playback would 403 anyway).
    if (!widget.item.isUnlocked) return;
    _resolving = true;
    final url =
        await DramaService.instance.getEpisodeVideoUrl(widget.item.episodeId);
    if (!mounted) return;
    if (url == null || url.isEmpty) {
      setState(() => _failed = true);
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    try {
      await controller.initialize();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) return;
    await controller.setLooping(true);
    await controller.setVolume(_muted ? 0.0 : 1.0);
    if (widget.active) await controller.play();
    if (mounted) setState(() {});
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        c.play();
      }
    });
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    await _controller?.setVolume(_muted ? 0.0 : 1.0);
  }

  Future<void> _toggleLike() async {
    final next = !_liked;
    setState(() {
      _liked = next;
      _likeCount = (_likeCount + (next ? 1 : -1)).clamp(0, 1 << 31);
    });
    final count =
        await DramaService.instance.toggleLike(widget.item.seriesId, next);
    if (!mounted) return;
    if (count != null) {
      setState(() => _likeCount = count);
    } else {
      // Revert the optimistic update on failure.
      setState(() {
        _liked = !next;
        _likeCount = (_likeCount + (next ? -1 : 1)).clamp(0, 1 << 31);
      });
    }
  }

  Future<void> _openFullEpisode() async {
    final detail =
        await DramaService.instance.fetchSeriesDetail(widget.item.seriesId);
    if (!mounted) return;
    if (detail == null) {
      showTopToastError(context, 'Could not load this series');
      return;
    }
    final idx =
        detail.episodes.indexWhere((e) => e.id == widget.item.episodeId);
    await DramaNav.openPlayer(
      context,
      series: detail.series,
      episodes: detail.episodes,
      startIndex: idx < 0 ? 0 : idx,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final c = _controller;
    final videoReady = c != null && c.value.isInitialized && !_failed;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (videoReady)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          )
        else
          TileImage(
            imageUrl: item.posterUrl ?? item.thumbnailUrl,
            borderRadius: 0,
            fallbackIcon: Icons.movie_outlined,
          ),
        // Legibility gradient for the overlay.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black54],
            ),
          ),
        ),
        // Tap anywhere on the clip toggles play/pause.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: videoReady ? _togglePlay : null,
          ),
        ),
        if (videoReady && !c.value.isPlaying && widget.active)
          const Center(
            child: Icon(Icons.play_circle_fill,
                size: 72, color: Colors.white70),
          ),
        if (!item.isUnlocked)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 44, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  item.isVipOnly ? 'VIP episode' : 'Locked episode',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ShortFeedCard(
            item: item,
            liked: _liked,
            likeCount: _likeCount,
            muted: _muted,
            onLike: _toggleLike,
            onToggleMute: _toggleMute,
            onWatchFull: _openFullEpisode,
          ),
        ),
      ],
    );
  }
}

/// The overlay UI of a Shorts page (series/episode captions, like + mute
/// rail, "Watch full episode" affordance). Stateless and callback-driven
/// so it is widget-testable without a video controller or network.
class ShortFeedCard extends StatelessWidget {
  const ShortFeedCard({
    super.key,
    required this.item,
    required this.liked,
    required this.likeCount,
    required this.muted,
    required this.onLike,
    required this.onToggleMute,
    required this.onWatchFull,
  });

  final ShortItem item;
  final bool liked;
  final int likeCount;
  final bool muted;
  final VoidCallback onLike;
  final VoidCallback onToggleMute;
  final VoidCallback onWatchFull;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.seriesTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.captionTitle} · Episode ${item.episodeNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('short-watch-full'),
                  onPressed: onWatchFull,
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: const Text('Watch full episode'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const ValueKey('short-like'),
                onPressed: onLike,
                icon: Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? const Color(0xFFFF4D6D) : Colors.white,
                  size: 30,
                ),
              ),
              Text(
                '$likeCount',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 8),
              IconButton(
                key: const ValueKey('short-mute'),
                onPressed: onToggleMute,
                icon: Icon(
                  muted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
