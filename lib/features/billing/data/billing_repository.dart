import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/db_connection.dart';
import '../../../core/database/db_providers.dart';
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

class BillingRepository {
  BillingRepository(this._db);

  final DbConnection _db;

  Future<List<Product>> searchProducts(String query, {int limit = 8}) async {
    final escapedQuery = query.replaceAll("'", "''").toLowerCase();
    final rows = await _db.query(
      "SELECT * FROM products WHERE LOWER(name) LIKE '%$escapedQuery%' OR LOWER(sku) LIKE '%$escapedQuery%' LIMIT $limit",
    );
    return rows.map(Product.fromJson).toList();
  }

  Future<Product?> findExactProduct(String query) async {
    final escapedQuery = query.replaceAll("'", "''");
    final rows = await _db.query(
      "SELECT * FROM products WHERE sku = '$escapedQuery' OR name = '$escapedQuery' LIMIT 1",
    );
    return rows.isEmpty ? null : Product.fromJson(rows.first);
  }

  Future<SaveBillResult> saveBill(BillData bill) async {
    final escapedBillId = bill.billId.replaceAll("'", "''");
    final billDataStr = bill.toJson().toString().replaceAll("'", "''");
    await _db.execute(
      "INSERT INTO bills (bill_id, bill_data, created_at) VALUES ('$escapedBillId', '$billDataStr', CURRENT_TIMESTAMP)",
    );
    return SaveBillResult(billId: escapedBillId);
  }

  Future<HoldResult> holdBill(BillData bill) async {
    final escapedBillId = bill.billId.replaceAll("'", "''");
    final billDataStr = bill.toJson().toString().replaceAll("'", "''");
    await _db.execute(
      "INSERT INTO bill_holds (bill_id, bill_data, created_at) VALUES ('$escapedBillId', '$billDataStr', CURRENT_TIMESTAMP)",
    );
    final countResult = await _db.query(
      'SELECT COUNT(*) as count FROM bill_holds',
    );
    final holdsLeft = (countResult.isNotEmpty
        ? int.parse(countResult.first['count'].toString())
        : 0);
    return HoldResult(holdsLeft: holdsLeft);
  }

  Future<BillListResult> listBills({
    int page = 1,
    int pageSize = 10,
    String billId = '',
    String paymentMode = '',
    String dateFrom = '',
    String dateTo = '',
  }) async {
    final offset = (page - 1) * pageSize;
    String whereClause = 'WHERE 1=1';

    if (billId.isNotEmpty) {
      final escapedBillId = billId.replaceAll("'", "''");
      whereClause += " AND bill_id LIKE '%$escapedBillId%'";
    }
    if (paymentMode.isNotEmpty) {
      final escapedPaymentMode = paymentMode.replaceAll("'", "''");
      whereClause +=
          " AND JSON_UNQUOTE(JSON_EXTRACT(bill_data, '\$.paymentMode')) = '$escapedPaymentMode'";
    }
    if (dateFrom.isNotEmpty) {
      whereClause += " AND created_at >= '$dateFrom'";
    }
    if (dateTo.isNotEmpty) {
      whereClause += " AND created_at <= '$dateTo'";
    }

    final totalResult = await _db.query(
      'SELECT COUNT(*) as count FROM bills $whereClause',
    );
    final total = totalResult.isNotEmpty
        ? int.parse(totalResult.first['count'].toString())
        : 0;

    final rows = await _db.query(
      'SELECT bill_id, bill_data, created_at FROM bills $whereClause ORDER BY created_at DESC LIMIT $pageSize OFFSET $offset',
    );

    return BillListResult(
      total: total,
      page: page,
      pageSize: pageSize,
      rows: rows,
    );
  }

  Future<Map<String, dynamic>> getBill(String billId) async {
    final escapedBillId = billId.replaceAll("'", "''");
    final rows = await _db.query(
      "SELECT bill_data FROM bills WHERE bill_id = '$escapedBillId' LIMIT 1",
    );
    if (rows.isEmpty) throw StateError('Bill $billId was not found.');
    return rows.first['bill_data'] as Map<String, dynamic>;
  }

  Future<void> updateBill(String billId, BillData bill) async {
    final escapedBillId = billId.replaceAll("'", "''");
    final billDataStr = bill.toJson().toString().replaceAll("'", "''");
    await _db.execute(
      "UPDATE bills SET bill_data = '$billDataStr', updated_at = CURRENT_TIMESTAMP WHERE bill_id = '$escapedBillId'",
    );
  }

  Future<void> deleteBill(String billId) async {
    final escapedBillId = billId.replaceAll("'", "''");
    await _db.execute("DELETE FROM bills WHERE bill_id = '$escapedBillId'");
  }

  Future<HeldBillsPage> listHeldBills({int limit = 3}) async {
    final rows = await _db.query(
      'SELECT hold_id, bill_id, bill_data FROM bill_holds ORDER BY created_at DESC LIMIT $limit',
    );
    final summaries = rows.map((row) {
      final data = (row['bill_data'] as Map<String, dynamic>?) ?? const {};
      return HeldBillSummary(
        holdId: (row['hold_id'] ?? '').toString(),
        billId: (data['billId'] ?? row['bill_id'] ?? '').toString(),
        grandTotalPaise:
            int.tryParse(data['grandTotalPaise']?.toString() ?? '0') ?? 0,
        raw: data,
      );
    }).toList();
    final holdsLeft = (limit - summaries.length).clamp(0, limit);
    return HeldBillsPage(rows: summaries, holdsLeft: holdsLeft);
  }

  Future<Map<String, dynamic>> resumeHeldBill(String holdId) async {
    final escapedHoldId = holdId.replaceAll("'", "''");
    final rows = await _db.query(
      "SELECT bill_data FROM bill_holds WHERE hold_id = '$escapedHoldId' LIMIT 1",
    );
    if (rows.isEmpty) throw StateError('Held bill was not found.');
    return rows.first['bill_data'] as Map<String, dynamic>;
  }

  Future<void> deleteHeldBill(String holdId) async {
    final escapedHoldId = holdId.replaceAll("'", "''");
    await _db.execute(
      "DELETE FROM bill_holds WHERE hold_id = '$escapedHoldId'",
    );
  }
}

final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => BillingRepository(ref.watch(dbConnectionProvider)),
);
