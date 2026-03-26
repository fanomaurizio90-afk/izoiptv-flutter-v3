import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/vod.dart';
import '../../../domain/entities/series.dart';
import '../../providers/player_provider.dart';
import '../../providers/providers.dart';
import '../../../domain/repositories/history_repository.dart';

class VodPlayerScreen extends ConsumerStatefulWidget {
  const VodPlayerScreen({
    super.key,
    required this.vod,
    required this.backPath,
    // Optional: episode list for series next-episode support
    this.episodes,
    this.episodeIndex,
  });
  final VodItem        vod;
  final String         backPath;
  final List<Episode>? episodes;
  final int?           episodeIndex;

  @override
  ConsumerState<VodPlayerScreen> createState() => _VodPlayerScreenState();
}

class _VodPlayerScreenState extends ConsumerState<VodPlayerScreen> {
  late VideoController    _videoController;
  late PlayerNotifier     _playerNotifier;   // saved in initState — safe to use in dispose
  late HistoryRepository  _historyRepo;      // saved in initState — safe to use in dispose
  bool   _showControls = true;
  Timer? _hideTimer;
  Timer? _saveTimer;

  int get _currentEpIndex => widget.episodeIndex ?? 0;
  bool get _hasNextEpisode =>
      widget.episodes != null && _currentEpIndex < widget.episodes!.length - 1;

