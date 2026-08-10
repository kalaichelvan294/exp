import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/module_scaffold.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../billing/domain/money.dart';
import '../application/bills_controller.dart';
import '../application/bills_state.dart';
import '../domain/bill_filters.dart';
import '../domain/bill_summary.dart';

/// Bills list (Phase 3). Ports the bills page: filter, paginate, and
/// open a saved bill in the Sales Desk for editing. Ctrl+B returns to the
/// Sales Desk (parity with the footer shortcut).
class BillsPage extends ConsumerStatefulWidget {
  const BillsPage({super.key});

  @override
  ConsumerState<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends ConsumerState<BillsPage> {
  final _billIdController = TextEditingController();
  String _paymentMode = '';
  String _dateFrom = '';
  String _dateTo = '';

  @override
  void dispose() {
    _billIdController.dispose();
    super.dispose();
  }

  BillsController get _c => ref.read(billsControllerProvider.notifier);

  void _apply() {
    _c.applyFilters(
      BillFilters(
        billId: _billIdController.text.trim(),
        paymentMode: _paymentMode,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      ),
    );
  }

  void _clear() {
    _billIdController.clear();
    setState(() {
      _paymentMode = '';
      _dateFrom = '';
      _dateTo = '';
    });
    _c.clearFilters();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final ctrl =
        keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyB) {
      context.go(AppRoutes.billing.path);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billsControllerProvider);
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: ModuleScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FiltersBar(
              billIdController: _billIdController,
              paymentMode: _paymentMode,
              dateFrom: _dateFrom,
              dateTo: _dateTo,
              onPaymentModeChanged: (v) => setState(() => _paymentMode = v),
              onPickDateFrom: (v) => setState(() => _dateFrom = v),
              onPickDateTo: (v) => setState(() => _dateTo = v),
              onApply: _apply,
              onClear: _clear,
            ),
            const SizedBox(height: AppSpacing.x16),
            Expanded(
              child: AppCard(child: _BillsTable(state: state)),
            ),
            const SizedBox(height: AppSpacing.x16),
            _Pagination(state: state),
          ],
        ),
      ),
    );
  }
}

const _paymentModeOptions = ['', 'CASH', 'GPAY', 'CARD'];

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.billIdController,
    required this.paymentMode,
    required this.dateFrom,
    required this.dateTo,
    required this.onPaymentModeChanged,
    required this.onPickDateFrom,
    required this.onPickDateTo,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController billIdController;
  final String paymentMode;
  final String dateFrom;
  final String dateTo;
  final ValueChanged<String> onPaymentModeChanged;
  final ValueChanged<String> onPickDateFrom;
  final ValueChanged<String> onPickDateTo;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.x16),
      child: Wrap(
        spacing: AppSpacing.x16,
        runSpacing: AppSpacing.x8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 180,
            height: AppSizing.controlHeight,
            child: TextField(
              controller: billIdController,
              decoration: const InputDecoration(
                hintText: 'Bill ID or Amount',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onSubmitted: (_) => onApply(),
            ),
          ),
          SizedBox(
            width: 160,
            height: AppSizing.controlHeight,
            child: DropdownButtonFormField<String>(
              initialValue: paymentMode,
              isExpanded: true,
              items: _paymentModeOptions
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(m.isEmpty ? 'All Modes' : m),
                    ),
                  )
                  .toList(),
              onChanged: (v) => onPaymentModeChanged(v ?? ''),
              decoration: const InputDecoration(
                hintText: 'Payment',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          _DateField(label: 'From', value: dateFrom, onPicked: onPickDateFrom),
          _DateField(label: 'To', value: dateTo, onPicked: onPickDateTo),
          FilledButton(onPressed: onApply, child: const Text('Apply')),
          OutlinedButton(onPressed: onClear, child: const Text('Clear')),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPicked,
  });

  final String label;
  final String value;
  final ValueChanged<String> onPicked;

  Future<void> _pick(BuildContext context) async {
    final initial = DateTime.tryParse(value) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      onPicked('$y-$m-$d');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizing.controlHeight,
      child: OutlinedButton.icon(
        onPressed: () => _pick(context),
        icon: const Icon(Icons.calendar_today, size: 16),
        label: Text(value.isEmpty ? label : value),
      ),
    );
  }
}

class _BillsTable extends StatelessWidget {
  const _BillsTable({required this.state});

  final BillsState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Text(
          state.error!,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.error500,
          ),
        ),
      );
    }
    if (state.isEmptyResult) {
      return Center(
        child: Text('No bills found', style: theme.textTheme.bodyMedium),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BillsHeaderRow(),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: state.rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _BillRow(bill: state.rows[index]),
          ),
        ),
      ],
    );
  }
}

class _BillsHeaderRow extends StatelessWidget {
  const _BillsHeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.neutral700,
    );
    Widget cell(String text, int flex, {TextAlign align = TextAlign.left}) =>
        Expanded(
          flex: flex,
          child: Text(text, style: style, textAlign: align),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
      child: Row(
        children: [
          cell('Bill ID', 4),
          cell('Date & Time', 4),
          cell('Payment', 2),
          cell('Items', 2, align: TextAlign.right),
          cell('Subtotal', 2, align: TextAlign.right),
          cell('Discount', 2, align: TextAlign.right),
          cell('Total', 2, align: TextAlign.right),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill});

  final BillSummary bill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget cell(
      String text,
      int flex, {
      TextAlign align = TextAlign.left,
      TextStyle? style,
    }) => Expanded(
      flex: flex,
      child: Text(
        text,
        style: style ?? theme.textTheme.bodyMedium,
        textAlign: align,
        overflow: TextOverflow.ellipsis,
      ),
    );
    return InkWell(
      onTap: () => context.go(
        '${AppRoutes.billing.path}?billId='
        '${Uri.encodeComponent(bill.billId)}',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
        child: Row(
          children: [
            cell(bill.billId, 4),
            cell(formatBillDateTime(bill.createdAt), 4),
            cell(bill.paymentMode, 2),
            cell('${bill.itemCount}', 2, align: TextAlign.right),
            cell(Money.format(bill.subtotalPaise), 2, align: TextAlign.right),
            cell(
              '-${Money.format(bill.discountPaise)}',
              2,
              align: TextAlign.right,
            ),
            cell(
              Money.format(bill.grandTotalPaise),
              2,
              align: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pagination extends ConsumerWidget {
  const _Pagination({required this.state});

  final BillsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(billsControllerProvider.notifier);
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

/// Formats an ISO timestamp for display. Falls back to the raw value when it is
/// not a parseable date (parity with the Electron `formatDateTime`).
String formatBillDateTime(String value) {
  if (value.isEmpty) return '-';
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  final local = date.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final day = local.day.toString().padLeft(2, '0');
  final month = months[local.month - 1];
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final ampm = local.hour < 12 ? 'AM' : 'PM';
  return '$day $month ${local.year}, $hour12:$minute $ampm';
}
