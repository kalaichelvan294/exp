import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/module_scaffold.dart';
import '../../../core/theme/app_tokens.dart';
import '../../billing/domain/money.dart';
import '../../billing/presentation/widgets/app_card.dart';
import '../application/reports_controller.dart';
import '../application/reports_state.dart';
import '../domain/analytics.dart';
import '../domain/report_filters.dart';
import 'widgets/sales_line_chart.dart';

/// Reports module (Phase 5). Ports reports.js: period filters, KPI summary,
/// sales trend / hourly / weekday line charts, and the top-sold-items table.
class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportsControllerProvider);
    final controller = ref.read(reportsControllerProvider.notifier);
    return ModuleScaffold(
      title: 'Reports',
      description: 'Daily, weekly, monthly, and custom sales analytics.',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FiltersCard(state: state, controller: controller),
            const SizedBox(height: AppSpacing.x8),
            _MessageLine(message: state.message),
            const SizedBox(height: AppSpacing.x16),
            if (state.analytics != null)
              _AnalyticsView(analytics: state.analytics!),
          ],
        ),
      ),
    );
  }
}

class _MessageLine extends StatelessWidget {
  const _MessageLine({required this.message});
  final ReportsMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      message.text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: message.isError ? AppColors.error500 : AppColors.neutral500,
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({required this.state, required this.controller});

  final ReportsState state;
  final ReportsController controller;

