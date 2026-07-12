import 'package:flutter/material.dart';
import '../../app.dart';

class CategorySparkline extends StatelessWidget {
  const CategorySparkline({
    super.key,
    required this.data,
    this.width = 100,
    this.height = 32,
    this.color,
  });

  final List<int> data;
  final double width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _SparklinePainter(
        data: data,
        lineColor: color ?? kBrandGold,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.data, required this.lineColor});

  final List<int> data;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || data.every((v) => v == 0)) {
      // Draw a flat line in the middle
      final paint = Paint()
        ..color = Colors.grey.shade300
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }

    final maxVal = data.reduce((a, b) => a > b ? a : b).toDouble();
    final minVal = data.reduce((a, b) => a < b ? a : b).toDouble();
    final range = maxVal - minVal;
    final effectiveRange = range == 0 ? 1.0 : range;

    final stepX = size.width / (data.length - 1);
    const padding = 2.0;
    final usableHeight = size.height - padding * 2;

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalised = (data[i] - minVal) / effectiveRange;
      final y = padding + usableHeight * (1 - normalised);
      points.add(Offset(x, y));
    }

    // Draw fill gradient
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withValues(alpha: 0.3), lineColor.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Draw end dot
    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(points.last, 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.lineColor != lineColor;
  }
}
