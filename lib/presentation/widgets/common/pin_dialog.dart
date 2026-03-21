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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
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
                    color:  filled ? AppColors.textPrimary : Colors.transparent,
                    border: Border.all(
                      color: _wrong ? AppColors.error : AppColors.textSecondary,
                      width: 1,
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

class _NumPad extends StatelessWidget {
  const _NumPad({required this.onDigit, required this.onDelete});
  final void Function(String) onDigit;
  final VoidCallback           onDelete;

  @override
  Widget build(BuildContext context) {
    // Layout: [1][2][3] / [4][5][6] / [7][8][9] / [←][0][  ]
    final rows = [
      ['1','2','3'],
      ['4','5','6'],
      ['7','8','9'],
      ['⌫','0',''],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((label) {
            if (label.isEmpty) return const SizedBox(width: 56, height: 48);
            final isDelete = label == '⌫';
            return _NumKey(
              label:    label,
              autofocus: label == '1',
              onTap: () => isDelete ? onDelete() : onDigit(label),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _NumKey extends StatefulWidget {
  const _NumKey({required this.label, required this.onTap, this.autofocus = false});
  final String       label;
  final VoidCallback onTap;
  final bool         autofocus;

  @override
  State<_NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<_NumKey> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
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
            color:        _focused ? AppColors.border : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border:       Border.all(
              color: _focused ? AppColors.textPrimary : AppColors.border,
              width: _focused ? 1 : 0.5,
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
