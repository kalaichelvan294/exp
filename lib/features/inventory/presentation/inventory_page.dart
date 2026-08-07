import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/module_scaffold.dart';
import '../../../core/theme/app_tokens.dart';
import '../../billing/domain/billing_enums.dart';
import '../../billing/presentation/widgets/app_card.dart';
import '../../items/domain/item.dart';
import '../application/inventory_controller.dart';
import '../application/inventory_state.dart';
import 'widgets/inventory_adjust_dialog.dart';

/// Inventory module (Phase 4). Ports the Electron inventory page: settings
/// gating, item listing with trackType + low-stock threshold filters,
/// pagination, and stock adjustments.
class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  final _searchController = TextEditingController();
  final _qtyController = TextEditingController();
  final _weightController = TextEditingController();
  String _trackType = '';

  @override
  void dispose() {
    _searchController.dispose();
    _qtyController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  InventoryController get _c =>
      ref.read(inventoryControllerProvider.notifier);

  void _applyFilters() {
    _c.applyFilters(
      query: _searchController.text,
      trackTypeFilter: _trackType,
      qtyThreshold: num.tryParse(_qtyController.text.trim()),
      weightThreshold: num.tryParse(_weightController.text.trim()),
    );
  }

  void _resetFilters() {
    _searchController.clear();
    _qtyController.clear();
    _weightController.clear();
    setState(() => _trackType = '');
    _c.resetFilters();
  }

  Future<void> _openAdjust(Item item) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => InventoryAdjustDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryControllerProvider);
    final theme = Theme.of(context);
    return ModuleScaffold(
      title: 'Inventory',
      description: 'Adjust stock levels and review low-stock items.',
      child: _body(state, theme),
    );
  }

  Widget _body(InventoryState state, ThemeData theme) {
    if (!state.settingsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!state.enabled) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 40, color: AppColors.neutral500),
              const SizedBox(height: AppSpacing.x16),
              Text('Inventory control is disabled',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.x8),
              Text(
                'Enable inventory control in Settings to track and adjust stock.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.neutral500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _filtersBar(),
        const SizedBox(height: AppSpacing.x8),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x8),
            child: Text(state.error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.error500)),
          ),
        Expanded(
          child: AppCard(
            child: _InventoryTable(state: state, onAdjust: _openAdjust),
          ),
        ),
        const SizedBox(height: AppSpacing.x16),
        _Pagination(state: state),
      ],
    );
  }

  Widget _filtersBar() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.x16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: SizedBox(
              height: AppSizing.controlHeight,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search by name, category, brand, or SKU',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
                onSubmitted: (_) => _applyFilters(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x16),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: _trackType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Track type'),
              items: const [
                DropdownMenuItem(value: '', child: Text('All')),
                DropdownMenuItem(value: 'quantity', child: Text('Quantity')),
                DropdownMenuItem(value: 'weight', child: Text('Weight')),
              ],
              onChanged: (v) => setState(() => _trackType = v ?? ''),
            ),
          ),
          const SizedBox(width: AppSpacing.x16),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: AppSizing.controlHeight,
              child: TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Qty ≤'),
                onSubmitted: (_) => _applyFilters(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x16),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: AppSizing.controlHeight,
              child: TextField(
                controller: _weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Weight ≤'),
                onSubmitted: (_) => _applyFilters(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x16),
          FilledButton(
              onPressed: _applyFilters, child: const Text('Search')),
          const SizedBox(width: AppSpacing.x8),
          OutlinedButton(
              onPressed: _resetFilters, child: const Text('Reset')),
        ],
      ),
    );
  }
}

class _InventoryTable extends StatelessWidget {
  const _InventoryTable({required this.state, required this.onAdjust});

  final InventoryState state;
  final ValueChanged<Item> onAdjust;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.isEmptyResult) {
      return Center(
          child: Text('No items found', style: theme.textTheme.bodyMedium));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _HeaderRow(),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: state.items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) =>
                _InventoryRow(item: state.items[i], onAdjust: onAdjust),
          ),
        ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600, color: AppColors.neutral700);
    Widget cell(String t, int flex, {TextAlign align = TextAlign.left}) =>
        Expanded(flex: flex, child: Text(t, style: style, textAlign: align));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
      child: Row(
        children: [
          cell('Item', 4),
          cell('SKU', 2),
          cell('Category', 2),
          cell('Track', 2),
          cell('Current', 2, align: TextAlign.right),
          cell('Status', 2, align: TextAlign.center),
          cell('Actions', 2, align: TextAlign.right),
        ],
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({required this.item, required this.onAdjust});

  final Item item;
  final ValueChanged<Item> onAdjust;

  String get _trackDisplay =>
      item.trackType == 'weight' ? 'Weight' : 'Quantity';

  String get _currentDisplay {
    final unit = item.pricingType == PricingType.weight ? 'kg' : '';
    final value = item.currentStock;
    return unit.isEmpty ? '$value' : '$value $unit';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget cell(String t, int flex, {TextAlign align = TextAlign.left}) =>
        Expanded(
          flex: flex,
          child: Text(t,
              style: theme.textTheme.bodyMedium,
              textAlign: align,
              overflow: TextOverflow.ellipsis),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
      child: Row(
        children: [
          cell(item.displayName.isEmpty ? '—' : item.displayName, 4),
          cell(item.sku, 2),
          cell(item.category.isEmpty ? '—' : item.category, 2),
          cell(_trackDisplay, 2),
          cell(_currentDisplay, 2, align: TextAlign.right),
          Expanded(flex: 2, child: Center(child: _StatusChip(item: item))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => onAdjust(item),
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('Adjust'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final low = item.isLowStock;
    final color = low ? AppColors.warning500 : AppColors.success500;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x8, vertical: AppSpacing.x4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.input,
      ),
      child: Text(
        low ? 'Low' : 'OK',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Pagination extends ConsumerWidget {
  const _Pagination({required this.state});

  final InventoryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(inventoryControllerProvider.notifier);
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: state.canPrev ? c.prevPage : null,
          icon: const Icon(Icons.chevron_left, size: 18),
          label: const Text('Prev'),
        ),
        const SizedBox(width: AppSpacing.x16),
        Text('Page ${state.page} / ${state.totalPages}',
            style: theme.textTheme.bodyMedium),
        const SizedBox(width: AppSpacing.x16),
        OutlinedButton.icon(
          onPressed: state.canNext ? c.nextPage : null,
          icon: const Icon(Icons.chevron_right, size: 18),
          label: const Text('Next'),
        ),
      ],
    );
  }
}
