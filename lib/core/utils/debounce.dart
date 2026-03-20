import 'dart:async';

class Debounce {
  Debounce({required this.duration});
  final Duration duration;
  Timer? _timer;

  void call(void Function() fn) {
    _timer?.cancel();
    _timer = Timer(duration, fn);
  }

  void dispose() => _timer?.cancel();
}
