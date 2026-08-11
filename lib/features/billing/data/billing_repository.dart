import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/db_connection.dart';
import '../../../core/database/db_providers.dart';
import '../domain/bill_id.dart';
import '../domain/bill_data.dart';
import '../domain/billing_enums.dart';
import '../domain/product.dart';

/// Result of a save/hold operation.
class SaveBillResult {
  const SaveBillResult({required this.billId});

  final String billId;
}

class HoldResult {
  const HoldResult({required this.holdId, required this.holdsLeft});

  final String holdId;
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

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k?.toString() ?? '', v));
    }
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k?.toString() ?? '', v));
      }
    }
    return const <String, dynamic>{};
  }

  String _jsonSqlLiteral(Map<String, dynamic> json) =>
      jsonEncode(json).replaceAll("'", "''");

  String _jsonSqlString(Map<String, dynamic> json) =>
      "'${_jsonSqlLiteral(json)}'";

  String _sqlString(String value) => "'${value.replaceAll("'", "''")}'";

  String _billSqlValues(BillData bill) {
    return [
      _sqlString(bill.billId),
      'CURRENT_TIMESTAMP',
      _sqlString(bill.paymentMode.wire),
      _sqlString(bill.discountMode.wire),
      bill.discountValue.toString(),
      bill.itemCount.toString(),
      bill.subtotalPaise.toString(),
      bill.discountPaise.toString(),
      bill.grandTotalPaise.toString(),
      _jsonSqlString(bill.toJson()),
    ].join(', ');
  }

  Future<void> _insertBill(BillData bill) async {
    await _db.execute(
      'INSERT INTO bills (bill_id, created_at, payment_mode, discount_mode, '
      'discount_value, item_count, subtotal_paise, discount_paise, '
      'grand_total_paise, bill_data) VALUES (${_billSqlValues(bill)})',
    );
  }

  Future<void> _updateBill(String billId, BillData bill) async {
    final escapedBillId = billId.replaceAll("'", "''");
    await _db.execute(
      'UPDATE bills SET '
      'payment_mode = ${_sqlString(bill.paymentMode.wire)}, '
      'discount_mode = ${_sqlString(bill.discountMode.wire)}, '
      'discount_value = ${bill.discountValue}, '
      'item_count = ${bill.itemCount}, '
      'subtotal_paise = ${bill.subtotalPaise}, '
      'discount_paise = ${bill.discountPaise}, '
      'grand_total_paise = ${bill.grandTotalPaise}, '
      'bill_data = ${_jsonSqlString(bill.toJson())}, '
      'updated_at = CURRENT_TIMESTAMP '
      "WHERE bill_id = '$escapedBillId'",
    );
  }

  /// Deducts inventory for each item in the bill based on pricingType.
  /// Updates inv_current_qty for unit items, inv_current_weight for weight items.
  /// Allows inventory to go negative (no validation).
  Future<void> _deductInventoryForBill(BillData bill) async {
    for (final item in bill.items) {
      final escapedId = item.id.replaceAll("'", "''");
      if (item.pricingType.wire == 'weight') {
        await _db.execute(
          'UPDATE products SET inv_current_weight = inv_current_weight - ${item.qty} '
          "WHERE id = '$escapedId'",
        );
      } else {
        await _db.execute(
          'UPDATE products SET inv_current_qty = inv_current_qty - ${item.qty} '
          "WHERE id = '$escapedId'",
        );
      }
    }
  }

  /// Gets the old bill data to calculate inventory delta on update.
  Future<BillData?> _getBillDataById(String billId) async {
    final escapedBillId = billId.replaceAll("'", "''");
    final rows = await _db.query(
      "SELECT bill_data FROM bills WHERE bill_id = '$escapedBillId' LIMIT 1",
    );
    if (rows.isEmpty) return null;
    final data = _asMap(rows.first['bill_data'] ?? rows.first['billData']);
    return _parseBillDataFromJson(data);
  }

  /// Parses BillData from JSON (minimal parsing to get items).
  BillData? _parseBillDataFromJson(Map<String, dynamic> json) {
    try {
      final items = (json['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final billItems = items.map((item) {
        return BillItem(
          id: (item['id'] ?? '').toString(),
          sku: (item['sku'] ?? '').toString(),
          name: (item['name'] ?? '').toString(),
          nameTa: (item['nameTa'] ?? '').toString(),
          brandName: (item['brandName'] ?? '').toString(),
          category: (item['category'] ?? 'UNCATEGORIZED').toString(),
          pricingType: (item['pricingType'] ?? 'unit') == 'weight'
              ? PricingType.weight
              : PricingType.unit,
          qty: (item['qty'] is num) ? item['qty'] : num.tryParse('${item['qty']}') ?? 0,
          retailPricePaise: (item['retailPricePaise'] is num)
              ? (item['retailPricePaise'] as num).toInt()
              : int.tryParse('${item['retailPricePaise']}') ?? 0,
          wholesalePricePaise: (item['wholesalePricePaise'] is num)
              ? (item['wholesalePricePaise'] as num).toInt()
              : int.tryParse('${item['wholesalePricePaise']}'),
          wholesaleMinQty: (item['wholesaleMinQty'] is num)
              ? item['wholesaleMinQty']
              : num.tryParse('${item['wholesaleMinQty']}'),
          priceTier: (item['priceTier'] ?? 'retail') == 'wholesale'
              ? PriceTier.wholesale
              : PriceTier.retail,
          ratePaise: (item['rate'] is num)
              ? (item['rate'] as num).toInt()
              : int.tryParse('${item['rate']}') ?? 0,
          lineTotalPaise: (item['lineTotalPaise'] is num)
              ? (item['lineTotalPaise'] as num).toInt()
              : int.tryParse('${item['lineTotalPaise']}') ?? 0,
        );
      }).toList();

      return BillData(
        billId: (json['billId'] ?? '').toString(),
        paymentMode: PaymentMode.fromWire(json['paymentMode'] ?? 'CASH'),
        discountMode: DiscountMode.fromWire(json['discountMode'] ?? 'PERCENT'),
        discountValue: (json['discountValue'] is num)
            ? json['discountValue']
            : num.tryParse('${json['discountValue']}') ?? 0,
        itemCount: (json['itemCount'] is num)
            ? (json['itemCount'] as num).toInt()
            : int.tryParse('${json['itemCount']}') ?? 0,
        subtotalPaise: (json['subtotalPaise'] is num)
            ? (json['subtotalPaise'] as num).toInt()
            : int.tryParse('${json['subtotalPaise']}') ?? 0,
        discountPaise: (json['discountPaise'] is num)
            ? (json['discountPaise'] as num).toInt()
            : int.tryParse('${json['discountPaise']}') ?? 0,
        grandTotalPaise: (json['grandTotalPaise'] is num)
            ? (json['grandTotalPaise'] as num).toInt()
            : int.tryParse('${json['grandTotalPaise']}') ?? 0,
        items: billItems,
        createdAt: (json['createdAt'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Calculates and applies the inventory delta between old and new bill.
  /// Reverts the old inventory and applies the new inventory.
  Future<void> _applyInventoryDelta(String billId, BillData newBill) async {
    final oldBill = await _getBillDataById(billId);
    if (oldBill == null) {
      // If we can't get old bill, just deduct new bill normally
      await _deductInventoryForBill(newBill);
      return;
    }

    // Build a map of old quantities by product id
    final oldQtyMap = <String, (num, String)>{};
    for (final item in oldBill.items) {
      oldQtyMap[item.id] = (item.qty, item.pricingType.wire);
    }

    // Process new bill items: revert old, apply new
    for (final item in newBill.items) {
      final escapedId = item.id.replaceAll("'", "''");
      if (oldQtyMap.containsKey(item.id)) {
        final (oldQty, pricingType) = oldQtyMap[item.id]!;
        final delta = item.qty - oldQty;
        if (item.pricingType.wire == 'weight') {
          await _db.execute(
            'UPDATE products SET inv_current_weight = inv_current_weight - $delta '
            "WHERE id = '$escapedId'",
          );
        } else {
          await _db.execute(
            'UPDATE products SET inv_current_qty = inv_current_qty - $delta '
            "WHERE id = '$escapedId'",
          );
        }
      } else {
        // New item in the bill, deduct full amount
        if (item.pricingType.wire == 'weight') {
          await _db.execute(
            'UPDATE products SET inv_current_weight = inv_current_weight - ${item.qty} '
            "WHERE id = '$escapedId'",
          );
        } else {
          await _db.execute(
            'UPDATE products SET inv_current_qty = inv_current_qty - ${item.qty} '
            "WHERE id = '$escapedId'",
          );
        }
      }
    }

    // Handle removed items (items in old but not in new)
    final newIdSet = newBill.items.map((item) => item.id).toSet();
    for (final entry in oldQtyMap.entries) {
      if (!newIdSet.contains(entry.key)) {
        final (oldQty, pricingType) = entry.value;
        final escapedId = entry.key.replaceAll("'", "''");
        if (pricingType == 'weight') {
          await _db.execute(
            'UPDATE products SET inv_current_weight = inv_current_weight + $oldQty '
            "WHERE id = '$escapedId'",
          );
        } else {
          await _db.execute(
            'UPDATE products SET inv_current_qty = inv_current_qty + $oldQty '
            "WHERE id = '$escapedId'",
          );
        }
      }
    }
  }

  Future<List<Product>> searchProducts(String query, {int limit = 8}) async {
    final escapedQuery = query.replaceAll("'", "''").toLowerCase();
    final rows = await _db.query(
      "SELECT * FROM products WHERE LOWER(name) LIKE '%$escapedQuery%' OR LOWER(sku) LIKE '%$escapedQuery%' OR LOWER(COALESCE(barcode, '')) LIKE '%$escapedQuery%' LIMIT $limit",
    );
    return rows.map(Product.fromJson).toList();
  }

  Future<Product?> findExactProduct(String query) async {
    final escapedQuery = query.replaceAll("'", "''");
    final rows = await _db.query(
      "SELECT * FROM products WHERE sku = '$escapedQuery' OR name = '$escapedQuery' OR barcode = '$escapedQuery' LIMIT 1",
    );
    return rows.isEmpty ? null : Product.fromJson(rows.first);
  }

  Future<SaveBillResult> saveBill(BillData bill) async {
    await _insertBill(bill);
    await _deductInventoryForBill(bill);
    return SaveBillResult(billId: bill.billId);
  }

  Future<HoldResult> holdBill(BillData bill) async {
    final holdId =
        'hold-${BillId.generate()}-${DateTime.now().microsecondsSinceEpoch}';
    final escapedHoldId = holdId.replaceAll("'", "''");
    await _db.execute(
      "INSERT INTO bill_holds (hold_id, bill_id, bill_data, created_at) VALUES ('$escapedHoldId', '${bill.billId.replaceAll("'", "''")}', ${_jsonSqlString(bill.toJson())}, CURRENT_TIMESTAMP)",
    );
    final countResult = await _db.query(
      'SELECT COUNT(*) as count FROM bill_holds',
    );
    final holdsLeft = (countResult.isNotEmpty
        ? int.parse(countResult.first['count'].toString())
        : 0);
    return HoldResult(holdId: holdId, holdsLeft: holdsLeft);
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
          " AND (payment_mode = '$escapedPaymentMode' OR "
          "JSON_UNQUOTE(JSON_EXTRACT(bill_data, '\$.paymentMode')) = '$escapedPaymentMode')";
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

    final rows =
        (await _db.query(
              'SELECT bill_id AS billId, bill_data AS billData, created_at AS createdAt, '
              'payment_mode AS paymentMode, discount_mode AS discountMode, '
              'discount_value AS discountValue, item_count AS itemCount, '
              'subtotal_paise AS subtotalPaise, discount_paise AS discountPaise, '
              'grand_total_paise AS grandTotalPaise '
              'FROM bills $whereClause ORDER BY created_at DESC LIMIT $pageSize OFFSET $offset',
            ))
            .map(
              (row) => <String, dynamic>{
                ...row,
                'billData': _asMap(row['billData'] ?? row['bill_data']),
              },
            )
            .toList();

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
    return _asMap(rows.first['bill_data'] ?? rows.first['billData']);
  }

  Future<void> updateBill(String billId, BillData bill) async {
    await _updateBill(billId, bill);
    await _applyInventoryDelta(billId, bill);
  }

  Future<void> deleteBill(String billId) async {
    final escapedBillId = billId.replaceAll("'", "''");
    await _db.execute("DELETE FROM bills WHERE bill_id = '$escapedBillId'");
  }

  Future<HeldBillsPage> listHeldBills({int limit = 3}) async {
    final rows = await _db.query(
      'SELECT hold_id AS holdId, bill_id AS billId, bill_data AS billData, '
      'created_at AS createdAt FROM bill_holds ORDER BY created_at DESC LIMIT $limit',
    );
    final summaries = rows.map((row) {
      final data = _asMap(row['billData'] ?? row['bill_data']);
      return HeldBillSummary(
        holdId: (row['holdId'] ?? row['hold_id'] ?? '').toString(),
        billId: (data['billId'] ?? row['billId'] ?? row['bill_id'] ?? '')
            .toString(),
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
    return _asMap(rows.first['bill_data'] ?? rows.first['billData']);
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
