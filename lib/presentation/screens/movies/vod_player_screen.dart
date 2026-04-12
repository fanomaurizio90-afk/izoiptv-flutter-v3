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
import '../../widgets/common/focusable_widget.dart';

class VodPlayerScreen extends ConsumerStatefulWidget {
  const VodPlayerScreen({
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
  ConsumerState<VodPlayerScreen> createState() => _VodPlayerScreenState();
}

class _VodPlayerScreenState extends ConsumerState<VodPlayerScreen> {
  late VideoController    _videoController;
  late PlayerNotifier     _playerNotifier;
  late HistoryRepository  _historyRepo;
  bool   _showControls = true;
  Timer? _hideTimer;
  Timer? _saveTimer;

  final _playPauseNode = FocusNode();
  final _backNode      = FocusNode();
  final _seekBackNode  = FocusNode();
  final _seekFwdNode   = FocusNode();
  final _nextEpNode    = FocusNode();
  final _topNextNode   = FocusNode();

  // True when playing a series episode
  bool get _isEpisode => widget.episodes != null;

  int get _currentEpIndex => widget.episodeIndex ?? 0;
  bool get _hasNextEpisode =>
      widget.episodes != null && _currentEpIndex < widget.episodes!.length - 1;

  // Extract series ID from backPath e.g. '/series/123' → 123
  int get _seriesId {
    final match = RegExp(r'/series/(\d+)').firstMatch(widget.backPath);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  // The current episode's ID (widget.vod.id is episode.id when in episode mode)
  int get _episodeId => widget.vod.id;

  String get _contentType => _isEpisode ? 'episode' : 'movie';
  int    get _contentId   => _isEpisode ? _seriesId : widget.vod.id;

  @override
  void initState() {
    super.initState();
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
    _playerNotifier.stop();
    _playPauseNode.dispose();
    _backNode.dispose();
    _seekBackNode.dispose();
    _seekFwdNode.dispose();
    _nextEpNode.dispose();
    _topNextNode.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  void _startPlayback() async {
    Duration startPos = Duration.zero;
    try {
      final repo = ref.read(historyRepositoryProvider);
      final hist = await repo.getPosition(
        _contentId,
        _contentType,
        episodeId: _isEpisode ? _episodeId : null,
      );
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
    if (mounted) {
      setState(() => _showControls = true);
      _playPauseNode.requestFocus();
    }
    _startHideTimer();
  }

  void _startSaveTimer() {
    _saveTimer = Timer.periodic(AppDurations.historyFlushPeriod, (_) => _savePosition());
  }

  Future<void> _savePosition() async {
    if (!mounted) return;
    final pos = ref.read(playerProvider).position.inSeconds;
    final dur = ref.read(playerProvider).duration.inSeconds;
    if (pos <= 0 || dur <= 0) return;
    try {
      await ref.read(historyRepositoryProvider).savePosition(
        contentId:    _contentId,
        contentType:  _contentType,
        contentName:  widget.vod.name,
        positionSecs: pos,
        durationSecs: dur,
        episodeId:    _isEpisode ? _episodeId : null,
        thumbnailUrl: widget.vod.posterUrl,
      );
    } catch (_) {}
  }

  void _savePositionSync() {
    final pos = _playerNotifier.currentPosition.inSeconds;
    final dur = _playerNotifier.currentDuration.inSeconds;
    if (pos <= 0 || dur <= 0) return;
    _historyRepo.savePosition(
      contentId:    _contentId,
      contentType:  _contentType,
      contentName:  widget.vod.name,
      positionSecs: pos,
      durationSecs: dur,
      episodeId:    _isEpisode ? _episodeId : null,
      thumbnailUrl: widget.vod.posterUrl,
    );
  }

  void _playNextEpisode() {
    if (!_hasNextEpisode) return;
    final nextEp    = widget.episodes![_currentEpIndex + 1];
    final nextIndex = _currentEpIndex + 1;
    // Build VodItem from the next episode — same structure the detail screen uses
    final nextVod = VodItem(
      id:          nextEp.id,
      name:        nextEp.title,
      streamUrl:   nextEp.streamUrl,
      categoryId:  0,
      posterUrl:   nextEp.thumbnailUrl,
      durationSecs: nextEp.durationSecs,
    );
    context.pushReplacement('/series/player', extra: {
      'vod':          nextVod,
      'backPath':     widget.backPath,
      'episodes':     widget.episodes!,
      'episodeIndex': nextIndex,
    });
  }

  static bool _isActivateKey(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.select) return true;
    if (event.logicalKey == LogicalKeyboardKey.enter) return true;
    if (event.logicalKey == LogicalKeyboardKey.numpadEnter) return true;
    if (event.logicalKey == LogicalKeyboardKey.gameButtonA) return true;
    if (event.physicalKey.usbHidUsage == 0x00070058) return true;
    if (event.physicalKey == PhysicalKeyboardKey.select) return true;
    if (event.physicalKey == PhysicalKeyboardKey.gameButtonA) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && context.canPop()) context.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Focus(
          autofocus:  true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final key = event.logicalKey;

            // Media keys always work regardless of control visibility
            if (key == LogicalKeyboardKey.mediaPlayPause) {
              _playerNotifier.togglePlay();
              _showControlsTemporarily();
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.mediaRewind) {
              final pos = ref.read(playerProvider).position;
              _playerNotifier.seek(pos - const Duration(seconds: 10));
              _showControlsTemporarily();
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.mediaFastForward) {
              final pos = ref.read(playerProvider).position;
              _playerNotifier.seek(pos + const Duration(seconds: 10));
              _showControlsTemporarily();
              return KeyEventResult.handled;
            }

            // When controls are hidden: D-pad seeks, select toggles play
            if (!_showControls) {
              if (_isActivateKey(event)) {
                _playerNotifier.togglePlay();
                _showControlsTemporarily();
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowLeft) {
                final pos = ref.read(playerProvider).position;
                _playerNotifier.seek(pos - const Duration(seconds: 10));
                _showControlsTemporarily();
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowRight) {
                final pos = ref.read(playerProvider).position;
                _playerNotifier.seek(pos + const Duration(seconds: 10));
                _showControlsTemporarily();
                return KeyEventResult.handled;
              }
              // Any other key shows controls
              _showControlsTemporarily();
              return KeyEventResult.handled;
            }

            // When controls are visible: let arrows navigate between buttons
            _startHideTimer();
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
                // CRITICAL: AnimatedOpacity ALWAYS in tree — use IgnorePointer to block
                // input when hidden. Never guard with if() — that breaks the fade animation
                // and lets D-pad keypresses land on hidden buttons.
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
                                  Focus(
                                    skipTraversal: true,
                                    canRequestFocus: false,
                                    onKeyEvent: (_, event) {
                                      if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                                      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                        if (_hasNextEpisode) {
                                          _topNextNode.requestFocus();
                                        } else {
                                          _playPauseNode.requestFocus();
                                        }
                                        return KeyEventResult.handled;
                                      }
                                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                        _playPauseNode.requestFocus();
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: FocusableWidget(
                                      focusNode: _backNode,
                                      onTap: () { if (context.canPop()) context.pop(); },
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.arrow_back,
                                            color: AppColors.textPrimary, size: 18),
                                      ),
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
                                  if (_hasNextEpisode)
                                    Focus(
                                      skipTraversal: true,
                                      canRequestFocus: false,
                                      onKeyEvent: (_, event) {
                                        if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                                        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                          _backNode.requestFocus();
                                          return KeyEventResult.handled;
                                        }
                                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                          _nextEpNode.requestFocus();
                                          return KeyEventResult.handled;
                                        }
                                        return KeyEventResult.ignored;
                                      },
                                      child: FocusableWidget(
                                        focusNode: _topNextNode,
                                        onTap: _playNextEpisode,
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Next',
                                                style: TextStyle(
                                                    color: AppColors.textSecondary,
                                                    fontSize: 12),
                                              ),
                                              SizedBox(width: 4),
                                              Icon(Icons.skip_next_outlined,
                                                  color: AppColors.textPrimary,
                                                  size: 18),
                                            ],
                                          ),
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
                            child: _VodControls(
                              hasNext:       _hasNextEpisode,
                              onNextEpisode: _playNextEpisode,
                              playPauseNode: _playPauseNode,
                              backNode:      _backNode,
                              seekBackNode:  _seekBackNode,
                              seekFwdNode:   _seekFwdNode,
                              nextEpNode:    _nextEpNode,
                              topNextNode:   _topNextNode,
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

class _VodControls extends ConsumerWidget {
  const _VodControls({
    required this.hasNext,
    required this.onNextEpisode,
    required this.playPauseNode,
    required this.backNode,
    required this.seekBackNode,
    required this.seekFwdNode,
    required this.nextEpNode,
    required this.topNextNode,
  });
  final bool         hasNext;
  final VoidCallback onNextEpisode;
  final FocusNode    playPauseNode;
  final FocusNode    backNode;
  final FocusNode    seekBackNode;
  final FocusNode    seekFwdNode;
  final FocusNode    nextEpNode;
  final FocusNode    topNextNode;

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
              Focus(
                skipTraversal: true,
                canRequestFocus: false,
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    playPauseNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    backNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: FocusableWidget(
                  focusNode: seekBackNode,
                  onTap: () {
                    final p = ref.read(playerProvider).position;
                    ref.read(playerProvider.notifier).seek(p - const Duration(seconds: 10));
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.replay_10,
                        color: AppColors.textSecondary, size: 26),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xl2),
              Focus(
                skipTraversal: true,
                canRequestFocus: false,
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    seekBackNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    seekFwdNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    backNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: FocusableWidget(
                  focusNode: playPauseNode,
                  onTap: () => ref.read(playerProvider.notifier).togglePlay(),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      playerState.isPlaying
                          ? Icons.pause_outlined
                          : Icons.play_arrow_outlined,
                      color: AppColors.textPrimary,
                      size:  AppSpacing.iconMd,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xl2),
              Focus(
                skipTraversal: true,
                canRequestFocus: false,
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    playPauseNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    if (hasNext) nextEpNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    backNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: FocusableWidget(
                  focusNode: seekFwdNode,
                  onTap: () {
                    final p = ref.read(playerProvider).position;
                    ref.read(playerProvider.notifier).seek(p + const Duration(seconds: 10));
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.forward_10,
                        color: AppColors.textSecondary, size: 26),
                  ),
                ),
              ),
              const Spacer(),
              if (hasNext)
                Focus(
                  skipTraversal: true,
                  canRequestFocus: false,
                  onKeyEvent: (_, event) {
                    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      seekFwdNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      topNextNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: FocusableWidget(
                    focusNode: nextEpNode,
                    onTap: onNextEpisode,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.skip_next_outlined,
                          color: AppColors.textSecondary, size: 18),
                    ),
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
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
