import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_tokens.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/admin_session_button.dart';
import '../features/settings/application/settings_controller.dart';
import 'app_routes.dart';

/// Persistent app shell: fixed top navigation bar + routed content area.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).uri.path;
    final isAdmin = ref.watch(
      authControllerProvider.select((s) => s.isElevated),
    );
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          _TopNav(currentPath: location, isAdmin: isAdmin),
          Container(height: 1, color: theme.dividerColor),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _TopNav extends StatelessWidget {
  const _TopNav({required this.currentPath, required this.isAdmin});

  final String currentPath;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Sales role sees only the non-admin modules; admin modules appear once the
    // session is elevated (parity with topbar.js role gating).
    final routes = [
      for (final route in AppRoutes.all)
        if (!route.adminOnly || isAdmin) route,
    ];

    return Container(
      height: AppSizing.navHeight,
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x20,
        vertical: AppSpacing.x4,
      ),
      child: Row(
        children: [
          // Left section: brand + navigation
          Expanded(
            child: Row(
              children: [
                // Shop identity
                SizedBox(
                  width: 180,
                  child: Center(
                    heightFactor: 1.0,
                    child: const _ShopIdentity(),
                  ),
                ),
                const SizedBox(width: AppSpacing.x8),
                // Navigation tabs
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < routes.length; i++) ...[
                          _NavTab(
                            route: routes[i],
                            active: currentPath.startsWith(routes[i].path),
                          ),
                          if (i < routes.length - 1)
                            const SizedBox(width: AppSpacing.x6),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x16),
          // Right section: admin + settings
          Row(
            children: [
              const AdminSessionButton(),
              const SizedBox(width: AppSpacing.x8),
              _SettingsButton(isAdmin: isAdmin, currentPath: currentPath),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShopIdentity extends ConsumerWidget {
  const _ShopIdentity();

  static const _storeNameMaxChars = 35;

  static String _trimStoreName(String value) {
    final normalized = value.trim();
    if (normalized.length <= _storeNameMaxChars) return normalized;
    return '${normalized.substring(0, _storeNameMaxChars)}...';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).settings;

    final storeName = _trimStoreName(settings.storeName);
    final businessType = settings.businessType;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          storeName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            fontSize: 13,
            height: 1.0,
          ),
        ),
        Text(
          businessType,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontWeight: FontWeight.w400,
            fontSize: 11,
            height: 1.0,
          ),
        ),
      ],
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
    final backgroundColor = active
        ? theme.colorScheme.primary
        : Colors.transparent;
    final foregroundColor = active
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    final borderColor = active ? theme.colorScheme.primary : theme.dividerColor;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        onTap: active ? null : () => context.go(route.path),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x16, // increased spacing
            vertical: AppSpacing.x6, // adds vertical breathing room
          ),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          alignment: Alignment.center, // ensures text is centered vertically
          child: Text(
            route.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.isAdmin, required this.currentPath});

  final bool isAdmin;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isActive = currentPath.startsWith('/settings');
    final backgroundColor = isActive
        ? theme.colorScheme.primary
        : Colors.transparent;
    final foregroundColor = isActive
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    final borderColor = isActive
        ? theme.colorScheme.primary
        : theme.dividerColor;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        onTap: isActive ? null : () => context.go('/settings'),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Icon(Icons.settings, size: 16, color: foregroundColor),
        ),
      ),
    );
  }
}
