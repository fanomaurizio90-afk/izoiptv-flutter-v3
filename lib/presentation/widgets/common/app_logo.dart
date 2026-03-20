import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/theme/app_theme.dart';

/// IZO IPTV hexagon logo — white monochrome, any size
class IzoLogo extends StatelessWidget {
  const IzoLogo({super.key, this.size = 72});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  size,
      height: size,
      child:  CustomPaint(painter: _IzoLogoPainter()),
    );
  }
}

class _IzoLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = size.width  / 2;

    // ── Hexagon outline ─────────────────────────────────────────────────────
    final hexPaint = Paint()
      ..color       = AppColors.textPrimary
      ..style       = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeJoin  = StrokeJoin.miter;

    final hexPath = Path();
    for (int i = 0; i < 6; i++) {
      final angle = math.pi / 180 * (60 * i - 30);
      final x     = cx + r * 0.88 * math.cos(angle);
      final y     = cy + r * 0.88 * math.sin(angle);
      if (i == 0) {
        hexPath.moveTo(x, y);
      } else {
        hexPath.lineTo(x, y);
      }
    }
    hexPath.close();
    canvas.drawPath(hexPath, hexPaint);

    // ── IZO lettering ────────────────────────────────────────────────────────
    final textPaint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.fill;

    final fontSize   = size.width * 0.28;
    final letterSpacing = size.width * 0.01;

    // I
    _drawLetter(canvas, textPaint, 'I', cx - fontSize * 0.85, cy, fontSize);
    // Z
    _drawLetter(canvas, textPaint, 'Z', cx - fontSize * 0.08 + letterSpacing, cy, fontSize);
    // O
    _drawLetter(canvas, textPaint, 'O', cx + fontSize * 0.72 + letterSpacing * 2, cy, fontSize);
  }

  void _drawLetter(
    Canvas canvas,
    Paint paint,
    String letter,
    double x,
    double y,
    double fontSize,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text:  letter,
        style: TextStyle(
          color:      AppColors.textPrimary,
          fontSize:   fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          height:     1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(_IzoLogoPainter old) => false;
}
