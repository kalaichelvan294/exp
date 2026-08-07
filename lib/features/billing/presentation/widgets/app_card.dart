import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// Standard card container per ux-guidelines.md (white, neutral-200 border,
/// 12px radius, minimal shadow, 20px padding).
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.x20),
      decoration: BoxDecoration(
        color: AppColors.neutral0,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.neutral200),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}
