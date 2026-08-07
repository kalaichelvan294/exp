import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/module_scaffold.dart';
import '../../../core/theme/app_tokens.dart';
import '../../billing/presentation/widgets/app_card.dart';
import '../application/bulk_controller.dart';
import '../application/bulk_state.dart';
import '../domain/bulk_enums.dart';
import '../domain/bulk_preview.dart';
import '../domain/bulk_result.dart';

/// Bulk Operations module (Phase 6). Two tabs — item import and inventory
/// update — each supporting template/export downloads, file → preview → apply,
/// last-batch revert, and error-report downloads.
class BulkPage extends ConsumerWidget {
  const BulkPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bulkControllerProvider);
    final controller = ref.read(bulkControllerProvider.notifier);

    ref.listen<BulkState>(bulkControllerProvider, (prev, next) {
      final toast = next.toast;
      if (toast != null && toast != prev?.toast) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(toast.text),
            backgroundColor:
                toast.isError ? AppColors.error500 : AppColors.neutral800,
          ));
        controller.clearToast();
      }
    });

    return ModuleScaffold(
      title: 'Bulk Ops',
      description: 'Import/export items and inventory via XLSX templates.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TabSwitcher(
            current: state.currentTab,
            onChanged: controller.setTab,
          ),
          const SizedBox(height: AppSpacing.x20),
          Expanded(
            child: SingleChildScrollView(
              child: state.currentTab == BulkOperationType.itemImport
                  ? const _ItemImportTab()
                  : const _InventoryUpdateTab(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabSwitcher extends StatelessWidget {
  const _TabSwitcher({required this.current, required this.onChanged});

  final BulkOperationType current;
  final ValueChanged<BulkOperationType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<BulkOperationType>(
        segments: const [
          ButtonSegment(
            value: BulkOperationType.itemImport,
            label: Text('Item Import'),
            icon: Icon(Icons.inventory_2_outlined),
          ),
          ButtonSegment(
            value: BulkOperationType.inventoryUpdate,
            label: Text('Inventory Update'),
            icon: Icon(Icons.warehouse_outlined),
          ),
        ],
        selected: {current},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

// ─── Item Import tab ─────────────────────────────────────────────────────────

class _ItemImportTab extends ConsumerWidget {
  const _ItemImportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bulkControllerProvider);
    final controller = ref.read(bulkControllerProvider.notifier);
    const type = BulkOperationType.itemImport;
    final tab = state.tab(type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          title: 'Download',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.x8,
                runSpacing: AppSpacing.x8,
                children: [
                  OutlinedButton.icon(
                    onPressed: controller.downloadItemTemplate,
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Download Template'),
                  ),
                  FilledButton.icon(
                    onPressed: controller.downloadItems,
                    icon: const Icon(Icons.download, size: 18),
                    label: Text(state.hasFilters
                        ? 'Download Filtered Items'
                        : 'Download All Items'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x16),
              _FilterChips(
                label: 'Categories',
                options: state.categoryOptions,
                selected: state.selectedCategories,
                onToggle: controller.toggleCategory,
              ),
              const SizedBox(height: AppSpacing.x8),
              _FilterChips(
                label: 'Brands',
                options: state.brandOptions,
                selected: state.selectedBrandNames,
                onToggle: controller.toggleBrand,
              ),
              if (state.hasFilters)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.x8),
                  child: TextButton.icon(
                    onPressed: controller.clearFilters,
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear filters'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x16),
        _UploadCard(type: type, tab: tab),
        if (tab.preview != null) ...[
          const SizedBox(height: AppSpacing.x16),
          _PreviewCard(type: type, tab: tab),
        ],
        if (tab.busy && tab.preview != null && tab.result == null) ...[
          const SizedBox(height: AppSpacing.x16),
          const _ApplyingCard(),
        ],
        if (tab.result != null) ...[
          const SizedBox(height: AppSpacing.x16),
          _ResultCard(type: type, tab: tab),
        ],
        const SizedBox(height: AppSpacing.x16),
        _LastBatchCard(type: type, tab: tab),
      ],
    );
  }
}

// ─── Inventory Update tab ────────────────────────────────────────────────────

class _InventoryUpdateTab extends ConsumerWidget {
  const _InventoryUpdateTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bulkControllerProvider);
    final controller = ref.read(bulkControllerProvider.notifier);
    const type = BulkOperationType.inventoryUpdate;
    final tab = state.tab(type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          title: 'Download',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.x16,
                runSpacing: AppSpacing.x8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: controller.downloadInventoryTemplate,
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Download Template'),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: state.invDownloadTrackType,
                      decoration:
                          const InputDecoration(labelText: 'Track type'),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('All')),
                        DropdownMenuItem(
                            value: 'quantity', child: Text('Quantity')),
                        DropdownMenuItem(
                            value: 'weight', child: Text('Weight')),
                      ],
                      onChanged: (v) =>
                          controller.setInvDownloadTrackType(v ?? ''),
                    ),
                  ),
                  _LowStockToggle(
                    value: state.invDownloadLowStockOnly,
                    onChanged: controller.setInvDownloadLowStockOnly,
                  ),
                  FilledButton.icon(
                    onPressed: controller.downloadCurrentInventory,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Download Current Inventory'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x16),
        if (!state.invControlEnabled)
          const _DisabledInventoryNotice()
        else ...[
          _UploadCard(type: type, tab: tab),
          if (tab.preview != null) ...[
            const SizedBox(height: AppSpacing.x16),
            _PreviewCard(type: type, tab: tab),
          ],
          if (tab.busy && tab.preview != null && tab.result == null) ...[
            const SizedBox(height: AppSpacing.x16),
            const _ApplyingCard(),
          ],
          if (tab.result != null) ...[
            const SizedBox(height: AppSpacing.x16),
            _ResultCard(type: type, tab: tab),
          ],
          const SizedBox(height: AppSpacing.x16),
          _LastBatchCard(type: type, tab: tab),
        ],
      ],
    );
  }
}

