import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// A token-compliant radio control (18px) that avoids the deprecated Material
/// [Radio] groupValue/onChanged API. Selected fill uses primary-500.
class RadioDot<T> extends StatelessWidget {
  const RadioDot({
    super.key,
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: AppRadius.input,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CustomPaint(painter: _DotPainter(selected)),
            ),
            const SizedBox(width: AppSpacing.x8),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  const _DotPainter(this.selected);
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = selected ? AppColors.primary500 : AppColors.neutral400;
    canvas.drawCircle(center, size.width / 2 - 1, ring);
    if (selected) {
      final fill = Paint()..color = AppColors.primary500;
      canvas.drawCircle(center, size.width / 4, fill);
    }
  }

  @override
  bool shouldRepaint(_DotPainter oldDelegate) =>
      oldDelegate.selected != selected;
}