  @override
  void initState() {
    super.initState();
    // Save references NOW — ref is not safe to use in dispose()
    _playerNotifier = ref.read(playerProvider.notifier);
    _historyRepo    = ref.read(historyRepositoryProvider);
    _videoController = VideoController(
      _playerNotifier.player,
      configuration: const VideoControllerConfiguration(enableHardwareAcceleration: false),
    );

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPlayback());
    _startHideTimer();
    _startSaveTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _savePositionSync();
    _playerNotifier.stop(); // use saved reference — always safe
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]); // clear override — TV stays landscape
    super.dispose();
  }

  void _startPlayback() async {
    Duration startPos = Duration.zero;
    try {
      final repo = ref.read(historyRepositoryProvider);
      final hist = await repo.getPosition(widget.vod.id, 'vod');
      if (hist != null) {
        startPos = Duration(seconds: hist['position_secs'] as int);
      }
    } catch (_) {}

    await _playerNotifier.openUrl(widget.vod.streamUrl);
    if (startPos > Duration.zero) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _playerNotifier.seek(startPos);
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(AppDurations.controlsAutoHide, () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _showControlsTemporarily() {
    if (mounted) setState(() => _showControls = true);
    _startHideTimer();
  }

  void _startSaveTimer() {
    _saveTimer = Timer.periodic(AppDurations.historyFlushPeriod, (_) => _savePosition());
  }

  // Async save — used by the periodic timer
  Future<void> _savePosition() async {
    if (!mounted) return;
    final pos = ref.read(playerProvider).position.inSeconds;
    final dur = ref.read(playerProvider).duration.inSeconds;
    if (pos <= 0) return;
    try {
      await ref.read(historyRepositoryProvider).savePosition(
        contentId:    widget.vod.id,
        contentType:  'vod',
        contentName:  widget.vod.name,
        positionSecs: pos,
        durationSecs: dur,
        thumbnailUrl: widget.vod.posterUrl,
      );
    } catch (_) {}
  }

  // Called from dispose — uses pre-saved references, fires async without awaiting.
  // The future completes independently after the widget is gone.
  void _savePositionSync() {
    final pos = _playerNotifier.currentPosition.inSeconds;
    final dur = _playerNotifier.currentDuration.inSeconds;
    if (pos <= 0) return;
    _historyRepo.savePosition(
      contentId:    widget.vod.id,
      contentType:  'vod',
      contentName:  widget.vod.name,
      positionSecs: pos,
      durationSecs: dur,
      thumbnailUrl: widget.vod.posterUrl,
    );
  }

  void _playNextEpisode() {
    if (!_hasNextEpisode) return;
    final nextEp    = widget.episodes![_currentEpIndex + 1];
    final nextIndex = _currentEpIndex + 1;
    // Use go_router to keep the back stack consistent
    context.pushReplacement('/series/player', extra: {
      'episode':  nextEp,
      'episodes': widget.episodes!,
      'index':    nextIndex,
      'seriesId': nextEp.seriesId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) context.go(widget.backPath);
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: Focus(
        autofocus:  true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            _playerNotifier.togglePlay();
            _showControlsTemporarily();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            final pos = ref.read(playerProvider).position;
            _playerNotifier.seek(pos - const Duration(seconds: 10));
            _showControlsTemporarily();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            final pos = ref.read(playerProvider).position;
            _playerNotifier.seek(pos + const Duration(seconds: 10));
            _showControlsTemporarily();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: _showControlsTemporarily,
          child: Stack(
            children: [
              RepaintBoundary(
                child: Video(
                  controller: _videoController,
                  fit:        BoxFit.contain,
                  fill:       AppColors.background,
                  controls:   NoVideoControls,
                ),
              ),
              if (_showControls)
                AnimatedOpacity(
                  opacity:  1.0,
                  duration: AppDurations.fast,
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
                                Focus(
                                  onKeyEvent: (_, event) {
                                    if (event is KeyDownEvent &&
                                        (event.logicalKey == LogicalKeyboardKey.select ||
                                         event.logicalKey == LogicalKeyboardKey.enter ||
                                         event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                                         event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
                                      context.go(widget.backPath);
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: GestureDetector(
                                    onTap: () => context.go(widget.backPath),
                                    child: const Icon(Icons.arrow_back,
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
                                // Next episode button (series only)
                                if (_hasNextEpisode)
                                  GestureDetector(
                                    onTap: _playNextEpisode,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Next',
                                          style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.skip_next_outlined,
                                            color: AppColors.textPrimary,
                                            size: 18),
                                      ],
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
                          child: _VodControls(
                            hasNext:       _hasNextEpisode,
                            onNextEpisode: _playNextEpisode,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      ), // Scaffold
    ); // PopScope
  }
}

class _VodControls extends ConsumerWidget {
  const _VodControls({
    required this.hasNext,
    required this.onNextEpisode,
  });
  final bool         hasNext;
  final VoidCallback onNextEpisode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final pos = playerState.position;
    final dur = playerState.duration;
    final progress = dur.inMilliseconds > 0
        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seek bar
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
                final seekTo = Duration(
                    milliseconds: (v * dur.inMilliseconds).round());
                ref.read(playerProvider.notifier).seek(seekTo);
              },
            ),
          ),
          Row(
            children: [
              Text(_fmt(pos),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
              const Spacer(),
              // Rewind 10s
              GestureDetector(
                onTap: () {
                  final p = ref.read(playerProvider).position;
                  ref.read(playerProvider.notifier).seek(p - const Duration(seconds: 10));
                },
                child: const Icon(Icons.replay_10,
                    color: AppColors.textSecondary, size: 26),
              ),
              const SizedBox(width: AppSpacing.xl2),
              // Play / Pause
              GestureDetector(
                onTap: () => ref.read(playerProvider.notifier).togglePlay(),
                child: Icon(
                  playerState.isPlaying
                      ? Icons.pause_outlined
                      : Icons.play_arrow_outlined,
                  color: AppColors.textPrimary,
                  size:  AppSpacing.iconMd,
                ),
              ),
              const SizedBox(width: AppSpacing.xl2),
              // Forward 10s
              GestureDetector(
                onTap: () {
                  final p = ref.read(playerProvider).position;
                  ref.read(playerProvider.notifier).seek(p + const Duration(seconds: 10));
                },
                child: const Icon(Icons.forward_10,
                    color: AppColors.textSecondary, size: 26),
              ),
              const Spacer(),
              // Next episode button in bottom bar (series)
              if (hasNext)
                GestureDetector(
                  onTap: onNextEpisode,
                  child: const Icon(Icons.skip_next_outlined,
                      color: AppColors.textSecondary, size: 18),
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
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
