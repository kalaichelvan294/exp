import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:io';

import '../../../app/app_routes.dart';
import '../../../app/module_scaffold.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../bills/application/bills_controller.dart';
import '../application/billing_controller.dart';
import '../domain/money.dart';
import 'widgets/billing_search_field.dart';
import 'widgets/camera_control_modal.dart';
import 'widgets/cart_table.dart';
import 'widgets/checkout_panel.dart';
import 'widgets/preview_overlay.dart';

/// Sales Desk (Phase 2). Keyboard-first billing screen.
///
/// Layout follows the POS billing rules: sales area 75% / checkout 25%. The
/// preview overlay replaces the layout when active. Keyboard model ports the
/// Electron shortcuts (Ctrl+S/N/H/P, F4, Delete, Esc).
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
  late final dynamic _earlyKeyHandler;

  @override
  void initState() {
    super.initState();
    _earlyKeyHandler = (KeyEvent event) => _handleGlobalKeyEvent(event);
    FocusManager.instance.addEarlyKeyEventHandler(_earlyKeyHandler);
    final billId = widget.editBillId?.trim();
    if (billId != null && billId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(billingControllerProvider.notifier).loadBillForEdit(billId);
      });
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_earlyKeyHandler);
    _searchFocus.dispose();
    super.dispose();
  }

  BillingController get _c => ref.read(billingControllerProvider.notifier);

  void _focusSearch() {
    _c.refreshSearch();
    _searchFocus.requestFocus();
  }

  KeyEventResult _handleGlobalKeyEvent(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return KeyEventResult.ignored;
    final isSlash =
        event.logicalKey == LogicalKeyboardKey.slash || event.character == '/';
    if (!isSlash) return KeyEventResult.ignored;
    final state = ref.read(billingControllerProvider);
    _focusSearch();
    if (!state.cameraTurnedOff && Platform.isWindows) {
      unawaited(_c.captureCameraSearch());
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final state = ref.read(billingControllerProvider);
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final ctrl =
        keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);

    if (event.logicalKey == LogicalKeyboardKey.escape &&
        state.searchDropdownOpen) {
      _c.setSearchDropdownOpen(false);
      _searchFocus.unfocus();
      FocusScope.of(context).unfocus();
      return KeyEventResult.handled;
    }

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

    if (state.previewVisible) {
      if (ctrl && event.logicalKey == LogicalKeyboardKey.keyP) {
        if (!state.submitting) _c.checkout();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.delete) {
      if (_c.removeSelectedLine()) return KeyEventResult.handled;
    }

    if (ctrl) {
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
          if (state.isEditing) {
            _c.reprintCurrentBill();
          } else if (state.canCheckout) {
            _c.showPreview();
          }
          return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final previewVisible = ref.watch(
      billingControllerProvider.select((s) => s.previewVisible),
    );
    final cameraModalVisible = ref.watch(
      billingControllerProvider.select((s) => s.cameraModalVisible),
    );
    final billingState = ref.watch(billingControllerProvider);

    // Show camera modal if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (cameraModalVisible &&
          !Navigator.of(context, rootNavigator: true).canPop()) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => CameraControlModal(
            state: billingState,
            cameraController: ref
                .read(billingControllerProvider.notifier)
                .cameraController,
            onClose: () {
              Navigator.of(ctx).pop(); // Close dialog first
            },
          ),
        ).then((_) {
          ref.read(billingControllerProvider.notifier).closeCameraModal();
        });
      }
    });

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: previewVisible
          ? const PreviewOverlay()
          : ModuleScaffold(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _HeldBillsBar(),
                  const SizedBox(height: AppSpacing.x16),
                  Expanded(
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.x20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  BillingSearchField(focusNode: _searchFocus),
                                  const SizedBox(height: AppSpacing.x16),
                                  Expanded(
                                    child: CartTable(
                                      onQtyConfirmed: _focusSearch,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const VerticalDivider(width: 1, thickness: 1),
                          Expanded(
                            flex: 1,
                            child: Container(
                              color: AppColors.neutral100,
                              padding: const EdgeInsets.all(AppSpacing.x20),
                              child: const CheckoutPanel(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _HeldBillsBar extends ConsumerWidget {
  const _HeldBillsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final held = ref.watch(
      billingControllerProvider.select((s) => s.heldBills),
    );
    final recent = ref.watch(
      billingControllerProvider.select((s) => s.recentBills),
    );
    final holdsLeft = ref.watch(
      billingControllerProvider.select((s) => s.holdsLeft),
    );
    final c = ref.read(billingControllerProvider.notifier);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.history,
                      size: 16,
                      color: AppColors.neutral500,
                    ),
                    const SizedBox(width: AppSpacing.x4),
                    Text(
                      'Recents:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral700,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x8),
                    if (recent.isEmpty)
                      Text(
                        'None',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.neutral500,
                        ),
                      )
                    else
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (int i = 0; i < recent.length; i++) ...[
                                _RecentChip(
                                  label: recent[i].billId,
                                  amount: Money.format(recent[i].amountPaise),
                                  onTap: () =>
                                      c.loadBillForEdit(recent[i].billId),
                                ),
                                if (i < recent.length - 1)
                                  const SizedBox(width: AppSpacing.x6),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x8),
                Row(
                  children: [
                    const Icon(
                      Icons.pause_circle_outline,
                      size: 16,
                      color: AppColors.neutral500,
                    ),
                    const SizedBox(width: AppSpacing.x4),
                    Text(
                      'Hold:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral700,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x8),
                    if (held.isEmpty)
                      Text(
                        'None',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.neutral500,
                        ),
                      )
                    else
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (int i = 0; i < held.length; i++) ...[
                                _HeldChip(
                                  label: held[i].label,
                                  amount: Money.format(held[i].amountPaise),
                                  onTap: () => c.resumeHeldBill(held[i].holdId),
                                  onDelete: () =>
                                      c.deleteHeldBill(held[i].holdId),
                                ),
                                if (i < held.length - 1)
                                  const SizedBox(width: AppSpacing.x6),
                              ],
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: AppSpacing.x12),
                    Text(
                      'Holds left: $holdsLeft',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.neutral500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x16),
          const _HeaderActions(),
        ],
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
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: c.reprintCurrentBill,
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Reprint (Ctrl+P)'),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: state.canHold ? c.holdCurrentBill : null,
          icon: const Icon(Icons.pause, size: 18),
          label: const Text('Hold Bill (Ctrl+H)'),
        ),
        const SizedBox(width: AppSpacing.x8),
        OutlinedButton.icon(
          onPressed: c.startNewBill,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('New Bill (Ctrl+N)'),
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
      ref.invalidate(billsControllerProvider);
      context.go(AppRoutes.bills.path);
    }
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({
    required this.label,
    required this.amount,
    required this.onTap,
  });

  final String label;
  final String amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.neutral100,
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x8,
            vertical: AppSpacing.x4,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.neutral300, width: 1),
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary600,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: AppSpacing.x6),
              Text(
                amount,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.neutral800,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
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
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.neutral300, width: 1),
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x8,
                  vertical: AppSpacing.x4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.neutral800,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x6),
                    Text(
                      amount,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.neutral800,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4,
                  vertical: AppSpacing.x4,
                ),
                child: Icon(Icons.close, size: 14, color: AppColors.neutral500),
              ),
            ),
            const SizedBox(width: AppSpacing.x4),
          ],
        ),
      ),
    );
  }
}
