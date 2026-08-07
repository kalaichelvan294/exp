import 'package:flutter_test/flutter_test.dart';
import 'package:pos_294_flutter/features/billing/domain/bill_totals.dart';
import 'package:pos_294_flutter/features/billing/domain/billing_enums.dart';
import 'package:pos_294_flutter/features/billing/domain/cart_line.dart';

CartLine _line({required num qty, required int ratePaise}) => CartLine(
      id: 'x',
      sku: 'X',
      name: 'X',
      qty: qty,
      retailRatePaise: ratePaise,
      ratePaise: ratePaise,
    );

void main() {
  group('computeDiscountPaise (parity with totals.js)', () {
    test('percent discount rounds like Math.round', () {
      // 10% of 12345 = 1234.5 → 1235
      expect(
        Totals.computeDiscountPaise(12345, DiscountMode.percent, 10),
        1235,
      );
    });

    test('percent caps at 100%', () {
      expect(
        Totals.computeDiscountPaise(5000, DiscountMode.percent, 150),
        5000,
      );
    });

    test('amount discount parses rupees to paise', () {
      // ₹12.50 → 1250 paise
      expect(
        Totals.computeDiscountPaise(5000, DiscountMode.amount, 12.5),
        1250,
      );
    });

    test('discount never exceeds subtotal', () {
      expect(
        Totals.computeDiscountPaise(3000, DiscountMode.amount, 99),
        3000,
      );
    });

    test('negative / invalid input treated as zero', () {
      expect(Totals.computeDiscountPaise(5000, DiscountMode.percent, -5), 0);
      expect(
          Totals.computeDiscountPaise(5000, DiscountMode.amount, 'abc'), 0);
    });
  });

  group('computeBillTotals (parity with totals.js)', () {
    test('subtotal = sum of round(qty * rate)', () {
      final cart = [
        _line(qty: 2, ratePaise: 1050), // 2100
        _line(qty: 0.5, ratePaise: 999), // round(499.5) = 500
      ];
      final totals = Totals.compute(cart, DiscountMode.percent, 0);
      expect(totals.subtotalPaise, 2600);
      expect(totals.discountPaise, 0);
      expect(totals.grandTotalPaise, 2600);
    });

    test('applies percentage discount to grand total', () {
      final cart = [_line(qty: 1, ratePaise: 10000)];
      final totals = Totals.compute(cart, DiscountMode.percent, 10);
      expect(totals.subtotalPaise, 10000);
      expect(totals.discountPaise, 1000);
      expect(totals.grandTotalPaise, 9000);
    });

    test('empty cart yields zero totals', () {
      final totals = Totals.compute(const [], DiscountMode.amount, 50);
      expect(totals.subtotalPaise, 0);
      expect(totals.discountPaise, 0);
      expect(totals.grandTotalPaise, 0);
    });
  });
}
