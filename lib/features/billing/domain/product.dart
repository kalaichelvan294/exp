import 'billing_enums.dart';

/// A searchable product returned by the API bridge.
///
/// Field names/semantics mirror the DB adapter DTO (`retailPricePaise`,
/// `wholesalePricePaise`, `wholesaleMinQty`, `rate`).
class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.name,
    this.nameTa = '',
    this.brandName = '',
    this.category = 'UNCATEGORIZED',
    this.pricingType = PricingType.unit,
    required this.retailPricePaise,
    this.wholesalePricePaise,
    this.wholesaleMinQty,
    required this.ratePaise,
  });

  final String id;
  final String sku;
  final String name;
  final String nameTa;
  final String brandName;
  final String category;
  final PricingType pricingType;
  final int retailPricePaise;
  final int? wholesalePricePaise;
  final num? wholesaleMinQty;

  /// Default display rate from the DB (`COALESCE(retail_price_paise, rate)`).
  final int ratePaise;

  /// Display name used in search/cart: "Tamil / English" when a Tamil name
  /// exists, otherwise just the English name.
  String get displayName => nameTa.isNotEmpty ? '$nameTa / $name' : name;

  factory Product.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => (v is num) ? v.round() : int.tryParse('$v') ?? 0;
    num? asNumOrNull(Object? v) {
      if (v == null) return null;
      if (v is num) return v;
      return num.tryParse('$v');
    }

    final retail = asInt(json['retailPricePaise'] ?? json['rate']);
    return Product(
      id: (json['id'] ?? '').toString(),
      sku: (json['sku'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      nameTa: (json['nameTa'] ?? '').toString(),
      brandName: (json['brandName'] ?? '').toString(),
      category: (json['category'] ?? 'UNCATEGORIZED').toString(),
      pricingType: PricingType.fromWire(json['pricingType']),
      retailPricePaise: retail,
      wholesalePricePaise: json['wholesalePricePaise'] == null
          ? null
          : asInt(json['wholesalePricePaise']),
      wholesaleMinQty: asNumOrNull(json['wholesaleMinQty']),
      ratePaise: asInt(json['rate'] ?? retail),
    );
  }
}
