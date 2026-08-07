import 'bulk_enums.dart';

// Progress payload. Parity with the bulk:apply-progress event shape.
//
// The REST api_client is request/response only, so live per-row streaming is
// not wired; the controller exposes this model so a streaming transport can be
// plugged in later without changing the UI. During apply the UI shows a busy
// state and then the final result counters.

/// A single apply-progress tick.
class BulkProgress {
  const BulkProgress({
    required this.operationType,
    this.current = 0,
    this.total = 0,
    this.sku = '',
    this.operation = '',
    this.inserted = 0,
    this.updated = 0,
    this.failed = 0,
  });

  final BulkOperationType operationType;
  final int current;
  final int total;
  final String sku;
  final String operation;
  final int inserted;
  final int updated;
  final int failed;

  factory BulkProgress.fromJson(Map<String, dynamic> json) {
    return BulkProgress(
      operationType:
          BulkOperationType.fromWire(json['operationType'] as String?),
      current: (json['current'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      sku: (json['sku'] ?? '').toString(),
      operation: (json['operation'] ?? '').toString(),
      inserted: (json['inserted'] as num?)?.toInt() ?? 0,
      updated: (json['updated'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
    );
  }
}
