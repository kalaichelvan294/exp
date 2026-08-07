import 'package:flutter_test/flutter_test.dart';
import 'package:pos_294_flutter/features/billing/domain/billing_enums.dart';
import 'package:pos_294_flutter/features/billing/domain/cart_line.dart';
import 'package:pos_294_flutter/features/billing/domain/product.dart';

Product _product({
  required PricingType pricingType,
  required int retail,
  int? wholesale,
  num? wholesaleMinQty,
}) =>
    Product(
      id: 'p1',
      sku: 'SKU1',
      name: 'Widget',
      pricingType: pricingType,
      retailPricePaise: retail,
      wholesalePricePaise: wholesale,
      wholesaleMinQty: wholesaleMinQty,
      ratePaise: retail,
    );

void main() {
  group('CartLine.fromProduct (parity with cart.addItem)', () {
    test('UNIT items default to qty 1', () {
      final line = CartLine.fromProduct(
        _product(pricingType: PricingType.unit, retail: 5000),
        'MANUAL_SEARCH',
      );
      expect(line.qty, 1);
      expect(line.priceTier, PriceTier.retail);
    });

    test('WEIGHT items default to qty 0.5', () {
      final line = CartLine.fromProduct(
        _product(pricingType: PricingType.weight, retail: 5000),
        'MANUAL_SEARCH',
      );
      expect(line.qty, 0.5);
    });
  });

  group('applyLinePricing (parity with cart.js)', () {
    test('switches to wholesale when qty >= min and auto-apply on', () {
      final line = CartLine.fromProduct(
        _product(
          pricingType: PricingType.unit,
          retail: 5000,
          wholesale: 4000,
          wholesaleMinQty: 3,
        ),
        'MANUAL_SEARCH',
      );
      line.qty = 3;
      line.applyLinePricing(true);
      expect(line.ratePaise, 4000);
      expect(line.priceTier, PriceTier.wholesale);
    });

    test('stays retail below the wholesale threshold', () {
      final line = CartLine.fromProduct(
        _product(
          pricingType: PricingType.unit,
          retail: 5000,
          wholesale: 4000,
          wholesaleMinQty: 3,
        ),
        'MANUAL_SEARCH',
      );
      line.qty = 2;
      line.applyLinePricing(true);
      expect(line.ratePaise, 5000);
      expect(line.priceTier, PriceTier.retail);
    });

    test('stays retail when auto-apply is off even if threshold met', () {
      final line = CartLine.fromProduct(
        _product(
          pricingType: PricingType.unit,
          retail: 5000,
          wholesale: 4000,
          wholesaleMinQty: 3,
        ),
        'MANUAL_SEARCH',
      );
      line.qty = 5;
      line.applyLinePricing(false);
      expect(line.ratePaise, 5000);
      expect(line.priceTier, PriceTier.retail);
    });

    test('lineTotalPaise = round(qty * rate)', () {
      final line = CartLine.fromProduct(
        _product(pricingType: PricingType.weight, retail: 999),
        'MANUAL_SEARCH',
      );
      line.qty = 0.5; // round(499.5) = 500
      line.applyLinePricing(true);
      expect(line.lineTotalPaise, 500);
    });
  });
}
