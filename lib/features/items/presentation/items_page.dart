import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/module_scaffold.dart';
import '../../../core/config/app_config.dart';
import '../../../core/images/item_image_path.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_tab_switcher.dart';
import '../../billing/domain/billing_enums.dart';
import '../../billing/domain/money.dart';
import '../../settings/application/settings_controller.dart';
import '../application/items_controller.dart';
import '../application/items_state.dart';
import '../domain/item.dart';
import 'widgets/item_form_dialog.dart';

/// Items module (Phase 4). Ports the Electron items page: search, paginate,
/// and create/update/delete items with SKU validation.
enum _ItemsViewMode { table, cards }

class ItemsPage extends ConsumerStatefulWidget {
  const ItemsPage({super.key});

  @override
  ConsumerState<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends ConsumerState<ItemsPage> {
  final _searchController = TextEditingController();
  _ItemsViewMode _viewMode = _ItemsViewMode.table;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ItemsController get _c => ref.read(itemsControllerProvider.notifier);

  Future<void> _openForm({Item? item}) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => ItemFormDialog(item: item),
    );
  }

  Future<void> _confirmDelete(Item item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item'),
        content: Text('Delete item "${item.name}"?'),
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
    if (confirmed == true) await _c.deleteItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemsControllerProvider);
    final settings = ref.watch(settingsControllerProvider).settings;
    final config = ref.watch(appConfigProvider);
    final theme = Theme.of(context);
    return ModuleScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with search and actions
          Row(
            children: [
              // Search section (left)
              Expanded(
                child: _SearchBar(
                  controller: _searchController,
                  onSearch: () => _c.search(_searchController.text),
                  onReset: () {
                    _searchController.clear();
                    _c.clearFilter();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.x8),
              // Actions section (right)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTabSwitcher<_ItemsViewMode>(
                    selected: _viewMode,
                    onChanged: (mode) => setState(() => _viewMode = mode),
                    options: const [
                      AppTabOption(value: _ItemsViewMode.table, label: 'Table'),
                      AppTabOption(value: _ItemsViewMode.cards, label: 'Cards'),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.x8),
                  AppTextButton(
                    outlined: true,
                    onPressed: () => context.go('/bulk'),
                    label: 'Bulk',
                  ),
                  const SizedBox(width: AppSpacing.x8),
                  AppTextIconButton(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add, size: 18),
                    label: 'Add Item',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x16),
          if (state.message.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x8),
              child: Text(
                state.message.text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: state.message.isError
                      ? AppColors.error500
                      : AppColors.neutral500,
                ),
              ),
            ),
          Expanded(
            child: AppCard(
              child: _viewMode == _ItemsViewMode.table
                  ? _ItemsTable(
                      state: state,
                      onEdit: (item) => _openForm(item: item),
                      onDelete: _confirmDelete,
                    )
                  : _ItemsCards(
                      state: state,
                      itemImagesRootPath: settings.itemImagesRootPath,
                      fallbackHost: config.databaseHost,
                      onEdit: (item) => _openForm(item: item),
                      onDelete: _confirmDelete,
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.x16),
          _Pagination(state: state),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onSearch,
    required this.onReset,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: AppSizing.controlHeight,
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Search by name, category, brand, or SKU',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onSubmitted: (_) => onSearch(),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.x16),
        FilledButton(onPressed: onSearch, child: const Text('Search')),
        const SizedBox(width: AppSpacing.x8),
        OutlinedButton(onPressed: onReset, child: const Text('Reset')),
      ],
    );
  }
}

class _ItemsTable extends StatelessWidget {
  const _ItemsTable({
    required this.state,
    required this.onEdit,
    required this.onDelete,
  });

