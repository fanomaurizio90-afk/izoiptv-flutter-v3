import 'package:flutter/material.dart';

extension BuildContextX on BuildContext {
  double get screenWidth  => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  double get topPadding   => MediaQuery.of(this).padding.top;
  double get bottomPadding => MediaQuery.of(this).padding.bottom;
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
}

extension DurationX on Duration {
  String toHms() {
    final h = inHours;
    final m = inMinutes.remainder(60);
    final s = inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m}:${s.toString().padLeft(2, '0')}';
  }
}

