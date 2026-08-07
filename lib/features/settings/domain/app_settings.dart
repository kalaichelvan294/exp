import '../../billing/domain/billing_enums.dart';

/// Valid UI size variants and their font/space scale factors (parity with
/// appearance.js UI_SIZE_VARIANTS).
const Map<String, double> kUiSizeScales = {
  'xs': 0.88,
  'sm': 0.94,
  'md': 1.0,
  'lg': 1.08,
  'xl': 1.14,
  'xxl': 1.2,
};

const List<PaymentMode> _allPaymentModes = [
  PaymentMode.cash,
  PaymentMode.gpay,
  PaymentMode.card,
];

/// Aggregated application settings persisted under `system:settings`. Field
/// names match the keys read/written by the Electron settings page.
class AppSettings {
  const AppSettings({
    this.storeName = '',
    this.businessType = '',
    this.storeAddress = '',
    this.fssaiNumber = '',
    this.printLanguage = 'en',
    this.upiId = '',
    this.upiDisplayName = '',
    this.billingPaymentModes = _allPaymentModes,
    this.uiSizeVariant = 'md',
    this.themeMode = 'light',
    this.itemCategories = const [],
    this.itemBrands = const [],
    this.itemsWholesaleAutoApply = true,
  });

  final String storeName;
  final String businessType;
  final String storeAddress;
  final String fssaiNumber;

  final String printLanguage; // 'en' | 'ta'

  final String upiId;
  final String upiDisplayName;

  final List<PaymentMode> billingPaymentModes;

  final String uiSizeVariant; // xs..xxl
  final String themeMode; // 'light' | 'dark'

  final List<String> itemCategories;
  final List<String> itemBrands;
  final bool itemsWholesaleAutoApply;

  double get fontScale => kUiSizeScales[uiSizeVariant] ?? 1.0;
  bool get isDark => themeMode == 'dark';

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      storeName: (json['storeName'] ?? '').toString(),
      businessType: (json['businessType'] ?? '').toString(),
      storeAddress: (json['storeAddress'] ?? '').toString(),
      fssaiNumber: (json['fssaiNumber'] ?? '').toString(),
      printLanguage:
          (json['printLanguage'] ?? '').toString() == 'ta' ? 'ta' : 'en',
      upiId: (json['upiId'] ?? '').toString(),
      upiDisplayName: (json['upiDisplayName'] ?? '').toString(),
      billingPaymentModes:
          normalizePaymentModes(json['billingPaymentModes']),
      uiSizeVariant: normalizeUiSizeVariant(json['uiSizeVariant']),
      themeMode: normalizeThemeMode(json['themeMode']),
      itemCategories: normalizeCategories(json['itemCategories']),
      itemBrands: normalizeBrands(json['itemBrands']),
      itemsWholesaleAutoApply: json['itemsWholesaleAutoApply'] != false,
    );
  }

  AppSettings copyWith({
    String? storeName,
    String? businessType,
    String? storeAddress,
    String? fssaiNumber,
    String? printLanguage,
    String? upiId,
    String? upiDisplayName,
    List<PaymentMode>? billingPaymentModes,
    String? uiSizeVariant,
    String? themeMode,
    List<String>? itemCategories,
    List<String>? itemBrands,
    bool? itemsWholesaleAutoApply,
  }) {
    return AppSettings(
      storeName: storeName ?? this.storeName,
      businessType: businessType ?? this.businessType,
      storeAddress: storeAddress ?? this.storeAddress,
      fssaiNumber: fssaiNumber ?? this.fssaiNumber,
      printLanguage: printLanguage ?? this.printLanguage,
      upiId: upiId ?? this.upiId,
      upiDisplayName: upiDisplayName ?? this.upiDisplayName,
      billingPaymentModes: billingPaymentModes ?? this.billingPaymentModes,
      uiSizeVariant: uiSizeVariant ?? this.uiSizeVariant,
      themeMode: themeMode ?? this.themeMode,
      itemCategories: itemCategories ?? this.itemCategories,
      itemBrands: itemBrands ?? this.itemBrands,
      itemsWholesaleAutoApply:
          itemsWholesaleAutoApply ?? this.itemsWholesaleAutoApply,
    );
  }

  // ── normalization helpers (parity with settings.js) ───────────────────────

  /// Deduped, valid payment modes. Falls back to all modes when empty (parity
  /// with normalizePaymentModes).
  static List<PaymentMode> normalizePaymentModes(Object? value) {
    final source = value is List ? value : const [];
    final result = <PaymentMode>[];
    for (final entry in source) {
      final wire = entry?.toString().trim().toUpperCase();
      final mode = _allPaymentModes.where((m) => m.wire == wire).toList();
      if (mode.isNotEmpty && !result.contains(mode.first)) {
        result.add(mode.first);
      }
    }
    return result.isEmpty ? List.of(_allPaymentModes) : result;
  }

  static String normalizeUiSizeVariant(Object? value) {
    final v = value?.toString();
    return kUiSizeScales.containsKey(v) ? v! : 'md';
  }

  static String normalizeThemeMode(Object? value) =>
      value?.toString() == 'dark' ? 'dark' : 'light';

  /// Uppercase, keep [A-Z0-9 -], collapse spaces, trim (parity with
  /// sanitizeCategoryDraft + normalizeCategoryName).
  static String sanitizeCategory(String value) => value
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9 -]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Uppercase, keep [A-Z0-9 ], collapse spaces, trim (parity with
  /// sanitizeBrandDraft + normalizeBrandName).
  static String sanitizeBrand(String value) => value
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Deduped user categories, excluding the reserved "OTHER" bucket.
  static List<String> normalizeCategories(Object? value) {
    final source = value is List ? value : const [];
    final seen = <String>{};
    final result = <String>[];
    for (final entry in source) {
      final normalized = sanitizeCategory('$entry');
      if (normalized.isNotEmpty &&
          normalized != 'OTHER' &&
          seen.add(normalized)) {
        result.add(normalized);
      }
    }
    return result;
  }

  static List<String> normalizeBrands(Object? value) {
    final source = value is List ? value : const [];
    final seen = <String>{};
    final result = <String>[];
    for (final entry in source) {
      final normalized = sanitizeBrand('$entry');
      if (normalized.isNotEmpty && seen.add(normalized)) {
        result.add(normalized);
      }
    }
    return result;
  }
}
