import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../application/auth_controller.dart';
import 'admin_pin_dialog.dart';

/// Topbar admin unlock/logout control with a live session countdown
/// (parity with the admin button + timer in `topbar.js`).
///
/// - Sales role: shows a "Admin" lock button that opens the PIN modal.
/// - Admin role: shows "Admin: Logout (mm:ss)" and logs out on tap. The
///   countdown resyncs from the bridge when the local clock hits expiry, so it
///   reflects timeout resets from recent admin activity.
class AdminSessionButton extends ConsumerStatefulWidget {
  const AdminSessionButton({super.key});

  @override
  ConsumerState<AdminSessionButton> createState() => _AdminSessionButtonState();
}

class _AdminSessionButtonState extends ConsumerState<AdminSessionButton> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker(DateTime? expiresAt) {
    _ticker?.cancel();
    _ticker = null;
    if (expiresAt == null) {
      _remaining = Duration.zero;
      return;
    }
    _remaining = expiresAt.difference(DateTime.now());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = expiresAt.difference(DateTime.now());
      if (left <= Duration.zero) {
        _ticker?.cancel();
        _ticker = null;
        // Local clock says expired — let the bridge confirm (it may have
        // extended the session on recent activity, or dropped it).
        ref.read(authControllerProvider.notifier).refresh();
        return;
      }
      if (mounted) setState(() => _remaining = left);
    });
  }

  String _format(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _onTap(bool isAdmin) async {
    final controller = ref.read(authControllerProvider.notifier);
    if (isAdmin) {
      await controller.logout();
    } else {
      await AdminPinDialog.show(context, ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(authControllerProvider);
    final isElevated = status.isElevated;

    // Keep the countdown in sync with the authoritative expiry.
    ref.listen(
      authControllerProvider.select((s) => s.isElevated ? s.expiresAt : null),
      (_, next) => _syncTicker(next),
    );
    // Ensure the ticker is running on first build when already elevated.
    if (isElevated && _ticker == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _syncTicker(status.expiresAt),
      );
    }

    final label = isElevated
        ? 'Admin: Logout (${_format(_remaining)})'
        : 'Admin';

    return TextButton.icon(
      onPressed: () => _onTap(isElevated),
      icon: Icon(
        isElevated ? Icons.lock_open : Icons.lock_outline,
        size: 18,
        color: AppColors.neutral700,
      ),
      label: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.neutral700, fontWeight: FontWeight.w600),
      ),
    );
  }
}
