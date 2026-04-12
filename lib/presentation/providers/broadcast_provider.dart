import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/broadcast_service.dart';
import 'providers.dart';

class BroadcastNotifier extends StateNotifier<Broadcast?> {
  BroadcastNotifier(this._ref) : super(null);

  final Ref _ref;
  Timer? _timer;

  static const _pollInterval = Duration(minutes: 2);

  void start() {
    _refresh();
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => _refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _refresh() async {
    final svc  = _ref.read(broadcastServiceProvider);
    final b    = await svc.fetchActive();
    if (b == null) { state = null; return; }
    final last = await svc.lastDismissedId();
    // Mandatory broadcasts always show — regardless of prior dismissal.
    if (!b.mandatory && last == b.id) { state = null; return; }
    state = b;
  }

  Future<void> dismiss() async {
    final b = state;
    if (b == null) return;
    if (b.mandatory) return; // cannot dismiss mandatory
    await _ref.read(broadcastServiceProvider).markDismissed(b.id);
    state = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final broadcastProvider = StateNotifierProvider<BroadcastNotifier, Broadcast?>((ref) {
  return BroadcastNotifier(ref);
});
