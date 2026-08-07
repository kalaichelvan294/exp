import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../billing/data/billing_repository.dart';
import '../domain/bill_filters.dart';
import '../domain/bill_summary.dart';
import 'bills_state.dart';

/// Bills list controller. Ports the interaction model from the Electron
/// `bills-page-controller.js`: filter/apply/clear, pagination, and post-load
/// page clamping.
class BillsController extends Notifier<BillsState> {
  BillingRepository get _repo => ref.read(billingRepositoryProvider);

  @override
  BillsState build() {
    Future.microtask(loadBills);
    return const BillsState();
  }

  Future<void> loadBills() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await _repo.listBills(
        page: state.page,
        pageSize: state.pageSize,
        billId: state.filters.billId,
        paymentMode: state.filters.paymentMode,
        dateFrom: state.filters.dateFrom,
        dateTo: state.filters.dateTo,
      );

      // Clamp to the last page if the current page overshoots (parity).
      final totalPages =
          result.total <= 0 ? 1 : ((result.total + state.pageSize - 1) ~/ state.pageSize);
      if (state.page > totalPages) {
        state = state.copyWith(page: totalPages);
        return loadBills();
      }

      state = state.copyWith(
        total: result.total,
        rows: result.rows.map(BillSummary.fromRow).toList(),
        loading: false,
        error: null,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message, rows: const []);
    }
  }

  /// Applies the given filters and reloads from page 1.
  Future<void> applyFilters(BillFilters filters) async {
    state = state.copyWith(filters: filters, page: 1);
    await loadBills();
  }

  /// Clears all filters and reloads from page 1.
  Future<void> clearFilters() async {
    state = state.copyWith(filters: BillFilters.empty, page: 1);
    await loadBills();
  }

  Future<void> nextPage() async {
    if (!state.canNext) return;
    state = state.copyWith(page: state.page + 1);
    await loadBills();
  }

  Future<void> prevPage() async {
    if (!state.canPrev) return;
    state = state.copyWith(page: state.page - 1);
    await loadBills();
  }
}

final billsControllerProvider =
    NotifierProvider<BillsController, BillsState>(BillsController.new);
