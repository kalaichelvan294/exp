import 'package:flutter_test/flutter_test.dart';
import 'package:pos_294_flutter/features/printing/domain/receipt_html_builder.dart';
import 'package:pos_294_flutter/features/printing/domain/receipt_models.dart';
import 'package:pos_294_flutter/features/settings/domain/app_settings.dart';

const rupee = '\u20B9';

ReceiptPayload buildPayload({
  String lang = 'en',
  String storeName = '',
  String fssai = '',
  List<Map<String, dynamic>> items = const [],
  int subtotal = 0,
  int discount = 0,
  int grand = 0,
  String billId = 'B-1001',
}) {
  final settings = AppSettings.fromJson({
    'printLanguage': lang,
    'storeName': storeName,
    'fssaiNumber': fssai,
  });
  return ReceiptPayload.fromBillDataJson({
    'billId': billId,
    'paymentMode': 'CASH',
    'itemCount': items.length,
    'subtotalPaise': subtotal,
    'discountPaise': discount,
    'grandTotalPaise': grand,
    'items': items,
    'createdAt': '2024-01-02T03:04:05.000Z',
  }, settings: settings);
}

void main() {
  group('ReceiptHtmlBuilder formatters', () {
    test('formatMoney renders paise as rupees with 2 decimals', () {
      expect(ReceiptHtmlBuilder.formatMoney(12345), '${rupee}123.45');
      expect(ReceiptHtmlBuilder.formatMoney(0), '${rupee}0.00');
      expect(ReceiptHtmlBuilder.formatMoney(50), '${rupee}0.50');
    });

    test('formatQty shows integers plainly and fractions to 3 decimals', () {
      expect(ReceiptHtmlBuilder.formatQty(2), '2');
      expect(ReceiptHtmlBuilder.formatQty(2.0), '2');
      expect(ReceiptHtmlBuilder.formatQty(2.5), '2.500');
      expect(ReceiptHtmlBuilder.formatQty(0.25), '0.250');
    });

    test('escapeHtml escapes markup-significant characters', () {
      expect(ReceiptHtmlBuilder.escapeHtml('<b>&"\'</b>'),
          '&lt;b&gt;&amp;&quot;&#39;&lt;/b&gt;');
    });
  });

  group('ReceiptHtmlBuilder.build', () {
    test('uses 2.5-inch page sizing and store header defaults', () {
      final html = ReceiptHtmlBuilder.build(buildPayload());
      expect(html, contains('@page{size:2.5in auto;margin:0;}'));
      expect(html, contains('width:2.5in'));
      expect(html, contains(ReceiptStoreDefaults.storeName));
      expect(html, contains('Wholesale &amp; Retail'));
      expect(html, contains(ReceiptStoreDefaults.address));
    });

    test('applies configured store name and FSSAI when present', () {
      final html = ReceiptHtmlBuilder.build(
        buildPayload(storeName: 'My Shop', fssai: '12345678901234'),
      );
      expect(html, contains('My Shop'));
      expect(html, contains('FSSAI: 12345678901234'));
    });

    test('omits FSSAI line when not configured', () {
      final html = ReceiptHtmlBuilder.build(buildPayload());
      expect(html, isNot(contains('FSSAI:')));
    });

    test('renders empty state when there are no items', () {
      final html = ReceiptHtmlBuilder.build(buildPayload());
      expect(html, contains('No bill items available.'));
    });

    test('renders item row with qty, rate, total and SKU block', () {
      final html = ReceiptHtmlBuilder.build(buildPayload(items: [
        {
          'id': 'SKU-9',
          'name': 'Banana Chips',
          'qty': 2,
          'rate': 5000,
          'lineTotalPaise': 10000,
        }
      ]));
      expect(html, contains('Banana Chips'));
      expect(html, contains('SKU: SKU-9'));
      expect(html, contains('${rupee}50.00'));
      expect(html, contains('${rupee}100.00'));
    });

    test('derives line total from qty*rate when absent', () {
      final html = ReceiptHtmlBuilder.build(buildPayload(items: [
        {'id': 'A', 'name': 'X', 'qty': 3, 'rate': 2000}
      ]));
      expect(html, contains('${rupee}60.00'));
    });

    test('shows discount row only when discount is positive', () {
      final withDiscount = ReceiptHtmlBuilder.build(
        buildPayload(subtotal: 10000, discount: 2000, grand: 8000),
      );
      expect(withDiscount, contains('Discount'));
      expect(withDiscount, contains('-${rupee}20.00'));

      final noDiscount = ReceiptHtmlBuilder.build(
        buildPayload(subtotal: 10000, grand: 10000),
      );
      expect(noDiscount, isNot(contains('Discount')));
    });

    test('derives grand total from subtotal minus discount when zero', () {
      final html = ReceiptHtmlBuilder.build(
        buildPayload(subtotal: 10000, discount: 2000, grand: 0),
      );
      expect(html, contains('Grand Total'));
      expect(html, contains('${rupee}80.00'));
    });

    test('falls back to "Unnamed Item" for blank names', () {
      final html = ReceiptHtmlBuilder.build(buildPayload(items: [
        {'id': 'A', 'name': '', 'qty': 1, 'rate': 100}
      ]));
      expect(html, contains('Unnamed Item'));
    });

    test('escapes item names in the rendered rows', () {
      final html = ReceiptHtmlBuilder.build(buildPayload(items: [
        {'id': 'A', 'name': 'A & B <x>', 'qty': 1, 'rate': 100}
      ]));
      expect(html, contains('A &amp; B &lt;x&gt;'));
    });
  });

  group('bilingual item names', () {
    final item = {
      'id': 'SKU-1',
      'name': 'Chips',
      'nameTa': '\u0B9A\u0BBF\u0BAA\u0BCD\u0BB8\u0BCD',
      'qty': 1,
      'rate': 100,
      'lineTotalPaise': 100,
    };

    test('uses the Tamil name when print language is Tamil', () {
      final html = ReceiptHtmlBuilder.build(
        buildPayload(lang: 'ta', items: [item]),
      );
      expect(html, contains('\u0B9A\u0BBF\u0BAA\u0BCD\u0BB8\u0BCD'));
      expect(html, isNot(contains('>Chips<')));
    });

    test('uses the English name when print language is English', () {
      final html = ReceiptHtmlBuilder.build(
        buildPayload(lang: 'en', items: [item]),
      );
      expect(html, contains('Chips'));
    });

    test('falls back to English when Tamil name is missing', () {
      final html = ReceiptHtmlBuilder.build(buildPayload(lang: 'ta', items: [
        {'id': 'A', 'name': 'Chips', 'qty': 1, 'rate': 100}
      ]));
      expect(html, contains('Chips'));
    });
  });

  group('ReceiptHtmlBuilder.document', () {
    test('carries the bill id and rendered html', () {
      final doc = ReceiptHtmlBuilder.document(buildPayload(billId: 'B-42'));
      expect(doc.billId, 'B-42');
      expect(doc.html, contains('Receipt B-42'));
    });

    test('normalizes a blank bill id to DRAFT-BILL', () {
      final doc = ReceiptHtmlBuilder.document(buildPayload(billId: ''));
      expect(doc.billId, 'DRAFT-BILL');
    });
  });
}
