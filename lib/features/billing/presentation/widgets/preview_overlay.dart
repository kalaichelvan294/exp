import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../application/billing_controller.dart';
import '../../domain/bill_totals.dart';
import '../../domain/billing_enums.dart';
import '../../domain/cart_line.dart';
import '../../domain/money.dart';
import 'radio_dot.dart';

/// Full-screen bill preview overlay shown before Save & Print.
///
/// Ports the Electron preview panel: left = store header + items + totals,
/// right = checkout controls with Save & Print (F4) and Cancel (Esc). Payment
/// mode and discount edit the shared billing state, so totals update live.
class PreviewOverlay extends ConsumerWidget {
  const PreviewOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(billingControllerProvider);
    final c = ref.read(billingControllerProvider.notifier);
    final totals = c.totals;
    final theme = Theme.of(context);

    return Container(
      color: AppColors.neutral50,
      padding: AppSpacing.pagePadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Bill Preview', style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.x4),
                  Text(
                    'Bill ID: ${state.pendingBillId}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Divider(height: AppSpacing.x24),
                  _itemsHeader(theme),
                  const Divider(height: 1),
                  Expanded(child: _itemsList(state.cart, theme)),
                  const Divider(height: AppSpacing.x24),
                  _totalsBlock(totals, theme),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x20),
          Expanded(
            flex: 1,
            child: _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Checkout', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.x16),
                  Text(
                    'Payment Mode',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x8),
                  Wrap(
                    spacing: AppSpacing.x16,
                    children: PaymentMode.values
                        .map(
                          (m) => _radio<PaymentMode>(
                            m.wire,
                            m,
                            state.paymentMode,
                            (v) => c.setPaymentMode(v!),
                          ),
                        )
                        .toList(),
                  ),
                  const Divider(height: AppSpacing.x32),
                  _summaryRow('Items', '${state.cart.length}', theme),
                  _summaryRow(
                    'Subtotal',
                    Money.format(totals.subtotalPaise),
                    theme,
                  ),
                  _summaryRow(
                    'Discount',
                    '-${Money.format(totals.discountPaise)}',
                    theme,
                  ),
                  const SizedBox(height: AppSpacing.x8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: theme.textTheme.titleMedium),
                      Text(
                        Money.format(totals.grandTotalPaise),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    height: AppSizing.controlHeight,
                    child: ElevatedButton.icon(
                      onPressed: state.submitting ? null : c.checkout,
                      icon: const Icon(Icons.print, size: 18),
                      label: Text(
                        state.isEditing
                            ? 'Update Bill (Ctrl+P)'
                            : 'Save & Print (Ctrl+P)',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x8),
                  SizedBox(
                    height: AppSizing.controlHeight,
                    child: OutlinedButton(
                      onPressed: c.hidePreview,
                      child: const Text('Cancel (Esc)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x20),
      decoration: BoxDecoration(
        color: AppColors.neutral0,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.neutral200),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }

  Widget _itemsHeader(ThemeData theme) {
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.neutral700,
    );
    return Row(
      children: [
        Expanded(flex: 1, child: Text('#', style: style)),
        Expanded(flex: 5, child: Text('Item', style: style)),
        Expanded(
          flex: 2,
          child: Text('Qty/Wt', style: style, textAlign: TextAlign.right),
        ),
        Expanded(
          flex: 2,
          child: Text('Rate', style: style, textAlign: TextAlign.right),
        ),
        Expanded(
          flex: 2,
          child: Text('Total', style: style, textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _itemsList(List<CartLine> cart, ThemeData theme) {
    return ListView.builder(
      itemCount: cart.length,
      itemBuilder: (context, index) {
        final line = cart[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
          child: Row(
            children: [
              Expanded(flex: 1, child: Text('${index + 1}')),
              Expanded(flex: 5, child: Text(line.displayName)),
              Expanded(
                flex: 2,
                child: Text(line.qtyDisplay, textAlign: TextAlign.right),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  Money.format(line.ratePaise),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  Money.format(line.lineTotalPaise),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _totalsBlock(BillTotals totals, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _summaryRow('Subtotal', Money.format(totals.subtotalPaise), theme),
        _summaryRow(
          'Discount',
          '-${Money.format(totals.discountPaise)}',
          theme,
        ),
        _summaryRow(
          'Grand Total',
          Money.format(totals.grandTotalPaise),
          theme,
          emphasize: true,
        ),
      ],
    );
  }

  Widget _summaryRow(
    String label,
    String value,
    ThemeData theme, {
    bool emphasize = false,
  }) {
    final valueStyle = emphasize
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }

  Widget _radio<T>(String label, T value, T group, ValueChanged<T?> onChanged) {
    return RadioDot<T>(
      label: label,
      value: value,
      groupValue: group,
      onChanged: (v) => onChanged(v),
    );
  }
}
