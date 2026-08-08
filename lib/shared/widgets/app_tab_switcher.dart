import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

class AppTabOption<T> {
  const AppTabOption({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

class AppTabSwitcher<T> extends StatelessWidget {
  const AppTabSwitcher({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.alignment = Alignment.centerLeft,
  });

  final List<AppTabOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SegmentedButton<T>(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.neutral0;
            return AppColors.neutral700;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primary500;
            return AppColors.neutral0;
          }),
        ),
        segments: options
            .map(
              (option) => ButtonSegment<T>(
                value: option.value,
                label: Text(option.label),
                icon: option.icon == null ? null : Icon(option.icon, size: 18),
              ),
            )
            .toList(),
        selected: {selected},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}
