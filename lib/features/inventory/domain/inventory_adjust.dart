import '../../billing/domain/billing_enums.dart';

/// Whether an adjustment adds to or deducts from current stock.
enum AdjustAction {
  add,
  deduct;

  /// Applies the sign to a positive magnitude.
  num signed(num magnitude) => this == AdjustAction.deduct ? -magnitude : magnitude;
}

/// A pending inventory adjustment for a single item. Mirrors the payload sent to
/// `inventory:adjust` (`{ qtyDelta, weightDelta, notes, actionType }`).
class InventoryAdjustment {
  const InventoryAdjustment({
    required this.trackType,
    required this.action,
    required this.magnitude,
    this.notes = '',
  });

  /// PricingType of the target item (drives qty vs weight delta).
  final PricingType trackType;
  final AdjustAction action;

  /// Positive value entered by the user.
  final num magnitude;
  final String notes;

  num get delta => action.signed(magnitude);

  /// Preview of the resulting stock: `max(0, current + delta)` (parity).
  num previewStock(num currentStock) {
    final next = currentStock + delta;
    return next < 0 ? 0 : next;
  }

  Map<String, dynamic> toPayload() {
    final isWeight = trackType == PricingType.weight;
    return {
      'qtyDelta': isWeight ? 0 : delta,
      'weightDelta': isWeight ? delta : 0,
      'notes': notes.trim(),
      'actionType': 'adjust',
    };
  }
}

/// Result of an inventory adjustment (parity with the adapter return shape).
class AdjustResult {
  const AdjustResult({
    required this.ok,
    this.prevQty = 0,
    this.prevWeight = 0,
    this.newQty = 0,
    this.newWeight = 0,
  });

  final bool ok;
  final num prevQty;
  final num prevWeight;
  final num newQty;
  final num newWeight;

  factory AdjustResult.fromJson(Map<String, dynamic> json) {
    num asNum(Object? v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
    return AdjustResult(
      ok: json['ok'] != false,
      prevQty: asNum(json['prevQty']),
      prevWeight: asNum(json['prevWeight']),
      newQty: asNum(json['newQty']),
      newWeight: asNum(json['newWeight']),
    );
  }
}
