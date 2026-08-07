import 'package:flutter/foundation.dart';

import '../domain/bill_filters.dart';
import '../domain/bill_summary.dart';

/// Immutable state for the Bills list. Pagination math mirrors
/// `bills-page-controller.js` (`getTotalPages`, prev/next enablement).
@immutable
class BillsState {
  const BillsState({
    this.page = 1,
    this.pageSize = 10,
    this.total = 0,
    this.filters = BillFilters.empty,
    this.rows = const [],
    this.loading = false,
    this.error,
  });

  final int page;
  final int pageSize;
  final int total;
  final BillFilters filters;
  final List<BillSummary> rows;
  final bool loading;

  /// Non-null when the last load failed.
  final String? error;

  /// `Math.max(1, Math.ceil(total / pageSize))`.
  int get totalPages => total <= 0 ? 1 : ((total + pageSize - 1) ~/ pageSize);

  bool get canPrev => page > 1;
  bool get canNext => page < totalPages;
  bool get isEmptyResult => !loading && error == null && rows.isEmpty;

  BillsState copyWith({
    int? page,
    int? pageSize,
    int? total,
    BillFilters? filters,
    List<BillSummary>? rows,
    bool? loading,
    Object? error = _noError,
  }) {
    return BillsState(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      total: total ?? this.total,
      filters: filters ?? this.filters,
      rows: rows ?? this.rows,
      loading: loading ?? this.loading,
      error: identical(error, _noError) ? this.error : error as String?,
    );
  }

  static const _noError = Object();
}
