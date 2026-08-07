import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_providers.dart';
import '../domain/bulk_batch.dart';
import '../domain/bulk_enums.dart';
import '../domain/bulk_file.dart';
import '../domain/bulk_preview.dart';
import '../domain/bulk_result.dart';

/// API-bridge data source for the Bulk Operations module. Wires the frozen
/// `/bulk/*` endpoints; request/response shapes mirror the Electron IPC layer.
class BulkRepository {
  BulkRepository(this._api);

  final ApiClient _api;

  // ── Downloads (templates + exports) ───────────────────────────────────────

  Future<BulkFile> downloadItemTemplate() async =>
      BulkFile.fromJson(await _api.getJson(ApiEndpoints.bulkItemTemplate));

  Future<BulkFile> downloadAllItems() async =>
      BulkFile.fromJson(await _api.getJson(ApiEndpoints.bulkDownloadAllItems));

  Future<BulkFile> downloadFilteredItems({
    required List<String> brandNames,
    required List<String> categories,
  }) async {
    final json = await _api.postJson(
      ApiEndpoints.bulkDownloadFilteredItems,
      body: {'brandNames': brandNames, 'categories': categories},
    );
    return BulkFile.fromJson(json);
  }

  Future<BulkFile> downloadInventoryTemplate() async =>
      BulkFile.fromJson(await _api.getJson(ApiEndpoints.bulkInventoryTemplate));

  Future<BulkFile> downloadCurrentInventory({
    required String trackType,
    required bool lowStockOnly,
  }) async {
    final json = await _api.postJson(
      ApiEndpoints.bulkCurrentInventory,
      body: {'trackType': trackType, 'lowStockOnly': lowStockOnly},
    );
    return BulkFile.fromJson(json);
  }

  // ── Preview ───────────────────────────────────────────────────────────────

  Future<BulkPreview> previewItems(List<int> bytes) async {
    final json = await _api.postJson(
      ApiEndpoints.bulkPreviewItems,
      body: {'bytes': bytes},
    );
    return BulkPreview.fromJson(json);
  }

  Future<BulkPreview> previewInventory(List<int> bytes) async {
    final json = await _api.postJson(
      ApiEndpoints.bulkPreviewInventory,
      body: {'bytes': bytes},
    );
    return BulkPreview.fromJson(json);
  }

  // ── Apply ─────────────────────────────────────────────────────────────────

  Future<BulkApplyResult> applyItems(List<int> bytes) async {
    final json = await _api.postJson(
      ApiEndpoints.bulkApplyItems,
      body: {'bytes': bytes},
    );
    return BulkApplyResult.fromJson(BulkOperationType.itemImport, json);
  }

  Future<BulkApplyResult> applyInventory(List<int> bytes) async {
    final json = await _api.postJson(
      ApiEndpoints.bulkApplyInventory,
      body: {'bytes': bytes},
    );
    return BulkApplyResult.fromJson(BulkOperationType.inventoryUpdate, json);
  }

  // ── Batch history / revert / error report ─────────────────────────────────

  Future<BulkBatch?> getLastBatch(BulkOperationType type) async {
    final json = await _api.getJson(ApiEndpoints.bulkLastBatch(type.wire));
    return BulkBatch.tryFromJson(json);
  }

  Future<BulkRevertResult> revert(String batchId) async {
    final json = await _api.postJson(ApiEndpoints.bulkRevert(batchId));
    return BulkRevertResult.fromJson(json);
  }

  Future<BulkFile> downloadErrorReport(String batchId) async =>
      BulkFile.fromJson(
          await _api.getJson(ApiEndpoints.bulkErrorReport(batchId)));
}

final bulkRepositoryProvider = Provider<BulkRepository>(
  (ref) => BulkRepository(ref.watch(apiClientProvider)),
);