class _DisabledInventoryNotice extends StatelessWidget {
  const _DisabledInventoryNotice();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.info500),
          const SizedBox(width: AppSpacing.x8),
          Expanded(
            child: Text(
              'Inventory control is disabled. Enable it in Settings to import '
              'inventory updates.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _LowStockToggle extends StatelessWidget {
  const _LowStockToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
        const Text('Low stock only'),
      ],
    );
  }
}

// ─── Upload card ─────────────────────────────────────────────────────────────

class _UploadCard extends ConsumerWidget {
  const _UploadCard({required this.type, required this.tab});

  final BulkOperationType type;
  final BulkTabState tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(bulkControllerProvider.notifier);
    return _SectionCard(
      title: 'Upload',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed:
                    tab.busy ? null : () => controller.pickAndPreview(type),
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Choose File'),
              ),
              const SizedBox(width: AppSpacing.x16),
              if (tab.fileName != null)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle,
                          size: 16, color: AppColors.success500),
                      const SizedBox(width: AppSpacing.x4),
                      Flexible(
                        child: Text(tab.fileName!,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (tab.error != null) ...[
            const SizedBox(height: AppSpacing.x8),
            _ErrorBanner(
              message: tab.error!,
              onClose: () => controller.clearError(type),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Preview card ────────────────────────────────────────────────────────────

class _PreviewCard extends ConsumerWidget {
  const _PreviewCard({required this.type, required this.tab});

  final BulkOperationType type;
  final BulkTabState tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(bulkControllerProvider.notifier);
    final preview = tab.preview!;
    final theme = Theme.of(context);
    final isItem = type == BulkOperationType.itemImport;

    return _SectionCard(
      title: 'Preview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isItem && preview.autoDetectMode)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x8),
              child: Text(
                'Operation auto-detected per row (create vs update).',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.info500),
              ),
            ),
          Text(preview.summary.label, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.x8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: isItem
                ? _ItemPreviewTable(rows: tab.pageRows)
                : _InventoryPreviewTable(rows: tab.pageRows),
          ),
          const SizedBox(height: AppSpacing.x8),
          _Pagination(
            info: tab.pageInfo,
            canPrev: tab.canPrev,
            canNext: tab.canNext,
            onPrev: () => controller.prevPage(type),
            onNext: () => controller.nextPage(type),
          ),
          const Divider(height: AppSpacing.x32),
          Row(
            children: [
              Expanded(
                child: Text(
                  tab.applyHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: preview.summary.hasErrors
                        ? AppColors.error500
                        : AppColors.warning500,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: tab.busy ? null : () => controller.reset(type),
                child: const Text('Reset'),
              ),
              const SizedBox(width: AppSpacing.x8),
              FilledButton(
                onPressed:
                    tab.applyEnabled ? () => controller.apply(type) : null,
                child: Text(tab.applyLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemPreviewTable extends StatelessWidget {
  const _ItemPreviewTable({required this.rows});

  final List<BulkPreviewRow> rows;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Row')),
        DataColumn(label: Text('Sl.No')),
        DataColumn(label: Text('SKU')),
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Operation')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Details')),
      ],
      rows: [
        for (final r in rows)
          DataRow(
            color: _rowColor(r.status),
            cells: [
              DataCell(Text('${r.rowNumber}')),
              DataCell(Text(r.slno.isEmpty ? '—' : r.slno)),
              DataCell(Text(r.sku.isEmpty ? '—' : r.sku)),
              DataCell(Text(r.name.isEmpty ? '—' : r.name)),
              DataCell(Text(r.operation.isEmpty ? '—' : r.operation)),
              DataCell(_StatusIcon(status: r.status)),
              DataCell(Text(r.detail)),
            ],
          ),
      ],
    );
  }
}

class _InventoryPreviewTable extends StatelessWidget {
  const _InventoryPreviewTable({required this.rows});

  final List<BulkPreviewRow> rows;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Row')),
        DataColumn(label: Text('SKU')),
        DataColumn(label: Text('Action')),
        DataColumn(label: Text('Qty / Weight')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Details')),
      ],
      rows: [
        for (final r in rows)
          DataRow(
            color: _rowColor(r.status),
            cells: [
              DataCell(Text('${r.rowNumber}')),
              DataCell(Text(r.sku.isEmpty ? '—' : r.sku)),
              DataCell(Text(r.action.isEmpty ? '—' : r.action)),
              DataCell(Text(r.quantityDisplay)),
              DataCell(_StatusIcon(status: r.status)),
              DataCell(Text(r.detail)),
            ],
          ),
      ],
    );
  }
}

// ─── Result card ─────────────────────────────────────────────────────────────

class _ResultCard extends ConsumerWidget {
  const _ResultCard({required this.type, required this.tab});

  final BulkOperationType type;
  final BulkTabState tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(bulkControllerProvider.notifier);
    final result = tab.result!;
    final theme = Theme.of(context);
    final isItem = type == BulkOperationType.itemImport;
    final rows = result.rows.take(50).toList();

    return _SectionCard(
      title: 'Result',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result.summaryLabel,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.x8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: isItem
                ? _ItemResultTable(rows: rows)
                : _InventoryResultTable(rows: rows),
          ),
          const SizedBox(height: AppSpacing.x16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => controller.downloadErrorReport(type),
                icon: const Icon(Icons.summarize_outlined, size: 18),
                label: const Text('Download Error Report'),
              ),
              const SizedBox(width: AppSpacing.x8),
              FilledButton(
                onPressed: () => controller.reset(type),
                child: const Text('Done'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemResultTable extends StatelessWidget {
  const _ItemResultTable({required this.rows});

  final List<BulkResultRow> rows;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Row')),
        DataColumn(label: Text('Sl.No')),
        DataColumn(label: Text('SKU')),
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Operation')),
        DataColumn(label: Text('Outcome')),
        DataColumn(label: Text('Message')),
      ],
      rows: [
        for (final r in rows)
          DataRow(cells: [
            DataCell(Text('${r.rowNumber}')),
            DataCell(Text(r.slno.isEmpty ? '—' : r.slno)),
            DataCell(Text(r.sku.isEmpty ? '—' : r.sku)),
            DataCell(Text(r.name.isEmpty ? '—' : r.name)),
            DataCell(Text(r.operation.isEmpty ? '—' : r.operation)),
            DataCell(_OutcomeIcon(outcome: r.outcome)),
            DataCell(Text(r.message.isEmpty ? '—' : r.message)),
          ]),
      ],
    );
  }
}

class _InventoryResultTable extends StatelessWidget {
  const _InventoryResultTable({required this.rows});

  final List<BulkResultRow> rows;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Row')),
        DataColumn(label: Text('SKU')),
        DataColumn(label: Text('Action')),
        DataColumn(label: Text('Before')),
        DataColumn(label: Text('After')),
        DataColumn(label: Text('Outcome')),
        DataColumn(label: Text('Message')),
      ],
      rows: [
        for (final r in rows)
          DataRow(cells: [
            DataCell(Text('${r.rowNumber}')),
            DataCell(Text(r.sku.isEmpty ? '—' : r.sku)),
            DataCell(Text(r.action.isEmpty ? '—' : r.action)),
            DataCell(Text(r.beforeDisplay)),
            DataCell(Text(r.afterDisplay)),
            DataCell(_OutcomeIcon(outcome: r.outcome)),
            DataCell(Text(r.message.isEmpty ? '—' : r.message)),
          ]),
      ],
    );
  }
}

