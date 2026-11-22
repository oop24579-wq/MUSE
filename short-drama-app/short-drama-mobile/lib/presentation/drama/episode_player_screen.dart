import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_export.dart';
import '../../models/drama/episode_model.dart';
import '../../models/drama/playback_model.dart';
import '../../models/drama/series_model.dart';
import '../../providers/drama/drama_providers.dart';
import '../../services/app_config_service.dart';
import '../../services/drama/drama_entitlement_service.dart';
import '../../services/drama/drama_service.dart';
import '../../services/drama/playback_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/header_glass_chip.dart';
import '../../widgets/tile_image.dart';
import '../../widgets/top_toast.dart';
import 'widgets/coin_balance_header.dart';
import 'widgets/lang_flags.dart';
import 'widgets/player/auto_next_overlay.dart';
import 'widgets/player/caption_overlay.dart';
import 'widgets/player/chapter_progress_bar.dart';
import 'widgets/player/edge_hud.dart';
import 'widgets/player/lock_overlay.dart';
import 'widgets/player/player_platform_service.dart';
import 'widgets/player/seek_ripple.dart';

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

class _EpisodePlayerScreenState extends ConsumerState<EpisodePlayerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late List<EpisodeModel> _episodes;
  late int _index;
  VideoPlayerController? _controller;
  bool _initializing = false;
  bool _controlsVisible = true;
  bool _locked = false;
  EpisodeAccess _access = EpisodeAccess.playable;

  /// Selected dub language (null = original track).
  String? _selectedLang;

  // --- Phase 2 player state -------------------------------------------------
  EpisodePlayback? _playback;
  double _speed = 1.0;
  String _qualityLabel = 'Auto';
  bool _bingeOn = false;
  bool _bgAudioOn = false;
  bool _controlsLocked = false;
  bool _show2xBadge = false;
  double? _speedBeforeLongPress;

  // Seek ripple
  late final AnimationController _rippleAnim;
  bool _showRipple = false;
  bool _rippleForward = true;
  String _rippleLabel = '+10s';
  double _doubleTapFraction = 0.5;

  // Swipe toast
  String? _swipeToast;
  Timer? _swipeToastTimer;

  // Edge brightness / volume
  EdgeHudKind? _hudKind;
  double _hudValue = 0;
  bool _hudVisible = false;
  Timer? _hudTimer;
  double _brightnessLevel = 1.0;
  double _volumeLevel = 1.0;
  double _dimOpacity = 0;

  // Vertical drag tracking
  double _dragStartY = 0;
  double _dragStartXFraction = 0.5;
  double _dragTotalDy = 0;
  double _dragStartEdgeValue = 0;
  String _dragMode = 'swipe'; // swipe | brightness | volume

  // Auto-next
  bool _showAutoNext = false;
  double _autoNextProgress = 1.0;
  int _autoNextSecondsLeft = 0;
  Timer? _autoNextTimer;
  bool _endHandled = false;

  // Sleep timer
  DateTime? _sleepDeadline;
  int? _sleepSelectedMinutes;
  bool _sleepAtEpisodeEnd = false;
  Timer? _sleepTimer;
  bool _sleepFading = false;

  // Captions
  String _captionLang = 'off';
  List<CaptionCue> _captionCues = const [];
  String _captionFontSize = 'medium';

  // Resume / watched (from existing watch-history service)
  final Set<String> _completedEpisodeIds = {};
  final Map<String, int> _resumeByEpisodeId = {};
  int? _resumeBannerSeconds;
  bool _showResumeBanner = false;

  EpisodeModel get _current => _episodes[_index];
  bool get _isVip => context.read<UserProvider>().isPro;
  AppConfigService get _cfg => AppConfigService.instance;

  /// Languages offered for this series (original + any dubs).
  List<String?> get _languages => [null, ...widget.series.dubLanguages];
  bool get _hasDubs => widget.series.dubLanguages.isNotEmpty;

  void _haptic() {
    if (!_cfg.hapticsEnabled) return;
    HapticFeedback.mediumImpact();
  }

  double get _captionFontSizePx => switch (_captionFontSize) {
        'small' => 13.0,
        'large' => 20.0,
        _ => 16.0,
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _episodes = List.of(widget.episodes);
    _index = widget.startIndex.clamp(0, _episodes.length - 1);
    _rippleAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _rippleAnim.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _showRipple = false);
      }
    });
    _loadPrefs();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _speed = prefs.getDouble('player_speed') ?? 1.0;
        _bingeOn = prefs.getBool('player_binge') ?? false;
        _bgAudioOn = prefs.getBool('player_bg_audio') ?? false;
        _captionLang = prefs.getString('caption_lang') ?? 'off';
        _captionFontSize = prefs.getString('caption_font_size') ?? 'medium';
      });
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    try {
      final history = await DramaService.instance.fetchWatchHistory(limit: 100);
      if (!mounted) return;
      for (final e in history) {
        if (e.series.id != widget.series.id) continue;
        final epId = e.episodeId;
        if (epId == null) continue;
        if (e.completed) {
          _completedEpisodeIds.add(epId);
        } else if (e.positionSeconds > 0 &&
            !_resumeByEpisodeId.containsKey(epId)) {
          _resumeByEpisodeId[epId] = e.positionSeconds;
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Background audio ON = keep playing; OFF = pause when app goes inactive.
    if (_bgAudioOn) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      final c = _controller;
      if (c != null && c.value.isInitialized && c.value.isPlaying) {
        c.pause();
      }
    }
  }

  Future<void> _load({Duration? seekTo}) async {
    _cancelAutoNext();
    _endHandled = false;
    _showResumeBanner = false;
    _resumeBannerSeconds = null;
    _disposeController();
    final episode = _current;
    final access = DramaEntitlementService.instance.accessFor(episode, _isVip);
    setState(() {
      _access = access;
      _locked = access != EpisodeAccess.playable;
      _initializing = access == EpisodeAccess.playable;
    });

    if (access != EpisodeAccess.playable) return;

    // Playback payload (default URL + qualities + caption languages), with
    // the legacy single-URL fetch as fallback.
    final playback = await PlaybackService.instance
        .getPlayback(episode.id, lang: _selectedLang);
    if (!mounted) return;
    _playback = playback;
    var url = playback?.videoUrl;
    url ??= await DramaService.instance
        .getEpisodeVideoUrl(episode.id, lang: _selectedLang);
    if (!mounted) return;
    if (_qualityLabel != 'Auto' && playback != null) {
      url = playback.urlForLabel(_qualityLabel) ?? url;
    }
    if (url == null || url.isEmpty) {
      setState(() {
        _initializing = false;
        _locked = true;
      });
      return;
    }

    // Resume position (only when no explicit seek was requested).
    Duration? resumeSeek;
    if (seekTo == null) {
      final saved = _resumeByEpisodeId[episode.id];
      if (saved != null && saved > 10) {
        resumeSeek = Duration(seconds: saved);
        _resumeBannerSeconds = saved;
      }
    }

    final ok = await _initController(url,
        seekTo: seekTo ?? resumeSeek, autoPlay: true);
    if (!ok) return;
    if (_resumeBannerSeconds != null && mounted) {
      setState(() => _showResumeBanner = true);
    }
    // Auto-apply a stored caption language when this episode offers it.
    if (_cfg.captionsEnabled &&
        _captionLang != 'off' &&
        (playback?.captionLanguages.contains(_captionLang) ?? false)) {
      unawaited(_applyCaptionLang(_captionLang, persist: false));
    } else {
      _captionCues = const [];
    }
    DramaService.instance.incrementView('episode', episode.id);
  }

  Future<bool> _initController(String url,
      {Duration? seekTo, bool autoPlay = true}) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    try {
      await controller.initialize();
      controller.setLooping(false);
      controller.addListener(_onTick);
      await controller.setPlaybackSpeed(_speed);
      if (seekTo != null && seekTo > Duration.zero) {
        await controller.seekTo(seekTo);
      }
      if (autoPlay) await controller.play();
      if (mounted) setState(() => _initializing = false);
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _locked = true;
        });
      }
      return false;
    }
  }

  Future<void> _switchLanguage(String? lang) async {
    if (lang == _selectedLang) return;
    final pos = _controller?.value.position;
    setState(() => _selectedLang = lang);
    await _load(seekTo: pos);
  }

  Future<void> _switchQuality(String label) async {
    if (label == _qualityLabel) return;
    final playback = _playback;
    if (playback == null) return;
    final url =
        label == 'Auto' ? playback.videoUrl : playback.urlForLabel(label);
    if (url == null || url.isEmpty) return;
    final c = _controller;
    final pos = c?.value.position ?? Duration.zero;
    final wasPlaying = c?.value.isPlaying ?? true;
    setState(() {
      _qualityLabel = label;
      _initializing = true;
    });
    _disposeController();
    await _initController(url, seekTo: pos, autoPlay: wasPlaying);
  }

  // --- Captions ---------------------------------------------------------------
  Future<void> _applyCaptionLang(String lang, {bool persist = true}) async {
    setState(() => _captionLang = lang);
    if (persist) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('caption_lang', lang);
      } catch (_) {}
    }
    if (lang == 'off') {
      if (mounted) setState(() => _captionCues = const []);
      return;
    }
    final vtt =
        await PlaybackService.instance.fetchCaptionVtt(_current.id, lang);
    if (!mounted) return;
    setState(
        () => _captionCues = vtt == null ? const [] : parseWebVtt(vtt));
  }

  String? get _activeCaption {
    if (!_cfg.captionsEnabled || _captionLang == 'off') return null;
    final c = _controller;
    if (c == null || !c.value.isInitialized || _captionCues.isEmpty) {
      return null;
    }
    return activeCaptionText(_captionCues, c.value.position);
  }

  // --- Playback tick / episode end --------------------------------------------
  void _onTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position.inSeconds;
    final dur = c.value.duration.inSeconds;
    final atEnd = dur > 0 && pos >= dur - 1;
    if (atEnd && !_endHandled) {
      _endHandled = true;
      _completedEpisodeIds.add(_current.id);
      _record(completed: true);
      _handleEpisodeEnd();
    }
    if (mounted) setState(() {}); // update scrubber / captions / chips
  }

  void _handleEpisodeEnd() {
    if (_sleepAtEpisodeEnd) {
      _sleepAtEpisodeEnd = false;
      _controller?.pause();
      if (mounted) {
        showTopToastInfo(context, 'Sleep timer: end of episode');
      }
      return;
    }
    if (_index >= _episodes.length - 1) return;
    if (_cfg.feature('binge_mode') && _bingeOn) {
      _playNext();
      return;
    }
    if (_cfg.feature('auto_next')) {
      _startAutoNext();
    } else {
      _playNext();
    }
  }

  void _startAutoNext() {
    final total = _cfg.autoNextCountdownSeconds;
    if (total <= 0) {
      _playNext();
      return;
    }
    final deadline = DateTime.now().add(Duration(seconds: total));
    setState(() {
      _showAutoNext = true;
      _autoNextSecondsLeft = total;
      _autoNextProgress = 1.0;
    });
    _autoNextTimer?.cancel();
    _autoNextTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        t.cancel();
        _cancelAutoNext();
        _playNext();
        return;
      }
      setState(() {
        _autoNextSecondsLeft = (remaining.inMilliseconds / 1000).ceil();
        _autoNextProgress =
            (remaining.inMilliseconds / (total * 1000)).clamp(0.0, 1.0);
      });
    });
  }

  void _cancelAutoNext() {
    _autoNextTimer?.cancel();
    _autoNextTimer = null;
    if (_showAutoNext && mounted) setState(() => _showAutoNext = false);
    _showAutoNext = false;
  }

  // --- Sleep timer --------------------------------------------------------------
  String? get _sleepChipLabel {
    if (_sleepAtEpisodeEnd) return 'Sleep: end of episode';
    final d = _sleepDeadline;
    if (d == null) return null;
    final remaining = d.difference(DateTime.now());
    if (remaining.isNegative) return null;
    final m = remaining.inMinutes;
    final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return 'Sleep: $m:$s';
  }

  void _setSleepTimer(int? minutes, {bool atEpisodeEnd = false}) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    setState(() {
      _sleepAtEpisodeEnd = atEpisodeEnd;
      _sleepSelectedMinutes = minutes;
      _sleepDeadline =
          minutes == null ? null : DateTime.now().add(Duration(minutes: minutes));
    });
    if (minutes != null) {
      _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        final d = _sleepDeadline;
        if (d == null || DateTime.now().isAfter(d)) {
          t.cancel();
          unawaited(_expireSleepTimer());
        } else {
          setState(() {});
        }
      });
    }
  }

  Future<void> _expireSleepTimer() async {
    if (_sleepFading) return;
    _sleepFading = true;
    setState(() {
      _sleepDeadline = null;
      _sleepSelectedMinutes = null;
    });
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      try {
        for (var i = 10; i >= 0; i--) {
          await c.setVolume(i / 10);
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        await c.pause();
        await c.setVolume(1.0);
      } catch (_) {}
    }
    _sleepFading = false;
    if (mounted) showTopToastInfo(context, 'Sleep timer: playback paused');
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
      _goToEpisode(_index + 1);
    }
  }

  void _playPrevious() {
    if (_index > 0) _goToEpisode(_index - 1);
  }

  void _goToEpisode(int index, {bool viaSwipe = false}) {
    if (index == _index || index < 0 || index >= _episodes.length) return;
    _record();
    setState(() => _index = index);
    _load();
    if (viaSwipe) {
      _haptic();
      final ep = _episodes[index];
      _swipeToastTimer?.cancel();
      setState(() =>
          _swipeToast = 'EP ${ep.episodeNumber} · ${ep.displayTitle}');
      _swipeToastTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _swipeToast = null);
      });
    }
  }

  void _playAt(int index) {
    if (index == _index) return;
    _goToEpisode(index);
    Navigator.of(context).maybePop(); // close episode sheet if open
  }

  /// Drops the cached series detail so every screen showing this series
  /// re-reads its lock state from the API.
  void _invalidateSeriesCaches() {
    ref.invalidate(seriesDetailProvider(widget.series.id));
  }

  Future<void> _handleUnlock() async {
    if (_access == EpisodeAccess.vipRequired) {
      final nowVip = await DramaEntitlementService.instance
          .presentPaywall(context, trigger: 'drama_episode');
      if (nowVip && mounted) {
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
    WidgetsBinding.instance.removeObserver(this);
    _autoNextTimer?.cancel();
    _sleepTimer?.cancel();
    _hudTimer?.cancel();
    _swipeToastTimer?.cancel();
    _rippleAnim.dispose();
    _record();
    _disposeController();
    super.dispose();
  }

  // --- Gestures -----------------------------------------------------------------
  void _onDoubleTapDown(TapDownDetails d, Size size) {
    _doubleTapFraction =
        size.width == 0 ? 0.5 : (d.globalPosition.dx / size.width);
  }

  void _onDoubleTap() {
    if (!_cfg.feature('double_tap_seek') || _controlsLocked) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final forward = _doubleTapFraction >= 0.5;
    final delta = Duration(seconds: forward ? 10 : -10);
    var target = c.value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > c.value.duration) target = c.value.duration;
    c.seekTo(target);
    _haptic();
    setState(() {
      _rippleForward = forward;
      _rippleLabel = forward ? '+10s' : '−10s';
      _showRipple = true;
    });
    _rippleAnim.forward(from: 0);
  }

  void _onLongPressStart() {
    if (!_cfg.feature('long_press_2x') || _controlsLocked) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    _speedBeforeLongPress = _speed;
    c.setPlaybackSpeed(2.0);
    setState(() => _show2xBadge = true);
  }

  void _onLongPressEnd() {
    if (!_show2xBadge) return;
    final c = _controller;
    c?.setPlaybackSpeed(_speedBeforeLongPress ?? _speed);
    _speedBeforeLongPress = null;
    setState(() => _show2xBadge = false);
  }

  void _onVerticalDragStart(DragStartDetails d, Size size) {
    _dragStartY = d.globalPosition.dy;
    _dragTotalDy = 0;
    _dragStartXFraction =
        size.width == 0 ? 0.5 : (d.globalPosition.dx / size.width);
    if (_cfg.feature('edge_brightness_volume') &&
        _dragStartXFraction <= 0.15) {
      _dragMode = 'volume';
      _dragStartEdgeValue = _volumeLevel;
    } else if (_cfg.feature('edge_brightness_volume') &&
        _dragStartXFraction >= 0.85) {
      _dragMode = 'brightness';
      _dragStartEdgeValue = _brightnessLevel;
    } else {
      _dragMode = 'swipe';
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    _dragTotalDy = d.globalPosition.dy - _dragStartY;
    if (_dragMode == 'swipe' || _controlsLocked) return;
    final value = (_dragStartEdgeValue - _dragTotalDy / 300).clamp(0.0, 1.0);
    if (_dragMode == 'brightness') {
      _brightnessLevel = value;
      unawaited(_applyBrightness(value));
      _showHud(EdgeHudKind.brightness, value);
    } else {
      _volumeLevel = value;
      unawaited(_applyVolume(value));
      _showHud(EdgeHudKind.volume, value);
    }
  }

  Future<void> _applyBrightness(double value) async {
    final ok =
        await PlayerPlatformService.instance.setBrightness(value);
    if (!ok && mounted) {
      // Fallback: dim overlay over the video.
      setState(() => _dimOpacity = (1 - value) * 0.7);
    } else if (mounted && _dimOpacity != 0) {
      setState(() => _dimOpacity = 0);
    }
  }

  Future<void> _applyVolume(double value) async {
    final ok = await PlayerPlatformService.instance.setVolume(value);
    if (!ok) {
      // Fallback: drive the player's own volume.
      try {
        await _controller?.setVolume(value);
      } catch (_) {}
    }
  }

  void _showHud(EdgeHudKind kind, double value) {
    _hudTimer?.cancel();
    setState(() {
      _hudKind = kind;
      _hudValue = value;
      _hudVisible = true;
    });
    _hudTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _hudVisible = false);
    });
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    if (_dragMode != 'swipe') return;
    if (!_cfg.feature('swipe_next_episode') || _controlsLocked) return;
    if (_dragTotalDy <= -60) {
      if (_index < _episodes.length - 1) {
        _goToEpisode(_index + 1, viaSwipe: true);
      }
    } else if (_dragTotalDy >= 60) {
      if (_index > 0) _goToEpisode(_index - 1, viaSwipe: true);
    }
  }

  Future<void> _enterPip() async {
    final ok = await PlayerPlatformService.instance.enterPip();
    if (!ok && mounted) {
      showTopToastInfo(context, 'PiP not supported here');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final size = MediaQuery.of(context).size;
    final caption = _activeCaption;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (_controlsLocked) return;
          setState(() => _controlsVisible = !_controlsVisible);
        },
        onDoubleTapDown: (d) => _onDoubleTapDown(d, size),
        onDoubleTap: _onDoubleTap,
        onLongPressStart: (_) => _onLongPressStart(),
        onLongPressEnd: (_) => _onLongPressEnd(),
        onLongPressCancel: _onLongPressEnd,
        onVerticalDragStart: (d) => _onVerticalDragStart(d, size),
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
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

            // Brightness fallback dim overlay
            if (_dimOpacity > 0)
              IgnorePointer(
                child: ColoredBox(
                    color: Colors.black.withValues(alpha: _dimOpacity)),
              ),

            if (_initializing)
              const Center(child: CircularProgressIndicator(color: Colors.white)),

            if (_locked) _lockOverlay(),

            // Double-tap seek ripple
            if (_showRipple && _cfg.feature('double_tap_seek'))
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: _rippleForward
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      child: SeekRipple(
                        label: _rippleLabel,
                        isForward: _rippleForward,
                        animation: _rippleAnim,
                      ),
                    ),
                  ),
                ),
              ),

            // 2x badge
            if (_show2xBadge)
              Positioned(
                top: 9.h,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.6.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('2×',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ),

            // Swipe toast chip
            if (_swipeToast != null)
              Center(
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_swipeToast!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
              ),

            // Edge HUD
            if (_hudVisible && _hudKind != null)
              EdgeHud(kind: _hudKind!, value: _hudValue),

            // Captions
            if (caption != null)
              CaptionOverlay(text: caption, fontSize: _captionFontSizePx),

            if (_controlsVisible && !_locked && !_controlsLocked)
              _controls(c),

            // Skip intro
            if (!_locked &&
                !_controlsLocked &&
                _cfg.feature('skip_intro') &&
                c != null &&
                c.value.isInitialized &&
                c.value.position.inSeconds <=
                    _cfg.skipIntroWindowSeconds &&
                c.value.position.inSeconds < _cfg.skipIntroToSeconds)
              Positioned(
                right: 4.w,
                bottom: 12.h,
                child: FilledButton(
                  onPressed: () => c.seekTo(
                      Duration(seconds: _cfg.skipIntroToSeconds)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Skip Intro',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),

            // Resume banner
            if (_showResumeBanner && _resumeBannerSeconds != null)
              Positioned(
                top: 11.h,
                left: 4.w,
                right: 4.w,
                child: Center(
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Resume from ${_fmt(Duration(seconds: _resumeBannerSeconds!))}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                        SizedBox(width: 2.w),
                        GestureDetector(
                          onTap: () {
                            _controller?.seekTo(Duration.zero);
                            _controller?.play();
                            setState(() => _showResumeBanner = false);
                          },
                          child: const Text('Restart',
                              style: TextStyle(
                                  color: Color(0xFFFF4D6D),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                        ),
                        SizedBox(width: 2.w),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showResumeBanner = false),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white70, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Auto-next overlay
            if (_showAutoNext && _index < _episodes.length - 1)
              AutoNextOverlay(
                nextLabel:
                    'EP ${_episodes[_index + 1].episodeNumber} · ${_episodes[_index + 1].displayTitle}',
                progress: _autoNextProgress,
                secondsLeft: _autoNextSecondsLeft,
                onNext: () {
                  _cancelAutoNext();
                  _playNext();
                },
                onCancel: _cancelAutoNext,
              ),

            // Controls lock overlay
            if (_controlsLocked && _cfg.feature('lock_controls'))
              LockOverlay(
                onUnlock: () {
                  _haptic();
                  setState(() => _controlsLocked = false);
                },
              ),
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
    final sleepLabel = _sleepChipLabel;
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
                if (_cfg.feature('quality_selector') &&
                    (_playback?.qualities.isNotEmpty ?? false)) ...[
                  GestureDetector(
                    onTap: _showQualitySheet,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 2.5.w, vertical: 0.6.h),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(_qualityLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  SizedBox(width: 2.w),
                ],
                if (_cfg.feature('pip'))
                  HeaderGlassIconButton(
                    isDark: true,
                    icon: Icons.picture_in_picture_alt_rounded,
                    onTap: _enterPip,
                  ),
                if (_cfg.feature('pip')) SizedBox(width: 2.w),
                if (_cfg.feature('lock_controls'))
                  HeaderGlassIconButton(
                    isDark: true,
                    icon: Icons.lock_open_rounded,
                    onTap: () {
                      _haptic();
                      setState(() => _controlsLocked = true);
                    },
                  ),
              ],
            ),
          ),

          // Sleep timer chip
          if (sleepLabel != null)
            Positioned(
              top: 6.5.h,
              right: 4.w,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bedtime_rounded,
                        color: Colors.white, size: 13),
                    SizedBox(width: 1.w),
                    Text(sleepLabel,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11)),
                  ],
                ),
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
                if (_cfg.captionsEnabled &&
                    (_playback?.captionLanguages.isNotEmpty ?? false)) ...[
                  _RailButton(
                    icon: Icons.closed_caption_rounded,
                    label: _captionLang == 'off'
                        ? 'CC'
                        : _captionLang.toUpperCase(),
                    onTap: _showCaptionSheet,
                  ),
                  SizedBox(height: 2.h),
                ],
                _RailButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: _shareEpisode,
                ),
                SizedBox(height: 2.h),
                _RailButton(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  onTap: _showSettingsSheet,
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
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.w),
                      child: _cfg.feature('scrub_chapters')
                          ? ChapterProgressBar(controller: c)
                          : VideoProgressIndicator(
                              c,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: Color(0xFFFF5252),
                                bufferedColor: Colors.white30,
                                backgroundColor: Colors.white24,
                              ),
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

  void _showQualitySheet() {
    final playback = _playback;
    if (playback == null) return;
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
                Text('Quality',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 2.h),
                _LangRow(
                  label: 'Auto',
                  flag: '',
                  selected: _qualityLabel == 'Auto',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _switchQuality('Auto');
                  },
                ),
                for (final q in playback.qualities)
                  _LangRow(
                    label: q.label,
                    flag: '',
                    selected: _qualityLabel == q.label,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _switchQuality(q.label);
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

  static String _captionLangName(String code) {
    switch (code) {
      case 'orig':
        return 'Original';
      case 'ar':
        return 'العربية';
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'pt':
        return 'Português';
      default:
        return code.toUpperCase();
    }
  }

  void _showCaptionSheet() {
    final langs = _playback?.captionLanguages ?? const <String>[];
    // Order: orig, ar, en first (when present), then the rest as offered.
    final ordered = <String>[];
    for (final preferred in const ['orig', 'ar', 'en']) {
      if (langs.contains(preferred)) ordered.add(preferred);
    }
    for (final l in langs) {
      if (!ordered.contains(l)) ordered.add(l);
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(4.w, 3.h, 4.w, 2.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Captions',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 2.h),
                  _LangRow(
                    label: 'Off',
                    flag: '',
                    selected: _captionLang == 'off',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _applyCaptionLang('off');
                    },
                  ),
                  for (final lang in ordered)
                    _LangRow(
                      label: _captionLangName(lang),
                      flag: '',
                      selected: _captionLang == lang,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _applyCaptionLang(lang);
                      },
                    ),
                  SizedBox(height: 1.h),
                  Text('Caption size',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 1.h),
                  Row(
                    children: [
                      for (final size in const ['small', 'medium', 'large'])
                        Padding(
                          padding: EdgeInsets.only(right: 2.w),
                          child: ChoiceChip(
                            label: Text(
                                size[0].toUpperCase() + size.substring(1)),
                            selected: _captionFontSize == size,
                            onSelected: (_) async {
                              setSheet(() => _captionFontSize = size);
                              setState(() => _captionFontSize = size);
                              try {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setString(
                                    'caption_font_size', size);
                              } catch (_) {}
                            },
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(4.w, 3.h, 4.w, 2.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Playback settings',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 2.h),
                  if (_cfg.feature('speed_menu')) ...[
                    Text('Speed',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 1.h),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final s in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                          ChoiceChip(
                            label: Text(s == 1.0 ? '1×' : '${s}×'),
                            selected: _speed == s,
                            onSelected: (_) async {
                              setSheet(() => _speed = s);
                              setState(() => _speed = s);
                              await _controller?.setPlaybackSpeed(s);
                              try {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setDouble('player_speed', s);
                              } catch (_) {}
                            },
                          ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                  ],
                  if (_cfg.feature('binge_mode'))
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Binge mode',
                          style: TextStyle(color: Colors.white)),
                      subtitle: const Text(
                          'Play the next episode immediately',
                          style: TextStyle(color: Colors.white54)),
                      value: _bingeOn,
                      onChanged: (v) async {
                        setSheet(() => _bingeOn = v);
                        setState(() => _bingeOn = v);
                        try {
                          final prefs =
                              await SharedPreferences.getInstance();
                          await prefs.setBool('player_binge', v);
                        } catch (_) {}
                      },
                    ),
                  if (_cfg.feature('pip'))
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Background audio',
                          style: TextStyle(color: Colors.white)),
                      subtitle: const Text(
                          'Keep playing when the app is in background',
                          style: TextStyle(color: Colors.white54)),
                      value: _bgAudioOn,
                      onChanged: (v) async {
                        setSheet(() => _bgAudioOn = v);
                        setState(() => _bgAudioOn = v);
                        try {
                          final prefs =
                              await SharedPreferences.getInstance();
                          await prefs.setBool('player_bg_audio', v);
                        } catch (_) {}
                      },
                    ),
                  if (_cfg.feature('sleep_timer')) ...[
                    SizedBox(height: 1.h),
                    Text('Sleep timer',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 1.h),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Off'),
                          selected: _sleepDeadline == null &&
                              !_sleepAtEpisodeEnd,
                          onSelected: (_) {
                            _setSleepTimer(null);
                            setSheet(() {});
                          },
                        ),
                        for (final m in const [15, 30, 60])
                          ChoiceChip(
                            label: Text('$m min'),
                            selected: !_sleepAtEpisodeEnd &&
                                _sleepSelectedMinutes == m,
                            onSelected: (_) {
                              _setSleepTimer(m);
                              setSheet(() {});
                            },
                          ),
                        ChoiceChip(
                          label: const Text('End of episode'),
                          selected: _sleepAtEpisodeEnd,
                          onSelected: (_) {
                            _setSleepTimer(null, atEpisodeEnd: true);
                            setSheet(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 1.h),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _shareEpisode() async {
    final ep = _current;
    final label = widget.series.totalSeasons > 1
        ? 'S${ep.seasonNumber} · Episode ${ep.episodeNumber}'
        : 'Episode ${ep.episodeNumber}';
    final pos = _controller?.value.position ?? Duration.zero;
    final stamp = _cfg.feature('share_moment') ? ' at ${_fmt(pos)}' : '';
    try {
      await SharePlus.instance.share(ShareParams(
        text: 'Watch "${widget.series.title}" ($label)$stamp on HERO DRAMA',
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

                    if (!isVip) ...[
                      _vipBanner(ctx),
                      SizedBox(height: 2.h),
                    ],

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
                          final ep = _episodes[gi];
                          return _PlayerEpisodeTile(
                            episode: ep,
                            isCurrent: gi == _index,
                            watched: _completedEpisodeIds.contains(ep.id),
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

/// Episode grid tile for the player's episode sheet: current episode gets an
/// accent background + equalizer icon, watched episodes a checkmark, locked
/// episodes a lock badge with their coin cost.
class _PlayerEpisodeTile extends StatelessWidget {
  const _PlayerEpisodeTile({
    required this.episode,
    required this.isCurrent,
    required this.watched,
    this.onTap,
  });

  final EpisodeModel episode;
  final bool isCurrent;
  final bool watched;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = episode.isLocked;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: isCurrent
              ? AppTheme.accentBlue.withValues(alpha: 0.9)
              : AppTheme.cardDarkBlue,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCurrent
                ? AppTheme.accentBlue
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${episode.episodeNumber}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (locked && episode.coinCost > 0)
                    Text(
                      '${episode.coinCost}',
                      style: const TextStyle(
                          color: Color(0xFFFFC107), fontSize: 8),
                    ),
                ],
              ),
            ),
            if (isCurrent)
              const Positioned(
                top: 3,
                right: 3,
                child: Icon(Icons.equalizer_rounded,
                    size: 12, color: Colors.white),
              )
            else if (watched)
              const Positioned(
                top: 3,
                right: 3,
                child: Icon(Icons.check_circle_rounded,
                    size: 12, color: Colors.greenAccent),
              ),
            if (locked)
              Positioned(
                top: 3,
                left: 3,
                child: Icon(
                  episode.isVipOnly
                      ? Icons.workspace_premium_rounded
                      : Icons.lock_rounded,
                  size: 12,
                  color: episode.isVipOnly
                      ? const Color(0xFFFFC107)
                      : Colors.white.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
    );
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
