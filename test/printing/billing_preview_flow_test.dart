import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_294_flutter/features/billing/application/billing_controller.dart';
import 'package:pos_294_flutter/features/billing/data/billing_repository.dart';
import 'package:pos_294_flutter/features/billing/domain/bill_data.dart';
import 'package:pos_294_flutter/features/billing/domain/product.dart';
import 'package:pos_294_flutter/features/printing/data/receipt_print_service.dart';
import 'package:pos_294_flutter/features/printing/domain/preview_outcome.dart';
import 'package:pos_294_flutter/features/printing/domain/receipt_models.dart';
import 'package:pos_294_flutter/features/settings/data/settings_repository.dart';
import 'package:pos_294_flutter/features/settings/domain/app_settings.dart';
import 'package:pos_294_flutter/features/inventory/domain/inventory_settings.dart';

class _FakePrintService implements ReceiptPrintService {
  _FakePrintService({this.outcome = const PreviewOutcome.opened()});

  PreviewOutcome outcome;
  ReceiptDocument? lastDocument;
  int calls = 0;

  @override
  Future<PreviewOutcome> openPreview(ReceiptDocument document) async {
    calls++;
    lastDocument = document;
    return outcome;
  }
}

class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<AppSettings> loadSettings() async => AppSettings.fromJson({
        'storeName': 'Test Store',
        'printLanguage': 'ta',
      });

  @override
  Future<InventorySettings> loadInventorySettings() async =>
      InventorySettings.fromJson({'invControlEnabled': true});

  @override
  Future<void> saveSettings(Map<String, dynamic> patch) async {}

  @override
  Future<void> saveInventorySettings({required bool invControlEnabled}) async {}

  @override
  Future<List<String>> propagateBrands() async => const [];
}

class _FakeBillingRepository implements BillingRepository {
  Map<String, dynamic> billData = const {};
  BillData? savedBill;

  @override
  Future<SaveBillResult> saveBill(BillData bill) async {
    savedBill = bill;
    return SaveBillResult(billId: bill.billId);
  }

  @override
  Future<Map<String, dynamic>> getBill(String billId) async => billData;

  @override
  Future<HeldBillsPage> listHeldBills({int limit = 3}) async =>
      const HeldBillsPage(rows: [], holdsLeft: 3);

  // Unused in these tests.
  @override
  Future<List<Product>> searchProducts(String query, {int limit = 8}) async =>
      const [];
  @override
  Future<Product?> findExactProduct(String query) async => null;
  @override
  Future<HoldResult> holdBill(BillData bill) async =>
      const HoldResult(holdsLeft: 3);
  @override
  Future<BillListResult> listBills({
    int page = 1,
    int pageSize = 10,
    String billId = '',
    String paymentMode = '',
    String dateFrom = '',
    String dateTo = '',
  }) async =>
      const BillListResult(total: 0, page: 1, pageSize: 10, rows: []);
  @override
  Future<void> updateBill(String billId, BillData bill) async {}
  @override
  Future<void> deleteBill(String billId) async {}
  @override
  Future<Map<String, dynamic>> resumeHeldBill(String holdId) async => const {};
  @override
  Future<void> deleteHeldBill(String holdId) async {}
}

ProviderContainer _container({
  required _FakeBillingRepository billing,
  required _FakePrintService print,
}) {
  return ProviderContainer(overrides: [
    billingRepositoryProvider.overrideWithValue(billing),
    settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepository()),
    receiptPrintServiceProvider.overrideWithValue(print),
  ]);
}

Product _product() => Product.fromJson({
      'id': 'P1',
      'sku': 'P1',
      'name': 'Chips',
      'nameTa': '\u0B9A\u0BBF\u0BAA\u0BCD\u0BB8\u0BCD',
      'retailPricePaise': 5000,
      'rate': 5000,
      'pricingType': 'unit',
    });

void main() {
  test('checkout opens the receipt preview and reports success', () async {
    final billing = _FakeBillingRepository();
    final print = _FakePrintService();
    final container = _container(billing: billing, print: print);
    addTearDown(container.dispose);

    final controller = container.read(billingControllerProvider.notifier);
    await pumpEventQueue();
    controller.addProduct(_product(), 'MANUAL');

    await controller.checkout();

    expect(print.calls, 1);
    expect(print.lastDocument, isNotNull);
    // Store profile + Tamil print language flow into the rendered receipt.
    expect(print.lastDocument!.html, contains('Test Store'));
    expect(print.lastDocument!.html,
        contains('\u0B9A\u0BBF\u0BAA\u0BCD\u0BB8\u0BCD'));

    final state = container.read(billingControllerProvider);
    expect(state.cart, isEmpty);
    expect(state.message.isError, isFalse);
    expect(state.message.text, contains('saved'));
    expect(state.message.text, contains('New bill started'));
  });

  test('checkout surfaces a preview failure without blocking the sale',
      () async {
    final billing = _FakeBillingRepository();
    final print = _FakePrintService(outcome: const PreviewOutcome.failed('boom'));
    final container = _container(billing: billing, print: print);
    addTearDown(container.dispose);

    final controller = container.read(billingControllerProvider.notifier);
    await pumpEventQueue();
    controller.addProduct(_product(), 'MANUAL');

    await controller.checkout();

    expect(billing.savedBill, isNotNull);
    final state = container.read(billingControllerProvider);
    expect(state.cart, isEmpty);
    expect(state.message.isError, isTrue);
    expect(state.message.text, contains('preview failed: boom'));
  });

  test('reprint composes the edited bill and opens the preview', () async {
    final billing = _FakeBillingRepository()
      ..billData = {
        'billId': 'B1',
        'paymentMode': 'CASH',
        'discountMode': 'FLAT',
        'discountValue': 0,
        'items': [
          {'id': 'P1', 'name': 'Chips', 'qty': 1, 'rate': 5000}
        ],
        'createdAt': '2024-01-02T03:04:05.000Z',
      };
    final print = _FakePrintService();
    final container = _container(billing: billing, print: print);
    addTearDown(container.dispose);

    final controller = container.read(billingControllerProvider.notifier);
    await pumpEventQueue();
    await controller.loadBillForEdit('B1');

    await controller.reprintCurrentBill();

    expect(print.calls, 1);
    expect(print.lastDocument!.billId, 'B1');
    final state = container.read(billingControllerProvider);
    expect(state.message.isError, isFalse);
    expect(state.message.text, contains('Print preview opened for bill B1'));
  });
}
