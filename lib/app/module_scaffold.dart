import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// Standard page layout wrapper following ux-guidelines.md:
/// Primary Content only (no header/footer/description rendering).
/// Navigation and status are handled by app shell.
class ModuleScaffold extends StatelessWidget {
  const ModuleScaffold({
    super.key,
    required this.child,
    // Deprecated parameters kept for compatibility but unused
    String? title,
    String? description,
    List<Widget>? actions,
    String? footer,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.pagePadding,
      child: child,
    );
  }
}
