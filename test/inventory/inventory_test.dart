import 'package:flutter_test/flutter_test.dart';
import 'package:pos_294_flutter/features/billing/domain/billing_enums.dart';
import 'package:pos_294_flutter/features/inventory/application/inventory_state.dart';
import 'package:pos_294_flutter/features/inventory/domain/inventory_adjust.dart';
import 'package:pos_294_flutter/features/inventory/domain/inventory_settings.dart';

void main() {
  group('InventorySettings.fromJson', () {
    test('parses enabled settings', () {
      final s = InventorySettings.fromJson({
        'invControlEnabled': true,
        'invLowStockQty': 8,
        'invLowStockWeight': 2.5,
      });
      expect(s.invControlEnabled, isTrue);
      expect(s.invLowStockQty, 8);
      expect(s.invLowStockWeight, 2.5);
    });

    test('applies defaults when missing', () {
      final s = InventorySettings.fromJson({});
      expect(s.invControlEnabled, isFalse);
      expect(s.invLowStockQty, 10);
      expect(s.invLowStockWeight, 5.0);
    });
  });

  group('AdjustAction.signed', () {
    test('add keeps sign, deduct negates', () {
      expect(AdjustAction.add.signed(5), 5);
      expect(AdjustAction.deduct.signed(5), -5);
    });
  });

  group('InventoryAdjustment', () {
    InventoryAdjustment adj({
      PricingType trackType = PricingType.unit,
      AdjustAction action = AdjustAction.add,
      num magnitude = 5,
      String notes = '',
    }) =>
        InventoryAdjustment(
          trackType: trackType,
          action: action,
          magnitude: magnitude,
          notes: notes,
        );

    test('delta reflects action', () {
      expect(adj().delta, 5);
      expect(adj(action: AdjustAction.deduct).delta, -5);
    });

    test('previewStock clamps at zero', () {
      expect(adj(action: AdjustAction.add, magnitude: 3).previewStock(10), 13);
      expect(
          adj(action: AdjustAction.deduct, magnitude: 4).previewStock(10), 6);
      expect(
          adj(action: AdjustAction.deduct, magnitude: 20).previewStock(10), 0);
    });

    test('toPayload routes qty vs weight delta', () {
      final unit = adj(action: AdjustAction.deduct, magnitude: 3, notes: ' x ')
          .toPayload();
      expect(unit['qtyDelta'], -3);
      expect(unit['weightDelta'], 0);
      expect(unit['notes'], 'x');
      expect(unit['actionType'], 'adjust');

      final weight =
          adj(trackType: PricingType.weight, magnitude: 2.5).toPayload();
      expect(weight['qtyDelta'], 0);
      expect(weight['weightDelta'], 2.5);
    });
  });

  group('AdjustResult.fromJson', () {
    test('parses adapter response', () {
      final r = AdjustResult.fromJson({
        'ok': true,
        'prevQty': 10,
        'newQty': 7,
      });
      expect(r.ok, isTrue);
      expect(r.prevQty, 10);
      expect(r.newQty, 7);
    });
  });

  group('InventoryState', () {
    test('disabled by default', () {
      const state = InventoryState();
      expect(state.enabled, isFalse);
      expect(state.settingsLoaded, isFalse);
    });

    test('pagination getters', () {
      const state = InventoryState(total: 25, page: 2);
      expect(state.pageSize, 12);
      expect(state.totalPages, 3);
      expect(state.canPrev, isTrue);
      expect(state.canNext, isTrue);
    });

    test('copyWith clears nullable thresholds via sentinel', () {
      const state = InventoryState(qtyThreshold: 5, weightThreshold: 2);
      final cleared = state.copyWith(qtyThreshold: null, weightThreshold: null);
      expect(cleared.qtyThreshold, isNull);
      expect(cleared.weightThreshold, isNull);
      final kept = state.copyWith(page: 2);
      expect(kept.qtyThreshold, 5);
      expect(kept.weightThreshold, 2);
    });
  });
}
