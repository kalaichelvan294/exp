import 'package:flutter_test/flutter_test.dart';
import 'package:pos_294_flutter/app/appearance.dart';
import 'package:pos_294_flutter/features/billing/domain/billing_enums.dart';
import 'package:pos_294_flutter/features/settings/domain/app_settings.dart';

void main() {
  group('AppSettings.fromJson', () {
    test('parses full payload', () {
      final s = AppSettings.fromJson({
        'storeName': 'My Store',
        'businessType': 'Retail',
        'storeAddress': '123 St',
        'fssaiNumber': 'FSSAI1',
        'printLanguage': 'ta',
        'upiId': 'store@upi',
        'upiDisplayName': 'My Store',
        'billingPaymentModes': ['GPAY', 'CASH'],
        'uiSizeVariant': 'lg',
        'themeMode': 'dark',
        'itemCategories': ['grocery', 'OTHER', 'Grocery'],
        'itemBrands': ['acme', 'ACME', 'foo!'],
        'itemsWholesaleAutoApply': false,
      });
      expect(s.storeName, 'My Store');
      expect(s.printLanguage, 'ta');
      expect(s.uiSizeVariant, 'lg');
      expect(s.isDark, isTrue);
      expect(s.billingPaymentModes, [PaymentMode.gpay, PaymentMode.cash]);
      expect(s.itemCategories, ['GROCERY']); // deduped, OTHER excluded
      expect(s.itemBrands, ['ACME', 'FOO']);
      expect(s.itemsWholesaleAutoApply, isFalse);
    });

    test('applies defaults for missing fields', () {
      final s = AppSettings.fromJson({});
      expect(s.printLanguage, 'en');
      expect(s.uiSizeVariant, 'md');
      expect(s.themeMode, 'light');
      expect(s.billingPaymentModes,
          [PaymentMode.cash, PaymentMode.gpay, PaymentMode.card]);
      expect(s.itemsWholesaleAutoApply, isTrue);
      expect(s.fontScale, 1.0);
    });
  });

  group('normalizePaymentModes', () {
    test('dedupes and keeps order', () {
      expect(
        AppSettings.normalizePaymentModes(['CASH', 'cash', 'CARD']),
        [PaymentMode.cash, PaymentMode.card],
      );
    });

    test('ignores invalid entries', () {
      expect(
        AppSettings.normalizePaymentModes(['BITCOIN', 'GPAY']),
        [PaymentMode.gpay],
      );
    });

    test('empty falls back to all modes', () {
      expect(
        AppSettings.normalizePaymentModes([]),
        [PaymentMode.cash, PaymentMode.gpay, PaymentMode.card],
      );
    });
  });

  group('sanitize category / brand', () {
    test('category keeps hyphen, uppercases, collapses spaces', () {
      expect(AppSettings.sanitizeCategory('  dry   goods-1 '), 'DRY GOODS-1');
      expect(AppSettings.sanitizeCategory('a*b#c'), 'ABC');
    });

    test('brand strips hyphen and specials', () {
      expect(AppSettings.sanitizeBrand(' acme-corp! '), 'ACMECORP');
    });
  });

  group('normalize variant / theme', () {
    test('ui size variant falls back to md', () {
      expect(AppSettings.normalizeUiSizeVariant('xxl'), 'xxl');
      expect(AppSettings.normalizeUiSizeVariant('huge'), 'md');
    });

    test('theme mode only light or dark', () {
      expect(AppSettings.normalizeThemeMode('dark'), 'dark');
      expect(AppSettings.normalizeThemeMode('neon'), 'light');
    });
  });

  group('AppearanceState', () {
    test('derives isDark and fontScale', () {
      const state = AppearanceState(themeMode: 'dark', uiSizeVariant: 'lg');
      expect(state.isDark, isTrue);
      expect(state.fontScale, kUiSizeScales['lg']);
    });

    test('defaults are light / md', () {
      const state = AppearanceState();
      expect(state.isDark, isFalse);
      expect(state.fontScale, 1.0);
    });
  });
}
