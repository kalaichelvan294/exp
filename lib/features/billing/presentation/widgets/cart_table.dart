import 'package:flutter/material.dart';
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
  const CartTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(billingControllerProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(theme),
        const Divider(height: 1),
        Expanded(
          child: state.cart.isEmpty
              ? Center(
                  child: Text('No items added',
                      style: theme.textTheme.bodySmall),
                )
              : ListView.separated(
                  itemCount: state.cart.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => _CartRow(
                    index: index,
                    line: state.cart[index],
                    selected: index == state.selectedCartIndex,
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

  Widget _cell(String text, TextStyle? style,
      {required int flex, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(text, style: style, textAlign: align),
    );
  }
}

class _CartRow extends ConsumerWidget {
  const _CartRow({
    required this.index,
    required this.line,
    required this.selected,
  });

  final int index;
  final CartLine line;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(billingControllerProvider.notifier);
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyMedium;

    return InkWell(
      onTap: () => c.selectCartLine(index),
      child: Container(
        color: selected ? AppColors.neutral50 : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x16,
          vertical: AppSpacing.x8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 1, child: Text('${index + 1}', style: bodyStyle)),
            Expanded(flex: 6, child: _itemCell(theme)),
            Expanded(flex: 3, child: Text(line.skuDisplay, style: bodyStyle)),
            Expanded(flex: 3, child: _qtyStepper(c)),
            Expanded(flex: 3, child: _rateCell(theme)),
            Expanded(
              flex: 3,
              child: Text(
                Money.format(line.lineTotalPaise),
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
                  onPressed: () => c.removeLine(index),
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
        Text(line.displayName,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        if (line.brandName.isNotEmpty)
          Text('Brand: ${line.brandName}', style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _rateCell(ThemeData theme) {
    final tier = line.priceTier == PriceTier.wholesale ? ' (Wholesale)' : '';
    String? detail;
    if (line.hasWholesaleConfig) {
      detail = line.priceTier == PriceTier.wholesale
          ? 'Applied: Wholesale ${Money.format(line.wholesaleRatePaise!)}'
          : 'Applied: Retail ${Money.format(line.retailRatePaise)}';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('${Money.format(line.ratePaise)}$tier',
            textAlign: TextAlign.right, style: theme.textTheme.bodyMedium),
        if (detail != null)
          Text(detail, textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _qtyStepper(BillingController c) {
    final step = line.pricingType == PricingType.weight ? 0.1 : 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _stepButton(Icons.remove, () => c.bumpQty(index, -step)),
        const SizedBox(width: AppSpacing.x4),
        Text(line.qtyDisplay),
        const SizedBox(width: AppSpacing.x4),
        _stepButton(Icons.add, () => c.bumpQty(index, step)),
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
