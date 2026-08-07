import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../settings/data/settings_repository.dart';
import '../data/bulk_file_service.dart';
import '../data/bulk_repository.dart';
import '../domain/bulk_enums.dart';
import '../domain/bulk_preview.dart';
import '../domain/bulk_result.dart';
import 'bulk_state.dart';

/// Bulk Operations controller. Ports bulk-controller.js: template/export
/// downloads, file pick → preview → apply state machine, pagination, last-batch
/// loading, revert, and error-report downloads.
class BulkController extends Notifier<BulkState> {
  BulkRepository get _repo => ref.read(bulkRepositoryProvider);
  BulkFileService get _files => ref.read(bulkFileServiceProvider);
  SettingsRepository get _settings => ref.read(settingsRepositoryProvider);

  @override
  BulkState build() {
    Future.microtask(_init);
    return const BulkState();
  }

  Future<void> _init() async {
    await Future.wait([
      loadFilterOptions(),
      _loadInventoryControl(),
    ]);
    await Future.wait([
      loadLastBatch(BulkOperationType.itemImport),
      loadLastBatch(BulkOperationType.inventoryUpdate),
    ]);
    state = state.copyWith(loaded: true);
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  void _setTabState(BulkOperationType type, BulkTabState next) =>
      state = state.withTab(type, next);

  String _clean(Object error) {
    if (error is ApiException) return error.message;
    return error.toString().replaceFirst(RegExp(r'^Error:\s*'), '');
  }

  void clearToast() => state = state.copyWith(clearToast: true);

  void clearError(BulkOperationType type) =>
      _setTabState(type, state.tab(type).copyWith(clearError: true));

  // ── Tab + filters ──────────────────────────────────────────────────────────

  void setTab(BulkOperationType type) {
    state = state.copyWith(currentTab: type);
    loadLastBatch(type);
  }

  void toggleCategory(String category) {
    final selected = List<String>.of(state.selectedCategories);
    selected.contains(category)
        ? selected.remove(category)
        : selected.add(category);
    state = state.copyWith(selectedCategories: selected);
  }

  void toggleBrand(String brand) {
    final selected = List<String>.of(state.selectedBrandNames);
    selected.contains(brand) ? selected.remove(brand) : selected.add(brand);
    state = state.copyWith(selectedBrandNames: selected);
  }

  void clearFilters() => state = state.copyWith(
        selectedCategories: const [],
        selectedBrandNames: const [],
      );

  void setInvDownloadTrackType(String value) {
    final v = (value == 'quantity' || value == 'weight') ? value : '';
    state = state.copyWith(invDownloadTrackType: v);
  }

  void setInvDownloadLowStockOnly(bool value) =>
      state = state.copyWith(invDownloadLowStockOnly: value);

  // ── Loading (options + inventory control + last batch) ─────────────────────

  Future<void> loadFilterOptions() async {
    try {
      final settings = await _settings.loadSettings();
      final categories = List<String>.of(settings.itemCategories)..sort();
      final brands = List<String>.of(settings.itemBrands)..sort();
      state = state.copyWith(
        categoryOptions: categories,
        brandOptions: brands,
        selectedCategories:
            state.selectedCategories.where(categories.contains).toList(),
        selectedBrandNames:
            state.selectedBrandNames.where(brands.contains).toList(),
      );
    } on ApiException {
      // Filter options are best-effort; leave existing state.
    }
  }

  Future<void> _loadInventoryControl() async {
    try {
      final inv = await _settings.loadInventorySettings();
      state = state.copyWith(invControlEnabled: inv.invControlEnabled);
    } on ApiException {
      state = state.copyWith(invControlEnabled: false);
    }
  }

  Future<void> loadLastBatch(BulkOperationType type) async {
    try {
      final batch = await _repo.getLastBatch(type);
      final tab = state.tab(type);
      _setTabState(
        type,
        batch == null
            ? tab.copyWith(clearLastBatch: true)
            : tab.copyWith(lastBatch: batch),
      );
    } on ApiException {
      // Non-fatal (parity: console.error only).
    }
  }

  // ── File pick + preview ────────────────────────────────────────────────────

  Future<void> pickAndPreview(BulkOperationType type) async {
    if (type == BulkOperationType.inventoryUpdate && !state.invControlEnabled) {
      return;
    }
    try {
      final picked = await _files.pickSpreadsheet();
      if (picked == null) return;
      _setTabState(
        type,
        state.tab(type).copyWith(
              fileName: picked.name,
              bytes: picked.bytes,
              clearError: true,
              clearResult: true,
            ),
      );
      await preview(type);
    } catch (error) {
      _setTabState(type, state.tab(type).copyWith(error: _clean(error)));
    }
  }

  Future<void> preview(BulkOperationType type) async {
    final tab = state.tab(type);
    if (!tab.hasFile) {
      _setTabState(type, tab.copyWith(error: 'No file selected.'));
      return;
    }
    _setTabState(type, tab.copyWith(busy: true, clearError: true));
    try {
      final BulkPreview result = type == BulkOperationType.itemImport
          ? await _repo.previewItems(tab.bytes!)
          : await _repo.previewInventory(tab.bytes!);
      _setTabState(
        type,
        state.tab(type).copyWith(
              preview: result,
              previewPage: 1,
              busy: false,
              clearError: true,
            ),
      );
      await loadLastBatch(type);
    } catch (error) {
      _setTabState(
        type,
        state.tab(type).copyWith(busy: false, error: _clean(error)),
      );
    }
  }

  void nextPage(BulkOperationType type) {
    final tab = state.tab(type);
    if (tab.canNext) {
      _setTabState(type, tab.copyWith(previewPage: tab.previewPage + 1));
    }
  }

  void prevPage(BulkOperationType type) {
    final tab = state.tab(type);
    if (tab.canPrev) {
      _setTabState(type, tab.copyWith(previewPage: tab.previewPage - 1));
    }
  }

  // ── Apply ──────────────────────────────────────────────────────────────────

  Future<void> apply(BulkOperationType type) async {
    final tab = state.tab(type);
    if (!tab.hasFile || !tab.applyEnabled) return;
    _setTabState(type, tab.copyWith(busy: true, clearError: true));
    try {
      final BulkApplyResult result = type == BulkOperationType.itemImport
          ? await _repo.applyItems(tab.bytes!)
          : await _repo.applyInventory(tab.bytes!);
      _setTabState(
        type,
        state.tab(type).copyWith(result: result, busy: false),
      );
      await loadLastBatch(type);
    } catch (error) {
      _setTabState(
        type,
        state.tab(type).copyWith(busy: false, error: _clean(error)),
      );
      state = state.copyWith(
        toast: BulkToast('Apply failed: ${_clean(error)}', isError: true),
      );
    }
  }

  // ── Reset ──────────────────────────────────────────────────────────────────

  void reset(BulkOperationType type) {
    final tab = state.tab(type);
    _setTabState(
      type,
      tab.copyWith(
        clearFile: true,
        clearPreview: true,
        clearResult: true,
        clearProgress: true,
        clearError: true,
        previewPage: 1,
      ),
    );
  }

  // ── Revert ─────────────────────────────────────────────────────────────────

  Future<void> revert(BulkOperationType type) async {
    final batch = state.tab(type).lastBatch;
    if (batch == null) return;
    try {
      final result = await _repo.revert(batch.batchId);
      final noun = type == BulkOperationType.itemImport ? 'Import' : 'Update';
      final skipped = result.skippedRows.isNotEmpty
          ? ' (${result.skippedRows.length} skipped)'
          : '';
      state = state.copyWith(
        toast: BulkToast('$noun reverted successfully.$skipped'),
      );
      await loadLastBatch(type);
    } catch (error) {
      state = state.copyWith(
        toast: BulkToast('Revert failed: ${_clean(error)}', isError: true),
      );
    }
  }

  // ── Downloads ──────────────────────────────────────────────────────────────

  Future<void> _download(Future<dynamic> Function() fetch) async {
    try {
      final file = await fetch();
      final path = await _files.saveDownload(file);
      if (path == null) return; // user cancelled the save dialog
      state = state.copyWith(toast: BulkToast('Saved to $path'));
    } catch (error) {
      state = state.copyWith(
        toast: BulkToast('Download failed: ${_clean(error)}', isError: true),
      );
    }
  }

  Future<void> downloadItemTemplate() =>
      _download(_repo.downloadItemTemplate);

  Future<void> downloadItems() => _download(() {
        if (state.hasFilters) {
          return _repo.downloadFilteredItems(
            brandNames: List.of(state.selectedBrandNames),
            categories: List.of(state.selectedCategories),
          );
        }
        return _repo.downloadAllItems();
      });

  Future<void> downloadInventoryTemplate() =>
      _download(_repo.downloadInventoryTemplate);

  Future<void> downloadCurrentInventory() => _download(
        () => _repo.downloadCurrentInventory(
          trackType: state.invDownloadTrackType,
          lowStockOnly: state.invDownloadLowStockOnly,
        ),
      );

  Future<void> downloadErrorReport(BulkOperationType type) async {
    final batch = state.tab(type).lastBatch;
    if (batch == null) return;
    await _download(() => _repo.downloadErrorReport(batch.batchId));
  }
}

final bulkControllerProvider =
    NotifierProvider<BulkController, BulkState>(BulkController.new);
