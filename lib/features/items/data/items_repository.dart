import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/db_connection.dart';
import '../../../core/database/db_providers.dart';
import '../../billing/domain/billing_enums.dart';
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

class ItemsRepository {
  ItemsRepository(this._db);

  final DbConnection _db;

  Future<ItemsPageResult> listItems({
    String query = '',
    int page = 1,
    int pageSize = 12,
  }) async {
    final offset = (page - 1) * pageSize;

    String whereClause = '';
    String countWhereClause = '';
    if (query.isNotEmpty) {
      final escapedQuery = query.replaceAll("'", "''").toLowerCase();
      whereClause =
          " WHERE LOWER(name) LIKE '%$escapedQuery%' OR LOWER(sku) LIKE '%$escapedQuery%' OR LOWER(category) LIKE '%$escapedQuery%'";
      countWhereClause = whereClause;
    }

    final totalResult = await _db.query(
      'SELECT COUNT(*) as count FROM products $countWhereClause',
    );
    final total = totalResult.isNotEmpty
        ? int.parse(totalResult.first['count'].toString())
        : 0;

    final rows = await _db.query(
      'SELECT * FROM products $whereClause ORDER BY id LIMIT $pageSize OFFSET $offset',
    );

    return ItemsPageResult(
      total: total,
      rows: rows.map(Item.fromJson).toList(),
    );
  }

  Future<String> createItem(Map<String, dynamic> payload) async {
    final itemId = (payload['id'] ?? '').toString().replaceAll("'", "''");
    final name = (payload['name'] ?? '').toString().replaceAll("'", "''");
    final sku = (payload['sku'] ?? '').toString().replaceAll("'", "''");
    final category = (payload['category'] ?? 'OTHER').toString().replaceAll(
      "'",
      "''",
    );
    final brand =
        (payload['brandName'] ??
                payload['brand_name'] ??
                payload['brand'] ??
                '')
            .toString()
            .replaceAll("'", "''");
    final pricingType =
        (payload['pricingType'] ?? payload['pricing_type'] ?? 'unit')
            .toString()
            .replaceAll("'", "''");
    final retailPaise =
        int.tryParse(
          '${payload['retailPricePaise'] ?? payload['retailPrice'] ?? payload['retail_price_paise'] ?? payload['rate'] ?? 0}',
        ) ??
        0;
    final wholesalePaise = int.tryParse(
      '${payload['wholesalePricePaise'] ?? payload['wholesalePrice'] ?? payload['wholesale_price_paise'] ?? 0}',
    );
    final wholesaleMinQty = num.tryParse(
      '${payload['wholesaleMinQty'] ?? payload['wholesale_min_qty'] ?? 0}',
    );

    final insertId = itemId.isNotEmpty
        ? itemId
        : 'item_${DateTime.now().microsecondsSinceEpoch}';
    await _db.execute(
      "INSERT INTO products (id, name, sku, category, brand_name, pricing_type, retail_price_paise, wholesale_price_paise, wholesale_min_qty, rate) VALUES ('$insertId', '$name', '$sku', '$category', '$brand', '$pricingType', $retailPaise, ${wholesalePaise ?? 'NULL'}, ${wholesaleMinQty ?? 'NULL'}, $retailPaise)",
    );

    return insertId;
  }

  Future<void> updateItem(String itemId, Map<String, dynamic> payload) async {
    final name = (payload['name'] ?? '').toString().replaceAll("'", "''");
    final sku = (payload['sku'] ?? '').toString().replaceAll("'", "''");
    final category = (payload['category'] ?? 'OTHER').toString().replaceAll(
      "'",
      "''",
    );
    final brand =
        (payload['brandName'] ??
                payload['brand_name'] ??
                payload['brand'] ??
                '')
            .toString()
            .replaceAll("'", "''");
    final pricingType =
        (payload['pricingType'] ?? payload['pricing_type'] ?? 'unit')
            .toString()
            .replaceAll("'", "''");
    final retailPaise =
        int.tryParse(
          '${payload['retailPricePaise'] ?? payload['retailPrice'] ?? payload['retail_price_paise'] ?? payload['rate'] ?? 0}',
        ) ??
        0;
    final wholesalePaise = int.tryParse(
      '${payload['wholesalePricePaise'] ?? payload['wholesalePrice'] ?? payload['wholesale_price_paise'] ?? 0}',
    );
    final wholesaleMinQty = num.tryParse(
      '${payload['wholesaleMinQty'] ?? payload['wholesale_min_qty'] ?? 0}',
    );
    final escapedItemId = itemId.replaceAll("'", "''");

    await _db.execute(
      "UPDATE products SET name = '$name', sku = '$sku', category = '$category', brand_name = '$brand', pricing_type = '$pricingType', retail_price_paise = $retailPaise, wholesale_price_paise = ${wholesalePaise ?? 'NULL'}, wholesale_min_qty = ${wholesaleMinQty ?? 'NULL'}, rate = $retailPaise WHERE id = '$escapedItemId'",
    );
  }

  Future<void> deleteItem(String itemId) async {
    await _db.execute(
      "DELETE FROM products WHERE id = '${itemId.replaceAll("'", "''")}'",
    );
  }

  Future<SkuValidation> validateSku(
    String sku, {
    String excludeItemId = '',
  }) async {
    final query = excludeItemId.isEmpty
        ? "SELECT COUNT(*) as count FROM products WHERE sku = '${sku.replaceAll("'", "''")}'"
        : "SELECT COUNT(*) as count FROM products WHERE sku = '${sku.replaceAll("'", "''")}' AND id != '${excludeItemId.replaceAll("'", "''")}'";

    final result = await _db.query(query);
    final exists =
        result.isNotEmpty && int.parse(result.first['count'].toString()) > 0;

    return SkuValidation(
      valid: !exists,
      exists: exists,
      message: exists ? 'SKU already exists' : '',
    );
  }

