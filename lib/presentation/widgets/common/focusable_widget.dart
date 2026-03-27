import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

/// Handles D-pad focus (TV remote), touch, and focus effects.
/// Focus: 1px white border only — no glow, no fill, no animation.
class FocusableWidget extends StatefulWidget {
  const FocusableWidget({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius  = 0.0,
    this.autofocus     = false,
    this.scaleOnFocus  = false,
    this.onLongPress,
    this.focusNode,
  });

  final Widget        child;
  final VoidCallback  onTap;
  final double        borderRadius;
  final bool          autofocus;
  final bool          scaleOnFocus;
  final VoidCallback? onLongPress;
  final FocusNode?    focusNode;

  @override
  State<FocusableWidget> createState() => _FocusableWidgetState();
}

class _FocusableWidgetState extends State<FocusableWidget> {
  bool _focused = false;
  bool _pressed = false;

  static bool _isActivateKey(KeyEvent event) {
    // Handle all possible "OK/confirm" keys on Android TV remotes and game controllers
    if (event.logicalKey == LogicalKeyboardKey.select) return true;
    if (event.logicalKey == LogicalKeyboardKey.enter) return true;
    if (event.logicalKey == LogicalKeyboardKey.numpadEnter) return true;
    if (event.logicalKey == LogicalKeyboardKey.gameButtonA) return true;
    // Raw numpad enter (USB HID usage 0x00070058) — some Android TV boxes report this
    if (event.physicalKey.usbHidUsage == 0x00070058) return true;
    // Android KEYCODE_DPAD_CENTER (23) → already covered by LogicalKeyboardKey.select on most
    // Android KEYCODE_BUTTON_A (96) → already covered by LogicalKeyboardKey.gameButtonA on most
    // Extra physical key aliases to cover manufacturer-specific mappings
    if (event.physicalKey == PhysicalKeyboardKey.select) return true;
    if (event.physicalKey == PhysicalKeyboardKey.gameButtonA) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus:  widget.autofocus,
      focusNode:  widget.focusNode,
      onFocusChange: (focused) {
        if (mounted) setState(() => _focused = focused);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && _isActivateKey(event)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap:       widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown:   (_) { if (mounted) setState(() => _pressed = true); },
        onTapUp:     (_) { if (mounted) setState(() => _pressed = false); },
        onTapCancel: ()  { if (mounted) setState(() => _pressed = false); },
        child: AnimatedScale(
          scale:    (_focused && widget.scaleOnFocus) ? 1.05
                  : _pressed                         ? 0.97
                  : 1.0,
          duration: (_focused && widget.scaleOnFocus)
                  ? AppDurations.fast
                  : AppDurations.press,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: _focused
                  ? Border.all(color: AppColors.focusBorder, width: 1.0)
                  : Border.all(color: Colors.transparent, width: 1.0),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
