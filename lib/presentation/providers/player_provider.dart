import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

class PlayerState {
  const PlayerState({
    this.isPlaying    = false,
    this.isBuffering  = false,
    this.position     = Duration.zero,
    this.duration     = Duration.zero,
    this.currentIndex = 0,
    this.error,
  });
  final bool     isPlaying;
  final bool     isBuffering;
  final Duration position;
  final Duration duration;
  final int      currentIndex;
  final String?  error;
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  PlayerNotifier() : super(const PlayerState()) {
    _player = Player();
    _setupListeners();
  }

  late final Player _player;
  Player get player => _player;

  void _setupListeners() {
    _player.stream.playing.listen((v) {
      if (mounted) state = PlayerState(
        isPlaying:    v,
        isBuffering:  state.isBuffering,
        position:     state.position,
        duration:     state.duration,
        currentIndex: state.currentIndex,
      );
    });
    _player.stream.buffering.listen((v) {
      if (mounted) state = PlayerState(
        isPlaying:    state.isPlaying,
        isBuffering:  v,
        position:     state.position,
        duration:     state.duration,
        currentIndex: state.currentIndex,
      );
    });
    // Throttle position to 2x/sec — 10x/sec is unnecessary and burns CPU
    DateTime _lastPos = DateTime.fromMillisecondsSinceEpoch(0);
    _player.stream.position.listen((v) {
      final now = DateTime.now();
      if (!mounted || now.difference(_lastPos).inMilliseconds < 500) return;
      _lastPos = now;
      state = PlayerState(
        isPlaying:    state.isPlaying,
        isBuffering:  state.isBuffering,
        position:     v,
        duration:     state.duration,
        currentIndex: state.currentIndex,
      );
    });
    _player.stream.duration.listen((v) {
      if (mounted) state = PlayerState(
        isPlaying:    state.isPlaying,
        isBuffering:  state.isBuffering,
        position:     state.position,
        duration:     v,
        currentIndex: state.currentIndex,
      );
    });
  }

  Future<void> openUrl(String url) async {
    await _player.open(Media(url));
  }

  Future<void> togglePlay() async {
    await _player.playOrPause();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> stop() async {
    await _player.stop();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier();
});
