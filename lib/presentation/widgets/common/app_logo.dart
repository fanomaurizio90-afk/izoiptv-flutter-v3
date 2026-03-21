import 'package:flutter/material.dart';
import 'dart:math' as math;

/// IZO IPTV hexagon logo — cyan gradient, any size
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

    // ── Hexagon outline — cyan gradient ─────────────────────────────────────
    final hexPath = _hexPath(cx, cy, r * 0.88);
    final hexPaint = Paint()
      ..shader = LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: const [Color(0xFF00F0FF), Color(0xFFA855F7)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style       = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05
      ..strokeJoin  = StrokeJoin.miter;
    canvas.drawPath(hexPath, hexPaint);

    // ── Corner accent dots ───────────────────────────────────────────────────
    final dotPaint = Paint()
      ..color = const Color(0xFF00F0FF)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 6; i++) {
      final angle = math.pi / 180 * (60 * i - 30);
      final x = cx + r * 0.88 * math.cos(angle);
      final y = cy + r * 0.88 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), size.width * 0.03, dotPaint);
    }

    // ── IZO lettering ────────────────────────────────────────────────────────
    final fontSize = size.width * 0.28;
    final offset   = size.width * 0.01;

    _drawLetter(canvas, 'I', cx - fontSize * 0.85,             cy, fontSize);
    _drawLetter(canvas, 'Z', cx - fontSize * 0.08 + offset,    cy, fontSize);
    _drawLetter(canvas, 'O', cx + fontSize * 0.72 + offset * 2, cy, fontSize);
  }

  Path _hexPath(double cx, double cy, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = math.pi / 180 * (60 * i - 30);
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    return path..close();
  }

  void _drawLetter(Canvas canvas, String letter, double x, double y, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text:  letter,
        style: TextStyle(
          color:      const Color(0xFF00F0FF),
          fontSize:   fontSize,
          fontWeight: FontWeight.w700,
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
