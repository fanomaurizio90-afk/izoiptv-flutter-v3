import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/vod.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/repositories/history_repository.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';

class SeriesPlayerScreen extends ConsumerStatefulWidget {
  const SeriesPlayerScreen({
    super.key,
    required this.vod,
    required this.backPath,
    this.episodes,
    this.episodeIndex,
  });
  final VodItem        vod;
  final String         backPath;
  final List<Episode>? episodes;
  final int?           episodeIndex;

  @override
  ConsumerState<SeriesPlayerScreen> createState() => _SeriesPlayerScreenState();
}

class _SeriesPlayerScreenState extends ConsumerState<SeriesPlayerScreen> {
  VideoPlayerController? _controller;
  late HistoryRepository _historyRepo;
  bool   _showControls = true;
  bool   _initialized  = false;
  bool   _disposed     = false;
  Timer? _hideTimer;
  Timer? _saveTimer;

  bool get _hasNext =>
      widget.episodes != null &&
      (widget.episodeIndex ?? 0) < widget.episodes!.length - 1;

  int get _currentIdx => widget.episodeIndex ?? 0;

  // Extract series ID from backPath e.g. '/series/123' → 123
  int get _seriesId {
    final match = RegExp(r'/series/(\d+)').firstMatch(widget.backPath);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  int get _episodeId => widget.vod.id;

  final _topFocusNode       = FocusNode(debugLabel: 'player-root');
  final _playPauseFocusNode = FocusNode(debugLabel: 'play-pause');

  @override
  void initState() {
    super.initState();
    // Store repository reference now — safer than calling ref.read() in dispose()
    _historyRepo = ref.read(historyRepositoryProvider);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _startHideTimer();
    _startSaveTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPlayer());
  }

  Future<void> _initPlayer() async {
    Duration startPos = Duration.zero;
    try {
      final hist = await _historyRepo.getPosition(
        _seriesId, 'episode', episodeId: _episodeId,
      );
      if (hist != null) {
        startPos = Duration(seconds: hist['position_secs'] as int);
      }
    } catch (_) {}

    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(widget.vod.streamUrl),
    );
    try {
      await ctrl.initialize();
    } catch (_) {}
    if (_disposed) { ctrl.dispose(); return; }  // exited during initialize()

    if (startPos > Duration.zero) {
      await ctrl.seekTo(startPos);
      if (_disposed) { ctrl.dispose(); return; }  // exited during seekTo()
    }

    await ctrl.play();

    if (mounted) {
      setState(() {
        _controller  = ctrl;
        _initialized = true;
      });
    } else {
      ctrl.dispose();  // exited during play() — no owner, must dispose here
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controller?.pause();   // stop audio immediately before anything else
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    try { _savePositionSync(); } catch (_) {}
    _controller?.dispose();
    _topFocusNode.dispose();
    _playPauseFocusNode.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(AppDurations.controlsAutoHide, () {
      if (mounted) {
        setState(() => _showControls = false);
        _topFocusNode.requestFocus();
      }
    });
  }

