import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../data/reports_repository.dart';
import '../domain/report_filters.dart';
import 'reports_state.dart';

/// Reports controller. Ports reports.js: period/filter changes prompt a refresh,
/// and Refresh builds the payload and loads analytics with parity messaging.
class ReportsController extends Notifier<ReportsState> {
  ReportsRepository get _repo => ref.read(reportsRepositoryProvider);

  @override
  ReportsState build() {
    return ReportsState(
      filters: ReportFilters(
        month: ReportDates.currentMonth(),
        day: ReportDates.today(),
        week: ReportDates.currentWeek(),
        dateFrom: ReportDates.today(),
        dateTo: ReportDates.today(),
      ),
    );
  }

  static const _changedMessage =
      ReportsMessage('Filters changed. Click Refresh to load analytics.');

  void setPeriod(ReportPeriod period) {
    state = state.copyWith(
      filters: state.filters.copyWith(period: period),
      message: _changedMessage,
    );
  }

  void setMonth(String value) => _updateFilter(month: value);
  void setDay(String value) => _updateFilter(day: value);
  void setWeek(String value) => _updateFilter(week: value);
  void setDateFrom(String value) => _updateFilter(dateFrom: value);
  void setDateTo(String value) => _updateFilter(dateTo: value);

  void _updateFilter({
    String? month,
    String? day,
    String? week,
    String? dateFrom,
    String? dateTo,
  }) {
    state = state.copyWith(
      filters: state.filters.copyWith(
        month: month,
        day: day,
        week: week,
        dateFrom: dateFrom,
        dateTo: dateTo,
      ),
      message: _changedMessage,
    );
  }

  Future<void> refresh() async {
    final Map<String, dynamic> payload;
    try {
      payload = state.filters.buildPayload();
    } on ReportFilterException catch (e) {
      state = state.copyWith(
          message: ReportsMessage(e.message, isError: true));
      return;
    }

    state = state.copyWith(
      loading: true,
      message: const ReportsMessage('Loading analytics...'),
    );
    try {
      final analytics = await _repo.getAnalytics(payload);
      state = state.copyWith(
        analytics: analytics,
        loading: false,
        message: const ReportsMessage('Analytics loaded.'),
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        analytics: null,
        loading: false,
        message: ReportsMessage(e.message, isError: true),
      );
    }
  }
}

final reportsControllerProvider =
    NotifierProvider<ReportsController, ReportsState>(ReportsController.new);
