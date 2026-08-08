import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/appearance.dart';
import '../../billing/domain/billing_enums.dart';
import '../data/settings_repository.dart';
import '../domain/app_settings.dart';
import 'settings_state.dart';

/// Settings controller. Ports settings.js: loads all settings, saves each
/// section independently (with parity validation), and manages the editable
/// category/brand lists and brand propagation.
class SettingsController extends Notifier<SettingsState> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  SettingsState build() {
    Future.microtask(load);
    return const SettingsState();
  }

  Future<void> load() async {
    try {
      final settings = await _repo.loadSettings();
      final inv = await _repo.loadInventorySettings();
      state = state.copyWith(
        settings: settings,
        invControlEnabled: inv.invControlEnabled,
        categories: List.of(settings.itemCategories),
        brands: List.of(settings.itemBrands),
        loaded: true,
        message: SettingsMessage.none,
      );
    } catch (e) {
      state = state.copyWith(
        loaded: true,
        message: SettingsMessage(
          'Failed to load settings: ${e.toString()}',
          SettingsMessageType.error,
        ),
      );
    }
  }

  void _ok(String text) => state = state.copyWith(
    message: SettingsMessage(text, SettingsMessageType.success),
  );

  void _err(String text) => state = state.copyWith(
    message: SettingsMessage(text, SettingsMessageType.error),
  );

  void clearMessage() => state = state.copyWith(message: SettingsMessage.none);

  void showSuccess(String text) => _ok(text);

  void showError(String text) => _err(text);

  void previewStoreProfile({
    required String storeName,
    required String businessType,
    required String storeAddress,
    required String fssaiNumber,
  }) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        storeName: storeName,
        businessType: businessType,
        storeAddress: storeAddress,
        fssaiNumber: fssaiNumber,
      ),
    );
  }

  void previewPrintLanguage(String language) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        printLanguage: language == 'ta' ? 'ta' : 'en',
      ),
    );
  }

  void previewUpi({
    required String upiId,
    required String displayName,
  }) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        upiId: upiId,
        upiDisplayName: displayName,
      ),
    );
  }

  void previewPaymentModes(List<PaymentMode> modes) {
    final normalized = modes.isEmpty
        ? <PaymentMode>[...state.settings.billingPaymentModes]
        : AppSettings.normalizePaymentModes(
            modes.map((m) => m.wire).toList(),
          );
    state = state.copyWith(
      settings: state.settings.copyWith(billingPaymentModes: normalized),
    );
  }

  void previewAppearance({
    required String uiSizeVariant,
    required String themeMode,
  }) {
    final variant = AppSettings.normalizeUiSizeVariant(uiSizeVariant);
    final mode = AppSettings.normalizeThemeMode(themeMode);
    state = state.copyWith(
      settings: state.settings.copyWith(
        uiSizeVariant: variant,
        themeMode: mode,
      ),
    );
    ref
        .read(appearanceControllerProvider.notifier)
        .apply(themeMode: mode, uiSizeVariant: variant);
  }

  void previewInventoryControl(bool enabled) {
    state = state.copyWith(invControlEnabled: enabled);
  }

  void previewItemConfig({
    required bool wholesaleAutoApply,
    required String itemImagesRootPath,
  }) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        itemsWholesaleAutoApply: wholesaleAutoApply,
        itemImagesRootPath: itemImagesRootPath.trim(),
      ),
    );
  }

  Future<void> _save(
    Map<String, dynamic> patch,
    AppSettings updated,
    String successText,
    String failPrefix,
  ) async {
    try {
      await _repo.saveSettings(patch);
      state = state.copyWith(settings: updated);
      _ok(successText);
    } catch (e) {
      _err('$failPrefix: ${e.toString()}');
    }
  }

  Future<void> saveStoreProfile({
    required String storeName,
    required String businessType,
    required String storeAddress,
    required String fssaiNumber,
  }) async {
    final name = storeName.trim();
    final type = businessType.trim();
    final address = storeAddress.trim();
    if (name.isEmpty) return _err('Store name is required');
    if (type.isEmpty) return _err('Business type is required');
    if (address.isEmpty) return _err('Store address is required');
    final fssai = fssaiNumber.trim();
    await _save(
      {
        'storeName': name,
        'businessType': type,
        'storeAddress': address,
        'fssaiNumber': fssai,
      },
      state.settings.copyWith(
        storeName: name,
        businessType: type,
        storeAddress: address,
        fssaiNumber: fssai,
      ),
      'Settings saved successfully!',
      'Failed to save settings',
    );
  }

  Future<void> savePrintLanguage(String language) async {
    final lang = language == 'ta' ? 'ta' : 'en';
    await _save(
      {'printLanguage': lang},
      state.settings.copyWith(printLanguage: lang),
      'Print settings saved successfully!',
      'Failed to save print settings',
    );
  }

  Future<void> saveUpi({
    required String upiId,
    required String displayName,
  }) async {
    final id = upiId.trim();
    final name = displayName.trim();
    await _save(
      {'upiId': id, 'upiDisplayName': name},
      state.settings.copyWith(upiId: id, upiDisplayName: name),
      'UPI settings saved successfully!',
      'Failed to save UPI settings',
    );
  }

  Future<void> savePaymentModes(List<PaymentMode> modes) async {
    if (modes.isEmpty) return _err('Select at least one payment mode.');
    final normalized = AppSettings.normalizePaymentModes(
      modes.map((m) => m.wire).toList(),
    );
    await _save(
      {'billingPaymentModes': normalized.map((m) => m.wire).toList()},
      state.settings.copyWith(billingPaymentModes: normalized),
      'Payment options saved successfully!',
      'Failed to save payment options',
    );
  }

  Future<void> saveAppearance({
    required String uiSizeVariant,
    required String themeMode,
  }) async {
    final variant = AppSettings.normalizeUiSizeVariant(uiSizeVariant);
    final mode = AppSettings.normalizeThemeMode(themeMode);
    try {
      await _repo.saveSettings({'uiSizeVariant': variant, 'themeMode': mode});
      state = state.copyWith(
        settings: state.settings.copyWith(
          uiSizeVariant: variant,
          themeMode: mode,
        ),
      );
      ref
          .read(appearanceControllerProvider.notifier)
          .apply(themeMode: mode, uiSizeVariant: variant);
      _ok('Appearance settings saved successfully!');
    } catch (e) {
      _err('Failed to save appearance settings: ${e.toString()}');
    }
  }

  Future<void> saveInventoryControl(bool enabled) async {
    try {
      await _repo.saveInventorySettings(invControlEnabled: enabled);
      state = state.copyWith(invControlEnabled: enabled);
      _ok('Inventory settings saved successfully!');
    } catch (e) {
      _err('Failed to save inventory settings: ${e.toString()}');
    }
  }

  // ── item config (categories / brands) ─────────────────────────────────────

  void addCategory(String name) {
    final normalized = AppSettings.sanitizeCategory(name);
    if (normalized.isEmpty) return _err('Category name is required.');
    if (normalized == 'OTHER') {
      return _err('"OTHER" is a system category and is always available.');
    }
    if (state.categories.contains(normalized)) {
      return _err('Category already exists.');
    }
    final categories = [...state.categories, normalized];
    state = state.copyWith(
      categories: categories,
      settings: state.settings.copyWith(itemCategories: categories),
      message: const SettingsMessage(
        'Category added. Save configuration to apply.',
        SettingsMessageType.success,
      ),
    );
  }

  void removeCategory(String name) {
    final categories = state.categories.where((c) => c != name).toList();
    state = state.copyWith(
      categories: categories,
      settings: state.settings.copyWith(itemCategories: categories),
    );
  }

  void addBrand(String name) {
    final normalized = AppSettings.sanitizeBrand(name);
    if (normalized.isEmpty) return _err('Brand name is required.');
    if (state.brands.contains(normalized)) {
      return _err('Brand already exists.');
    }
    final brands = [...state.brands, normalized];
    state = state.copyWith(
      brands: brands,
      settings: state.settings.copyWith(itemBrands: brands),
      message: const SettingsMessage(
        'Brand added. Save configuration to apply.',
        SettingsMessageType.success,
      ),
    );
  }

  void removeBrand(String name) {
    final brands = state.brands.where((b) => b != name).toList();
    state = state.copyWith(
      brands: brands,
      settings: state.settings.copyWith(itemBrands: brands),
    );
  }

  Future<void> propagateBrands() async {
    try {
      final brands = await _repo.propagateBrands();
      state = state.copyWith(
        brands: brands,
        settings: state.settings.copyWith(itemBrands: brands),
        message: SettingsMessage(
          'Propagated ${brands.length} unique brands from catalog.',
          SettingsMessageType.success,
        ),
      );
    } catch (e) {
      _err('Propagate failed: ${e.toString()}');
    }
  }

  Future<void> saveItemConfig({
    required bool wholesaleAutoApply,
    required String itemImagesRootPath,
  }) async {
    final imagesRoot = itemImagesRootPath.trim();
    await _save(
      {
        'itemCategories': state.categories,
        'itemBrands': state.brands,
        'itemsWholesaleAutoApply': wholesaleAutoApply,
        'itemImagesRootPath': imagesRoot,
      },
      state.settings.copyWith(
        itemCategories: List.of(state.categories),
        itemBrands: List.of(state.brands),
        itemsWholesaleAutoApply: wholesaleAutoApply,
        itemImagesRootPath: imagesRoot,
      ),
      'Item configuration saved successfully!',
      'Failed to save item configuration',
    );
  }

  /// Restores the working category/brand lists from the last-saved settings
  /// (parity with the reset buttons).
  void resetItemConfig() {
    state = state.copyWith(
      categories: List.of(state.settings.itemCategories),
      brands: List.of(state.settings.itemBrands),
      message: SettingsMessage.none,
    );
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
