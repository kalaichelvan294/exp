import '../../billing/domain/billing_enums.dart';

/// A catalog item as returned by the Electron `items:list` handler. Field names
/// mirror the sqlite/postgres adapter projection (camelCase for item metadata,
/// snake_case for inventory columns).
class Item {
  const Item({
    required this.id,
    required this.name,
    this.nameTa = '',
    this.category = 'OTHER',
    required this.sku,
    required this.pricingType,
    this.brandName = '',
    required this.retailPricePaise,
    this.wholesalePricePaise,
    this.wholesaleMinQty,
    this.invCurrentQty = 0,
    this.invCurrentWeight = 0,
    this.invMinQty = 0,
    this.invMinWeight = 0,
  });

  final String id;
  final String name;
  final String nameTa;
  final String category;
  final String sku;
  final PricingType pricingType;
  final String brandName;
  final int retailPricePaise;
  final int? wholesalePricePaise;
  final num? wholesaleMinQty;

  final num invCurrentQty;
  final num invCurrentWeight;
  final num invMinQty;
  final num invMinWeight;

  /// "nameTa / name" when a Tamil name is present, else the English name.
  String get displayName => nameTa.trim().isNotEmpty
      ? '${nameTa.trim()} / ${name.trim()}'
      : name.trim();

  /// "quantity" for UNIT items, "weight" for WEIGHT items.
  String get trackType =>
      pricingType == PricingType.weight ? 'weight' : 'quantity';

  /// Current stock in the item's tracked unit.
  num get currentStock =>
      pricingType == PricingType.weight ? invCurrentWeight : invCurrentQty;

  /// Low-stock threshold in the item's tracked unit.
  num get minStock =>
      pricingType == PricingType.weight ? invMinWeight : invMinQty;

  /// Parity with the Electron low-stock rule: stock > 0 and <= min.
  bool get isLowStock => currentStock > 0 && currentStock <= minStock;

  factory Item.fromJson(Map<String, dynamic> json) {
    num asNum(Object? v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
    int asInt(Object? v) => asNum(v).round();
    final retail = asInt(
      json['retailPricePaise'] ??
          json['retail_price_paise'] ??
          json['rate'] ??
          json['retailPrice'] ??
          0,
    );
    final brand = json['brandName'] ?? json['brand_name'] ?? '';
    final pricingWire = json['pricingType'] ?? json['pricing_type'] ?? 'unit';
    final wholesalePaise =
        json['wholesalePricePaise'] ??
        json['wholesale_price_paise'] ??
        json['wholesalePrice'];
    final wholesaleMinQtyValue =
        json['wholesaleMinQty'] ??
        json['wholesale_min_qty'] ??
        json['wholesaleMin'];

    return Item(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      nameTa: (json['nameTa'] ?? json['name_ta'] ?? '').toString(),
      category: (json['category'] ?? 'OTHER').toString(),
      sku: (json['sku'] ?? '').toString(),
      pricingType: PricingType.fromWire(pricingWire),
      brandName: brand.toString(),
      retailPricePaise: retail,
      wholesalePricePaise: wholesalePaise == null
          ? null
          : asInt(wholesalePaise),
      wholesaleMinQty: wholesaleMinQtyValue == null
          ? null
          : asNum(wholesaleMinQtyValue),
      invCurrentQty: asNum(json['inv_current_qty']),
      invCurrentWeight: asNum(json['inv_current_weight']),
      invMinQty: asNum(json['inv_min_qty']),
      invMinWeight: asNum(json['inv_min_weight']),
    );
  }
}
