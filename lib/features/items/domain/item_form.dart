import '../../billing/domain/billing_enums.dart';
import '../../billing/domain/money.dart';

/// Result of a server SKU validation (parity with `items:validate-sku`).
class SkuValidation {
  const SkuValidation({
    required this.valid,
    this.exists = false,
    this.message = '',
  });

  final bool valid;
  final bool exists;
  final String message;

  static const requiredSku = SkuValidation(
    valid: false,
    message: 'SKU is required.',
  );

  factory SkuValidation.fromJson(Map<String, dynamic> json) => SkuValidation(
    valid: json['valid'] == true,
    exists: json['exists'] == true,
    message: (json['message'] ?? '').toString(),
  );
}

/// Editable item form inputs and their validation/serialization. Mirrors
/// `readFormData` + `validateForm` in items-page-controller.js and the
/// `mapItemData` guards in the adapter.
class ItemFormData {
  const ItemFormData({
    required this.name,
    this.nameTa = '',
    this.category = 'OTHER',
    this.brandName = '',
    required this.sku,
    required this.pricingType,
    required this.retailPriceInput,
    this.wholesalePriceInput = '',
    this.wholesaleMinQtyInput = '',
  });

  final String name;
  final String nameTa;
  final String category;
  final String brandName;
  final String sku;
  final PricingType pricingType;

  /// Raw rupee strings from the form fields.
  final String retailPriceInput;
  final String wholesalePriceInput;
  final String wholesaleMinQtyInput;

  static final RegExp skuPattern = RegExp(r'^[A-Z0-9-]+$');

  /// Uppercase and strip whitespace (parity with `normalizeSku`).
  static String normalizeSku(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'\s+'), '').trim();

  bool get _hasWholesalePrice => wholesalePriceInput.trim().isNotEmpty;
  bool get _hasWholesaleMinQty => wholesaleMinQtyInput.trim().isNotEmpty;

  /// Returns the first validation error, or null when the form is valid.
  /// Does not perform server SKU uniqueness (handled separately).
  String? validate() {
    final normalizedSku = normalizeSku(sku);
    if (name.trim().isEmpty ||
        category.trim().isEmpty ||
        normalizedSku.isEmpty) {
      return 'All fields except Tamil name are required.';
    }

    final retailPaise = Money.parseInrToPaise(retailPriceInput);
    if (retailPaise <= 0) {
      return 'Retail price must be greater than 0.';
    }

    if (_hasWholesalePrice != _hasWholesaleMinQty) {
      return 'Wholesale price and minimum qty must both be provided.';
    }
    if (_hasWholesalePrice) {
      final wholesalePaise = Money.parseInrToPaise(wholesalePriceInput);
      if (wholesalePaise <= 0) {
        return 'Wholesale price must be greater than 0.';
      }
      final minQty = num.tryParse(wholesaleMinQtyInput.trim()) ?? 0;
      if (minQty <= 0) {
        return 'Wholesale minimum qty must be greater than 0.';
      }
      if (pricingType == PricingType.unit && minQty != minQty.roundToDouble()) {
        return 'Wholesale minimum qty must be a whole number for UNIT items.';
      }
    }
    return null;
  }

  /// Builds the `items:create` / `items:update` payload (prices in paise).
  Map<String, dynamic> toPayload() {
    final retailPaise = Money.parseInrToPaise(retailPriceInput);
    final wholesalePaise = _hasWholesalePrice
        ? Money.parseInrToPaise(wholesalePriceInput)
        : null;
    final wholesaleMinQty = _hasWholesaleMinQty
        ? num.tryParse(wholesaleMinQtyInput.trim())
        : null;

    return {
      'name': name.trim(),
      'nameTa': nameTa.trim(),
      'category': category.trim().isEmpty ? 'OTHER' : category.trim(),
      'brandName': brandName.trim(),
      'brand_name': brandName.trim(),
      'sku': normalizeSku(sku),
      'pricingType': pricingType.wire,
      'pricing_type': pricingType.wire,
      'retailPrice': retailPaise,
      'retailPricePaise': retailPaise,
      'retail_price_paise': retailPaise,
      'rate': retailPaise,
      'wholesalePrice': wholesalePaise,
      'wholesalePricePaise': wholesalePaise,
      'wholesale_price_paise': wholesalePaise,
      'wholesaleMinQty': wholesaleMinQty,
      'wholesale_min_qty': wholesaleMinQty,
    };
  }
}
