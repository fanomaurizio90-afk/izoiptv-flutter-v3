import 'package:flutter/material.dart';

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
    final h = canvasSize.height;

    final fontSize = h * 0.62;
    final tp = TextPainter(
      text: TextSpan(
        text: 'IZO',
        style: TextStyle(
          color:         const Color(0xFFECECF4),
          fontSize:      fontSize,
          fontWeight:    FontWeight.w500,
          letterSpacing: fontSize * 0.08,
          height:        1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textY = (h - tp.height) / 2 - h * 0.06;
    tp.paint(canvas, Offset(0, textY));

    const amber = Color(0xFFD4A76A);
    final barW = tp.width * 0.32;
    final barH = h * 0.035;
    final barY = textY + tp.height + h * 0.08;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, barY, barW, barH),
        Radius.circular(barH / 2),
      ),
      Paint()
        ..color = amber
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_IzoLogoPainter old) => old.size != size;
}
