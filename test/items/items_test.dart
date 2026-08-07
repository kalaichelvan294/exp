import 'package:flutter_test/flutter_test.dart';
import 'package:pos_294_flutter/features/billing/domain/billing_enums.dart';
import 'package:pos_294_flutter/features/items/application/items_state.dart';
import 'package:pos_294_flutter/features/items/domain/item.dart';
import 'package:pos_294_flutter/features/items/domain/item_form.dart';

void main() {
  ItemFormData form({
    String name = 'Rice',
    String category = 'GROCERY',
    String sku = 'RICE-1',
    PricingType pricingType = PricingType.unit,
    String retail = '100',
    String wholesalePrice = '',
    String wholesaleMinQty = '',
  }) =>
      ItemFormData(
        name: name,
        category: category,
        sku: sku,
        pricingType: pricingType,
        retailPriceInput: retail,
        wholesalePriceInput: wholesalePrice,
        wholesaleMinQtyInput: wholesaleMinQty,
      );

  group('ItemFormData.normalizeSku', () {
    test('uppercases and strips whitespace', () {
      expect(ItemFormData.normalizeSku(' ab c-1 '), 'ABC-1');
    });

    test('pattern accepts uppercase, digits, hyphen only', () {
      expect(ItemFormData.skuPattern.hasMatch('ABC-123'), isTrue);
      expect(ItemFormData.skuPattern.hasMatch('abc'), isFalse);
      expect(ItemFormData.skuPattern.hasMatch('AB C'), isFalse);
      expect(ItemFormData.skuPattern.hasMatch('AB_C'), isFalse);
    });
  });

  group('ItemFormData.validate (parity with validateForm/mapItemData)', () {
    test('valid minimal form returns null', () {
      expect(form().validate(), isNull);
    });

    test('missing required fields', () {
      expect(form(name: '').validate(), isNotNull);
      expect(form(category: '').validate(), isNotNull);
      expect(form(sku: '   ').validate(), isNotNull);
    });

    test('retail price must be > 0', () {
      expect(form(retail: '0').validate(),
          'Retail price must be greater than 0.');
      expect(form(retail: '').validate(),
          'Retail price must be greater than 0.');
    });

    test('wholesale price and minQty are both-or-neither', () {
      expect(form(wholesalePrice: '80').validate(),
          'Wholesale price and minimum qty must both be provided.');
      expect(form(wholesaleMinQty: '5').validate(),
          'Wholesale price and minimum qty must both be provided.');
    });

    test('wholesale price and minQty must be > 0', () {
      expect(form(wholesalePrice: '0', wholesaleMinQty: '5').validate(),
          'Wholesale price must be greater than 0.');
      expect(form(wholesalePrice: '80', wholesaleMinQty: '0').validate(),
          'Wholesale minimum qty must be greater than 0.');
    });

    test('UNIT items require whole-number wholesale minQty', () {
      expect(
        form(wholesalePrice: '80', wholesaleMinQty: '2.5').validate(),
        'Wholesale minimum qty must be a whole number for UNIT items.',
      );
      expect(
        form(wholesalePrice: '80', wholesaleMinQty: '3').validate(),
        isNull,
      );
    });

    test('WEIGHT items allow fractional wholesale minQty', () {
      expect(
        form(
          pricingType: PricingType.weight,
          wholesalePrice: '80',
          wholesaleMinQty: '2.5',
        ).validate(),
        isNull,
      );
    });
  });

  group('ItemFormData.toPayload', () {
    test('converts rupee inputs to paise and normalizes sku', () {
      final payload = form(
        sku: 'ab-1',
        retail: '100',
        wholesalePrice: '80',
        wholesaleMinQty: '5',
      ).toPayload();
      expect(payload['sku'], 'AB-1');
      expect(payload['retailPrice'], 10000);
      expect(payload['wholesalePrice'], 8000);
      expect(payload['wholesaleMinQty'], 5);
      expect(payload['pricingType'], 'UNIT');
    });

    test('omits wholesale fields when blank', () {
      final payload = form().toPayload();
      expect(payload['wholesalePrice'], isNull);
      expect(payload['wholesaleMinQty'], isNull);
    });
  });

  group('Item.fromJson / low-stock', () {
    test('maps adapter projection', () {
      final item = Item.fromJson({
        'id': '1',
        'name': 'Rice',
        'nameTa': 'அரிசி',
        'category': 'GROCERY',
        'sku': 'RICE-1',
        'pricingType': 'UNIT',
        'brandName': 'ACME',
        'retailPricePaise': 10000,
        'wholesalePricePaise': 8000,
        'wholesaleMinQty': 5,
        'inv_current_qty': 3,
        'inv_min_qty': 10,
      });
      expect(item.displayName, 'அரிசி / Rice');
      expect(item.trackType, 'quantity');
      expect(item.currentStock, 3);
      expect(item.isLowStock, isTrue);
    });

    test('weight item uses weight columns', () {
      final item = Item.fromJson({
        'id': '2',
        'name': 'Sugar',
        'sku': 'SUG-1',
        'pricingType': 'WEIGHT',
        'retailPricePaise': 5000,
        'inv_current_weight': 6,
        'inv_min_weight': 5,
      });
      expect(item.trackType, 'weight');
      expect(item.currentStock, 6);
      expect(item.isLowStock, isFalse);
    });

    test('zero stock is not low stock', () {
      final item = Item.fromJson({
        'id': '3',
        'name': 'Salt',
        'sku': 'SALT-1',
        'pricingType': 'UNIT',
        'retailPricePaise': 2000,
        'inv_current_qty': 0,
        'inv_min_qty': 10,
      });
      expect(item.isLowStock, isFalse);
    });
  });

  group('SkuValidation.fromJson', () {
    test('parses server response', () {
      final v = SkuValidation.fromJson(
          {'valid': true, 'exists': false, 'message': ''});
      expect(v.valid, isTrue);
      expect(v.exists, isFalse);
    });
  });

  group('ItemsState pagination', () {
    test('computes total pages and nav flags', () {
      const state = ItemsState(total: 25, page: 2);
      expect(state.pageSize, 12);
      expect(state.totalPages, 3);
      expect(state.canPrev, isTrue);
      expect(state.canNext, isTrue);
    });

    test('single page has no navigation', () {
      const state = ItemsState(total: 5, page: 1);
      expect(state.totalPages, 1);
      expect(state.canPrev, isFalse);
      expect(state.canNext, isFalse);
    });
  });
}
