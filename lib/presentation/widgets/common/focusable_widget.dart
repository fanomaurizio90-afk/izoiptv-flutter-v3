import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

/// Handles D-pad focus (TV remote), touch, and optional hover effects.
/// Use this for ALL interactive elements — never GestureDetector alone on TV.
class FocusableWidget extends StatefulWidget {
  const FocusableWidget({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius  = 0.0,
    this.autofocus     = false,
    this.scaleOnFocus  = false, // no scale per spec — 1px border only
    this.onLongPress,
    this.focusNode,
  });

  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  final bool autofocus;
  final bool scaleOnFocus;
  final VoidCallback? onLongPress;
  final FocusNode? focusNode;

  @override
  State<FocusableWidget> createState() => _FocusableWidgetState();
}

class _FocusableWidgetState extends State<FocusableWidget> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus:  widget.autofocus,
      focusNode:  widget.focusNode,
      onFocusChange: (focused) {
        if (mounted) setState(() => _focused = focused);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap:      widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: _focused
                ? Border.all(
                    color: AppColors.focusBorder,
                    width: AppSpacing.focusBorderWidth,
                  )
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
