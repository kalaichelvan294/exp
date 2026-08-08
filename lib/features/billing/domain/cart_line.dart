import 'billing_enums.dart';
import 'product.dart';

/// A mutable cart line. Ports the line model + `applyLinePricing` from
/// `cart.js` so wholesale-tier behavior matches the Electron app exactly.
class CartLine {
  CartLine({
    required this.id,
    required this.sku,
    required this.name,
    this.nameTa = '',
    this.brandName = '',
    this.category = 'UNCATEGORIZED',
    this.pricingType = PricingType.unit,
    required this.qty,
    required this.retailRatePaise,
    this.wholesaleRatePaise,
    this.wholesaleMinQty,
    required this.ratePaise,
    this.priceTier = PriceTier.retail,
    this.entryMethod = 'MANUAL_SEARCH',
  });

  final String id;
  final String sku;
  final String name;
  final String nameTa;
  final String brandName;
  final String category;
  final PricingType pricingType;

  num qty;
  final int retailRatePaise;
  final int? wholesaleRatePaise;
  final num? wholesaleMinQty;

  /// Effective per-unit rate in paise (updated by [applyLinePricing]).
  int ratePaise;
  PriceTier priceTier;
  final String entryMethod;

  String get displayName => nameTa.isNotEmpty ? '$nameTa / $name' : name;

  String get skuDisplay => sku.isNotEmpty ? sku : (id.isNotEmpty ? id : '—');

  String get mergeKey => '$id|$sku|$pricingType';

  bool get hasWholesaleConfig =>
      (wholesaleRatePaise != null && wholesaleRatePaise! > 0) &&
      (wholesaleMinQty != null && wholesaleMinQty! > 0);

  /// `line.qty * line.rate` rounded, in paise.
  int get lineTotalPaise => (qty * ratePaise).round();

  String get qtyDisplay =>
      pricingType == PricingType.weight ? qty.toDouble().toStringAsFixed(3) : '${qty.round()}';

  /// Ports `applyLinePricing`: when auto-apply is on and the wholesale
  /// threshold is met, switch to the wholesale rate/tier; else retail.
  int applyLinePricing(bool autoWholesale) {
    final baseRetail = retailRatePaise > 0 ? retailRatePaise : ratePaise;
    if (autoWholesale &&
        wholesaleRatePaise != null &&
        wholesaleRatePaise! > 0 &&
        wholesaleMinQty != null &&
        wholesaleMinQty! > 0 &&
        qty >= wholesaleMinQty!) {
      ratePaise = wholesaleRatePaise!;
      priceTier = PriceTier.wholesale;
      return ratePaise;
    }
    ratePaise = baseRetail;
    priceTier = PriceTier.retail;
    return ratePaise;
  }

  /// Ports `cart.addItem`: WEIGHT items default to qty 0.5, UNIT to 1.
  factory CartLine.fromProduct(Product product, String entryMethod) {
    final base = product.retailPricePaise > 0
        ? product.retailPricePaise
        : product.ratePaise;
    return CartLine(
      id: product.id,
      sku: product.sku,
      name: product.name,
      nameTa: product.nameTa,
      brandName: product.brandName,
      category: product.category,
      pricingType: product.pricingType,
      qty: product.pricingType == PricingType.weight ? 0.5 : 1,
      retailRatePaise: base,
      wholesaleRatePaise: product.wholesalePricePaise,
      wholesaleMinQty: product.wholesaleMinQty,
      ratePaise: base,
      priceTier: PriceTier.retail,
      entryMethod: entryMethod,
    );
  }
}
