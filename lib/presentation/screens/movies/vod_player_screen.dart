import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/vod.dart';
import '../../providers/player_provider.dart';
import '../../providers/providers.dart';

class VodPlayerScreen extends ConsumerStatefulWidget {
  const VodPlayerScreen({super.key, required this.vod});
  final VodItem vod;

  @override
  ConsumerState<VodPlayerScreen> createState() => _VodPlayerScreenState();
}

class _VodPlayerScreenState extends ConsumerState<VodPlayerScreen> {
  late VideoController _videoController;
  bool   _showControls = true;
  Timer? _hideTimer;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _videoController = VideoController(ref.read(playerProvider.notifier).player);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPlayback());
    _startHideTimer();
    _startSaveTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _savePosition();
    ref.read(playerProvider.notifier).stop();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _startPlayback() async {
    final repo = ref.read(historyRepositoryProvider);
    final hist = await repo.getPosition(widget.vod.id, 'vod');
    final startPos = hist != null ? Duration(seconds: hist['position_secs'] as int) : Duration.zero;

    await ref.read(playerProvider.notifier).openUrl(widget.vod.streamUrl);
    if (startPos > Duration.zero) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) ref.read(playerProvider.notifier).seek(startPos);
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(AppDurations.controlsAutoHide, () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _showControlsTemporarily() {
    setState(() => _showControls = true);
    _startHideTimer();
  }

  void _startSaveTimer() {
    _saveTimer = Timer.periodic(AppDurations.historyFlushPeriod, (_) => _savePosition());
  }

  Future<void> _savePosition() async {
    final pos = ref.read(playerProvider).position.inSeconds;
    final dur = ref.read(playerProvider).duration.inSeconds;
    if (pos <= 0) return;
    try {
      await ref.read(historyRepositoryProvider).savePosition(
        contentId:   widget.vod.id,
        contentType: 'vod',
        contentName: widget.vod.name,
        positionSecs: pos,
        durationSecs: dur,
        thumbnailUrl: widget.vod.posterUrl,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Focus(
        autofocus:  true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            ref.read(playerProvider.notifier).togglePlay();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: _showControlsTemporarily,
          child: Stack(
            children: [
              Video(
                controller: _videoController,
                fit:        BoxFit.contain,
                fill:       AppColors.background,
                controls:   NoVideoControls,
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
                          top: MediaQuery.of(context).padding.top,
                          left: 0,
                          right: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 18),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    widget.vod.name,
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w400),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Bottom seek bar + controls
                        Positioned(
                          bottom: 0,
                          left:   0,
                          right:  0,
                          child:  _VodControls(playerState: playerState),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VodControls extends ConsumerWidget {
  const _VodControls({required this.playerState});
  final PlayerState playerState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              trackHeight:         1.0,
              thumbShape:          const RoundSliderThumbShape(enabledThumbRadius: 4),
              activeTrackColor:    AppColors.textPrimary,
              inactiveTrackColor:  AppColors.accentSoft,
              thumbColor:          AppColors.textPrimary,
              overlayShape:        SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: progress.toDouble(),
              onChanged: (v) {
                final seekTo = Duration(milliseconds: (v * dur.inMilliseconds).round());
                ref.read(playerProvider.notifier).seek(seekTo);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(pos),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
              GestureDetector(
                onTap: () => ref.read(playerProvider.notifier).togglePlay(),
                child: Icon(
                  playerState.isPlaying ? Icons.pause_outlined : Icons.play_arrow_outlined,
                  color: AppColors.textPrimary,
                  size:  AppSpacing.iconMd,
                ),
              ),
              Text(
                _fmt(dur),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
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
