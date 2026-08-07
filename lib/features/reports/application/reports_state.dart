import 'package:flutter/foundation.dart';

import '../domain/analytics.dart';
import '../domain/report_filters.dart';

/// A user-facing status message with an error flag (parity with reports.js
/// setMessage / error-message styling).
@immutable
class ReportsMessage {
  const ReportsMessage(this.text, {this.isError = false});
  final String text;
  final bool isError;

  static const initial =
      ReportsMessage('Select filters and click Refresh.');
}

@immutable
class ReportsState {
  const ReportsState({
    this.filters = const ReportFilters(),
    this.analytics,
    this.loading = false,
    this.message = ReportsMessage.initial,
  });

  final ReportFilters filters;
  final Analytics? analytics;
  final bool loading;
  final ReportsMessage message;

  ReportsState copyWith({
    ReportFilters? filters,
    Object? analytics = _sentinel,
    bool? loading,
    ReportsMessage? message,
  }) {
    return ReportsState(
      filters: filters ?? this.filters,
      analytics: identical(analytics, _sentinel)
          ? this.analytics
          : analytics as Analytics?,
      loading: loading ?? this.loading,
      message: message ?? this.message,
    );
  }

  static const _sentinel = Object();
}