  Future<List<String>> loadCategories() async {
    final result = await _db.query(
      "SELECT DISTINCT UPPER(category) as category FROM products WHERE category IS NOT NULL AND category != 'OTHER' ORDER BY category",
    );
    return result.map((row) => (row['category'] ?? '').toString()).toList();
  }

  Future<List<String>> loadBrands() async {
    final result = await _db.query(
      "SELECT DISTINCT UPPER(REGEXP_REPLACE(brand_name, '[^A-Z0-9 ]', '')) as brand FROM products WHERE brand_name IS NOT NULL ORDER BY brand",
    );
    return result
        .map((row) => (row['brand'] ?? '').toString())
        .where((b) => b.isNotEmpty)
        .toList();
  }

  Future<InventorySettings> loadInventorySettings() async {
    final result = await _db.query(
      'SELECT inv_control_enabled, inv_low_stock_qty, inv_low_stock_weight FROM inventory_settings LIMIT 1',
    );
    if (result.isEmpty) return InventorySettings();
    final row = result.first;
    final val = row['inv_control_enabled'];
    final isEnabled = val == 1 ||
        val == true ||
        val?.toString() == '1' ||
        val?.toString().toLowerCase() == 'true';
    return InventorySettings(
      invControlEnabled: isEnabled,
      invLowStockQty: num.tryParse(
            row['inv_low_stock_qty']?.toString() ?? '10',
          ) ??
          10,
      invLowStockWeight: num.tryParse(
            row['inv_low_stock_weight']?.toString() ?? '5.0',
          ) ??
          5.0,
    );
  }

  Future<AdjustResult> adjustInventory(
    String itemId,
    InventoryAdjustment adjustment,
  ) async {
    final escapedItemId = itemId.replaceAll("'", "''");
    final escapedNotes = adjustment.notes.replaceAll("'", "''");
    await _db.begin();
    try {
      final rows = await _db.query(
        "SELECT id, pricing_type, inv_current_qty, inv_current_weight FROM products WHERE id = '$escapedItemId' LIMIT 1",
      );
      if (rows.isEmpty) {
        throw StateError('Item $itemId was not found.');
      }

      final row = rows.first;
      num asNum(Object? v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
      final isWeight = adjustment.trackType == PricingType.weight;
      final prevQty = asNum(row['inv_current_qty']);
      final prevWeight = asNum(row['inv_current_weight']);
      final delta = adjustment.delta;
      final newQty = isWeight ? prevQty : _clampZero(prevQty + delta);
      final newWeight = isWeight ? _clampZero(prevWeight + delta) : prevWeight;
      final qtyDelta = isWeight ? 0 : delta;
      final weightDelta = isWeight ? delta : 0;

      await _db.execute(
        "UPDATE products SET inv_current_qty = $newQty, inv_current_weight = $newWeight WHERE id = '$escapedItemId'",
      );
      await _db.execute(
        "INSERT INTO inventory_audit (product_id, action_type, qty_delta, weight_delta, prev_qty, new_qty, prev_weight, new_weight, bill_id, reference_id, notes) VALUES ('$escapedItemId', 'adjust', $qtyDelta, $weightDelta, $prevQty, $newQty, $prevWeight, $newWeight, NULL, NULL, '$escapedNotes')",
      );
      await _db.commit();
      return AdjustResult(
        ok: true,
        prevQty: prevQty,
        prevWeight: prevWeight,
        newQty: newQty,
        newWeight: newWeight,
      );
    } catch (e) {
      await _db.rollback();
      rethrow;
    }
  }

  Future<({int total, List<Map<String, dynamic>> rows})> listInventoryAudit({
    String itemId = '',
    String actionType = '',
    String query = '',
    int page = 1,
    int pageSize = 10,
  }) async {
    final offset = (page - 1) * pageSize;
    String whereClause = 'WHERE 1=1';

    if (itemId.isNotEmpty) {
      final escapedItemId = itemId.replaceAll("'", "''");
      whereClause += " AND product_id = '$escapedItemId'";
    }
    if (actionType.isNotEmpty) {
      final escapedActionType = actionType.replaceAll("'", "''");
      whereClause += " AND action_type = '$escapedActionType'";
    }
    if (query.isNotEmpty) {
      final escapedQuery = query.replaceAll("'", "''").toLowerCase();
      whereClause +=
          " AND (LOWER(notes) LIKE '%$escapedQuery%' OR LOWER(action_type) LIKE '%$escapedQuery%')";
    }

    final totalResult = await _db.query(
      'SELECT COUNT(*) as count FROM inventory_audit $whereClause',
    );
    final total = totalResult.isNotEmpty
        ? int.parse(totalResult.first['count'].toString())
        : 0;

    final rows = await _db.query(
      'SELECT ia.*, p.sku, p.name, p.name_ta, p.category, p.pricing_type '
      'FROM inventory_audit ia '
      'LEFT JOIN products p ON p.id = ia.product_id '
      '$whereClause ORDER BY ia.created_at DESC LIMIT $pageSize OFFSET $offset',
    );

    return (total: total, rows: rows);
  }

  num _clampZero(num value) => value < 0 ? 0 : value;
}

final itemsRepositoryProvider = Provider<ItemsRepository>(
  (ref) => ItemsRepository(ref.watch(dbConnectionProvider)),
);
