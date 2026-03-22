import 'package:flutter/material.dart';

/// IZO IPTV logo — bold wordmark with cyan underline accent
class IzoLogo extends StatelessWidget {
  const IzoLogo({super.key, this.size = 72});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.6,
      height: size,
      child: CustomPaint(painter: _IzoLogoPainter(size: size)),
    );
  }
}

class _IzoLogoPainter extends CustomPainter {
  const _IzoLogoPainter({required this.size});
  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final w = canvasSize.width;
    final h = canvasSize.height;

    // ── "IZO" text ────────────────────────────────────────────────────────────
    final fontSize = h * 0.72;
    final tp = TextPainter(
      text: TextSpan(
        text: 'IZO',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: fontSize * 0.04,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textX = (w - tp.width) / 2;
    final textY = (h - tp.height) / 2 - h * 0.04;
    tp.paint(canvas, Offset(textX, textY));

    // ── Cyan underline ────────────────────────────────────────────────────────
    const accent = Color(0xFF00C8F0);
    final lineW = tp.width * 0.5;
    final lineH = h * 0.055;
    final lineY = textY + tp.height + h * 0.06;
    final lineX = (w - lineW) / 2;

    final paint = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(lineX, lineY, lineW, lineH),
        Radius.circular(lineH / 2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_IzoLogoPainter old) => old.size != size;
}
