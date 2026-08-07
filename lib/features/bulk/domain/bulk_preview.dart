import 'bulk_enums.dart';

// Preview models. Parity with mapBulkPreviewResponse (main.js) and the
// previewItemImport / previewInventoryUpdate row shapes.

/// A single validated preview row. Covers both item-import and
/// inventory-update rows; fields not relevant to a flow stay null.
class BulkPreviewRow {
  const BulkPreviewRow({
    required this.rowNumber,
    required this.status,
    required this.messages,
    this.slno = '',
    this.sku = '',
    this.name = '',
    this.operation = '',
    this.action = '',
    this.quantity,
    this.weightKg,
  });

  final int rowNumber;
  final BulkRowStatus status;
  final List<String> messages;

  // Item-import fields.
  final String slno;
  final String sku;
  final String name;
  final String operation;

  // Inventory-update fields.
  final String action;
  final num? quantity;
  final num? weightKg;

  /// Joined messages, or an em dash when empty (parity with detailText).
  String get detail => messages.isNotEmpty ? messages.join('; ') : '—';

  /// Inventory quantity/weight display (parity with qtyOrWeight rendering).
  String get quantityDisplay {
    if (quantity != null) return _trimNum(quantity!);
    if (weightKg != null) return '${_trimNum(weightKg!)} kg';
    return '—';
  }

  factory BulkPreviewRow.fromJson(Map<String, dynamic> json) {
    return BulkPreviewRow(
      rowNumber: (json['rowNumber'] as num?)?.toInt() ?? 0,
      status: BulkRowStatus.fromWire(json['status'] as String?),
      messages: _stringList(json['messages']),
      slno: _str(json['slno']),
      sku: _str(json['sku']),
      name: _str(json['name']),
      operation: _str(json['operation']),
      action: _str(json['action']),
      quantity: json['quantity'] as num?,
      weightKg: json['weight_kg'] as num?,
    );
  }
}

/// Aggregate preview counters (parity with the summary reducer).
class BulkPreviewSummary {
  const BulkPreviewSummary({
    this.readyCount = 0,
    this.warningCount = 0,
    this.errorCount = 0,
    this.skippedCount = 0,
  });

  final int readyCount;
  final int warningCount;
  final int errorCount;
  final int skippedCount;

  bool get hasErrors => errorCount > 0;
  bool get hasWarnings => warningCount > 0;

  factory BulkPreviewSummary.fromJson(Map<String, dynamic> json) {
    return BulkPreviewSummary(
      readyCount: (json['readyCount'] as num?)?.toInt() ?? 0,
      warningCount: (json['warningCount'] as num?)?.toInt() ?? 0,
      errorCount: (json['errorCount'] as num?)?.toInt() ?? 0,
      skippedCount: (json['skippedCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Summary line, e.g. "3 ready · 1 warnings · 0 errors".
  String get label {
    final e = errorCount == 1 ? 'error' : 'errors';
    return '$readyCount ready · $warningCount warnings · $errorCount $e';
  }
}

/// Full preview response: rows + summary + auto-detect flag.
class BulkPreview {
  const BulkPreview({
    required this.rows,
    required this.summary,
    this.autoDetectMode = false,
  });

  final List<BulkPreviewRow> rows;
  final BulkPreviewSummary summary;
  final bool autoDetectMode;

  factory BulkPreview.fromJson(Map<String, dynamic> json) {
    final rawRows = json['rows'];
    return BulkPreview(
      rows: rawRows is List
          ? rawRows
              .whereType<Map>()
              .map((r) => BulkPreviewRow.fromJson(Map<String, dynamic>.from(r)))
              .toList()
          : const [],
      summary: json['summary'] is Map
          ? BulkPreviewSummary.fromJson(
              Map<String, dynamic>.from(json['summary'] as Map))
          : const BulkPreviewSummary(),
      autoDetectMode: json['autoDetectMode'] == true,
    );
  }
}

String _str(Object? v) => v == null ? '' : v.toString();

List<String> _stringList(Object? v) {
  if (v is List) {
    return v.map((e) => e == null ? '' : e.toString()).toList();
  }
  return const [];
}

String _trimNum(num value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}
