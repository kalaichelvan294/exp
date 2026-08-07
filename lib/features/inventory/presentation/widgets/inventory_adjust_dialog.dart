import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../billing/domain/billing_enums.dart';
import '../../../items/domain/item.dart';
import '../../application/inventory_controller.dart';
import '../../domain/inventory_adjust.dart';

/// Stock adjustment modal. Ports the Electron adjust modal: add/deduct toggle,
/// qty-or-weight input based on the item's track type, notes, and a live
/// `current → new` preview (new = max(0, current + delta)).
class InventoryAdjustDialog extends ConsumerStatefulWidget {
  const InventoryAdjustDialog({super.key, required this.item});

  final Item item;

  @override
  ConsumerState<InventoryAdjustDialog> createState() =>
      _InventoryAdjustDialogState();
}

class _InventoryAdjustDialogState extends ConsumerState<InventoryAdjustDialog> {
  final _value = TextEditingController();
  final _notes = TextEditingController();
  AdjustAction _action = AdjustAction.add;
  bool _submitting = false;

  @override
  void dispose() {
    _value.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _isWeight => widget.item.pricingType == PricingType.weight;
  String get _unit => _isWeight ? 'kg' : 'units';

  num get _magnitude => num.tryParse(_value.text.trim()) ?? 0;

  InventoryAdjustment _adjustment() => InventoryAdjustment(
        trackType: widget.item.pricingType,
        action: _action,
        magnitude: _magnitude,
        notes: _notes.text,
      );

  Future<void> _submit() async {
    if (_magnitude <= 0) return;
    setState(() => _submitting = true);
    final ok = await ref
        .read(inventoryControllerProvider.notifier)
        .adjust(widget.item.id, _adjustment());
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final current = item.currentStock;
    final magnitude = _magnitude;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Adjust Stock', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.x8),
              Text(item.displayName,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Text('SKU: ${item.sku} · ${item.category}',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.x4),
              Text('Current Stock: $current $_unit',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.x20),
              _actionToggle(),
              const SizedBox(height: AppSpacing.x16),
              TextField(
                controller: _value,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: _isWeight ? 'Weight ($_unit)' : 'Quantity',
                ),
              ),
              const SizedBox(height: AppSpacing.x16),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
              if (magnitude > 0) ...[
                const SizedBox(height: AppSpacing.x16),
                _preview(current, theme),
              ],
              const SizedBox(height: AppSpacing.x24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.x8),
                  FilledButton(
                    onPressed:
                        (magnitude > 0 && !_submitting) ? _submit : null,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionToggle() {
    return SegmentedButton<AdjustAction>(
      segments: const [
        ButtonSegment(
          value: AdjustAction.add,
          label: Text('Add'),
          icon: Icon(Icons.add, size: 16),
        ),
        ButtonSegment(
          value: AdjustAction.deduct,
          label: Text('Deduct'),
          icon: Icon(Icons.remove, size: 16),
        ),
      ],
      selected: {_action},
      onSelectionChanged: (s) => setState(() => _action = s.first),
    );
  }

  Widget _preview(num current, ThemeData theme) {
    final newStock = _adjustment().previewStock(current);
    final zero = newStock <= 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x8),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: AppRadius.input,
      ),
      child: Row(
        children: [
          Text('$current $_unit', style: theme.textTheme.bodyMedium),
          const SizedBox(width: AppSpacing.x8),
          Icon(_action == AdjustAction.deduct ? Icons.remove : Icons.add,
              size: 16, color: AppColors.neutral500),
          const SizedBox(width: AppSpacing.x8),
          Text('$_magnitude', style: theme.textTheme.bodyMedium),
          const SizedBox(width: AppSpacing.x8),
          const Icon(Icons.arrow_right_alt, size: 18),
          const SizedBox(width: AppSpacing.x8),
          Text('$newStock $_unit',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          if (zero) ...[
            const SizedBox(width: AppSpacing.x8),
            Icon(Icons.warning_amber_rounded,
                size: 16, color: AppColors.warning500),
            const SizedBox(width: AppSpacing.x4),
            Text('Stock will be zero',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.warning500)),
          ],
        ],
      ),
    );
  }
}
