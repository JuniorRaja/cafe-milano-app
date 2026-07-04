import 'package:flutter/material.dart';
import '../app.dart';

/// Sparse, low-opacity decorative pattern painted behind screen content.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AppBackgroundPainter(),
      size: Size.infinite,
    );
  }
}

class _AppBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint = Paint()..color = kBrandGold.withAlpha(12);
    final brownPaint = Paint()..color = kBrandBrown.withAlpha(9);

    const step = 120.0;
    for (double y = 0; y < size.height + step; y += step) {
      for (double x = 0; x < size.width + step; x += step) {
        final offsetRow = (y / step).round().isOdd ? step / 2 : 0.0;
        final cx = x + offsetRow;
        canvas.drawCircle(Offset(cx, y), 28, goldPaint);
        canvas.drawCircle(Offset(cx + step / 2, y + step / 2), 14, brownPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AppBackgroundPainter oldDelegate) => false;
}
