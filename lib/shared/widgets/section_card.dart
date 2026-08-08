import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'app_card.dart';
import 'app_buttons.dart';

/// Reusable titled card wrapper for sectioned forms and content blocks.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.child,
    this.children = const [],
    this.onSave,
    this.onReset,
    this.childrenAlignment = CrossAxisAlignment.start,
    this.fullWidthChildren = false,
    this.showActions = true,
  });

  final String title;
  final Widget? child;
  final List<Widget> children;
  final VoidCallback? onSave;
  final VoidCallback? onReset;
  final CrossAxisAlignment childrenAlignment;
  final bool fullWidthChildren;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasChildren = child != null || children.isNotEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.x16),
          if (hasChildren)
            if (child != null)
              child!
            else if (fullWidthChildren)
              Column(crossAxisAlignment: childrenAlignment, children: children)
            else
              Wrap(
                spacing: AppSpacing.x16,
                runSpacing: AppSpacing.x16,
                children: children,
              ),
          if (showActions && onSave != null && onReset != null) ...[
            const SizedBox(height: AppSpacing.x16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppTextButton(
                  label: 'Reset',
                  outlined: true,
                  onPressed: onReset,
                ),
                const SizedBox(width: AppSpacing.x8),
                AppTextButton(label: 'Save', onPressed: onSave),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
