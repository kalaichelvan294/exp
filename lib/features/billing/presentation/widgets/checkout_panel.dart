import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../application/billing_controller.dart';
import '../../domain/bill_totals.dart';
import '../../domain/billing_enums.dart';
import '../../domain/money.dart';
import 'radio_dot.dart';

/// Checkout sidebar (25% width per POS billing screen rules). Contains payment
/// mode, discount, item count, subtotal, discount, total, and the primary
/// Preview Bill action.
class CheckoutPanel extends ConsumerStatefulWidget {
  const CheckoutPanel({super.key});

  @override
  ConsumerState<CheckoutPanel> createState() => _CheckoutPanelState();
}

class _CheckoutPanelState extends ConsumerState<CheckoutPanel> {
  final _discountController = TextEditingController(text: '0.00');

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  BillingController get _c => ref.read(billingControllerProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billingControllerProvider);
    final totals = ref.watch(billingControllerProvider.notifier).totals;
    final theme = Theme.of(context);

    // Keep discount field in sync after resets.
    final expected = state.discountValue.toStringAsFixed(2);
    if (state.discountValue == 0 && _discountController.text != '0.00') {
      _discountController.text = '0.00';
    } else if (state.discountValue != 0 &&
        double.tryParse(_discountController.text) != state.discountValue) {
      // avoid clobbering active typing; only sync when clearly divergent
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Checkout', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.x16),
                _label('Payment Mode', theme),
                const SizedBox(height: AppSpacing.x8),
                _paymentModes(state.paymentMode),
                const SizedBox(height: AppSpacing.x24),
                _label('Discount', theme),
                const SizedBox(height: AppSpacing.x8),
                _discountRow(state.discountMode, expected),
                const Divider(height: AppSpacing.x32),
                _summaryRow('Items', '${state.cart.length}', theme),
                _summaryRow('Subtotal', Money.format(totals.subtotalPaise), theme),
                _summaryRow(
                    'Discount', '-${Money.format(totals.discountPaise)}', theme),
                const SizedBox(height: AppSpacing.x8),
                _totalRow(totals, theme),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x16),
        SizedBox(
          height: AppSizing.controlHeight,
          child: ElevatedButton.icon(
            onPressed: state.canCheckout ? _c.showPreview : null,
            icon: const Icon(Icons.visibility, size: 18),
            label: Text(
              state.isEditing ? 'Preview Update (F4)' : 'Preview Bill (F4)',
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text, ThemeData theme) => Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      );

  Widget _paymentModes(PaymentMode selected) {
    return Wrap(
      spacing: AppSpacing.x16,
      children: PaymentMode.values.map((mode) {
        return _radio<PaymentMode>(
          label: mode.wire,
          value: mode,
          groupValue: selected,
          onChanged: (v) => _c.setPaymentMode(v!),
        );
      }).toList(),
    );
  }

  Widget _discountRow(DiscountMode mode, String expected) {
    return Row(
      children: [
        _radio<DiscountMode>(
          label: '%',
          value: DiscountMode.percent,
          groupValue: mode,
          onChanged: (v) => _c.setDiscountMode(v!),
        ),
        const SizedBox(width: AppSpacing.x8),
        _radio<DiscountMode>(
          label: 'INR',
          value: DiscountMode.amount,
          groupValue: mode,
          onChanged: (v) => _c.setDiscountMode(v!),
        ),
        const SizedBox(width: AppSpacing.x16),
        Expanded(
          child: SizedBox(
            height: AppSizing.controlHeight,
            child: TextField(
              controller: _discountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: _c.setDiscountValue,
              textAlign: TextAlign.right,
            ),
          ),
        ),
      ],
    );
  }

  Widget _radio<T>({
    required String label,
    required T value,
    required T groupValue,
    required ValueChanged<T?> onChanged,
  }) {
    return RadioDot<T>(
      label: label,
      value: value,
      groupValue: groupValue,
      onChanged: (v) => onChanged(v),
    );
  }

  Widget _summaryRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(BillTotals totals, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Total', style: theme.textTheme.titleMedium),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              Money.format(totals.grandTotalPaise),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.neutral900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
