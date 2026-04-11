import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class FocusableWidget extends StatefulWidget {
  const FocusableWidget({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.focusNode,
    this.autofocus       = false,
    this.borderRadius    = 0.0,
    this.enabled         = true,
    this.showFocusBorder = true,
  });

  final Widget        child;
  final VoidCallback  onTap;
  final VoidCallback? onLongPress;
  final FocusNode?    focusNode;
  final bool          autofocus;
  final double        borderRadius;
  final bool          enabled;
  final bool          showFocusBorder;

  @override
  State<FocusableWidget> createState() => _FocusableWidgetState();
}

class _FocusableWidgetState extends State<FocusableWidget> {
  late FocusNode _ownNode;
  FocusNode get _node => widget.focusNode ?? _ownNode;

  bool   _focused          = false;
  bool   _pressed          = false;
  Timer? _longPressTimer;
  bool   _longPressFired   = false;

  static bool _isActivateKey(KeyEvent event) {
    final lk = event.logicalKey;
    if (lk == LogicalKeyboardKey.select)       return true;
    if (lk == LogicalKeyboardKey.enter)        return true;
    if (lk == LogicalKeyboardKey.numpadEnter)  return true;
    if (lk == LogicalKeyboardKey.gameButtonA)  return true;

    final pk = event.physicalKey;
    if (pk == PhysicalKeyboardKey.select)      return true;
    if (pk == PhysicalKeyboardKey.gameButtonA) return true;
    if (pk.usbHidUsage == 0x00070058)          return true;

    return false;
  }

  static bool _isLongPressKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.contextMenu;
  }

  void _ensureVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = context;
      final scrollable = Scrollable.maybeOf(ctx);
      if (scrollable == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment:       0.5,
        duration:        AppDurations.medium,
        curve:           AppCurves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _ownNode = FocusNode();
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    if (widget.focusNode == null) _ownNode.dispose();
    super.dispose();
  }

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

        if (event is KeyDownEvent && _isActivateKey(event)) {
          if (mounted) setState(() => _pressed = true);
          if (widget.onLongPress != null) {
            _longPressFired = false;
            _longPressTimer?.cancel();
            _longPressTimer = Timer(const Duration(milliseconds: 500), () {
              _longPressTimer = null;
              _longPressFired = true;
              widget.onLongPress!();
              if (mounted) setState(() => _pressed = false);
            });
          } else {
            widget.onTap();
          }
          return KeyEventResult.handled;
        }
        if (event is KeyUpEvent && _isActivateKey(event)) {
          _longPressTimer?.cancel();
          _longPressTimer = null;
          if (mounted) setState(() => _pressed = false);
          if (widget.onLongPress != null && !_longPressFired) {
            widget.onTap();
          }
          _longPressFired = false;
          return KeyEventResult.handled;
        }

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
          scale: _pressed
              ? 0.96
              : (_focused && widget.showFocusBorder ? 1.02 : 1.0),
          duration: AppDurations.press,
          curve:    AppCurves.easeOut,
          child: AnimatedContainer(
            duration: AppDurations.focus,
            curve:    AppCurves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: _focused && widget.showFocusBorder
                    ? AppColors.focusBorder
                    : widget.showFocusBorder
                        ? AppColors.glassBorder
                        : Colors.transparent,
                width: AppSpacing.focusBorderWidth,
              ),
              boxShadow: _focused && widget.showFocusBorder
                  ? [
                      BoxShadow(
                        color:        AppColors.focusGlow,
                        blurRadius:   20,
                        spreadRadius: -2,
                      ),
                      BoxShadow(
                        color:        AppColors.focusGlow.withValues(alpha: 0.12),
                        blurRadius:   48,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
