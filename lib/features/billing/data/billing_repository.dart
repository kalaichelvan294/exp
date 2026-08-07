import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_providers.dart';
import '../domain/bill_data.dart';
import '../domain/product.dart';

/// Result of a save/hold operation.
class SaveBillResult {
  const SaveBillResult({required this.billId});

  final String billId;
}

class HoldResult {
  const HoldResult({required this.holdsLeft});
  final int holdsLeft;
}

/// A page of saved bills returned by [BillingRepository.listBills].
///
/// [rows] are the raw bill rows (`{billId, billData, createdAt}`) so the Bills
/// domain can map them without the data layer depending on presentation models.
class BillListResult {
  const BillListResult({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.rows,
  });

  final int total;
  final int page;
  final int pageSize;
  final List<Map<String, dynamic>> rows;
}

/// A held-bill summary chip shown on the Sales Desk.
class HeldBillSummary {
  const HeldBillSummary({
    required this.holdId,
    required this.billId,
    required this.grandTotalPaise,
    required this.raw,
  });

  final String holdId;
  final String billId;
  final int grandTotalPaise;

  /// Full `billData` map, used when resuming.
  final Map<String, dynamic> raw;
}

class HeldBillsPage {
  const HeldBillsPage({required this.rows, required this.holdsLeft});
  final List<HeldBillSummary> rows;
  final int holdsLeft;
}

/// API-bridge backed data source for the Sales Desk (Phase 2 scope).
class BillingRepository {
  BillingRepository(this._api);

  final ApiClient _api;

  Future<List<Product>> searchProducts(String query, {int limit = 8}) async {
    final response = await _api.postJson(
      ApiEndpoints.productsSearch,
      body: {'query': query, 'limit': limit},
    );
    return _asList(response)
        .whereType<Map<String, dynamic>>()
        .map(Product.fromJson)
        .toList();
  }

  Future<Product?> findExactProduct(String query) async {
    final response = await _api.postJson(
      ApiEndpoints.productsFindExact,
      body: {'query': query},
    );
    final data = response['data'] ?? response;
    if (data is Map<String, dynamic> && data['id'] != null) {
      return Product.fromJson(data);
    }
    return null;
  }

  Future<SaveBillResult> saveBill(BillData bill) async {
    final response = await _api.postJson(
      ApiEndpoints.billingSave,
      body: bill.toJson(),
    );
    return SaveBillResult(
      billId: _resolveBillId(response, fallback: bill.billId),
    );
  }

  Future<HoldResult> holdBill(BillData bill) async {
    final response = await _api.postJson(
      ApiEndpoints.billingHold,
      body: bill.toJson(),
    );
    return HoldResult(holdsLeft: _asInt(response['holdsLeft']));
  }

  // ── Saved bills (Phase 3) ─────────────────────────────────────────────────

  /// Lists saved bills with optional filters (parity with `billing:list`).
  Future<BillListResult> listBills({
    int page = 1,
    int pageSize = 10,
    String billId = '',
    String paymentMode = '',
    String dateFrom = '',
    String dateTo = '',
  }) async {
    final response = await _api.getJson(
      ApiEndpoints.billingList,
      query: {
        'page': page,
        'pageSize': pageSize,
        'billId': billId,
        'paymentMode': paymentMode,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
      },
    );
    return BillListResult(
      total: _asInt(response['total']),
      page: response.containsKey('page') ? _asInt(response['page']) : page,
      pageSize: response.containsKey('pageSize')
          ? _asInt(response['pageSize'])
          : pageSize,
      rows: _asList(response['rows'] ?? response)
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }

  /// Fetches a single saved bill and returns its raw `billData` map.
  Future<Map<String, dynamic>> getBill(String billId) async {
    final response = await _api.getJson(ApiEndpoints.billingGet(billId));
    final data = response['billData'];
    if (data is Map<String, dynamic>) return data;
    throw StateError('Bill $billId was not found.');
  }

  /// Updates a saved bill (parity with `billing:update`).
  Future<void> updateBill(String billId, BillData bill) async {
    await _api.putJson(
      ApiEndpoints.billingUpdate(billId),
      body: bill.toJson(),
    );
  }

  /// Deletes a saved bill (parity with `billing:delete`).
  Future<void> deleteBill(String billId) async {
    await _api.deleteJson(ApiEndpoints.billingDelete(billId));
  }

  Future<HeldBillsPage> listHeldBills({int limit = 3}) async {
    final response = await _api.getJson(
      ApiEndpoints.billingListHolds,
      query: {'limit': limit},
    );
    final rows = _asList(response['rows']).whereType<Map<String, dynamic>>();
    final summaries = rows.map((row) {
      final data = (row['billData'] as Map<String, dynamic>?) ?? const {};
      return HeldBillSummary(
        holdId: (row['holdId'] ?? '').toString(),
        billId: (data['billId'] ?? row['holdId'] ?? '').toString(),
        grandTotalPaise: _asInt(data['grandTotalPaise']),
        raw: data,
      );
    }).toList();
    final holdsLeft = response.containsKey('holdsLeft')
        ? _asInt(response['holdsLeft'])
        : (limit - summaries.length).clamp(0, limit);
    return HeldBillsPage(rows: summaries, holdsLeft: holdsLeft);
  }

  /// Resumes a held bill and returns its raw `billData` map.
  Future<Map<String, dynamic>> resumeHeldBill(String holdId) async {
    final response = await _api.postJson(ApiEndpoints.billingResumeHold(holdId));
    final hold = response['hold'];
    if (hold is Map<String, dynamic> &&
        hold['billData'] is Map<String, dynamic>) {
      return hold['billData'] as Map<String, dynamic>;
    }
    throw StateError('Held bill was not found.');
  }

  Future<void> deleteHeldBill(String holdId) async {
    await _api.deleteJson(ApiEndpoints.billingDeleteHold(holdId));
  }

  String _resolveBillId(Map<String, dynamic> result, {required String fallback}) {
    for (final key in ['billId', 'bill_id', 'id']) {
      final value = result[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return fallback;
  }

  List<dynamic> _asList(Object? value) {
    if (value is List) return value;
    if (value is Map<String, dynamic>) {
      final data = value['data'] ?? value['rows'];
      if (data is List) return data;
    }
    return const [];
  }

  int _asInt(Object? value) =>
      value is num ? value.round() : int.tryParse('$value') ?? 0;
}

final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => BillingRepository(ref.watch(apiClientProvider)),
);
