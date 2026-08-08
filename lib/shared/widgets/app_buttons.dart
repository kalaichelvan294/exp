import 'package:flutter/material.dart';

class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(onPressed: onPressed, child: Text(label));
    }
    return FilledButton(onPressed: onPressed, child: Text(label));
  }
}

class AppTextIconButton extends StatelessWidget {
  const AppTextIconButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(label),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
    );
  }
}

class AppIconOnlyButton extends StatelessWidget {
  const AppIconOnlyButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: icon,
    );
  }
}
