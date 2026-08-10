import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../application/billing_controller.dart';
import '../../domain/billing_enums.dart';
import '../../domain/cart_line.dart';
import '../../domain/money.dart';

/// The cart table. Ports `cart.js` rendering: line number, bilingual item name
/// + brand, SKU, qty stepper, rate (with wholesale/retail tier detail), line
/// total, and a remove action. Numeric columns are right-aligned.
class CartTable extends ConsumerWidget {
  const CartTable({super.key, required this.onQtyConfirmed});

  final VoidCallback onQtyConfirmed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(billingControllerProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.hasMergeableDuplicates)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: ref
                    .read(billingControllerProvider.notifier)
                    .mergeDuplicateLines,
                icon: const Icon(Icons.call_merge_outlined, size: 18),
                label: const Text('Merge Same Items'),
              ),
            ),
          ),
        _header(theme),
        const Divider(height: 1),
        Expanded(
          child: state.cart.isEmpty
              ? Center(
                  child: Text(
                    'No items added',
                    style: theme.textTheme.bodySmall,
                  ),
                )
              : ListView.separated(
                  itemCount: state.cart.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => _CartRow(
                    index: index,
                    line: state.cart[index],
                    selected: index == state.selectedCartIndex,
                    qtyFocusRequestToken: state.qtyFocusRequestToken,
                    onQtyConfirmed: onQtyConfirmed,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _header(ThemeData theme) {
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.neutral700,
    );
    return Container(
      height: AppSizing.tableHeaderHeight,
      color: AppColors.neutral50,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16),
      child: Row(
        children: [
          _cell('#', style, flex: 1),
          _cell('Item Name', style, flex: 6),
          _cell('SKU', style, flex: 3),
          _cell('Qty/Wt', style, flex: 3, align: TextAlign.right),
          _cell('Rate', style, flex: 3, align: TextAlign.right),
          _cell('Total', style, flex: 3, align: TextAlign.right),
          _cell('', style, flex: 2, align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _cell(
    String text,
    TextStyle? style, {
    required int flex,
    TextAlign align = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Text(text, style: style, textAlign: align),
    );
  }
}

class _CartRow extends ConsumerStatefulWidget {
  const _CartRow({
    required this.index,
    required this.line,
    required this.selected,
    required this.qtyFocusRequestToken,
    required this.onQtyConfirmed,
  });

  final int index;
  final CartLine line;
  final bool selected;
  final int qtyFocusRequestToken;
  final VoidCallback onQtyConfirmed;

  @override
  ConsumerState<_CartRow> createState() => _CartRowState();
}

class _CartRowState extends ConsumerState<_CartRow> {
  late final TextEditingController _qtyController;
  late final FocusNode _qtyFocusNode;
  late String _lastSyncedQtyDisplay;

  void _requestQtyFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _qtyFocusNode.requestFocus();
      _qtyController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _qtyController.text.length,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _lastSyncedQtyDisplay = widget.line.qtyDisplay;
    _qtyController = TextEditingController(text: _lastSyncedQtyDisplay);
    _qtyFocusNode = FocusNode();
    if (widget.selected) {
      _requestQtyFocus();
    }
  }

  @override
  void didUpdateWidget(covariant _CartRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextQtyDisplay = widget.line.qtyDisplay;
    if (nextQtyDisplay != _lastSyncedQtyDisplay) {
      _lastSyncedQtyDisplay = nextQtyDisplay;
      _qtyController.text = nextQtyDisplay;
      if (_qtyFocusNode.hasFocus) {
        _qtyController.selection = TextSelection.collapsed(
          offset: _qtyController.text.length,
        );
      }
    }
    if (widget.selected &&
        (!oldWidget.selected ||
            oldWidget.qtyFocusRequestToken != widget.qtyFocusRequestToken)) {
      _requestQtyFocus();
    }
  }

  @override
  void dispose() {
    _qtyFocusNode.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _commitQty() {
    final c = ref.read(billingControllerProvider.notifier);
    final parsed = num.tryParse(_qtyController.text.trim());
    if (parsed == null || parsed < 0) {
      _qtyController.text = widget.line.qtyDisplay;
      return;
    }
    c.updateQty(widget.index, parsed, commit: true);
  }

  void _commitQtyAndFocusSearch() {
    _commitQty();
    widget.onQtyConfirmed();
  }

  void _nudgeQty(num delta) {
    final c = ref.read(billingControllerProvider.notifier);
    final current = num.tryParse(_qtyController.text.trim()) ?? widget.line.qty;
    final next = current + delta;
    if (next < 0) return;
    c.updateQty(widget.index, next, commit: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.read(billingControllerProvider.notifier);
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyMedium;

    return InkWell(
      onTap: () => c.selectCartLine(widget.index),
      child: Container(
        color: widget.selected ? AppColors.neutral50 : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x16,
          vertical: AppSpacing.x8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 1,
              child: Text('${widget.index + 1}', style: bodyStyle),
            ),
            Expanded(flex: 6, child: _itemCell(theme)),
            Expanded(
              flex: 3,
              child: Text(widget.line.skuDisplay, style: bodyStyle),
            ),
            Expanded(flex: 3, child: _qtyEditor(c)),
            Expanded(flex: 3, child: _rateCell(theme)),
            Expanded(
              flex: 3,
              child: Text(
                Money.format(widget.line.lineTotalPaise),
                textAlign: TextAlign.right,
                style: bodyStyle?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppColors.neutral500,
                  tooltip: 'Remove item',
                  onPressed: () => c.removeLine(widget.index),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemCell(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.line.displayName,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (widget.line.brandName.isNotEmpty)
          Text(
            'Brand: ${widget.line.brandName}',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _rateCell(ThemeData theme) {
    final tier = widget.line.priceTier == PriceTier.wholesale
        ? ' (Wholesale)'
        : '';
    String? detail;
    if (widget.line.hasWholesaleConfig) {
      detail = widget.line.priceTier == PriceTier.wholesale
          ? 'Applied: Wholesale ${Money.format(widget.line.wholesaleRatePaise!)}'
          : 'Applied: Retail ${Money.format(widget.line.retailRatePaise)}';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${Money.format(widget.line.ratePaise)}$tier',
          textAlign: TextAlign.right,
          style: theme.textTheme.bodyMedium,
        ),
        if (detail != null)
          Text(
            detail,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _qtyEditor(BillingController c) {
    final isWeight = widget.line.pricingType == PricingType.weight;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _stepButton(
          Icons.remove,
          () => c.bumpQty(widget.index, isWeight ? -0.1 : -1),
        ),
        const SizedBox(width: AppSpacing.x4),
        SizedBox(
          width: isWeight ? 84 : 68,
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                return KeyEventResult.ignored;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                _nudgeQty(isWeight ? 0.1 : 1);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                _nudgeQty(isWeight ? -0.1 : -1);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _qtyController,
              focusNode: _qtyFocusNode,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _commitQtyAndFocusSearch(),
              onEditingComplete: _commitQty,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.x4),
        _stepButton(
          Icons.add,
          () => c.bumpQty(widget.index, isWeight ? 0.1 : 1),
        ),
      ],
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.input,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.neutral300),
          borderRadius: AppRadius.input,
        ),
        child: Icon(icon, size: 14, color: AppColors.neutral700),
      ),
    );
  }
}
