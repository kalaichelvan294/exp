import 'billing_enums.dart';
import '../../../core/images/item_image_path.dart';

/// A searchable product returned by the API bridge.
///
/// Field names/semantics mirror the DB adapter DTO (`retailPricePaise`,
/// `wholesalePricePaise`, `wholesaleMinQty`, `rate`).
class Product {
  const Product({
    required this.id,
    required this.sku,
    this.barcode = '',
    required this.name,
    this.nameTa = '',
    this.brandName = '',
    this.category = 'UNCATEGORIZED',
    this.pricingType = PricingType.unit,
    required this.retailPricePaise,
    this.wholesalePricePaise,
    this.wholesaleMinQty,
    this.invCurrentQty = 0,
    this.invCurrentWeight = 0,
    required this.ratePaise,
  });

  final String id;
  final String sku;
  final String barcode;
  final String name;
  final String nameTa;
  final String brandName;
  final String category;
  final PricingType pricingType;
  final int retailPricePaise;
  final int? wholesalePricePaise;
  final num? wholesaleMinQty;
  final num invCurrentQty;
  final num invCurrentWeight;

  /// Default display rate from the DB (`COALESCE(retail_price_paise, rate)`).
  final int ratePaise;

  /// Display name used in search/cart: "Tamil / English" when a Tamil name
  /// exists, otherwise just the English name.
  String get displayName => nameTa.isNotEmpty ? '$nameTa / $name' : name;

  String get imageFileName => '${sku.trim()}_master.jpg';

  Iterable<String> get trainingImageFileNames =>
      ItemImagePath.trainingFileNamesForSku(sku);

  num get currentStock =>
      pricingType == PricingType.weight ? invCurrentWeight : invCurrentQty;

  String get stockDisplay {
    final stock = currentStock;
    if (pricingType == PricingType.weight) {
      return '${stock.toDouble().toStringAsFixed(3)} wt';
    }
    return '${stock.round()} qty';
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => (v is num) ? v.round() : int.tryParse('$v') ?? 0;
    num asNum(Object? v) => v is num ? v : num.tryParse('$v') ?? 0;
    num? asNumOrNull(Object? v) {
      if (v == null) return null;
      if (v is num) return v;
      return num.tryParse('$v');
    }

    final retail = asInt(
      json['retailPricePaise'] ??
          json['retail_price_paise'] ??
          json['rate'] ??
          json['retailPrice'] ??
          0,
    );
    final pricingWire = json['pricingType'] ?? json['pricing_type'] ?? 'unit';
    final brand = json['brandName'] ?? json['brand_name'] ?? '';
    final wholesalePaise =
        json['wholesalePricePaise'] ??
        json['wholesale_price_paise'] ??
        json['wholesalePrice'];
    final wholesaleMinQtyValue =
        json['wholesaleMinQty'] ??
        json['wholesale_min_qty'] ??
        json['wholesaleMin'];

    return Product(
      id: (json['id'] ?? '').toString(),
      sku: (json['sku'] ?? json['id'] ?? '').toString(),
      barcode: (json['barcode'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      nameTa: (json['nameTa'] ?? '').toString(),
      brandName: brand.toString(),
      category: (json['category'] ?? 'UNCATEGORIZED').toString(),
      pricingType: PricingType.fromWire(pricingWire),
      retailPricePaise: retail,
      wholesalePricePaise: wholesalePaise == null
          ? null
          : asInt(wholesalePaise),
      wholesaleMinQty: asNumOrNull(wholesaleMinQtyValue),
      invCurrentQty: asNum(json['inv_current_qty']),
      invCurrentWeight: asNum(json['inv_current_weight']),
      ratePaise: asInt(json['rate'] ?? json['retail_price_paise'] ?? retail),
    );
  }
}
