import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/channel.dart';
import '../../providers/channel_provider.dart';
import '../../providers/providers.dart';
import 'package:go_router/go_router.dart';
import '../../providers/player_provider.dart';
import '../../widgets/common/focusable_widget.dart';

class LivePlayerScreen extends ConsumerStatefulWidget {
  const LivePlayerScreen({super.key});

  @override
  ConsumerState<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends ConsumerState<LivePlayerScreen> {
  late VideoController  _mkVideoController;
  late PlayerNotifier   _playerNotifier;
  bool   _showControls  = true;
  bool   _usingExo      = false;
  Timer? _hideTimer;

  // ExoPlayer (video_player)
  VideoPlayerController? _exoController;

  // Focus
  final _playPauseFocusNode = FocusNode(debugLabel: 'live-play-pause');

  // EPG
  String? _epgNow;
  String? _epgNext;

  @override
  void initState() {
    super.initState();
    _playerNotifier = ref.read(playerProvider.notifier);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _mkVideoController = VideoController(
      _playerNotifier.player,
      configuration: const VideoControllerConfiguration(enableHardwareAcceleration: false),
    );
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playCurrentChannel());
    _startHideTimer();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _hideTimer?.cancel();
    _exoController?.dispose();
    _playPauseFocusNode.dispose();
    _playerNotifier.stop();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  // ── Channel playback ────────────────────────────────────────────────────────

  Future<void> _playCurrentChannel() async {
    final ch = ref.read(selectedChannelProvider);
    if (ch != null) {
      await _playUrl(ch.streamUrl);
      _fetchEpg(ch);
    }
  }

  Future<void> _fetchEpg(Channel ch) async {
    if (ch.epgChannelId == null || ch.epgChannelId!.isEmpty) {
      if (mounted) setState(() { _epgNow = null; _epgNext = null; });
      return;
    }
    try {
      final repo = ref.read(channelRepositoryProvider);
      final epg  = await repo.getShortEpg(ch.id);
      if (!mounted) return;
      final now = DateTime.now();
      String? nowTitle;
      String? nextTitle;
      for (var i = 0; i < epg.length; i++) {
        final start = DateTime.tryParse(epg[i]['start'] ?? '');
        final end   = DateTime.tryParse(epg[i]['end'] ?? '');
        if (start != null && end != null && now.isAfter(start) && now.isBefore(end)) {
          nowTitle = epg[i]['title'];
          if (i + 1 < epg.length) nextTitle = epg[i + 1]['title'];
          break;
        }
      }
      if (mounted) setState(() { _epgNow = nowTitle; _epgNext = nextTitle; });
    } catch (_) {
      if (mounted) setState(() { _epgNow = null; _epgNext = null; });
    }
  }

  Future<void> _playUrl(String url) async {
    // Dispose previous ExoPlayer if any
    _exoController?.dispose();
    _exoController = null;

    // Try ExoPlayer first
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize().timeout(const Duration(seconds: 5));
      if (!mounted) { ctrl.dispose(); return; }
      await ctrl.play();
      if (mounted) {
        setState(() {
          _exoController = ctrl;
          _usingExo = true;
        });
      } else {
        ctrl.dispose();
      }
      return;
    } catch (_) {
      // ExoPlayer failed — fall back to media_kit
    }

    if (!mounted) return;
    if (_usingExo) setState(() => _usingExo = false);
    _playerNotifier.openUrl(url);
  }

  // ── Track selection ──────────────────────────────────────────────────────

  mk.Player get _mkPlayer => _playerNotifier.player;

  void _showSubtitlePicker() {
    if (_usingExo) {
      _showToast('Subtitles not available with this player');
      return;
    }
    final tracks = _mkPlayer.state.tracks.subtitle;
    if (tracks.isEmpty) {
      _showToast('No subtitle tracks found');
      return;
    }
    _showTrackDialog<mk.SubtitleTrack>(
      title: 'Subtitles',
      items: [mk.SubtitleTrack.no(), ...tracks],
      labelOf: (t) {
        if (t.id == 'no') return 'Off';
        final lang  = t.language ?? '';
        final title = t.title ?? '';
        if (lang.isNotEmpty && title.isNotEmpty) return '$lang — $title';
        return lang.isNotEmpty ? lang : (title.isNotEmpty ? title : 'Track ${t.id}');
      },
      selectedId: _mkPlayer.state.track.subtitle.id,
      onSelect: (t) => _mkPlayer.setSubtitleTrack(t),
    );
  }

