import 'package:flutter/material.dart';

/// IZO IPTV logo — refined wordmark with warm gold accent bar
class IzoLogo extends StatelessWidget {
  const IzoLogo({super.key, this.size = 72});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.5,
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

    // ── "IZO" wordmark ────────────────────────────────────────────────────────
    final fontSize = h * 0.68;
    final tp = TextPainter(
      text: TextSpan(
        text: 'IZO',
        style: TextStyle(
          color:       const Color(0xFFF0F0F4),
          fontSize:    fontSize,
          fontWeight:  FontWeight.w500,
          letterSpacing: fontSize * 0.06,
          height:      1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textX = 0.0;
    final textY = (h - tp.height) / 2 - h * 0.06;
    tp.paint(canvas, Offset(textX, textY));

    // ── Gold accent bar — sits below the text ─────────────────────────────────
    const gold = Color(0xFFC8A058);
    final barW  = tp.width * 0.38;
    final barH  = h * 0.045;
    final barY  = textY + tp.height + h * 0.07;
    const barX  = 0.0;

    final paint = Paint()
      ..color = gold
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barW, barH),
        Radius.circular(barH / 2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_IzoLogoPainter old) => old.size != size;
}
