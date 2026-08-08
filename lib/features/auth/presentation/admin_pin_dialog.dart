import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../application/auth_controller.dart';

/// Admin PIN modal (parity with `admin-auth.js#openPinModal`).
///
/// Runs in first-run **setup** mode when no PIN is configured (create +
/// confirm, then unlock), otherwise in **elevate** mode. Returns `true` when
/// the session was elevated, `false`/`null` when the user cancels.
class AdminPinDialog extends ConsumerStatefulWidget {
  const AdminPinDialog._({required this.setupMode});

  final bool setupMode;

  /// Opens the dialog, choosing setup vs elevate from the current status.
  static Future<bool> show(BuildContext context, WidgetRef ref) async {
    final setupMode = !ref.read(authControllerProvider).pinConfigured;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AdminPinDialog._(setupMode: setupMode),
    );
    return result ?? false;
  }

  @override
  ConsumerState<AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends ConsumerState<AdminPinDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  static final _digits = RegExp(r'^[0-9]{4,12}$');

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String _clean(String message) =>
      message.replaceFirst(RegExp(r'^Error:\s*'), '');

  Future<void> _submit() async {
    setState(() => _error = null);
    final pin = _pin.text;

    if (widget.setupMode) {
      if (!_digits.hasMatch(pin)) {
        setState(() => _error = 'PIN must be 4 to 12 digits.');
        return;
      }
      if (pin != _confirm.text) {
        setState(() => _error = 'PINs do not match.');
        return;
      }
    }

    setState(() => _busy = true);
    final controller = ref.read(authControllerProvider.notifier);
    try {
      if (widget.setupMode) {
        await controller.configurePin(newPin: pin);
      }
      await controller.elevate(pin);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _clean(e.toString());
      });
      _pin.selection =
          TextSelection(baseOffset: 0, extentOffset: _pin.text.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setup = widget.setupMode;

    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
      title: Text(setup ? 'Set Admin PIN' : 'Admin Access'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              setup
                  ? 'No admin PIN is set. Create one (4–12 digits) to protect '
                      'admin actions.'
                  : 'Enter the admin PIN to unlock admin features.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.x16),
            TextField(
              controller: _pin,
              autofocus: true,
              obscureText: true,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: setup ? 'New PIN' : 'PIN',
              ),
              onSubmitted: (_) => setup ? null : _submit(),
            ),
            if (setup) ...[
              const SizedBox(height: AppSpacing.x8),
              TextField(
                controller: _confirm,
                obscureText: true,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
                onSubmitted: (_) => _submit(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.x8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.error500),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(setup ? 'Save & Unlock' : 'Unlock'),
        ),
      ],
    );
  }
}
