import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

enum EmptyStateType { channels, movies, series, favourites, search }

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.type,
    this.searchTerm,
  });
  final EmptyStateType type;
  final String?        searchTerm;

  @override
  Widget build(BuildContext context) {
    final cfg = _config(type, searchTerm);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EmptyIcon(type: type),
          const SizedBox(height: 20),
          Text(
            cfg.$1,
            style: GoogleFonts.dmSans(
              color:      AppColors.textPrimary,
              fontSize:   14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            cfg.$2,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color:    AppColors.textMuted,
              fontSize: 12,
              height:   1.5,
            ),
          ),
        ],
      ),
    );
  }

  static (String, String) _config(EmptyStateType t, String? q) {
    switch (t) {
      case EmptyStateType.channels:
        return ('No channels found', 'Try a different category');
      case EmptyStateType.movies:
        return ('No movies found', 'Try a different category or search term');
      case EmptyStateType.series:
        return ('No series found', 'Try a different category or search term');
      case EmptyStateType.favourites:
        return ('Nothing saved yet', 'Tap the heart on any channel or movie');
      case EmptyStateType.search:
        return ('No results for "${q ?? ''}"', 'Check your spelling or try something else');
    }
  }
}

class _EmptyIcon extends StatelessWidget {
  const _EmptyIcon({required this.type});
  final EmptyStateType type;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  56,
      height: 56,
      child:  CustomPaint(painter: _EmptyIconPainter(type: type)),
    );
  }
}

class _EmptyIconPainter extends CustomPainter {
  const _EmptyIconPainter({required this.type});
  final EmptyStateType type;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = const Color(0xFF3A3A3A)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    switch (type) {
      case EmptyStateType.channels:
        // TV frame
        final r = Rect.fromLTWH(4, 10, size.width - 8, size.height - 22);
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), paint);
        canvas.drawLine(Offset(cx - 8, size.height - 6), Offset(cx + 8, size.height - 6), paint);
        canvas.drawLine(Offset(cx, size.height - 12), Offset(cx, size.height - 6), paint);
        break;

      case EmptyStateType.movies:
      case EmptyStateType.series:
        // Film frame
        final fr = Rect.fromLTWH(6, 8, size.width - 12, size.height - 16);
        canvas.drawRRect(RRect.fromRectAndRadius(fr, const Radius.circular(3)), paint);
        // Sprocket holes
        for (int i = 0; i < 3; i++) {
          final y = 14.0 + i * 12;
          canvas.drawCircle(Offset(11, y), 2.5, paint);
          canvas.drawCircle(Offset(size.width - 11, y), 2.5, paint);
        }
        break;

      case EmptyStateType.favourites:
        // Heart outline
        final path = Path();
        path.moveTo(cx, cy + 12);
        path.cubicTo(cx - 20, cy + 2, cx - 20, cy - 12, cx, cy - 4);
        path.cubicTo(cx + 20, cy - 12, cx + 20, cy + 2, cx, cy + 12);
        canvas.drawPath(path, paint);
        break;

      case EmptyStateType.search:
        // Magnifier
        canvas.drawCircle(Offset(cx - 4, cy - 4), 14, paint);
        canvas.drawLine(
          Offset(cx - 4 + 14 * 0.707, cy - 4 + 14 * 0.707),
          Offset(cx + 12, cy + 12),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(_EmptyIconPainter old) => old.type != type;
}