  void _showControlsTemporarily() {
    final wasHidden = !_showControls;
    if (mounted) setState(() => _showControls = true);
    _startHideTimer();
    if (wasHidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showControls) _playPauseFocusNode.requestFocus();
      });
    }
  }

  void _startSaveTimer() {
    _saveTimer = Timer.periodic(AppDurations.historyFlushPeriod, (_) => _savePosition());
  }

  Future<void> _savePosition() async {
    final ctrl = _controller;
    if (!mounted || ctrl == null || !ctrl.value.isInitialized) return;
    final pos = ctrl.value.position.inSeconds;
    final dur = ctrl.value.duration.inSeconds;
    if (pos <= 0) return;
    try {
      await _historyRepo.savePosition(
        contentId:    _seriesId,
        contentType:  'episode',
        contentName:  widget.vod.name,
        positionSecs: pos,
        durationSecs: dur,
        episodeId:    _episodeId,
        thumbnailUrl: widget.vod.posterUrl,
      );
    } catch (_) {}
  }

  void _savePositionSync() {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final pos = ctrl.value.position.inSeconds;
    final dur = ctrl.value.duration.inSeconds;
    if (pos <= 0) return;
    _historyRepo.savePosition(
      contentId:    _seriesId,
      contentType:  'episode',
      contentName:  widget.vod.name,
      positionSecs: pos,
      durationSecs: dur,
      episodeId:    _episodeId,
      thumbnailUrl: widget.vod.posterUrl,
    );
  }

  void _togglePlay() {
    final ctrl = _controller;
    if (ctrl == null) return;
    ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
    _showControlsTemporarily();
  }

  void _seek(Duration offset) {
    final ctrl = _controller;
    if (ctrl == null) return;
    final newPos = ctrl.value.position + offset;
    ctrl.seekTo(newPos.isNegative ? Duration.zero : newPos);
    _showControlsTemporarily();
  }

  void _playNextEpisode() {
    if (!_hasNext) return;
    final nextEp  = widget.episodes![_currentIdx + 1];
    final nextVod = VodItem(
      id:           nextEp.id,
      name:         nextEp.title,
      streamUrl:    nextEp.streamUrl,
      categoryId:   0,
      posterUrl:    nextEp.thumbnailUrl,
      durationSecs: nextEp.durationSecs,
    );
    context.pushReplacement('/series/player', extra: {
      'vod':          nextVod,
      'backPath':     widget.backPath,
      'episodes':     widget.episodes!,
      'episodeIndex': _currentIdx + 1,
    });
  }

  static bool _isActivateKey(KeyEvent e) =>
      e.logicalKey == LogicalKeyboardKey.select       ||
      e.logicalKey == LogicalKeyboardKey.enter        ||
      e.logicalKey == LogicalKeyboardKey.numpadEnter  ||
      e.logicalKey == LogicalKeyboardKey.gameButtonA  ||
      e.physicalKey == PhysicalKeyboardKey.select     ||
      e.physicalKey == PhysicalKeyboardKey.gameButtonA ||
      e.physicalKey.usbHidUsage == 0x00070058;

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && context.canPop()) context.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Focus(
          focusNode: _topFocusNode,
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final key = event.logicalKey;

            // Dedicated media keys always work regardless of controls state
            if (key == LogicalKeyboardKey.mediaPlayPause) {
              _togglePlay();
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.mediaRewind) {
              _seek(const Duration(seconds: -10));
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.mediaFastForward) {
              _seek(const Duration(seconds: 10));
              return KeyEventResult.handled;
            }

            // Controls visible — let focused buttons handle D-pad input
            if (_showControls) {
              _startHideTimer();
              return KeyEventResult.ignored;
            }

            // Controls hidden — D-pad shortcuts
            if (_isActivateKey(event)) {
              _togglePlay();
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowLeft) {
              _seek(const Duration(seconds: -10));
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowRight) {
              _seek(const Duration(seconds: 10));
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.contextMenu) {
              _showControlsTemporarily();
              return KeyEventResult.handled;
            }
            _showControlsTemporarily();
            return KeyEventResult.handled;
          },
          child: GestureDetector(
            onTap: _showControlsTemporarily,
            child: Stack(
              children: [
                // Video surface
                if (ctrl != null && _initialized)
                  Center(
                    child: AspectRatio(
                      aspectRatio: ctrl.value.aspectRatio > 0
                          ? ctrl.value.aspectRatio
                          : 16 / 9,
                      child: VideoPlayer(ctrl),
                    ),
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.textPrimary,
                      strokeWidth: 1.5,
                    ),
                  ),
                // Controls overlay — always in tree, IgnorePointer when hidden
                AnimatedOpacity(
                  opacity:  _showControls ? 1.0 : 0.0,
                  duration: AppDurations.fast,
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: Container(
                      color: AppColors.playerOverlay,
                      child: Stack(
                        children: [
                          // Top bar
                          Positioned(
                            top:   MediaQuery.of(context).padding.top,
                            left:  0,
                            right: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Row(
                                children: [
                                  FocusableWidget(
                                    onTap: () { if (context.canPop()) context.pop(); },
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.arrow_back,
                                          color: AppColors.textPrimary, size: 18),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      widget.vod.name,
                                      style: const TextStyle(
                                        color:      AppColors.textPrimary,
                                        fontSize:   14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_hasNext)
                                    FocusableWidget(
                                      onTap: _playNextEpisode,
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Next',
                                                style: TextStyle(
                                                    color: AppColors.textSecondary,
                                                    fontSize: 12)),
                                            SizedBox(width: 4),
                                            Icon(Icons.skip_next_outlined,
                                                color: AppColors.textPrimary, size: 18),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // Bottom controls
                          Positioned(
                            bottom: 0,
                            left:   0,
                            right:  0,
                            child: _SeriesControls(
                              controller:         ctrl,
                              hasNext:             _hasNext,
                              onSeek:              _seek,
                              onToggle:            _togglePlay,
                              onNext:              _playNextEpisode,
                              playPauseFocusNode:  _playPauseFocusNode,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Controls bar ─────────────────────────────────────────────────────────────

class _SeriesControls extends StatelessWidget {
  const _SeriesControls({
    required this.controller,
    required this.hasNext,
    required this.onSeek,
    required this.onToggle,
    required this.onNext,
    this.playPauseFocusNode,
  });
  final VideoPlayerController? controller;
  final bool                   hasNext;
  final void Function(Duration) onSeek;
  final VoidCallback           onToggle;
  final VoidCallback           onNext;
  final FocusNode?             playPauseFocusNode;

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    if (ctrl == null) return const SizedBox.shrink();
    // ValueListenableBuilder rebuilds only this widget on every position tick,
    // avoiding full-screen setState while keeping the progress bar smooth.
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: ctrl,
      builder: (context, value, _) {
        if (!value.isInitialized) return const SizedBox.shrink();
        final pos      = value.position;
        final dur      = value.duration;
        final progress = dur.inMilliseconds > 0
            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight:        1.0,
                  thumbShape:         const RoundSliderThumbShape(enabledThumbRadius: 4),
                  activeTrackColor:   AppColors.textPrimary,
                  inactiveTrackColor: AppColors.accentSoft,
                  thumbColor:         AppColors.textPrimary,
                  overlayShape:       SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: progress.toDouble(),
                  onChanged: (v) {
                    if (dur.inMilliseconds <= 0) return;
                    ctrl.seekTo(Duration(
                        milliseconds: (v * dur.inMilliseconds).round()));
                  },
                ),
              ),
              Row(
                children: [
                  Text(_fmt(pos),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                  const Spacer(),
                  FocusableWidget(
                    onTap: () => onSeek(const Duration(seconds: -10)),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.replay_10,
                          color: AppColors.textSecondary, size: 26),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xl2),
                  FocusableWidget(
                    focusNode: playPauseFocusNode,
                    onTap: onToggle,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        value.isPlaying
                            ? Icons.pause_outlined
                            : Icons.play_arrow_outlined,
                        color: AppColors.textPrimary,
                        size:  AppSpacing.iconMd,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xl2),
                  FocusableWidget(
                    onTap: () => onSeek(const Duration(seconds: 10)),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.forward_10,
                          color: AppColors.textSecondary, size: 26),
                    ),
                  ),
                  const Spacer(),
                  if (hasNext)
                    FocusableWidget(
                      onTap: onNext,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.skip_next_outlined,
                            color: AppColors.textSecondary, size: 18),
                      ),
                    )
                  else
                    Text(_fmt(dur),
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
