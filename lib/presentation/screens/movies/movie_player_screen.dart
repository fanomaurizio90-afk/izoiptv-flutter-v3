import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/vod.dart';
import '../../../domain/repositories/history_repository.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';

class MoviePlayerScreen extends ConsumerStatefulWidget {
  const MoviePlayerScreen({
    super.key,
    required this.vod,
    required this.backPath,
  });
  final VodItem vod;
  final String  backPath;

  @override
  ConsumerState<MoviePlayerScreen> createState() => _MoviePlayerScreenState();
}

class _MoviePlayerScreenState extends ConsumerState<MoviePlayerScreen> {
  VideoPlayerController? _controller;
  late HistoryRepository _historyRepo;
  bool   _showControls = true;
  bool   _initialized  = false;
  bool   _disposed     = false;
  Timer? _hideTimer;
  Timer? _saveTimer;

  int get _vodId => widget.vod.id;

  final _topFocusNode       = FocusNode(debugLabel: 'player-root');
  final _playPauseFocusNode = FocusNode(debugLabel: 'play-pause');

  @override
  void initState() {
    super.initState();
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
      final hist = await _historyRepo.getPosition(_vodId, 'movie');
      if (hist != null) {
        startPos = Duration(seconds: hist['position_secs'] as int);
      }
    } catch (_) {}

    if (_disposed) return;

    final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.vod.streamUrl));
    try {
      await ctrl.initialize();
    } catch (_) {}
    if (_disposed) { ctrl.dispose(); return; }

    if (startPos > Duration.zero) {
      await ctrl.seekTo(startPos);
      if (_disposed) { ctrl.dispose(); return; }
    }

    await ctrl.play();

    if (mounted) {
      setState(() {
        _controller  = ctrl;
        _initialized = true;
      });
    } else {
      ctrl.dispose();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controller?.pause();
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
    _saveTimer = Timer.periodic(
      AppDurations.historyFlushPeriod, (_) => _savePosition());
  }

  Future<void> _savePosition() async {
    final ctrl = _controller;
    if (!mounted || ctrl == null || !ctrl.value.isInitialized) return;
    final pos = ctrl.value.position.inSeconds;
    final dur = ctrl.value.duration.inSeconds;
    if (pos <= 0) return;
    try {
      await _historyRepo.savePosition(
        contentId:    _vodId,
        contentType:  'movie',
        contentName:  widget.vod.name,
        positionSecs: pos,
        durationSecs: dur,
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
      contentId:    _vodId,
      contentType:  'movie',
      contentName:  widget.vod.name,
      positionSecs: pos,
      durationSecs: dur,
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
                // Controls overlay
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
                                ],
                              ),
                            ),
                          ),
                          // Bottom controls
                          Positioned(
                            bottom: 0,
                            left:   0,
                            right:  0,
                            child: _MovieControls(
                              controller:         ctrl,
                              onSeek:             _seek,
                              onToggle:           _togglePlay,
                              playPauseFocusNode: _playPauseFocusNode,
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

class _MovieControls extends StatelessWidget {
  const _MovieControls({
    required this.controller,
    required this.onSeek,
    required this.onToggle,
    this.playPauseFocusNode,
  });
  final VideoPlayerController? controller;
  final void Function(Duration) onSeek;
  final VoidCallback           onToggle;
  final FocusNode?             playPauseFocusNode;

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    if (ctrl == null) return const SizedBox.shrink();
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
