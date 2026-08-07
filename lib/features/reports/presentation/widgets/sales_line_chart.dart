import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/analytics.dart';

/// A lightweight line chart for a sales series, ported from the SVG polyline in
/// reports.js `renderLineChart`. Draws an axis, a scaled polyline, dots, and a
/// meta row (first label · formatted last value · last label).
class SalesLineChart extends StatelessWidget {
  const SalesLineChart({
    super.key,
    required this.rows,
    required this.formatter,
    required this.emptyText,
    this.height = 200,
  });

  final List<SalesPoint> rows;
  final String Function(SalesPoint) formatter;
  final String emptyText;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rows.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(emptyText,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.neutral500)),
        ),
      );
    }
    final first = rows.first;
    final last = rows.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _LineChartPainter(
              rows: rows,
              lineColor: theme.colorScheme.primary,
              axisColor: AppColors.neutral200,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(first.label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.neutral500)),
            Flexible(
              child: Text(
                formatter(last),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(last.label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.neutral500)),
          ],
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.rows,
    required this.lineColor,
    required this.axisColor,
  });

  final List<SalesPoint> rows;
  final Color lineColor;
  final Color axisColor;

  @override
  void paint(Canvas canvas, Size size) {
    const paddingX = 24.0;
    const paddingY = 20.0;
    final graphWidth = size.width - (paddingX * 2);
    final graphHeight = size.height - (paddingY * 2);

    var maxValue = 0;
    for (final row in rows) {
      if (row.totalSalesPaise > maxValue) maxValue = row.totalSalesPaise;
    }
    final denominator = maxValue > 0 ? maxValue : 1;
    final stepX = rows.length > 1 ? graphWidth / (rows.length - 1) : 0.0;

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    final baseY = size.height - paddingY;
    canvas.drawLine(
      Offset(paddingX, baseY),
      Offset(size.width - paddingX, baseY),
      axisPaint,
    );

    final points = <Offset>[];
    for (var i = 0; i < rows.length; i++) {
      final value = rows[i].totalSalesPaise;
      final x = paddingX + (i * stepX);
      final y = paddingY + (graphHeight - ((value / denominator) * graphHeight));
      points.add(Offset(x, y));
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, linePaint);
    }

    final dotPaint = Paint()..color = lineColor;
    for (final p in points) {
      canvas.drawCircle(p, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) =>
      oldDelegate.rows != rows ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.axisColor != axisColor;
}
