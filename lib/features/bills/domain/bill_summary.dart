/// A row in the Bills list. Mirrors the `billData` projection returned by the
/// Electron `billing:list` handler (see bills-page-controller.js `renderRows`).
class BillSummary {
  const BillSummary({
    required this.billId,
    required this.createdAt,
    required this.paymentMode,
    required this.itemCount,
    required this.subtotalPaise,
    required this.discountPaise,
    required this.grandTotalPaise,
  });

  final String billId;

  /// ISO timestamp string (or empty). Kept as-is for locale formatting in UI.
  final String createdAt;
  final String paymentMode;
  final int itemCount;
  final int subtotalPaise;
  final int discountPaise;
  final int grandTotalPaise;

  /// Builds a summary from a raw list row: `{ billId, billData, createdAt }`.
  factory BillSummary.fromRow(Map<String, dynamic> row) {
    final data = (row['billData'] as Map<String, dynamic>?) ?? const {};
    return BillSummary(
      billId: (row['billId'] ?? data['billId'] ?? '').toString(),
      createdAt: (row['createdAt'] ?? data['createdAt'] ?? '').toString(),
      paymentMode: (data['paymentMode'] ?? '-').toString(),
      itemCount: _asInt(data['itemCount']),
      subtotalPaise: _asInt(data['subtotalPaise']),
      discountPaise: _asInt(data['discountPaise']),
      grandTotalPaise: _asInt(data['grandTotalPaise']),
    );
  }

  static int _asInt(Object? value) =>
      value is num ? value.round() : int.tryParse('${value ?? ''}') ?? 0;
}
