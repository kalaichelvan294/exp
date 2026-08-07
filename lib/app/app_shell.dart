import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_tokens.dart';
import 'app_routes.dart';

/// Persistent app shell: fixed top navigation bar + routed content area.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: Column(
        children: [
          _TopNav(currentPath: location),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _TopNav extends StatelessWidget {
  const _TopNav({required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizing.navHeight,
      color: AppColors.neutral0,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final route in AppRoutes.all)
              _NavTab(
                route: route,
                active: currentPath.startsWith(route.path),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({required this.route, required this.active});

  final AppRoute route;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = active ? AppColors.primary500 : Colors.transparent;
    final foreground = active ? AppColors.neutral0 : AppColors.neutral700;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.x4),
      child: Material(
        color: background,
        borderRadius: AppRadius.button,
        child: InkWell(
          borderRadius: AppRadius.button,
          onTap: active ? null : () => context.go(route.path),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16),
            child: Row(
              children: [
                Icon(route.icon, size: 18, color: foreground),
                const SizedBox(width: AppSpacing.x8),
                Text(
                  route.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
