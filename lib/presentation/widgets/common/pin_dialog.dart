import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parental_control.dart';

/// Shows a D-pad-friendly PIN entry dialog.
/// Returns true if the correct PIN was entered, false if cancelled.
Future<bool> showPinDialog(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _PinDialog(),
  ) ?? false;
}

class _PinDialog extends StatefulWidget {
  const _PinDialog();

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  String _entered = '';
  bool   _wrong   = false;

  void _onDigit(String d) {
    if (_entered.length >= 4) return;
    setState(() {
      _wrong   = false;
      _entered = _entered + d;
    });
    if (_entered.length == 4) _submit();
  }

  void _onDelete() {
    if (_entered.isEmpty) return;
    setState(() {
      _wrong   = false;
      _entered = _entered.substring(0, _entered.length - 1);
    });
  }

  void _submit() {
    if (_entered == kParentalPin) {
      Navigator.of(context).pop(true);
    } else {
      setState(() { _wrong = true; _entered = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        side: BorderSide(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Parental Control',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Enter PIN to continue',
              style: TextStyle(
                color:    _wrong ? AppColors.error : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            // 4 PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _entered.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  width:  12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:  filled ? AppColors.accentPrimary : Colors.transparent,
                    border: Border.all(
                      color: _wrong ? AppColors.error : AppColors.glassBorder,
                      width: filled ? 1.5 : 1,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.xl),
            // Number pad — 3 columns, navigable with D-pad
            _NumPad(onDigit: _onDigit, onDelete: _onDelete),
          ],
        ),
      ),
    );
  }
}

class _NumPad extends StatefulWidget {
  const _NumPad({required this.onDigit, required this.onDelete});
  final void Function(String) onDigit;
  final VoidCallback           onDelete;

  @override
  State<_NumPad> createState() => _NumPadState();
}

class _NumPadState extends State<_NumPad> {
  // Grid: [1][2][3] / [4][5][6] / [7][8][9] / [⌫][0][  ]
  static const _grid = [
    ['1','2','3'],
    ['4','5','6'],
    ['7','8','9'],
    ['⌫','0',''],
  ];

  late final List<List<FocusNode?>> _nodes;
  int _row = 0, _col = 0;

  @override
  void initState() {
    super.initState();
    _nodes = List.generate(4, (r) =>
      List.generate(3, (c) => _grid[r][c].isEmpty ? null : FocusNode()),
    );
  }

  @override
  void dispose() {
    for (final row in _nodes) {
      for (final n in row) { n?.dispose(); }
    }
    super.dispose();
  }

  void _move(int dr, int dc) {
    var nr = _row + dr, nc = _col + dc;
    // Clamp within grid bounds
    nr = nr.clamp(0, 3);
    nc = nc.clamp(0, 2);
    // Skip empty cell (row 3, col 2)
    if (_grid[nr][nc].isEmpty) {
      if (dc > 0) return;      // can't move right into empty
      if (dr > 0) nc = 1;      // moving down into last row, go to '0'
    }
    _row = nr;
    _col = nc;
    _nodes[_row][_col]?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (r) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (c) {
            final label = _grid[r][c];
            if (label.isEmpty) return const SizedBox(width: 56, height: 48);
            final isDelete = label == '⌫';
            return _NumKey(
              label:     label,
              focusNode: _nodes[r][c]!,
              autofocus: r == 0 && c == 0,
              onTap: () => isDelete ? widget.onDelete() : widget.onDigit(label),
              onArrow: (dr, dc) { _move(dr, dc); },
            );
          }),
        );
      }),
    );
  }
}

class _NumKey extends StatefulWidget {
  const _NumKey({
    required this.label,
    required this.onTap,
    required this.focusNode,
    required this.onArrow,
    this.autofocus = false,
  });
  final String       label;
  final VoidCallback onTap;
  final FocusNode    focusNode;
  final void Function(int dr, int dc) onArrow;
  final bool         autofocus;

  @override
  State<_NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<_NumKey> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp)    { widget.onArrow(-1,  0); return KeyEventResult.handled; }
        if (key == LogicalKeyboardKey.arrowDown)  { widget.onArrow( 1,  0); return KeyEventResult.handled; }
        if (key == LogicalKeyboardKey.arrowLeft)  { widget.onArrow( 0, -1); return KeyEventResult.handled; }
        if (key == LogicalKeyboardKey.arrowRight) { widget.onArrow( 0,  1); return KeyEventResult.handled; }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width:  56,
          height: 48,
          margin: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color:        _focused ? AppColors.accentSoft : AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border:       Border.all(
              color: _focused ? AppColors.accentPrimary.withValues(alpha: 0.5) : AppColors.glassBorder,
              width: 0.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color:      _focused ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize:   16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
