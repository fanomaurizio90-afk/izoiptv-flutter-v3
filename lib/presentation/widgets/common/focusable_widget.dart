import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

/// Universal D-pad + touch widget for Fire Stick & Android TV.
///
/// Handles every remote key that means "activate":
///   select, enter, numpadEnter, gameButtonA,
///   DPAD_CENTER (keycode 23), BUTTON_A (keycode 96).
///
/// Focus visual : 1px solid white border — no glow, no shadow.
/// Press visual : AnimatedScale to 0.97 on key/tap down.
/// Auto-scroll  : ensures focused element is visible in nearest Scrollable.
/// Long-press   : contextMenu key fires onLongPress (TV menu button).
///
/// NEVER use InkWell or GestureDetector alone — always FocusableWidget.
class FocusableWidget extends StatefulWidget {
  const FocusableWidget({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.focusNode,
    this.autofocus    = false,
    this.borderRadius = 0.0,
    this.enabled      = true,
  });

  final Widget        child;
  final VoidCallback  onTap;
  final VoidCallback? onLongPress;
  final FocusNode?    focusNode;
  final bool          autofocus;
  final double        borderRadius;
  final bool          enabled;

  @override
  State<FocusableWidget> createState() => _FocusableWidgetState();
}

class _FocusableWidgetState extends State<FocusableWidget> {
  late FocusNode _ownNode;
  FocusNode get _node => widget.focusNode ?? _ownNode;

  bool _focused = false;
  bool _pressed = false;

  // ── Activate key detection ────────────────────────────────────────────────

  static bool _isActivateKey(KeyEvent event) {
    final lk = event.logicalKey;
    // Logical keys: select, enter, numpadEnter, gameButtonA
    if (lk == LogicalKeyboardKey.select)       return true;
    if (lk == LogicalKeyboardKey.enter)        return true;
    if (lk == LogicalKeyboardKey.numpadEnter)  return true;
    if (lk == LogicalKeyboardKey.gameButtonA)  return true;

    // Physical key fallbacks for manufacturer-specific mappings
    final pk = event.physicalKey;
    // DPAD_CENTER (Android keycode 23) — USB HID select
    if (pk == PhysicalKeyboardKey.select)      return true;
    // BUTTON_A (Android keycode 96) — USB HID gameButtonA
    if (pk == PhysicalKeyboardKey.gameButtonA) return true;
    // Raw numpad-enter (USB HID 0x00070058) — some Android TV boxes
    if (pk.usbHidUsage == 0x00070058)          return true;

    return false;
  }

  static bool _isLongPressKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.contextMenu;
  }

  // ── Auto-scroll ───────────────────────────────────────────────────────────

  void _ensureVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = context;
      final scrollable = Scrollable.maybeOf(ctx);
      if (scrollable == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment:  0.5,
        duration:   AppDurations.medium,
        curve:      Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ownNode = FocusNode();
  }

  @override
  void dispose() {
    // Only dispose if we created it
    if (widget.focusNode == null) _ownNode.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode:  _node,
      autofocus:  widget.autofocus,
      onFocusChange: (focused) {
        if (!mounted) return;
        setState(() => _focused = focused);
        if (focused) _ensureVisible();
      },
      onKeyEvent: (node, event) {
        if (!widget.enabled) return KeyEventResult.ignored;

        // Activate on key down
        if (event is KeyDownEvent && _isActivateKey(event)) {
          setState(() => _pressed = true);
          widget.onTap();
          return KeyEventResult.handled;
        }
        // Release press visual on key up
        if (event is KeyUpEvent && _isActivateKey(event)) {
          if (mounted) setState(() => _pressed = false);
          return KeyEventResult.handled;
        }

        // Long-press via menu/context-menu key
        if (event is KeyDownEvent && _isLongPressKey(event)) {
          widget.onLongPress?.call();
          return widget.onLongPress != null
              ? KeyEventResult.handled
              : KeyEventResult.ignored;
        }

        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap:       widget.enabled ? widget.onTap : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        onTapDown:   widget.enabled ? (_) { if (mounted) setState(() => _pressed = true); }  : null,
        onTapUp:     widget.enabled ? (_) { if (mounted) setState(() => _pressed = false); } : null,
        onTapCancel: widget.enabled ? ()  { if (mounted) setState(() => _pressed = false); } : null,
        child: AnimatedScale(
          scale:    _pressed ? 0.97 : 1.0,
          duration: AppDurations.press,
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
