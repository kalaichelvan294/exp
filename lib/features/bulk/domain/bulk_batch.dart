import 'bulk_enums.dart';

// Last-batch and revert models. Parity with getLastBulkBatch (adapter) and the
// revert result shape.

/// Metadata for the most recent applied batch of a given operation type.
class BulkBatch {
  const BulkBatch({
    required this.batchId,
    required this.operationType,
    required this.rowCount,
    required this.reverted,
    this.appliedAt,
  });

  final String batchId;
  final BulkOperationType operationType;
  final int rowCount;
  final bool reverted;
  final String? appliedAt;

  /// Parses a last-batch payload. Returns null when the payload is empty or
  /// carries no batch id (parity with the "no previous batch" branch).
  static BulkBatch? tryFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    // The API bridge returns null (→ {'data': null}) when there is no batch.
    if (json['data'] == null && !json.containsKey('batchId')) {
      if (json.length == 1 && json.containsKey('data')) return null;
    }
    final batchId = (json['batchId'] ?? '').toString().trim();
    if (batchId.isEmpty) return null;
    return BulkBatch(
      batchId: batchId,
      operationType: BulkOperationType.fromWire(json['operationType'] as String?),
      rowCount: (json['rowCount'] as num?)?.toInt() ?? 0,
      reverted: json['reverted'] == true,
      appliedAt: json['appliedAt']?.toString(),
    );
  }
}

/// A row that could not be reverted (parity with revert `skippedRows`).
class BulkRevertSkip {
  const BulkRevertSkip({required this.sku, required this.reason});

  final String sku;
  final String reason;

  factory BulkRevertSkip.fromJson(Map<String, dynamic> json) => BulkRevertSkip(
        sku: (json['sku'] ?? '').toString(),
        reason: (json['reason'] ?? '').toString(),
      );
}

/// Result of reverting a batch.
class BulkRevertResult {
  const BulkRevertResult({
    this.revertedCount = 0,
    this.skippedRows = const [],
  });

  final int revertedCount;
  final List<BulkRevertSkip> skippedRows;

  factory BulkRevertResult.fromJson(Map<String, dynamic> json) {
    final raw = json['skippedRows'];
    return BulkRevertResult(
      revertedCount: (json['revertedCount'] as num?)?.toInt() ?? 0,
      skippedRows: raw is List
          ? raw
              .whereType<Map>()
              .map((r) => BulkRevertSkip.fromJson(Map<String, dynamic>.from(r)))
              .toList()
          : const [],
    );
  }
}