  void _showAudioPicker() {
    if (_usingExo) {
      _showToast('Audio tracks not available with this player');
      return;
    }
    final tracks = _mkPlayer.state.tracks.audio;
    if (tracks.length <= 1) {
      _showToast('Only one audio track available');
      return;
    }
    _showTrackDialog<mk.AudioTrack>(
      title: 'Audio',
      items: tracks,
      labelOf: (t) {
        final lang  = t.language ?? '';
        final title = t.title ?? '';
        if (lang.isNotEmpty && title.isNotEmpty) return '$lang — $title';
        return lang.isNotEmpty ? lang : (title.isNotEmpty ? title : 'Track ${t.id}');
      },
      selectedId: _mkPlayer.state.track.audio.id,
      onSelect: (t) => _mkPlayer.setAudioTrack(t),
    );
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
                        final id = (t is mk.SubtitleTrack) ? t.id : (t as mk.AudioTrack).id;
                        final isSel = id == selectedId;
                        return FocusableWidget(
                          autofocus: isSel,
                          borderRadius: 8,
                          onTap: () {
                            onSelect(t);
                            Navigator.of(ctx).pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Row(
                              children: [
                                if (isSel)
                                  const Icon(Icons.check, color: Colors.white, size: 14)
                                else
                                  const SizedBox(width: 14),
                                const SizedBox(width: 8),
                                Expanded(child: Text(labelOf(t),
                                  style: const TextStyle(color: Colors.white, fontSize: 14))),
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

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
      backgroundColor: const Color(0xFF1A1A1A),
    ));
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(AppDurations.controlsAutoHide, () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _showControlsTemporarily() {
    final wasHidden = !_showControls;
    setState(() => _showControls = true);
    _startHideTimer();
    if (wasHidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showControls) _playPauseFocusNode.requestFocus();
      });
    }
  }

  void _togglePlay() {
    if (_usingExo) {
      final ctrl = _exoController;
      if (ctrl == null) return;
      ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
    } else {
      _playerNotifier.togglePlay();
    }
    _showControlsTemporarily();
  }

  void _previousChannel() {
    final list  = ref.read(currentChannelListProvider);
    final index = ref.read(currentChannelIndexProvider);
    if (list.isEmpty || index <= 0 || index >= list.length) return;
    final newIndex = index - 1;
    final channel  = list[newIndex];
    ref.read(currentChannelIndexProvider.notifier).state = newIndex;
    ref.read(selectedChannelProvider.notifier).state     = channel;
    _playUrl(channel.streamUrl);
    _fetchEpg(channel);
    _showControlsTemporarily();
  }

  void _nextChannel() {
    final list  = ref.read(currentChannelListProvider);
    final index = ref.read(currentChannelIndexProvider);
    if (list.isEmpty || index >= list.length - 1) return;
    final newIndex = index + 1;
    final channel  = list[newIndex];
    ref.read(currentChannelIndexProvider.notifier).state = newIndex;
    ref.read(selectedChannelProvider.notifier).state     = channel;
    _playUrl(channel.streamUrl);
    _fetchEpg(channel);
    _showControlsTemporarily();
  }

  void _seek(Duration offset) {
    if (_usingExo) {
      final ctrl = _exoController;
      if (ctrl == null) return;
      final newPos = ctrl.value.position + offset;
      ctrl.seekTo(newPos.isNegative ? Duration.zero : newPos);
    } else {
      final pos = ref.read(playerProvider).position;
      _playerNotifier.seek(pos + offset);
    }
    _showControlsTemporarily();
  }

  @override
  Widget build(BuildContext context) {
    final ch = ref.watch(selectedChannelProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Focus(
        autofocus:  true,
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
          if (key == LogicalKeyboardKey.channelUp ||
              key == LogicalKeyboardKey.mediaTrackPrevious) {
            _previousChannel();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.channelDown ||
              key == LogicalKeyboardKey.mediaTrackNext) {
            _nextChannel();
            return KeyEventResult.handled;
          }

          // Controls visible — let D-pad navigate between buttons
          if (_showControls) {
            _startHideTimer();
            return KeyEventResult.ignored;
          }

          // Controls hidden — D-pad shortcuts
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter ||
              key == LogicalKeyboardKey.gameButtonA) {
            _togglePlay();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp) {
            _previousChannel();
            _showControlsTemporarily();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowDown) {
            _nextChannel();
            _showControlsTemporarily();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowLeft) {
            _seek(const Duration(seconds: -10));
            _showControlsTemporarily();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight) {
            _seek(const Duration(seconds: 10));
            _showControlsTemporarily();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.contextMenu) {
            _showControlsTemporarily();
            return KeyEventResult.handled;
          }
          // Any other key — show controls
          _showControlsTemporarily();
          return KeyEventResult.handled;
        },
        child: GestureDetector(
          onTap: _showControlsTemporarily,
          child: Stack(
            children: [
              // Video surface — ExoPlayer or media_kit
              if (_usingExo && _exoController != null)
                Center(
                  child: AspectRatio(
                    aspectRatio: _exoController!.value.aspectRatio > 0
                        ? _exoController!.value.aspectRatio
                        : 16 / 9,
                    child: VideoPlayer(_exoController!),
                  ),
                )
              else
                RepaintBoundary(
                  child: Video(
                    controller: _mkVideoController,
                    fit:        BoxFit.contain,
                    fill:       AppColors.background,
                    controls:   NoVideoControls,
                  ),
                ),
              // Controls overlay
              AnimatedOpacity(
                opacity:  _showControls ? 1.0 : 0.0,
                duration: AppDurations.fast,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: _ControlsOverlay(
                    channel:     ch,
                    usingExo:    _usingExo,
                    onPrev:      _previousChannel,
                    onNext:      _nextChannel,
                    onBack:      () => context.pop(),
                    onTogglePlay: _togglePlay,
                    onSubtitles: _showSubtitlePicker,
                    onAudio:     _showAudioPicker,
                    isPlaying:   _usingExo
                        ? (_exoController?.value.isPlaying ?? false)
                        : ref.watch(playerProvider.select((s) => s.isPlaying)),
                    epgNow:      _epgNow,
                    epgNext:     _epgNext,
                    playPauseFocusNode: _playPauseFocusNode,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({
    required this.channel,
    required this.usingExo,
    required this.onPrev,
    required this.onNext,
    required this.onBack,
    required this.onTogglePlay,
    required this.onSubtitles,
    required this.onAudio,
    required this.isPlaying,
    this.epgNow,
    this.epgNext,
    this.playPauseFocusNode,
  });
  final Channel?    channel;
  final bool        usingExo;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onTogglePlay;
  final VoidCallback onSubtitles;
  final VoidCallback onAudio;
  final bool         isPlaying;
  final String?      epgNow;
  final String?      epgNext;
  final FocusNode?   playPauseFocusNode;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      color: AppColors.playerOverlay,
      child: Stack(
        children: [
          // Top bar
          Positioned(
            top:  0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  FocusableWidget(
                    onTap: onBack,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 18),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  if (channel != null)
                    Expanded(
                      child: Text(
                        channel!.name,
                        style: const TextStyle(
                          color:      AppColors.textPrimary,
                          fontSize:   14,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const Spacer(),
                  if (usingExo)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('EXO', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w600)),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('MK', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                  Text(
                    timeStr,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          // EPG info
          if (epgNow != null)
            Positioned(
              bottom: 70,
              left:   AppSpacing.lg,
              right:  AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('NOW', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          epgNow!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w400),
                        ),
                      ),
                    ],
                  ),
                  if (epgNext != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text('NEXT', style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            epgNext!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w300),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          // Bottom controls
          Positioned(
            bottom: 0,
            left:   0,
            right:  0,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CtrlBtn(icon: Icons.subtitles_outlined, onTap: onSubtitles),
                  const SizedBox(width: AppSpacing.lg),
                  _CtrlBtn(icon: Icons.audiotrack_outlined, onTap: onAudio),
                  const SizedBox(width: AppSpacing.xl2),
                  _CtrlBtn(icon: Icons.skip_previous_outlined, onTap: onPrev),
                  const SizedBox(width: AppSpacing.xl2),
                  FocusableWidget(
                    focusNode: playPauseFocusNode,
                    onTap: onTogglePlay,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isPlaying ? Icons.pause_outlined : Icons.play_arrow_outlined,
                        color: AppColors.textPrimary,
                        size:  AppSpacing.iconLg,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xl2),
                  _CtrlBtn(icon: Icons.skip_next_outlined, onTap: onNext),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  const _CtrlBtn({required this.icon, required this.onTap});
  final IconData     icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: AppColors.textPrimary, size: AppSpacing.iconMd),
      ),
    );
  }
}