  @override
  Widget build(BuildContext context) {
    final filters = state.filters;
    return AppCard(
      child: Wrap(
        spacing: AppSpacing.x16,
        runSpacing: AppSpacing.x16,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<ReportPeriod>(
              isExpanded: true,
              initialValue: filters.period,
              decoration: const InputDecoration(labelText: 'Period'),
              items: const [
                DropdownMenuItem(
                    value: ReportPeriod.daily, child: Text('Daily')),
                DropdownMenuItem(
                    value: ReportPeriod.weekly, child: Text('Weekly')),
                DropdownMenuItem(
                    value: ReportPeriod.monthly, child: Text('Monthly')),
                DropdownMenuItem(
                    value: ReportPeriod.custom, child: Text('Custom Range')),
              ],
              onChanged: (v) {
                if (v != null) controller.setPeriod(v);
              },
            ),
          ),
          ..._periodInputs(context, filters),
          FilledButton.icon(
            onPressed: state.loading ? null : controller.refresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  List<Widget> _periodInputs(BuildContext context, ReportFilters filters) {
    switch (filters.period) {
      case ReportPeriod.monthly:
        return [
          _TextFilter(
            key: const ValueKey('month'),
            label: 'Month (YYYY-MM)',
            value: filters.month,
            onChanged: controller.setMonth,
          ),
        ];
      case ReportPeriod.daily:
        return [
          _DateFilter(
            label: 'Day',
            value: filters.day,
            onChanged: controller.setDay,
          ),
        ];
      case ReportPeriod.weekly:
        return [
          _TextFilter(
            key: const ValueKey('week'),
            label: 'Week (YYYY-Www)',
            value: filters.week,
            onChanged: controller.setWeek,
          ),
        ];
      case ReportPeriod.custom:
        return [
          _DateFilter(
            label: 'From',
            value: filters.dateFrom,
            onChanged: controller.setDateFrom,
          ),
          _DateFilter(
            label: 'To',
            value: filters.dateTo,
            onChanged: controller.setDateTo,
          ),
        ];
    }
  }
}

class _TextFilter extends StatefulWidget {
  const _TextFilter({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TextFilter> createState() => _TextFilterState();
}

class _TextFilterState extends State<_TextFilter> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(labelText: widget.label),
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _DateFilter extends StatelessWidget {
  const _DateFilter({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  Future<void> _pick(BuildContext context) async {
    final initial = DateTime.tryParse(value) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onChanged(picked.toIso8601String().substring(0, 10));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: InkWell(
        onTap: () => _pick(context),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today, size: 16),
          ),
          child: Text(value.isEmpty ? '—' : value),
        ),
      ),
    );
  }
}

class _AnalyticsView extends StatelessWidget {
  const _AnalyticsView({required this.analytics});

  final Analytics analytics;

  bool get _showHour =>
      analytics.period != 'weekly' && analytics.period != 'monthly';
  bool get _showWeekday => analytics.period != 'daily';

  String get _trendTitle {
    switch (analytics.period) {
      case 'daily':
        return 'Hourly Sales Trend (Daily)';
      case 'weekly':
        return 'Weekday Sales Trend (Weekly)';
      case 'custom':
        return 'Daily Sales Trend (Custom Range)';
      default:
        return 'Daily Sales Trend (Monthly)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final kpis = analytics.kpis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.x16,
          runSpacing: AppSpacing.x16,
          children: [
            _KpiCard(
                label: 'Total Sales',
                value: Money.format(kpis.totalSalesPaise)),
            _KpiCard(label: 'Total Bills', value: '${kpis.totalBills}'),
            _KpiCard(
                label: 'Total Discount',
                value: Money.format(kpis.totalDiscountPaise)),
            _KpiCard(label: 'Peak Hour', value: analytics.peakHour),
            _KpiCard(label: 'Peak Weekday', value: analytics.peakWeekday),
          ],
        ),
        const SizedBox(height: AppSpacing.x16),
        _ChartSection(
          title: _trendTitle,
          rows: analytics.trend,
          formatter: (row) =>
              '${Money.format(row.totalSalesPaise)} (${row.billCount} bills)',
          emptyText: 'No sales trend for selected period.',
        ),
        const SizedBox(height: AppSpacing.x16),
        _TopItemsSection(rows: analytics.topSoldItems),
        if (_showHour) ...[
          const SizedBox(height: AppSpacing.x16),
          _ChartSection(
            title: 'Sales by Hour',
            rows: analytics.salesByHour,
            formatter: (row) =>
                '${Money.format(row.totalSalesPaise)} (${row.billCount})',
            emptyText: 'No hourly sales data.',
          ),
        ],
        if (_showWeekday) ...[
          const SizedBox(height: AppSpacing.x16),
          _ChartSection(
            title: 'Sales by Weekday',
            rows: analytics.salesByWeekday,
            formatter: (row) =>
                '${Money.format(row.totalSalesPaise)} (${row.billCount})',
            emptyText: 'No weekday sales data.',
          ),
        ],
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 200,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.neutral500)),
            const SizedBox(height: AppSpacing.x4),
            Text(value,
                style: theme.textTheme.headlineMedium,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.title,
    required this.rows,
    required this.formatter,
    required this.emptyText,
  });

  final String title;
  final List<SalesPoint> rows;
  final String Function(SalesPoint) formatter;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.x16),
          SalesLineChart(
              rows: rows, formatter: formatter, emptyText: emptyText),
        ],
      ),
    );
  }
}

class _TopItemsSection extends StatelessWidget {
  const _TopItemsSection({required this.rows});

  final List<TopSoldItem> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.bodyMedium
        ?.copyWith(fontWeight: FontWeight.w600, color: AppColors.neutral700);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Top Sold Items', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.x16),
          Row(
            children: [
              Expanded(flex: 4, child: Text('Item', style: headerStyle)),
              Expanded(flex: 2, child: Text('Type', style: headerStyle)),
              Expanded(
                  flex: 2,
                  child: Text('Qty',
                      style: headerStyle, textAlign: TextAlign.right)),
              Expanded(
                  flex: 3,
                  child: Text('Sales',
                      style: headerStyle, textAlign: TextAlign.right)),
            ],
          ),
          const Divider(),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x16),
              child: Text('No item sales for selected period.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.neutral500)),
            )
          else
            ...rows.map((row) => Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.x4),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 4,
                          child: Text(row.name,
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis)),
                      Expanded(
                          flex: 2,
                          child: Text(row.pricingType,
                              style: theme.textTheme.bodyMedium)),
                      Expanded(
                          flex: 2,
                          child: Text(row.qtyDisplay,
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.right)),
                      Expanded(
                          flex: 3,
                          child: Text(Money.format(row.totalSalesPaise),
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.right)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
