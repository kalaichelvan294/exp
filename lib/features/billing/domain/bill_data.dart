import 'billing_enums.dart';
import 'bill_totals.dart';
import 'cart_line.dart';

/// A single line in a bill payload. Mirrors `buildBillItemsFromCart`.
class BillItem {
  const BillItem({
    required this.id,
    required this.sku,
    required this.name,
    this.nameTa = '',
    this.brandName = '',
    this.category = 'UNCATEGORIZED',
    required this.pricingType,
    required this.qty,
    required this.retailPricePaise,
    this.wholesalePricePaise,
    this.wholesaleMinQty,
    required this.priceTier,
    required this.ratePaise,
    required this.lineTotalPaise,
  });

  final String id;
  final String sku;
  final String name;
  final String nameTa;
  final String brandName;
  final String category;
  final PricingType pricingType;
  final num qty;
  final int retailPricePaise;
  final int? wholesalePricePaise;
  final num? wholesaleMinQty;
  final PriceTier priceTier;
  final int ratePaise;
  final int lineTotalPaise;

  factory BillItem.fromCartLine(CartLine line) => BillItem(
    id: line.id,
    sku: line.sku,
    name: line.name,
    nameTa: line.nameTa,
    brandName: line.brandName,
    category: line.category,
    pricingType: line.pricingType,
    qty: line.qty,
    retailPricePaise: line.retailRatePaise,
    wholesalePricePaise: line.wholesaleRatePaise,
    wholesaleMinQty: line.wholesaleMinQty,
    priceTier: line.priceTier,
    ratePaise: line.ratePaise,
    lineTotalPaise: line.lineTotalPaise,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sku': sku,
    'name': name,
    'nameTa': nameTa,
    'brandName': brandName,
    'category': category,
    'pricingType': pricingType.wire,
    'qty': qty,
    'retailPricePaise': retailPricePaise,
    'wholesalePricePaise': wholesalePricePaise,
    'wholesaleMinQty': wholesaleMinQty,
    'priceTier': priceTier.wire,
    'rate': ratePaise,
    'lineTotalPaise': lineTotalPaise,
  };
}

/// The bill payload sent to the API bridge and used as the receipt payload for
/// the Phase 7 WebView print flow. Mirrors `buildBillData`.
class BillData {
  const BillData({
    required this.billId,
    required this.paymentMode,
    required this.discountMode,
    required this.discountValue,
    required this.itemCount,
    required this.subtotalPaise,
    required this.discountPaise,
    required this.grandTotalPaise,
    required this.items,
    required this.createdAt,
  });

  final String billId;
  final PaymentMode paymentMode;
  final DiscountMode discountMode;
  final num discountValue;
  final int itemCount;
  final int subtotalPaise;
  final int discountPaise;
  final int grandTotalPaise;
  final List<BillItem> items;
  final String createdAt;

  factory BillData.fromCart({
    required String billId,
    required PaymentMode paymentMode,
    required DiscountMode discountMode,
    required num discountValue,
    required List<CartLine> cart,
    required BillTotals totals,
    String? createdAt,
  }) {
    return BillData(
      billId: billId,
      paymentMode: paymentMode,
      discountMode: discountMode,
      discountValue: discountValue,
      itemCount: cart.length,
      subtotalPaise: totals.subtotalPaise,
      discountPaise: totals.discountPaise,
      grandTotalPaise: totals.grandTotalPaise,
      items: cart.map(BillItem.fromCartLine).toList(),
      createdAt: createdAt ?? DateTime.now().toUtc().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
    'billId': billId,
    'paymentMode': paymentMode.wire,
    'discountMode': discountMode.wire,
    'discountValue': discountValue,
    'itemCount': itemCount,
    'subtotalPaise': subtotalPaise,
    'discountPaise': discountPaise,
    'grandTotalPaise': grandTotalPaise,
    'items': items.map((i) => i.toJson()).toList(),
    'createdAt': createdAt,
  };
}
