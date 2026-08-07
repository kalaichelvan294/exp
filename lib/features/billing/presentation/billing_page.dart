import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/module_scaffold.dart';
import '../../../core/theme/app_tokens.dart';
import '../application/billing_controller.dart';
import '../domain/money.dart';
import 'widgets/app_card.dart';
import 'widgets/billing_search_field.dart';
import 'widgets/cart_table.dart';
import 'widgets/checkout_panel.dart';
import 'widgets/preview_overlay.dart';

/// Sales Desk (Phase 2). Keyboard-first billing screen.
///
/// Layout follows the POS billing rules: sales area 75% / checkout 25%. The
/// preview overlay replaces the layout when active. Keyboard model ports the
/// Electron shortcuts (Alt+S/N/H/P, F4, Delete, Esc).
///
/// When [editBillId] is supplied (via `/billing?billId=`), the referenced saved
/// bill is loaded for editing (Phase 3 edit flow).
class BillingPage extends ConsumerStatefulWidget {
  const BillingPage({super.key, this.editBillId});

  final String? editBillId;

  @override
  ConsumerState<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends ConsumerState<BillingPage> {
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final billId = widget.editBillId?.trim();
    if (billId != null && billId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(billingControllerProvider.notifier).loadBillForEdit(billId);
      });
    }
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  BillingController get _c => ref.read(billingControllerProvider.notifier);

  void _focusSearch() {
    _c.refreshSearch();
    _searchFocus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final state = ref.read(billingControllerProvider);
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final alt = keys.contains(LogicalKeyboardKey.altLeft) ||
        keys.contains(LogicalKeyboardKey.altRight);

    if (event.logicalKey == LogicalKeyboardKey.escape && state.previewVisible) {
      _c.hidePreview();
      return KeyEventResult.handled;
    }

    // F4: preview (new bill) or Save & Print (in preview).
    if (event.logicalKey == LogicalKeyboardKey.f4) {
      if (state.previewVisible) {
        if (!state.submitting) _c.checkout();
      } else if (state.canCheckout) {
        _c.showPreview();
      }
      return KeyEventResult.handled;
    }

    if (state.previewVisible) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.delete) {
      if (_c.removeSelectedLine()) return KeyEventResult.handled;
    }

    if (alt) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyS:
          _focusSearch();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyN:
          _c.startNewBill();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyH:
          _c.holdCurrentBill();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyP:
          if (state.canCheckout) _c.showPreview();
          return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final previewVisible =
        ref.watch(billingControllerProvider.select((s) => s.previewVisible));
    final isEditing =
        ref.watch(billingControllerProvider.select((s) => s.isEditing));
    final editingBillId =
        ref.watch(billingControllerProvider.select((s) => s.editingBillId));

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: previewVisible
          ? const PreviewOverlay()
          : ModuleScaffold(
              title: isEditing ? 'Edit Bill' : 'Sales Desk',
              description: isEditing
                  ? 'Editing bill $editingBillId. Update and press F4 to save.'
                  : 'Search products, build the cart, and check out.',
              actions: const [_HeaderActions()],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _HeldBillsBar(),
                  const SizedBox(height: AppSpacing.x16),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                BillingSearchField(focusNode: _searchFocus),
                                const SizedBox(height: AppSpacing.x16),
                                const Expanded(child: CartTable()),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x20),
                        const Expanded(flex: 1, child: CheckoutPanel()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _HeaderActions extends ConsumerWidget {
  const _HeaderActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(billingControllerProvider);
    final c = ref.read(billingControllerProvider.notifier);

    if (state.isEditing) {
      return Row(
        children: [
          OutlinedButton.icon(
            onPressed: c.reprintCurrentBill,
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Reprint'),
          ),
          const SizedBox(width: AppSpacing.x8),
          OutlinedButton.icon(
            onPressed: () => _confirmDelete(context, ref),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete Bill'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error500,
            ),
          ),
          const SizedBox(width: AppSpacing.x8),
          OutlinedButton.icon(
            onPressed: () {
              c.exitEdit();
              context.go(AppRoutes.bills.path);
            },
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Cancel Edit'),
          ),
        ],
      );
    }

    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: state.canHold ? c.holdCurrentBill : null,
          icon: const Icon(Icons.pause, size: 18),
          label: const Text('Hold Bill (Alt+H)'),
        ),
        const SizedBox(width: AppSpacing.x8),
        OutlinedButton.icon(
          onPressed: c.startNewBill,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('New Bill (Alt+N)'),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final c = ref.read(billingControllerProvider.notifier);
    final billId = ref.read(billingControllerProvider).editingBillId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete bill'),
        content: Text('Delete bill $billId permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error500),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await c.deleteCurrentBill();
    if (ok && context.mounted) {
      context.go(AppRoutes.bills.path);
    }
  }
}

class _HeldBillsBar extends ConsumerWidget {
  const _HeldBillsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final held = ref.watch(billingControllerProvider.select((s) => s.heldBills));
    final holdsLeft =
        ref.watch(billingControllerProvider.select((s) => s.holdsLeft));
    final c = ref.read(billingControllerProvider.notifier);
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x16, vertical: AppSpacing.x8),
      child: Row(
        children: [
          const Icon(Icons.pause_circle_outline,
              size: 18, color: AppColors.neutral500),
          const SizedBox(width: AppSpacing.x8),
          Text('Hold', style: theme.textTheme.bodySmall),
          const SizedBox(width: AppSpacing.x16),
          Expanded(
            child: held.isEmpty
                ? Text('No held bills', style: theme.textTheme.bodySmall)
                : Wrap(
                    spacing: AppSpacing.x8,
                    runSpacing: AppSpacing.x8,
                    children: held
                        .map((chip) => _HeldChip(
                              label: chip.label,
                              amount: Money.format(chip.amountPaise),
                              onTap: () => c.resumeHeldBill(chip.holdId),
                              onDelete: () => c.deleteHeldBill(chip.holdId),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(width: AppSpacing.x16),
          Text('Holds left: $holdsLeft', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _HeldChip extends StatelessWidget {
  const _HeldChip({
    required this.label,
    required this.amount,
    required this.onTap,
    required this.onDelete,
  });

  final String label;
  final String amount;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.neutral100,
      borderRadius: AppRadius.input,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: AppRadius.input,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x8, vertical: AppSpacing.x4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.neutral700,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: AppSpacing.x8),
                  Text(amount, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: onDelete,
            borderRadius: AppRadius.input,
            child: const Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4, vertical: AppSpacing.x4),
              child: Icon(Icons.close, size: 14, color: AppColors.neutral500),
            ),
          ),
          const SizedBox(width: AppSpacing.x4),
        ],
      ),
    );
  }
}