// ─── Last batch card ─────────────────────────────────────────────────────────

class _LastBatchCard extends ConsumerWidget {
  const _LastBatchCard({required this.type, required this.tab});

  final BulkOperationType type;
  final BulkTabState tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(bulkControllerProvider.notifier);
    final batch = tab.lastBatch;
    final theme = Theme.of(context);
    final noun = type == BulkOperationType.itemImport ? 'import' : 'update';

    final String info;
    if (batch == null) {
      info = 'No previous $noun to revert';
    } else if (batch.reverted) {
      info =
          'Reverted${batch.appliedAt != null ? ' on ${batch.appliedAt}' : ''}';
    } else {
      final applied = batch.appliedAt ?? '—';
      info = 'Applied: $applied · ${batch.rowCount} rows';
    }

    return _SectionCard(
      title: 'Last Batch',
      child: Row(
        children: [
          Expanded(child: Text(info, style: theme.textTheme.bodyMedium)),
          if (batch != null && !batch.reverted)
            OutlinedButton.icon(
              onPressed: () => _confirmRevert(context, controller, type, noun),
              icon: const Icon(Icons.undo, size: 18),
              label: const Text('Revert'),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmRevert(
    BuildContext context,
    BulkController controller,
    BulkOperationType type,
    String noun,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Revert last $noun?'),
        content: Text(
            'Are you sure you want to revert the last $noun? This restores the '
            'affected records to their pre-$noun state.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revert'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.revert(type);
    }
  }
}

// ─── Shared building blocks ──────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.x16),
          child,
        ],
      ),
    );
  }
}

