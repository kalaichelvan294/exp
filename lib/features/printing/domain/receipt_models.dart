import '../../billing/domain/bill_data.dart';
import '../../settings/domain/app_settings.dart';

/// Default store profile, mirroring `normalizeBill` in the Electron
/// `receipt-printer.js`. Used when a settings value is blank so the receipt
/// still renders a complete header.
class ReceiptStoreDefaults {
  static const storeName = 'Sri Perumal Chips and Snacks';
  static const businessType = 'Wholesale & Retail';
  static const address = 'No 49, Valmikki st, Thiruvanmiyur, Chennai 41';
}

/// A single printed receipt line. Mirrors the row shape consumed by
/// `buildReceiptHtml` (qty, rate in paise, line total in paise, sku, names).
class ReceiptItem {
  const ReceiptItem({
    required this.name,
    this.nameTa = '',
    this.sku = '',
    this.qty = 0,
    this.ratePaise = 0,
    this.lineTotalPaise = 0,
  });

  final String name;
  final String nameTa;
  final String sku;
  final num qty;
  final int ratePaise;
  final int lineTotalPaise;

  /// The name shown on the receipt given the print language. Falls back to the
  /// English name (or "Unnamed Item") when Tamil is unavailable (parity with
  /// the `useTamil && line.nameTa` guard).
  String displayName({required bool useTamil}) {
    if (useTamil && nameTa.trim().isNotEmpty) return nameTa;
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'Unnamed Item' : name;
  }

  factory ReceiptItem.fromBillItem(BillItem item) => ReceiptItem(
        name: item.name,
        nameTa: item.nameTa,
        sku: item.id,
        qty: item.qty,
        ratePaise: item.ratePaise,
        lineTotalPaise: item.lineTotalPaise,
      );

  /// Builds a line from a raw `billData.items[]` map (used when reprinting a
  /// saved bill). Mirrors the field fallbacks in `buildReceiptHtml`.
  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    num asNum(Object? v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
    int asInt(Object? v) => (v is num) ? v.round() : int.tryParse('$v') ?? 0;
    final qty = asNum(json['qty']);
    final rate = asInt(json['rate'] ?? json['ratePaise']);
    final sku = (json['sku'] ?? json['skuCode'] ?? json['id'] ?? '')
        .toString()
        .trim();
    final lineTotal = json['lineTotalPaise'] != null
        ? asInt(json['lineTotalPaise'])
        : (qty * rate).round();
    return ReceiptItem(
      name: (json['name'] ?? '').toString(),
      nameTa: (json['nameTa'] ?? '').toString(),
      sku: sku,
      qty: qty,
      ratePaise: rate,
      lineTotalPaise: lineTotal,
    );
  }
}

/// Normalized receipt payload used to render the 2.5-inch receipt HTML.
///
/// Ports `toReceiptPayload` + `normalizeBill` from the Electron main process:
/// applies store-profile defaults, clamps discounts, and derives the grand
/// total when absent so the rendered receipt matches the current app exactly.
class ReceiptPayload {
  ReceiptPayload._({
    required this.billId,
    required this.storeName,
    required this.storeBusinessType,
    required this.storeAddress,
    required this.fssaiNumber,
    required this.printLanguage,
    required this.paymentMode,
    required this.itemCount,
    required this.subtotalPaise,
    required this.discountPaise,
    required this.grandTotalPaise,
    required this.createdAt,
    required this.items,
  });

  final String billId;
  final String storeName;
  final String storeBusinessType;
  final String storeAddress;
  final String fssaiNumber;
  final String printLanguage; // 'en' | 'ta'
  final String paymentMode;
  final int itemCount;
  final int subtotalPaise;
  final int discountPaise;
  final int grandTotalPaise;
  final String createdAt;
  final List<ReceiptItem> items;

  bool get useTamil => printLanguage == 'ta';

  static String _storeName(AppSettings s) =>
      s.storeName.trim().isEmpty ? ReceiptStoreDefaults.storeName : s.storeName;

  static String _businessType(AppSettings s) => s.businessType.trim().isEmpty
      ? ReceiptStoreDefaults.businessType
      : s.businessType;

  static String _address(AppSettings s) => s.storeAddress.trim().isEmpty
      ? ReceiptStoreDefaults.address
      : s.storeAddress;

  static ReceiptPayload _normalize({
    required String billId,
    required AppSettings settings,
    required String paymentMode,
    required int itemCountRaw,
    required int subtotalPaise,
    required int discountPaiseRaw,
    required int grandTotalPaiseRaw,
    required String createdAt,
    required List<ReceiptItem> items,
  }) {
    final subtotal = subtotalPaise < 0 ? 0 : subtotalPaise;
    final discount = discountPaiseRaw < 0 ? 0 : discountPaiseRaw;
    final derivedTotal = subtotal - discount;
    final grandTotal = grandTotalPaiseRaw != 0
        ? grandTotalPaiseRaw
        : (derivedTotal < 0 ? 0 : derivedTotal);
    final count = itemCountRaw > 0 ? itemCountRaw : items.length;
    return ReceiptPayload._(
      billId: billId.trim().isEmpty ? 'DRAFT-BILL' : billId.trim(),
      storeName: _storeName(settings),
      storeBusinessType: _businessType(settings),
      storeAddress: _address(settings),
      fssaiNumber: settings.fssaiNumber,
      printLanguage: settings.printLanguage == 'ta' ? 'ta' : 'en',
      paymentMode: paymentMode.trim().isEmpty ? 'CASH' : paymentMode,
      itemCount: count < 0 ? 0 : count,
      subtotalPaise: subtotal,
      discountPaise: discount,
      grandTotalPaise: grandTotal,
      createdAt: createdAt,
      items: items,
    );
  }

  /// Builds a payload from the typed [BillData] currently in the cart/editor
  /// plus the persisted store profile and print language.
  factory ReceiptPayload.fromBillData(
    BillData bill, {
    required AppSettings settings,
  }) {
    return _normalize(
      billId: bill.billId,
      settings: settings,
      paymentMode: bill.paymentMode.wire,
      itemCountRaw: bill.itemCount,
      subtotalPaise: bill.subtotalPaise,
      discountPaiseRaw: bill.discountPaise,
      grandTotalPaiseRaw: bill.grandTotalPaise,
      createdAt: bill.createdAt,
      items: bill.items.map(ReceiptItem.fromBillItem).toList(),
    );
  }

  /// Builds a payload from a raw saved `billData` map (reprint flow).
  factory ReceiptPayload.fromBillDataJson(
    Map<String, dynamic> json, {
    required AppSettings settings,
    String? billId,
  }) {
    int asInt(Object? v) => (v is num) ? v.round() : int.tryParse('$v') ?? 0;
    final rawItems = (json['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(ReceiptItem.fromJson)
        .toList();
    return _normalize(
      billId: (billId ?? json['billId'] ?? '').toString(),
      settings: settings,
      paymentMode: (json['paymentMode'] ?? 'CASH').toString(),
      itemCountRaw: asInt(json['itemCount']),
      subtotalPaise: asInt(json['subtotalPaise']),
      discountPaiseRaw: asInt(json['discountPaise']),
      grandTotalPaiseRaw: asInt(json['grandTotalPaise']),
      createdAt: (json['createdAt'] ?? '').toString(),
      items: items,
    );
  }
}

/// A rendered receipt ready to preview/print: the bill id (used as the window
/// title / preview label) and the full HTML document.
class ReceiptDocument {
  const ReceiptDocument({required this.billId, required this.html});

  final String billId;
  final String html;
}
