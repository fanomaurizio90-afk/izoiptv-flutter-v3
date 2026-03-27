import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/channel.dart';
import '../../providers/channel_provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/player_provider.dart';

class LivePlayerScreen extends ConsumerStatefulWidget {
  const LivePlayerScreen({super.key});

  @override
  ConsumerState<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends ConsumerState<LivePlayerScreen> {
  late VideoController _videoController;
  late PlayerNotifier  _playerNotifier; // saved in initState — safe to use in dispose
  bool   _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _playerNotifier = ref.read(playerProvider.notifier);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _videoController = VideoController(
      _playerNotifier.player,
      configuration: const VideoControllerConfiguration(enableHardwareAcceleration: false),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _playCurrentChannel());
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _playerNotifier.stop(); // use saved reference — always safe
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]); // clear override — TV stays landscape
    super.dispose();
  }

  void _playCurrentChannel() {
    final ch = ref.read(selectedChannelProvider);
    if (ch != null) {
      ref.read(playerProvider.notifier).openUrl(ch.streamUrl);
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

  void _previousChannel() {
    // Snapshot list and index atomically — a sync could replace the list
    // between reads, making the index stale and out-of-bounds.
    final list  = ref.read(currentChannelListProvider);
    final index = ref.read(currentChannelIndexProvider);
    if (list.isEmpty || index <= 0 || index >= list.length) return;
    final newIndex = index - 1;
    final channel  = list[newIndex];
    ref.read(currentChannelIndexProvider.notifier).state = newIndex;
    ref.read(selectedChannelProvider.notifier).state     = channel;
    ref.read(playerProvider.notifier).openUrl(channel.streamUrl);
  }

  void _nextChannel() {
    final list  = ref.read(currentChannelListProvider);
    final index = ref.read(currentChannelIndexProvider);
    if (list.isEmpty || index >= list.length - 1) return;
    final newIndex = index + 1;
    final channel  = list[newIndex];
    ref.read(currentChannelIndexProvider.notifier).state = newIndex;
    ref.read(selectedChannelProvider.notifier).state     = channel;
    ref.read(playerProvider.notifier).openUrl(channel.streamUrl);
  }

  @override
  Widget build(BuildContext context) {
    final ch = ref.watch(selectedChannelProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) context.go('/live');
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Focus(
        autofocus:  true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          switch (event.logicalKey) {
            case LogicalKeyboardKey.arrowUp:
              _previousChannel();
              return KeyEventResult.handled;
            case LogicalKeyboardKey.arrowDown:
              _nextChannel();
              return KeyEventResult.handled;
            case LogicalKeyboardKey.select:
            case LogicalKeyboardKey.enter:
              ref.read(playerProvider.notifier).togglePlay();
              return KeyEventResult.handled;
            case LogicalKeyboardKey.escape:
            case LogicalKeyboardKey.arrowLeft:
            case LogicalKeyboardKey.numpadEnter:
              context.go('/live');
              return KeyEventResult.handled;
            case LogicalKeyboardKey.contextMenu:
              _showControlsTemporarily();
              return KeyEventResult.handled;
            default:
              return KeyEventResult.ignored;
          }
        },
        child: GestureDetector(
          onTap: _showControlsTemporarily,
          child: Stack(
            children: [
              // Video
              RepaintBoundary(
                child: Video(
                  controller: _videoController,
                  fit:        BoxFit.contain,
                  fill:       AppColors.background,
                  controls:   NoVideoControls,
                ),
              ),
              // Controls overlay — AnimatedOpacity lives outside the if-guard
              // so the fade-out animation actually plays when hiding
              AnimatedOpacity(
                opacity:  _showControls ? 1.0 : 0.0,
                duration: AppDurations.fast,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: _ControlsOverlay(
                    channel:   ch,
                    onPrev:    _previousChannel,
                    onNext:    _nextChannel,
                    onBack:    () => context.go('/live'),
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

class _ControlsOverlay extends ConsumerWidget {
  const _ControlsOverlay({
    required this.channel,
    required this.onPrev,
    required this.onNext,
    required this.onBack,
  });
  final Channel?  channel;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  Focus(
                    onKeyEvent: (_, event) {
                      if (event is KeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.select ||
                           event.logicalKey == LogicalKeyboardKey.enter ||
                           event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                           event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
                        onBack();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: GestureDetector(
                      onTap: onBack,
                      child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 18),
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
                  Text(
                    timeStr,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CtrlBtn(icon: Icons.skip_previous_outlined, onTap: onPrev),
                  const SizedBox(width: AppSpacing.xl2),
                  _PlayPauseBtn(),
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
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: AppColors.textPrimary, size: AppSpacing.iconMd),
    );
  }
}

class _PlayPauseBtn extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    return GestureDetector(
      onTap: () => ref.read(playerProvider.notifier).togglePlay(),
      child: Icon(
        isPlaying ? Icons.pause_outlined : Icons.play_arrow_outlined,
        color: AppColors.textPrimary,
        size:  AppSpacing.iconLg,
      ),
    );
  }
}