class _ApplyingCard extends StatelessWidget {
  const _ApplyingCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Applying…', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.x16),
          const LinearProgressIndicator(),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final String label;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.x4),
        if (options.isEmpty)
          Text('None configured', style: theme.textTheme.bodySmall)
        else
          Wrap(
            spacing: AppSpacing.x8,
            runSpacing: AppSpacing.x4,
            children: [
              for (final option in options)
                FilterChip(
                  label: Text(option),
                  selected: selected.contains(option),
                  onSelected: (_) => onToggle(option),
                ),
            ],
          ),
      ],
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.info,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
  });

  final String info;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(info, style: Theme.of(context).textTheme.bodySmall),
        const Spacer(),
        IconButton(
          onPressed: canPrev ? onPrev : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: canNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x16, vertical: AppSpacing.x8),
      decoration: BoxDecoration(
        color: const Color(0x14DC2626),
        borderRadius: AppRadius.input,
        border: Border.all(color: AppColors.error500),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.error500),
          const SizedBox(width: AppSpacing.x8),
          Expanded(
            child: Text(message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.error500)),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 16),
            color: AppColors.error500,
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final BulkRowStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case BulkRowStatus.ok:
        return const Icon(Icons.check_circle,
            size: 18, color: AppColors.success500);
      case BulkRowStatus.warning:
        return const Icon(Icons.warning_amber_rounded,
            size: 18, color: AppColors.warning500);
      case BulkRowStatus.error:
        return const Icon(Icons.cancel, size: 18, color: AppColors.error500);
      case BulkRowStatus.skipped:
        return const Icon(Icons.skip_next,
            size: 18, color: AppColors.neutral400);
    }
  }
}

class _OutcomeIcon extends StatelessWidget {
  const _OutcomeIcon({required this.outcome});

  final BulkRowOutcome outcome;

  @override
  Widget build(BuildContext context) {
    switch (outcome) {
      case BulkRowOutcome.applied:
        return const Icon(Icons.check_circle,
            size: 18, color: AppColors.success500);
      case BulkRowOutcome.failed:
        return const Icon(Icons.cancel, size: 18, color: AppColors.error500);
      case BulkRowOutcome.skipped:
        return const Icon(Icons.skip_next,
            size: 18, color: AppColors.neutral400);
    }
  }
}

WidgetStateProperty<Color?>? _rowColor(BulkRowStatus status) {
  switch (status) {
    case BulkRowStatus.error:
      return WidgetStateProperty.all(const Color(0x14DC2626));
    case BulkRowStatus.warning:
      return WidgetStateProperty.all(const Color(0x14D97706));
    case BulkRowStatus.ok:
    case BulkRowStatus.skipped:
      return null;
  }
}
