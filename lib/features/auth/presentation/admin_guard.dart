import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../application/auth_controller.dart';
import 'admin_pin_dialog.dart';

/// Guards admin-only routes (parity with `admin-guard.js`).
///
/// When the session is elevated the wrapped [child] is shown; otherwise a lock
/// panel offers to unlock (PIN) or return to the Sales Desk. Authorization is
/// enforced by the bridge — this only keeps admin UI from being used without
/// elevation, and it reacts to session drops (logout/timeout) automatically.
class AdminGuard extends ConsumerWidget {
  const AdminGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elevated = ref.watch(
      authControllerProvider.select((s) => s.isElevated),
    );
    if (elevated) return child;
    return const _AdminLockPanel();
  }
}

class _AdminLockPanel extends ConsumerWidget {
  const _AdminLockPanel();

  Future<void> _unlock(BuildContext context, WidgetRef ref) async {
    await AdminPinDialog.show(context, ref);
    // On success the guard rebuilds via the watched auth state; nothing else
    // to do here.
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      color: AppColors.neutral50,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined,
                size: 46, color: AppColors.neutral500),
            const SizedBox(height: AppSpacing.x16),
            Text('Admin access required',
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.x8),
            Text(
              'This page is available to the shop admin only.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.neutral500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: () => _unlock(context, ref),
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: const Text('Unlock'),
                ),
                const SizedBox(width: AppSpacing.x8),
                OutlinedButton(
                  onPressed: () => context.go(AppRoutes.billing.path),
                  child: const Text('Back to Sales Desk'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
