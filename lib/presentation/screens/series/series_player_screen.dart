import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/vod.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/repositories/history_repository.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';

/// Unified series player: tries ExoPlayer (video_player) first,
/// falls back to media_kit if initialization fails.
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
  // ── Player state ──────────────────────────────────────────────────────────
  late HistoryRepository _historyRepo;
  bool   _showControls  = true;
  bool   _initialized   = false;
  bool   _disposed      = false;
  bool   _usingMediaKit = false;
  Timer? _hideTimer;
  Timer? _saveTimer;
  Timer? _uiRefreshTimer;

  // ExoPlayer (video_player)
  VideoPlayerController? _exoController;

  // media_kit fallback
  mk.Player?           _mkPlayer;
  mkv.VideoController? _mkController;

  bool get _hasNext =>
      widget.episodes != null &&
      (widget.episodeIndex ?? 0) < widget.episodes!.length - 1;

  int get _currentIdx => widget.episodeIndex ?? 0;

  int get _seriesId {
    final match = RegExp(r'/series/(\d+)').firstMatch(widget.backPath);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  int get _episodeId => widget.vod.id;

  final _topFocusNode       = FocusNode(debugLabel: 'player-root');
  final _backFocusNode      = FocusNode(debugLabel: 'back');
  final _nextEpFocusNode    = FocusNode(debugLabel: 'next-ep');
  final _subtitleFocusNode  = FocusNode(debugLabel: 'subtitle');
  final _audioFocusNode     = FocusNode(debugLabel: 'audio');
  final _rewindFocusNode    = FocusNode(debugLabel: 'rewind');
  final _playPauseFocusNode = FocusNode(debugLabel: 'play-pause');
  final _forwardFocusNode   = FocusNode(debugLabel: 'forward');
  final _speedFocusNode     = FocusNode(debugLabel: 'speed');
  final _nextEpBotFocusNode = FocusNode(debugLabel: 'next-ep-bottom');

  /// Ordered list of focusable nodes in the bottom control bar.
  List<FocusNode> get _bottomNodes => [
    if (_usingMediaKit) _subtitleFocusNode,
    if (_usingMediaKit) _audioFocusNode,
    _rewindFocusNode,
    _playPauseFocusNode,
    _forwardFocusNode,
    _speedFocusNode,
    if (_hasNext) _nextEpBotFocusNode,
  ];

  /// Ordered list of focusable nodes in the top bar.
  List<FocusNode> get _topNodes => [
    _backFocusNode,
    if (_hasNext) _nextEpFocusNode,
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _historyRepo = ref.read(historyRepositoryProvider);
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _startHideTimer();
    _startSaveTimer();
    _startUiRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPlayer());
  }

  void _startUiRefresh() {
    _uiRefreshTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) { if (mounted && _initialized) setState(() {}); },
    );
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
    if (_disposed) return;

    // ── Try ExoPlayer first ───────────────────────────────────────────────
    bool exoFailed = false;
    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.vod.streamUrl),
      );
      await ctrl.initialize();
      if (_disposed) { ctrl.dispose(); return; }

      if (startPos > Duration.zero) {
        await ctrl.seekTo(startPos);
        if (_disposed) { ctrl.dispose(); return; }
      }
      await ctrl.play();

      if (mounted) {
        setState(() {
          _exoController = ctrl;
          _initialized   = true;
          _usingMediaKit = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _showControls) _playPauseFocusNode.requestFocus();
        });
      } else {
        ctrl.dispose();
      }
      return;
    } catch (_) {
      exoFailed = true;
    }
    if (_disposed) return;

    // ── Fallback to media_kit ─────────────────────────────────────────────
    if (exoFailed) {
      _showToast('Switching to backup player…');
      try {
        final player = mk.Player();
        final controller = mkv.VideoController(
          player,
          configuration: const mkv.VideoControllerConfiguration(
            enableHardwareAcceleration: false,
          ),
        );
        await player.open(mk.Media(widget.vod.streamUrl));
        if (_disposed) { player.dispose(); return; }

        if (startPos > Duration.zero) {
          await player.seek(startPos);
          if (_disposed) { player.dispose(); return; }
        }

        if (mounted) {
          setState(() {
            _mkPlayer      = player;
            _mkController   = controller;
            _initialized    = true;
            _usingMediaKit  = true;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _showControls) _playPauseFocusNode.requestFocus();
          });
        } else {
          player.dispose();
        }
      } catch (_) {
        if (mounted) _showToast('Unable to play this stream');
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _exoController?.pause();
    _mkPlayer?.pause();
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _uiRefreshTimer?.cancel();
    try { _savePositionSync(); } catch (_) {}
    _exoController?.dispose();
    _mkPlayer?.dispose();
    _topFocusNode.dispose();
    _backFocusNode.dispose();
    _nextEpFocusNode.dispose();
    _subtitleFocusNode.dispose();
    _audioFocusNode.dispose();
    _rewindFocusNode.dispose();
    _playPauseFocusNode.dispose();
    _forwardFocusNode.dispose();
    _speedFocusNode.dispose();
    _nextEpBotFocusNode.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  // ── Toast ─────────────────────────────────────────────────────────────────

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 3),
      backgroundColor: const Color(0xFF1A1A1A),
    ));
  }

  // ── Timers ────────────────────────────────────────────────────────────────

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

  // ── Playback abstraction ──────────────────────────────────────────────────

  bool get _isPlaying {
    if (_usingMediaKit) return _mkPlayer?.state.playing ?? false;
    return _exoController?.value.isPlaying ?? false;
  }

  Duration get _position {
    if (_usingMediaKit) return _mkPlayer?.state.position ?? Duration.zero;
    return _exoController?.value.position ?? Duration.zero;
  }

  Duration get _duration {
    if (_usingMediaKit) return _mkPlayer?.state.duration ?? Duration.zero;
    return _exoController?.value.duration ?? Duration.zero;
  }

  double get _aspectRatio {
    if (_usingMediaKit) {
      final w = _mkPlayer?.state.width;
      final h = _mkPlayer?.state.height;
      if (w != null && h != null && h > 0) return w / h;
      return 16 / 9;
    }
    final ar = _exoController?.value.aspectRatio ?? 0;
    return ar > 0 ? ar : 16 / 9;
  }

  // ── History ───────────────────────────────────────────────────────────────

  Future<void> _savePosition() async {
    if (!mounted || !_initialized) return;
    final pos = _position.inSeconds;
    final dur = _duration.inSeconds;
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
    if (!_initialized) return;
    final pos = _position.inSeconds;
    final dur = _duration.inSeconds;
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

  // ── Playback controls ─────────────────────────────────────────────────────

  void _togglePlay() {
    if (_usingMediaKit) {
      _mkPlayer?.playOrPause();
    } else {
      final ctrl = _exoController;
      if (ctrl == null) return;
      ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
    }
    _showControlsTemporarily();
  }

  void _seek(Duration offset) {
    final newPos = _position + offset;
    final clamped = newPos.isNegative ? Duration.zero : newPos;
    if (_usingMediaKit) {
      _mkPlayer?.seek(clamped);
    } else {
      _exoController?.seekTo(clamped);
    }
    _showControlsTemporarily();
  }

  void _seekTo(Duration pos) {
    if (_usingMediaKit) {
      _mkPlayer?.seek(pos);
    } else {
      _exoController?.seekTo(pos);
    }
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

  // ── Track selection (media_kit only) ──────────────────────────────────────

  void _showSubtitlePicker() {
    if (!_usingMediaKit || _mkPlayer == null) {
      _showToast('Subtitles not available with this player');
      return;
    }
    final tracks = _mkPlayer!.state.tracks.subtitle;
    if (tracks.isEmpty) {
      _showToast('No subtitle tracks found');
      return;
    }
    _showTrackDialog<mk.SubtitleTrack>(
      title: 'Subtitles',
      items: [mk.SubtitleTrack.no(), ...tracks],
      labelOf: (t) {
        if (t.id == 'no') return 'Off';
        final parts = <String>[];
        if (t.title != null && t.title!.isNotEmpty) parts.add(t.title!);
        if (t.language != null && t.language!.isNotEmpty) parts.add(t.language!);
        return parts.isNotEmpty ? parts.join(' — ') : 'Track ${t.id}';
      },
      selectedId: _mkPlayer!.state.track.subtitle.id,
      onSelect: (t) => _mkPlayer!.setSubtitleTrack(t),
    );
  }

  void _showAudioPicker() {
    if (!_usingMediaKit || _mkPlayer == null) {
      _showToast('Audio tracks not available with this player');
      return;
    }
    final tracks = _mkPlayer!.state.tracks.audio;
    if (tracks.length <= 1) {
      _showToast('Only one audio track available');
      return;
    }
    _showTrackDialog<mk.AudioTrack>(
      title: 'Audio',
      items: tracks,
      labelOf: (t) {
        final parts = <String>[];
        if (t.title != null && t.title!.isNotEmpty) parts.add(t.title!);
        if (t.language != null && t.language!.isNotEmpty) parts.add(t.language!);
        return parts.isNotEmpty ? parts.join(' — ') : 'Track ${t.id}';
      },
      selectedId: _mkPlayer!.state.track.audio.id,
      onSelect: (t) => _mkPlayer!.setAudioTrack(t),
    );
  }

  void _showSpeedPicker() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final current = _usingMediaKit
        ? _mkPlayer?.state.rate ?? 1.0
        : _exoController?.value.playbackSpeed ?? 1.0;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Playback Speed',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              ...speeds.map((s) => FocusableWidget(
                autofocus: (s - current).abs() < 0.01,
                borderRadius: 8,
                onTap: () {
                  if (_usingMediaKit) {
                    _mkPlayer?.setRate(s);
                  } else {
                    _exoController?.setPlaybackSpeed(s);
                  }
                  Navigator.of(ctx).pop();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if ((s - current).abs() < 0.01)
                        const Icon(Icons.check, color: Colors.white, size: 14)
                      else
                        const SizedBox(width: 14),
                      const SizedBox(width: 8),
                      Text('${s}x',
                          style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
    _showControlsTemporarily();
  }

  void _showTrackDialog<T>({
    required String title,
    required List<T> items,
    required String Function(T) labelOf,
    required String selectedId,
    required void Function(T) onSelect,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(title,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: items.map((t) {
                        final id = (t as dynamic).id as String;
                        final selected = id == selectedId;
                        return FocusableWidget(
                          autofocus: selected,
                          borderRadius: 8,
                          onTap: () {
                            onSelect(t);
                            Navigator.of(ctx).pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (selected)
                                  const Icon(Icons.check, color: Colors.white, size: 14)
                                else
                                  const SizedBox(width: 14),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(labelOf(t),
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    _showControlsTemporarily();
  }

  // ── Key handling ──────────────────────────────────────────────────────────

  static bool _isActivateKey(KeyEvent e) =>
      e.logicalKey == LogicalKeyboardKey.select       ||
      e.logicalKey == LogicalKeyboardKey.enter        ||
      e.logicalKey == LogicalKeyboardKey.numpadEnter  ||
      e.logicalKey == LogicalKeyboardKey.gameButtonA  ||
      e.physicalKey == PhysicalKeyboardKey.select     ||
      e.physicalKey == PhysicalKeyboardKey.gameButtonA ||
      e.physicalKey.usbHidUsage == 0x00070058;

  // ── Build ─────────────────────────────────────────────────────────────────

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
          focusNode: _topFocusNode,
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final key = event.logicalKey;

            // Dedicated media keys always work regardless of OSD state
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

            // Controls visible — navigate between on-screen buttons
            if (_showControls) {
              _startHideTimer();
              // SELECT → let FocusableWidget handle it
              if (_isActivateKey(event)) return KeyEventResult.ignored;

              // D-pad → explicit index-based focus navigation
              // (focusInDirection is broken inside Stack/Positioned overlays)
              final pf = FocusManager.instance.primaryFocus;
              final bottom = _bottomNodes;
              final top    = _topNodes;
              final bIdx   = pf != null ? bottom.indexOf(pf) : -1;
              final tIdx   = pf != null ? top.indexOf(pf) : -1;

              if (key == LogicalKeyboardKey.arrowLeft) {
                if (bIdx > 0) bottom[bIdx - 1].requestFocus();
                else if (tIdx > 0) top[tIdx - 1].requestFocus();
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowRight) {
                if (bIdx >= 0 && bIdx < bottom.length - 1) bottom[bIdx + 1].requestFocus();
                else if (tIdx >= 0 && tIdx < top.length - 1) top[tIdx + 1].requestFocus();
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowUp) {
                if (bIdx >= 0) _backFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowDown) {
                if (tIdx >= 0) _playPauseFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            }

            // Controls hidden — first press shows OSD
            if (_isActivateKey(event)) {
              _togglePlay();
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
                _buildVideoSurface(),
                AnimatedOpacity(
                  opacity:  _showControls ? 1.0 : 0.0,
                  duration: AppDurations.fast,
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: Container(
                      color: AppColors.playerOverlay,
                      child: Stack(
                        children: [
                          Positioned(
                            top:   MediaQuery.of(context).padding.top,
                            left:  0,
                            right: 0,
                            child: _buildTopBar(),
                          ),
                          Positioned(
                            bottom: 0,
                            left:   0,
                            right:  0,
                            child: _buildBottomControls(),
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

  Widget _buildVideoSurface() {
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.textPrimary,
          strokeWidth: 1.5,
        ),
      );
    }
    if (_usingMediaKit && _mkController != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: _aspectRatio,
          child: mkv.Video(controller: _mkController!),
        ),
      );
    }
    if (_exoController != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: _aspectRatio,
          child: VideoPlayer(_exoController!),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          FocusableWidget(
            focusNode: _backFocusNode,
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
          if (_usingMediaKit)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('MK', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w600)),
            ),
          if (_hasNext)
            FocusableWidget(
              focusNode: _nextEpFocusNode,
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
    );
  }

  Widget _buildBottomControls() {
    final pos      = _position;
    final dur      = _duration;
    final progress = dur.inMilliseconds > 0
        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Focus(
            canRequestFocus: false,
            descendantsAreFocusable: false,
            child: SliderTheme(
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
                  _seekTo(Duration(
                      milliseconds: (v * dur.inMilliseconds).round()));
                },
              ),
            ),
          ),
          Row(
            children: [
              Text(_fmt(pos),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
              const Spacer(),
              if (_usingMediaKit) ...[
                FocusableWidget(
                  focusNode: _subtitleFocusNode,
                  onTap: _showSubtitlePicker,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.subtitles_outlined,
                        color: AppColors.textSecondary, size: 20),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                FocusableWidget(
                  focusNode: _audioFocusNode,
                  onTap: _showAudioPicker,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.audiotrack_outlined,
                        color: AppColors.textSecondary, size: 20),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              FocusableWidget(
                focusNode: _rewindFocusNode,
                onTap: () => _seek(const Duration(seconds: -10)),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.replay_10,
                      color: AppColors.textSecondary, size: 26),
                ),
              ),
              const SizedBox(width: AppSpacing.xl2),
              FocusableWidget(
                focusNode: _playPauseFocusNode,
                onTap: _togglePlay,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _isPlaying
                        ? Icons.pause_outlined
                        : Icons.play_arrow_outlined,
                    color: AppColors.textPrimary,
                    size:  AppSpacing.iconMd,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xl2),
              FocusableWidget(
                focusNode: _forwardFocusNode,
                onTap: () => _seek(const Duration(seconds: 10)),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.forward_10,
                      color: AppColors.textSecondary, size: 26),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              FocusableWidget(
                focusNode: _speedFocusNode,
                onTap: _showSpeedPicker,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.speed,
                      color: AppColors.textSecondary, size: 20),
                ),
              ),
              const Spacer(),
              if (_hasNext)
                FocusableWidget(
                  focusNode: _nextEpBotFocusNode,
                  onTap: _playNextEpisode,
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
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
