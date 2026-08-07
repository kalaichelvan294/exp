import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// Standard page layout wrapper following ux-guidelines.md:
/// Page Header → Description → Toolbar/Actions → Primary Content.
class ModuleScaffold extends StatelessWidget {
  const ModuleScaffold({
    super.key,
    required this.title,
    this.description,
    this.actions = const [],
    required this.child,
  });

  final String title;
  final String? description;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(title, style: theme.textTheme.headlineMedium),
              ),
              ...actions,
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.x8),
            Text(description!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.x24),
          Expanded(child: child),
        ],
      ),
    );
  }
}
