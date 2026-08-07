import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_providers.dart';
import '../../inventory/domain/inventory_adjust.dart';
import '../../inventory/domain/inventory_settings.dart';
import '../domain/item.dart';
import '../domain/item_form.dart';

/// A page of items returned by [ItemsRepository.listItems].
class ItemsPageResult {
  const ItemsPageResult({required this.total, required this.rows});
  final int total;
  final List<Item> rows;
}

/// API-bridge data source for the Items and Inventory modules. Centralizes item
/// CRUD, SKU validation, category/brand options, and inventory operations.
class ItemsRepository {
  ItemsRepository(this._api);

  final ApiClient _api;

  Future<ItemsPageResult> listItems({
    String query = '',
    int page = 1,
    int pageSize = 12,
  }) async {
    final response = await _api.postJson(
      ApiEndpoints.itemsList,
      body: {'query': query, 'page': page, 'pageSize': pageSize},
    );
    final rows = _asList(response['rows'] ?? response)
        .whereType<Map<String, dynamic>>()
        .map(Item.fromJson)
        .toList();
    final total = response.containsKey('total')
        ? _asInt(response['total'])
        : rows.length;
    return ItemsPageResult(total: total, rows: rows);
  }

  /// Creates an item and returns the generated item id.
  Future<String> createItem(Map<String, dynamic> payload) async {
    final response = await _api.postJson(ApiEndpoints.itemsCreate, body: payload);
    return (response['itemId'] ?? response['id'] ?? '').toString();
  }

  Future<void> updateItem(String itemId, Map<String, dynamic> payload) async {
    await _api.putJson(ApiEndpoints.itemsUpdate(itemId), body: payload);
  }

  Future<void> deleteItem(String itemId) async {
    await _api.deleteJson(ApiEndpoints.itemsDelete(itemId));
  }

  Future<SkuValidation> validateSku(String sku, {String excludeItemId = ''}) async {
    final response = await _api.postJson(
      ApiEndpoints.itemsValidateSku,
      body: {'sku': sku, 'excludeItemId': excludeItemId},
    );
    return SkuValidation.fromJson(response);
  }

  /// Normalized, de-duplicated item categories from system settings (excludes
  /// the always-present "OTHER" bucket, which the form injects).
  Future<List<String>> loadCategories() async {
    final settings = await _api.getJson(ApiEndpoints.loadSettings);
    final raw = _asList(settings['itemCategories']);
    final seen = <String>{};
    final result = <String>[];
    for (final entry in raw) {
      final normalized = _normalizeCategory('$entry');
      if (normalized.isNotEmpty &&
          normalized != 'OTHER' &&
          seen.add(normalized)) {
        result.add(normalized);
      }
    }
    return result;
  }

  Future<List<String>> loadBrands() async {
    final settings = await _api.getJson(ApiEndpoints.loadSettings);
    final raw = _asList(settings['itemBrands']);
    final seen = <String>{};
    final result = <String>[];
    for (final entry in raw) {
      final normalized = _normalizeBrand('$entry');
      if (normalized.isNotEmpty && seen.add(normalized)) {
        result.add(normalized);
      }
    }
    return result;
  }

  Future<InventorySettings> loadInventorySettings() async {
    final response = await _api.getJson(ApiEndpoints.loadInventorySettings);
    return InventorySettings.fromJson(response);
  }

  Future<AdjustResult> adjustInventory(
    String itemId,
    InventoryAdjustment adjustment,
  ) async {
    final response = await _api.postJson(
      ApiEndpoints.inventoryAdjust(itemId),
      body: adjustment.toPayload(),
    );
    return AdjustResult.fromJson(response);
  }

  /// Raw inventory audit rows (kept generic; presentation maps as needed).
  Future<({int total, List<Map<String, dynamic>> rows})> listInventoryAudit({
    String itemId = '',
    String actionType = '',
    String query = '',
    int page = 1,
    int pageSize = 10,
  }) async {
    final response = await _api.getJson(
      ApiEndpoints.inventoryListAudit,
      query: {
        'itemId': itemId,
        'actionType': actionType,
        'query': query,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return (
      total: _asInt(response['total']),
      rows: _asList(response['rows'])
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }

  // ── normalization helpers (parity with items-page-controller.js) ──────────

  String _normalizeCategory(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  String _normalizeBrand(String value) => value
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  List<dynamic> _asList(Object? value) {
    if (value is List) return value;
    if (value is Map<String, dynamic>) {
      final data = value['data'] ?? value['rows'];
      if (data is List) return data;
    }
    return const [];
  }

  int _asInt(Object? value) =>
      value is num ? value.round() : int.tryParse('$value') ?? 0;
}

final itemsRepositoryProvider = Provider<ItemsRepository>(
  (ref) => ItemsRepository(ref.watch(apiClientProvider)),
);
