import 'bulk_enums.dart';

// Apply result models. Parity with mapBulkApplyResponse (main.js) and the
// item/inventory result row rendering in bulk-controller.js.

/// A single apply-result row.
class BulkResultRow {
  const BulkResultRow({
    required this.rowNumber,
    required this.outcome,
    this.slno = '',
    this.sku = '',
    this.name = '',
    this.operation = '',
    this.action = '',
    this.message = '',
    this.trackType = '',
    this.prevQty,
    this.prevWeight,
    this.newQty,
    this.newWeight,
  });

  final int rowNumber;
  final BulkRowOutcome outcome;
  final String message;

  // Item-import fields.
  final String slno;
  final String sku;
  final String name;
  final String operation;

  // Inventory-update fields.
  final String action;
  final String trackType;
  final num? prevQty;
  final num? prevWeight;
  final num? newQty;
  final num? newWeight;

  String get beforeDisplay =>
      _formatInventoryValue(trackType, prevQty, prevWeight);

  String get afterDisplay =>
      _formatInventoryValue(trackType, newQty, newWeight);

  factory BulkResultRow.fromJson(Map<String, dynamic> json) {
    return BulkResultRow(
      rowNumber: (json['rowNumber'] as num?)?.toInt() ?? 0,
      outcome: BulkRowOutcome.fromWire(json['outcome'] as String?),
      message: _str(json['message']),
      slno: _str(json['slno']),
      sku: _str(json['sku']),
      name: _str(json['name']),
      operation: _str(json['operation']),
      action: _str(json['action']),
      trackType: _str(json['trackType']),
      prevQty: json['prevQty'] as num?,
      prevWeight: json['prevWeight'] as num?,
      newQty: json['newQty'] as num?,
      newWeight: json['newWeight'] as num?,
    );
  }
}

/// Aggregate apply result: counters + per-row outcomes.
class BulkApplyResult {
  const BulkApplyResult({
    required this.operationType,
    this.inserted = 0,
    this.updated = 0,
    this.failed = 0,
    this.skipped = 0,
    this.rows = const [],
  });

  final BulkOperationType operationType;
  final int inserted;
  final int updated;
  final int failed;
  final int skipped;
  final List<BulkResultRow> rows;

  /// Result summary line. Item import shows Inserted/Updated; inventory shows
  /// Updated only. Both append Failed when > 0 (parity with renderResult).
  String get summaryLabel {
    final base = operationType == BulkOperationType.inventoryUpdate
        ? 'Updated: $updated'
        : 'Inserted: $inserted · Updated: $updated';
    return failed > 0 ? '$base · Failed: $failed' : base;
  }

  factory BulkApplyResult.fromJson(
    BulkOperationType operationType,
    Map<String, dynamic> json,
  ) {
    final rawRows = json['rows'];
    return BulkApplyResult(
      operationType: operationType,
      inserted: (json['inserted'] as num?)?.toInt() ?? 0,
      updated: (json['updated'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
      rows: rawRows is List
          ? rawRows
              .whereType<Map>()
              .map((r) => BulkResultRow.fromJson(Map<String, dynamic>.from(r)))
              .toList()
          : const [],
    );
  }
}

String _str(Object? v) => v == null ? '' : v.toString();

String _formatInventoryValue(String trackType, num? quantity, num? weight) {
  if (trackType == 'weight') {
    return '${_trimNum(weight ?? 0)} kg';
  }
  return '${_trimNum(quantity ?? 0)} units';
}

String _trimNum(num value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}
