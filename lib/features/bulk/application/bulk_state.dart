import '../domain/bulk_batch.dart';
import '../domain/bulk_enums.dart';
import '../domain/bulk_preview.dart';
import '../domain/bulk_progress.dart';
import '../domain/bulk_result.dart';

/// Rows shown per preview page (parity with ROWS_PER_PAGE).
const int kBulkRowsPerPage = 25;

/// A transient banner/toast message.
class BulkToast {
  const BulkToast(this.text, {this.isError = false});

  final String text;
  final bool isError;
}

/// Per-tab state for one bulk operation flow.
class BulkTabState {
  const BulkTabState({
    this.fileName,
    this.bytes,
    this.preview,
    this.previewPage = 1,
    this.result,
    this.lastBatch,
    this.progress,
    this.busy = false,
    this.error,
  });

  final String? fileName;
  final List<int>? bytes;
  final BulkPreview? preview;
  final int previewPage;
  final BulkApplyResult? result;
  final BulkBatch? lastBatch;
  final BulkProgress? progress;
  final bool busy;
  final String? error;

  bool get hasFile => bytes != null && bytes!.isNotEmpty;

  int get totalPages {
    final count = preview?.rows.length ?? 0;
    if (count == 0) return 1;
    return (count / kBulkRowsPerPage).ceil();
  }

  List<BulkPreviewRow> get pageRows {
    final rows = preview?.rows ?? const [];
    final start = (previewPage - 1) * kBulkRowsPerPage;
    if (start >= rows.length) return const [];
    final end = (start + kBulkRowsPerPage).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  /// "Showing rows a–b of n" (parity with pageInfo).
  String get pageInfo {
    final rows = preview?.rows ?? const [];
    if (rows.isEmpty) return 'Showing rows 0–0 of 0';
    final start = (previewPage - 1) * kBulkRowsPerPage;
    final end = (start + kBulkRowsPerPage).clamp(0, rows.length);
    return 'Showing rows ${start + 1}–$end of ${rows.length}';
  }

  bool get canPrev => previewPage > 1;
  bool get canNext => previewPage < totalPages;

  /// Apply is allowed only when a preview exists with zero errors and we are
  /// not busy (parity with updateApplyButtonState).
  bool get applyEnabled {
    final p = preview;
    if (p == null || busy) return false;
    return !p.summary.hasErrors;
  }

  /// Apply button label (parity: "Apply N rows" when clean).
  String get applyLabel {
    final ready = preview?.summary.readyCount ?? 0;
    return 'Apply $ready row${ready == 1 ? '' : 's'}';
  }

  /// Message shown next to the Apply button (parity with applyMessage).
  String get applyHint {
    final summary = preview?.summary;
    if (summary == null) return '';
    if (summary.hasErrors) return 'Fix errors to enable Apply';
    if (summary.hasWarnings) {
      final w = summary.warningCount;
      return '$w warning${w == 1 ? '' : 's'} found. '
          'Apply continues without confirmation.';
    }
    return '';
  }

  BulkTabState copyWith({
    String? fileName,
    List<int>? bytes,
    BulkPreview? preview,
    int? previewPage,
    BulkApplyResult? result,
    BulkBatch? lastBatch,
    BulkProgress? progress,
    bool? busy,
    String? error,
    bool clearFile = false,
    bool clearPreview = false,
    bool clearResult = false,
    bool clearLastBatch = false,
    bool clearProgress = false,
    bool clearError = false,
  }) {
    return BulkTabState(
      fileName: clearFile ? null : (fileName ?? this.fileName),
      bytes: clearFile ? null : (bytes ?? this.bytes),
      preview: clearPreview ? null : (preview ?? this.preview),
      previewPage: previewPage ?? this.previewPage,
      result: clearResult ? null : (result ?? this.result),
      lastBatch: clearLastBatch ? null : (lastBatch ?? this.lastBatch),
      progress: clearProgress ? null : (progress ?? this.progress),
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Top-level bulk module state (both tabs + shared filters).
class BulkState {
  const BulkState({
    this.currentTab = BulkOperationType.itemImport,
    this.itemImport = const BulkTabState(),
    this.inventoryUpdate = const BulkTabState(),
    this.invControlEnabled = false,
    this.categoryOptions = const [],
    this.brandOptions = const [],
    this.selectedCategories = const [],
    this.selectedBrandNames = const [],
    this.invDownloadTrackType = '',
    this.invDownloadLowStockOnly = false,
    this.loaded = false,
    this.toast,
  });

  final BulkOperationType currentTab;
  final BulkTabState itemImport;
  final BulkTabState inventoryUpdate;
  final bool invControlEnabled;
  final List<String> categoryOptions;
  final List<String> brandOptions;
  final List<String> selectedCategories;
  final List<String> selectedBrandNames;

  /// '' | 'quantity' | 'weight'
  final String invDownloadTrackType;
  final bool invDownloadLowStockOnly;
  final bool loaded;
  final BulkToast? toast;

  bool get hasFilters =>
      selectedCategories.isNotEmpty || selectedBrandNames.isNotEmpty;

  BulkTabState tab(BulkOperationType type) =>
      type == BulkOperationType.itemImport ? itemImport : inventoryUpdate;

  BulkState copyWith({
    BulkOperationType? currentTab,
    BulkTabState? itemImport,
    BulkTabState? inventoryUpdate,
    bool? invControlEnabled,
    List<String>? categoryOptions,
    List<String>? brandOptions,
    List<String>? selectedCategories,
    List<String>? selectedBrandNames,
    String? invDownloadTrackType,
    bool? invDownloadLowStockOnly,
    bool? loaded,
    BulkToast? toast,
    bool clearToast = false,
  }) {
    return BulkState(
      currentTab: currentTab ?? this.currentTab,
      itemImport: itemImport ?? this.itemImport,
      inventoryUpdate: inventoryUpdate ?? this.inventoryUpdate,
      invControlEnabled: invControlEnabled ?? this.invControlEnabled,
      categoryOptions: categoryOptions ?? this.categoryOptions,
      brandOptions: brandOptions ?? this.brandOptions,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedBrandNames: selectedBrandNames ?? this.selectedBrandNames,
      invDownloadTrackType: invDownloadTrackType ?? this.invDownloadTrackType,
      invDownloadLowStockOnly:
          invDownloadLowStockOnly ?? this.invDownloadLowStockOnly,
      loaded: loaded ?? this.loaded,
      toast: clearToast ? null : (toast ?? this.toast),
    );
  }

  /// Returns a copy with the given tab's sub-state replaced.
  BulkState withTab(BulkOperationType type, BulkTabState next) {
    return type == BulkOperationType.itemImport
        ? copyWith(itemImport: next)
        : copyWith(inventoryUpdate: next);
  }
}
