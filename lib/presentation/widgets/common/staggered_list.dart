import 'package:flutter/material.dart';

/// Animates [children] in with a stagger effect — each child fades in and
/// slides up 8px, 50ms apart, 150ms per element, Curves.easeOut.
///
/// Pass [triggerKey] to re-trigger the animation (e.g. on season switch).
/// Uses [Column] layout by default.
class StaggeredList extends StatefulWidget {
  const StaggeredList({
    super.key,
    required this.children,
    this.triggerKey,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.itemDuration  = const Duration(milliseconds: 150),
    this.slideOffset   = 8.0,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize       = MainAxisSize.min,
  });

  final List<Widget>        children;
  final Object?             triggerKey;
  final Duration            staggerDelay;
  final Duration            itemDuration;
  final double              slideOffset;
  final CrossAxisAlignment  crossAxisAlignment;
  final MainAxisSize        mainAxisSize;

  @override
  State<StaggeredList> createState() => _StaggeredListState();
}

class _StaggeredListState extends State<StaggeredList>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Object? _lastTrigger;

  @override
  void initState() {
    super.initState();
    _lastTrigger = widget.triggerKey;
    _initController();
  }

  void _initController() {
    final totalMs = widget.staggerDelay.inMilliseconds * widget.children.length +
                    widget.itemDuration.inMilliseconds;
    _ctrl = AnimationController(
      vsync:    this,
      duration: Duration(milliseconds: totalMs.clamp(150, 3000)),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(StaggeredList old) {
    super.didUpdateWidget(old);
    if (widget.triggerKey != _lastTrigger ||
        widget.children.length != old.children.length) {
      _lastTrigger = widget.triggerKey;
      _ctrl.dispose();
      _initController();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.children.length;
    if (count == 0) return const SizedBox.shrink();

    final totalMs = _ctrl.duration!.inMilliseconds;

    return Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      mainAxisSize:       widget.mainAxisSize,
      children: List.generate(count, (i) {
        final startMs = widget.staggerDelay.inMilliseconds * i;
        final endMs   = startMs + widget.itemDuration.inMilliseconds;
        final begin   = (startMs / totalMs).clamp(0.0, 1.0);
        final end     = (endMs   / totalMs).clamp(0.0, 1.0);

        final curved = CurvedAnimation(
          parent: _ctrl,
          curve:  Interval(begin, end, curve: Curves.easeOut),
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, widget.slideOffset / 100),
              end:   Offset.zero,
            ).animate(curved),
            child: widget.children[i],
          ),
        );
      }),
    );
  }
}