  final ItemsState state;
  final ValueChanged<Item> onEdit;
  final ValueChanged<Item> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.isEmptyResult) {
      return Center(
        child: Text('No items found', style: theme.textTheme.bodyMedium),
      );
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
            itemBuilder: (_, i) => _ItemRow(
              item: state.items[i],
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemsCards extends StatelessWidget {
  const _ItemsCards({
    required this.state,
    required this.itemImagesRootPath,
    required this.fallbackHost,
    required this.onEdit,
    required this.onDelete,
  });

  final ItemsState state;
  final String itemImagesRootPath;
  final String fallbackHost;
  final ValueChanged<Item> onEdit;
  final ValueChanged<Item> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.isEmptyResult) {
      return Center(
        child: Text('No items found', style: theme.textTheme.bodyMedium),
      );
    }
    return GridView.builder(
      itemCount: state.items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisExtent: 292,
        crossAxisSpacing: AppSpacing.x16,
        mainAxisSpacing: AppSpacing.x16,
      ),
      itemBuilder: (_, i) => _ItemCard(
        item: state.items[i],
        itemImagesRootPath: itemImagesRootPath,
        fallbackHost: fallbackHost,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.itemImagesRootPath,
    required this.fallbackHost,
    required this.onEdit,
    required this.onDelete,
  });

  final Item item;
  final String itemImagesRootPath;
  final String fallbackHost;
  final ValueChanged<Item> onEdit;
  final ValueChanged<Item> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = ItemImagePath.resolve(
      sku: item.sku,
      configuredRootPath: itemImagesRootPath,
      fallbackHost: fallbackHost,
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.neutral0,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: image.filePath != null
                  ? Image.file(
                      File(image.filePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stackTrace) => _noImage(),
                    )
                  : image.networkUrl != null
                  ? Image.network(
                      image.networkUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stackTrace) => _noImage(),
                    )
                  : _noImage(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x12,
              AppSpacing.x8,
              AppSpacing.x12,
              AppSpacing.x12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.displayName.isEmpty ? '—' : item.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x8),
                    Text(
                      Money.format(item.retailPricePaise),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.primary600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x8),
                Text(
                  'SKU: ${item.sku.isEmpty ? '—' : item.sku}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  'Brand: ${item.brandName.isEmpty ? '—' : item.brandName}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  'Category: ${item.category.isEmpty ? '—' : item.category}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.x6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit',
                      onPressed: () => onEdit(item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: AppColors.error500,
                      tooltip: 'Delete',
                      onPressed: () => onDelete(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noImage() => Container(
    color: AppColors.neutral100,
    alignment: Alignment.center,
    child: const Text('No image'),
  );
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.neutral700,
    );
    Widget cell(String t, int flex, {TextAlign align = TextAlign.left}) =>
        Expanded(
          flex: flex,
          child: Text(t, style: style, textAlign: align),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
      child: Row(
        children: [
          cell('Item', 4),
          cell('Brand', 2),
          cell('SKU', 2),
          cell('Category', 2),
          cell('Retail', 2, align: TextAlign.right),
          cell('Wholesale', 3, align: TextAlign.right),
          cell('Actions', 2, align: TextAlign.right),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final Item item;
  final ValueChanged<Item> onEdit;
  final ValueChanged<Item> onDelete;

  String get _wholesaleSummary {
    final rate = item.wholesalePricePaise;
    final minQty = item.wholesaleMinQty;
    if (rate == null || rate <= 0 || minQty == null || minQty <= 0) return '—';
    final qtyText = item.pricingType == PricingType.unit
        ? minQty.round().toString()
        : '$minQty';
    return '${Money.format(rate)} from qty $qtyText';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget cell(String t, int flex, {TextAlign align = TextAlign.left}) =>
        Expanded(
          flex: flex,
          child: Text(
            t,
            style: theme.textTheme.bodyMedium,
            textAlign: align,
            overflow: TextOverflow.ellipsis,
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
      child: Row(
        children: [
          cell(item.displayName.isEmpty ? '—' : item.displayName, 4),
          cell(item.brandName.isEmpty ? '—' : item.brandName, 2),
          cell(item.sku, 2),
          cell(item.category.isEmpty ? '—' : item.category, 2),
          cell(Money.format(item.retailPricePaise), 2, align: TextAlign.right),
          cell(_wholesaleSummary, 3, align: TextAlign.right),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit',
                  onPressed: () => onEdit(item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppColors.error500,
                  tooltip: 'Delete',
                  onPressed: () => onDelete(item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pagination extends ConsumerWidget {
  const _Pagination({required this.state});

  final ItemsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(itemsControllerProvider.notifier);
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
        Text(
          'Page ${state.page} / ${state.totalPages}',
          style: theme.textTheme.bodyMedium,
        ),
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
