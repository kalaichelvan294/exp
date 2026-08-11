import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/appearance.dart';
import '../../../core/logging/exception_file_logger.dart';
import '../../billing/domain/billing_enums.dart';
import '../../image_search/data/product_embedding_repository.dart';
import '../data/settings_repository.dart';
import '../domain/app_settings.dart';
import 'settings_state.dart';

/// Settings controller. Ports settings.js: loads all settings, saves each
/// section independently (with parity validation), and manages the editable
/// category/brand lists and brand propagation.
class SettingsController extends Notifier<SettingsState> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);
  bool _embeddingCancelRequested = false;

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
        cleanupTrainingImagesAfterEmbedding: false,
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

  void previewUpi({required String upiId, required String displayName}) {
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
        : AppSettings.normalizePaymentModes(modes.map((m) => m.wire).toList());
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

  void previewEmbeddingCleanup(bool enabled) {
    state = state.copyWith(cleanupTrainingImagesAfterEmbedding: enabled);
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

  Future<void> refreshImageEmbeddings() async {
    if (state.embeddingRefreshRunning) return;
    final rootPath = state.settings.itemImagesRootPath.trim();
    if (rootPath.isEmpty) {
      return _err(
        'Item images root path is required before refreshing embeddings.',
      );
    }

    _embeddingCancelRequested = false;
    state = state.copyWith(
      embeddingRefreshRunning: true,
      embeddingRefreshDialogVisible: true,
      embeddingTotalProducts: 0,
      embeddingProcessedProducts: 0,
      embeddingProductsIndexed: 0,
      embeddingImagesIndexed: 0,
      embeddingProductsSkipped: 0,
      embeddingBarcodeUpdates: 0,
      embeddingCurrentSku: '',
      embeddingCurrentStage: 'starting',
      embeddingResult: '',
      message: SettingsMessage.none,
    );

    try {
      final result = await ref
          .read(productEmbeddingRepositoryProvider)
          .rebuildIndex(
            imagesRootPath: rootPath,
            cleanupTrainingImages: state.cleanupTrainingImagesAfterEmbedding,
            onProgress: (progress) {
              state = state.copyWith(
                embeddingTotalProducts: progress.totalProducts,
                embeddingProcessedProducts: progress.processedProducts,
                embeddingProductsIndexed: progress.productsIndexed,
                embeddingImagesIndexed: progress.imagesIndexed,
                embeddingProductsSkipped: progress.productsSkipped,
                embeddingBarcodeUpdates: progress.barcodeUpdates,
                embeddingCurrentSku: progress.currentSku,
                embeddingCurrentStage: progress.currentStage,
              );
            },
            isCancelled: () => _embeddingCancelRequested,
          );
      final summary =
          'Indexed ${result.productsIndexed} product(s), ${result.imagesIndexed} image(s), '
          'skipped ${result.productsSkipped} product(s), barcode updates ${result.barcodeUpdates}.';
      state = state.copyWith(
        embeddingRefreshRunning: false,
        embeddingProductsIndexed: result.productsIndexed,
        embeddingImagesIndexed: result.imagesIndexed,
        embeddingProductsSkipped: result.productsSkipped,
        embeddingBarcodeUpdates: result.barcodeUpdates,
        embeddingCurrentStage: result.cancelled ? 'cancelled' : 'completed',
        embeddingResult: result.cancelled ? 'Cancelled. $summary' : summary,
      );
      if (result.cancelled) {
        _err('Embedding refresh cancelled.');
      } else {
        _ok(summary);
      }
    } catch (e) {
      state = state.copyWith(
        embeddingRefreshRunning: false,
        embeddingCurrentStage: 'failed',
        embeddingResult: 'Failed to refresh embeddings: ${e.toString()}',
      );
      _err('Failed to refresh embeddings: ${e.toString()}');
    }
  }

  void closeEmbeddingRefreshDialog() {
    if (state.embeddingRefreshRunning) {
      _embeddingCancelRequested = true;
    }
    state = state.copyWith(embeddingRefreshDialogVisible: false);
  }

  Future<void> downloadExceptionLogFile() async {
    try {
      final path = await ref.read(exceptionFileLoggerProvider).exportLogFile();
      if (path == null) {
        _err('No exception log file available to download.');
        return;
      }
      _ok('Exception log downloaded to: $path');
    } catch (e) {
      _err('Failed to download exception log: ${e.toString()}');
    }
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
