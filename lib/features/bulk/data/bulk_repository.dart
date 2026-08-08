import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/db_connection.dart';
import '../../../core/database/db_providers.dart';
import '../../billing/domain/billing_enums.dart';
import '../../billing/domain/money.dart';
import '../../items/domain/item_form.dart';
import '../domain/bulk_batch.dart';
import '../domain/bulk_enums.dart';
import '../domain/bulk_file.dart';
import '../domain/bulk_preview.dart';
import '../domain/bulk_result.dart';

class BulkRepository {
  BulkRepository(this._db);

  final DbConnection _db;

  // ── Downloads (templates + exports) ───────────────────────────────────────

  Future<BulkFile> downloadItemTemplate() async {
    const rows = [
      [
        'slno',
        'sku',
        'item_name',
        'brand_name',
        'item_tamil_name',
        'category',
        'weight_or_qty',
        'wholesale_min_qty',
        'wholesale_price',
        'retail_price',
      ],
      [
        '1',
        'BALA-CHIP-POTA-500G',
        'Potato chips(500g)',
        'BALAJI CHIPS',
        'உருளைக்கிழங்கு சிப்ஸ் (500கி)',
        'CHIPS',
        'QTY',
        '5',
        '105.00',
        '120.00',
      ],
    ];
    return BulkFile(
      fileName: 'items_template.csv',
      base64: base64Encode(utf8.encode(_toCsv(rows))),
      contentType: 'text/csv',
    );
  }

  Future<BulkFile> downloadAllItems() async {
    final rows = await _db.query(
      'SELECT id, sku, name, name_ta, category, brand_name, pricing_type, '
      'wholesale_min_qty, wholesale_price_paise, retail_price_paise '
      'FROM products ORDER BY id',
    );
    final csvRows = <List<String>>[
      [
        'slno',
        'sku',
        'item_name',
        'brand_name',
        'item_tamil_name',
        'category',
        'weight_or_qty',
        'wholesale_min_qty',
        'wholesale_price',
        'retail_price',
      ],
      for (var i = 0; i < rows.length; i++)
        _itemExportRow(rows[i], slno: i + 1),
    ];
    return BulkFile(
      fileName: 'items_export.csv',
      base64: base64Encode(utf8.encode(_toCsv(csvRows))),
      contentType: 'text/csv',
    );
  }

  Future<BulkFile> downloadFilteredItems({
    required List<String> brandNames,
    required List<String> categories,
  }) async {
    final filters = <String>['1=1'];
    if (brandNames.isNotEmpty) {
      final brands = brandNames
          .map((b) => "'${b.replaceAll("'", "''")}'")
          .join(',');
      filters.add("brand_name IN ($brands)");
    }
    if (categories.isNotEmpty) {
      final cats = categories.map((c) => "'${c.replaceAll("'", "''")}'").join(',');
      filters.add("category IN ($cats)");
    }
    final rows = await _db.query(
      'SELECT id, sku, name, name_ta, category, brand_name, pricing_type, '
      'wholesale_min_qty, wholesale_price_paise, retail_price_paise '
      'FROM products WHERE ${filters.join(' AND ')} ORDER BY id',
    );
    final csvRows = <List<String>>[
      [
        'slno',
        'sku',
        'item_name',
        'brand_name',
        'item_tamil_name',
        'category',
        'weight_or_qty',
        'wholesale_min_qty',
        'wholesale_price',
        'retail_price',
      ],
      for (var i = 0; i < rows.length; i++)
        _itemExportRow(rows[i], slno: i + 1),
    ];
    return BulkFile(
      fileName: 'items_filtered_export.csv',
      base64: base64Encode(utf8.encode(_toCsv(csvRows))),
      contentType: 'text/csv',
    );
  }

  Future<BulkFile> downloadInventoryTemplate() async {
    const rows = [
      ['slno', 'sku', 'action_type', 'quantity', 'notes'],
      ['1', 'BALA-CHIP-POTA-500G', 'SET', '5', 'Opening stock'],
    ];
    return BulkFile(
      fileName: 'inventory_template.csv',
      base64: base64Encode(utf8.encode(_toCsv(rows))),
      contentType: 'text/csv',
    );
  }

  Future<BulkFile> downloadCurrentInventory({
    required String trackType,
    required bool lowStockOnly,
  }) async {
    final rows = await _db.query(
      'SELECT id, sku, name, name_ta, category, brand_name, pricing_type, '
      'inv_current_qty, inv_current_weight, inv_min_qty, inv_min_weight '
      'FROM products ORDER BY id',
    );
    final filtered = <Map<String, dynamic>>[];
    for (final row in rows) {
      final pricingType = PricingType.fromWire(row['pricing_type']);
      if (trackType == 'quantity' && pricingType != PricingType.unit) continue;
      if (trackType == 'weight' && pricingType != PricingType.weight) continue;
      if (lowStockOnly && !_isLowStock(row)) continue;
      filtered.add(row);
    }

    final csvRows = <List<String>>[
      ['slno', 'sku', 'action_type', 'quantity', 'notes'],
      for (var i = 0; i < filtered.length; i++)
        _inventoryExportRow(filtered[i], slno: i + 1),
    ];
    return BulkFile(
      fileName: 'inventory_export.csv',
      base64: base64Encode(utf8.encode(_toCsv(csvRows))),
      contentType: 'text/csv',
    );
  }

  // ── Preview ───────────────────────────────────────────────────────────────

  Future<BulkPreview> previewItems(List<int> bytes) async {
    final parsed = _parseItemRows(bytes);
    final rows = <BulkPreviewRow>[];
    for (final row in parsed.rows) {
      final existing = row.sku.isEmpty ? null : await _findItemBySku(row.sku);
      var status = row.status;
      final messages = List<String>.of(row.messages);
      final operation = existing == null ? 'CREATE' : 'UPDATE';
      if (existing != null && status != BulkRowStatus.error) {
        status = BulkRowStatus.warning;
        if (!messages.contains('Existing SKU will be updated.')) {
          messages.add('Existing SKU will be updated.');
        }
      }
      rows.add(
        BulkPreviewRow(
          rowNumber: row.rowNumber,
          status: status,
          messages: messages,
          slno: row.slno,
          sku: row.sku,
          name: row.itemName,
          operation: operation,
        ),
      );
    }
    return BulkPreview(
      rows: rows,
      summary: BulkPreviewSummary(
        readyCount: rows.where((r) => r.status != BulkRowStatus.error).length,
        warningCount: rows.where((r) => r.status == BulkRowStatus.warning).length,
        errorCount: rows.where((r) => r.status == BulkRowStatus.error).length,
        skippedCount: rows.where((r) => r.status == BulkRowStatus.skipped).length,
      ),
      autoDetectMode: true,
    );
  }

  Future<BulkPreview> previewInventory(List<int> bytes) async {
    final parsed = _parseInventoryRows(bytes);
    final rows = <BulkPreviewRow>[];
    for (final row in parsed.rows) {
      final existing = row.sku.isEmpty ? null : await _findItemBySku(row.sku);
      var status = row.status;
      final messages = List<String>.of(row.messages);
      final trackType = existing == null
          ? row.trackType
          : PricingType.fromWire(existing['pricing_type']);
      if (existing == null && status != BulkRowStatus.error) {
        status = BulkRowStatus.error;
        messages.add('SKU not found in catalog.');
      }
      rows.add(
        BulkPreviewRow(
          rowNumber: row.rowNumber,
          status: status,
          messages: messages,
          sku: row.sku,
          action: row.actionType,
          quantity: trackType == PricingType.weight ? null : row.targetQuantity,
          weightKg: trackType == PricingType.weight ? row.targetQuantity : null,
        ),
      );
    }
    return BulkPreview(
      rows: rows,
      summary: BulkPreviewSummary(
        readyCount: rows.where((r) => r.status != BulkRowStatus.error).length,
        warningCount: rows.where((r) => r.status == BulkRowStatus.warning).length,
        errorCount: rows.where((r) => r.status == BulkRowStatus.error).length,
        skippedCount: rows.where((r) => r.status == BulkRowStatus.skipped).length,
      ),
      autoDetectMode: false,
    );
  }

  // ── Apply ─────────────────────────────────────────────────────────────────

  Future<BulkApplyResult> applyItems(List<int> bytes) async {
    final parsed = _parseItemRows(bytes);
    final changes = <Map<String, dynamic>>[];
    var inserted = 0;
    var updated = 0;
    var failed = 0;
    var skipped = 0;

    await _db.begin();
    try {
      for (final row in parsed.rows) {
        if (row.status == BulkRowStatus.skipped) {
          skipped += 1;
          changes.add(row.toApplyChange(outcome: 'skipped'));
          continue;
        }
        if (row.status == BulkRowStatus.error) {
          failed += 1;
          changes.add(row.toApplyChange(
            outcome: 'failed',
            message: row.messages.join('; '),
          ));
          continue;
        }

        final existing = await _findItemBySku(row.sku);
        if (existing == null) {
          final itemId = await _insertItem(row);
          inserted += 1;
          changes.add(row.toApplyChange(
            outcome: 'applied',
            operation: 'CREATE',
            itemId: itemId,
          ));
        } else {
          await _updateItem(existing['id'].toString(), row);
          updated += 1;
          changes.add(row.toApplyChange(
            outcome: 'applied',
            operation: 'UPDATE',
            itemId: existing['id'].toString(),
            before: existing,
          ));
        }
      }

      await _insertBatch(
        type: BulkOperationType.itemImport,
        rowCount: parsed.rows.length,
        processedCount: inserted + updated + failed + skipped,
        insertedCount: inserted,
        updatedCount: updated,
        successCount: inserted + updated,
        failedCount: failed,
        skippedCount: skipped,
        itemsJson: changes,
      );
      await _db.commit();
      return BulkApplyResult(
        operationType: BulkOperationType.itemImport,
        inserted: inserted,
        updated: updated,
        failed: failed,
        skipped: skipped,
        rows: [
          for (final change in changes)
            BulkResultRow(
              rowNumber: (change['rowNumber'] as num).toInt(),
              outcome: BulkRowOutcome.fromWire(change['outcome'] as String?),
              slno: _str(change['slno']),
              sku: _str(change['sku']),
              name: _str(change['itemName']),
              operation: _str(change['operation']),
              message: _str(change['message']),
            ),
        ],
      );
    } catch (e) {
      await _db.rollback();
      rethrow;
    }
  }

  Future<BulkApplyResult> applyInventory(List<int> bytes) async {
    final parsed = _parseInventoryRows(bytes);
    final changes = <Map<String, dynamic>>[];
    var inserted = 0;
    var updated = 0;
    var failed = 0;
    var skipped = 0;

    await _db.begin();
    try {
      for (final row in parsed.rows) {
        if (row.status == BulkRowStatus.skipped) {
          skipped += 1;
          changes.add(row.toApplyChange(outcome: 'skipped'));
          continue;
        }
        if (row.status == BulkRowStatus.error) {
          failed += 1;
          changes.add(row.toApplyChange(
            outcome: 'failed',
            message: row.messages.join('; '),
          ));
          continue;
        }

        final existing = await _findItemBySku(row.sku);
        if (existing == null) {
          failed += 1;
          changes.add(row.toApplyChange(
            outcome: 'failed',
            message: 'SKU not found in catalog.',
          ));
          continue;
        }

        final result = await _applyInventoryChange(existing, row);
        updated += 1;
        changes.add(row.toApplyChange(
          outcome: 'applied',
          itemId: existing['id'].toString(),
          before: result['before'],
          after: result['after'],
          trackType: result['trackType'],
        ));
      }

      await _insertBatch(
        type: BulkOperationType.inventoryUpdate,
        rowCount: parsed.rows.length,
        processedCount: inserted + updated + failed + skipped,
        insertedCount: inserted,
        updatedCount: updated,
        successCount: updated,
        failedCount: failed,
        skippedCount: skipped,
        itemsJson: changes,
      );
      await _db.commit();
      return BulkApplyResult(
        operationType: BulkOperationType.inventoryUpdate,
        inserted: inserted,
        updated: updated,
        failed: failed,
        skipped: skipped,
        rows: [
          for (final change in changes)
            BulkResultRow(
              rowNumber: (change['rowNumber'] as num).toInt(),
              outcome: BulkRowOutcome.fromWire(change['outcome'] as String?),
              sku: _str(change['sku']),
              action: _str(change['actionType']),
              trackType: _str(change['trackType']),
              prevQty: _nestedNum(change['before'], 'qty'),
              prevWeight: _nestedNum(change['before'], 'weight'),
              newQty: _nestedNum(change['after'], 'qty'),
              newWeight: _nestedNum(change['after'], 'weight'),
              message: _str(change['message']),
            ),
        ],
      );
    } catch (e) {
      await _db.rollback();
      rethrow;
    }
  }

  // ── Batch history / revert / error report ─────────────────────────────────

  Future<BulkBatch?> getLastBatch(BulkOperationType type) async {
    final rows = await _db.query(
      "SELECT * FROM bulk_batches WHERE operation_type = '${type.wire}' ORDER BY created_at DESC LIMIT 1",
    );
    return rows.isEmpty ? null : BulkBatch.tryFromJson(rows.first);
  }

  Future<BulkRevertResult> revert(String batchId) async {
    final escapedBatchId = batchId.replaceAll("'", "''");
    final rows = await _db.query(
      "SELECT * FROM bulk_batches WHERE batch_id = '$escapedBatchId' LIMIT 1",
    );
    if (rows.isEmpty) {
      return const BulkRevertResult(revertedCount: 0, skippedRows: []);
    }

    final batch = rows.first;
    final operationType = BulkOperationType.fromWire(batch['operation_type'] as String?);
    final items = _asList(batch['items_json']);
    final skippedRows = <BulkRevertSkip>[];
    var revertedCount = 0;

    await _db.begin();
    try {
      for (var i = items.length - 1; i >= 0; i--) {
        final change = items[i];
        final outcome = change['outcome']?.toString();
        if (outcome != 'applied') {
          continue;
        }

        if (operationType == BulkOperationType.itemImport) {
          final itemId = _str(change['itemId']);
          final operation = _str(change['operation']);
          final before = _asMap(change['before']);
          if (itemId.isEmpty) {
            skippedRows.add(BulkRevertSkip(
              sku: _str(change['sku']),
              reason: 'Missing item id.',
            ));
            continue;
          }
          if (operation == 'CREATE') {
            await _db.execute(
              "DELETE FROM products WHERE id = '${itemId.replaceAll("'", "''")}'",
            );
          } else if (operation == 'UPDATE') {
            await _restoreItem(itemId, before);
          } else {
            skippedRows.add(BulkRevertSkip(
              sku: _str(change['sku']),
              reason: 'Unknown item operation.',
            ));
            continue;
          }
          revertedCount += 1;
        } else {
          final itemId = _str(change['itemId']);
          final before = _asMap(change['before']);
          if (itemId.isEmpty) {
            skippedRows.add(BulkRevertSkip(
              sku: _str(change['sku']),
              reason: 'Missing item id.',
            ));
            continue;
          }
          await _restoreInventory(itemId, before);
          revertedCount += 1;
        }
      }

      await _db.execute(
        "UPDATE bulk_batches SET reverted = 1, reverted_at = CURRENT_TIMESTAMP WHERE batch_id = '$escapedBatchId'",
      );
      await _db.commit();
      return BulkRevertResult(revertedCount: revertedCount, skippedRows: skippedRows);
    } catch (e) {
      await _db.rollback();
      rethrow;
    }
  }

  Future<BulkFile> downloadErrorReport(String batchId) async {
    final escapedBatchId = batchId.replaceAll("'", "''");
    final rows = await _db.query(
      "SELECT items_json FROM bulk_batches WHERE batch_id = '$escapedBatchId' LIMIT 1",
    );
    final changes = rows.isEmpty ? const [] : _asList(rows.first['items_json']);
    final csvRows = <List<String>>[
      ['row_number', 'sku', 'message'],
      for (final change in changes)
        if (change is Map<String, dynamic> && change['outcome'] == 'failed')
          [
            _str(change['rowNumber']),
            _str(change['sku']),
            _str(change['message']),
          ],
    ];
    return BulkFile(
      fileName: 'error_report.csv',
      base64: base64Encode(utf8.encode(_toCsv(csvRows))),
      contentType: 'text/csv',
    );
  }

  // ── Internal parsing / persistence helpers ────────────────────────────────

  Future<Map<String, dynamic>?> _findItemBySku(String sku) async {
    final rows = await _db.query(
      "SELECT * FROM products WHERE sku = '${sku.replaceAll("'", "''")}' LIMIT 1",
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<String> _insertItem(_ParsedItemRow row) async {
    final itemId = 'item_${DateTime.now().microsecondsSinceEpoch}_${row.rowNumber}';
    final sku = row.sku.replaceAll("'", "''");
    final name = row.itemName.replaceAll("'", "''");
    final tamil = row.tamilName.replaceAll("'", "''");
    final category = row.category.replaceAll("'", "''");
    final brand = row.brandName.replaceAll("'", "''");
    final pricingType = row.pricingType.wire.toLowerCase();
    final wholesalePrice = row.wholesalePricePaise == null ? 'NULL' : row.wholesalePricePaise.toString();
    final wholesaleMinQty = row.wholesaleMinQty == null ? 'NULL' : row.wholesaleMinQty.toString();
    await _db.execute(
      "INSERT INTO products (id, name, name_ta, category, sku, pricing_type, brand_name, retail_price_paise, wholesale_price_paise, wholesale_min_qty, rate) "
      "VALUES ('$itemId', '$name', '$tamil', '$category', '$sku', '$pricingType', '$brand', ${row.retailPricePaise}, $wholesalePrice, $wholesaleMinQty, ${row.retailPricePaise})",
    );
    return itemId;
  }

  Future<void> _updateItem(String itemId, _ParsedItemRow row) async {
    final escapedItemId = itemId.replaceAll("'", "''");
    final sku = row.sku.replaceAll("'", "''");
    final name = row.itemName.replaceAll("'", "''");
    final tamil = row.tamilName.replaceAll("'", "''");
    final category = row.category.replaceAll("'", "''");
    final brand = row.brandName.replaceAll("'", "''");
    final pricingType = row.pricingType.wire.toLowerCase();
    final wholesalePrice = row.wholesalePricePaise == null ? 'NULL' : row.wholesalePricePaise.toString();
    final wholesaleMinQty = row.wholesaleMinQty == null ? 'NULL' : row.wholesaleMinQty.toString();
    await _db.execute(
      "UPDATE products SET name = '$name', name_ta = '$tamil', category = '$category', sku = '$sku', pricing_type = '$pricingType', brand_name = '$brand', retail_price_paise = ${row.retailPricePaise}, wholesale_price_paise = $wholesalePrice, wholesale_min_qty = $wholesaleMinQty, rate = ${row.retailPricePaise} WHERE id = '$escapedItemId'",
    );
  }

  Future<void> _restoreItem(String itemId, Map<String, dynamic> before) async {
    final escapedItemId = itemId.replaceAll("'", "''");
    if (before.isEmpty) {
      return;
    }
    final name = _str(before['name']).replaceAll("'", "''");
    final tamil = _str(before['name_ta']).replaceAll("'", "''");
    final category = _str(before['category']).replaceAll("'", "''");
    final sku = _str(before['sku']).replaceAll("'", "''");
    final pricingType = _str(before['pricing_type']).replaceAll("'", "''");
    final brand = _str(before['brand_name']).replaceAll("'", "''");
    final retail = _num(before['retail_price_paise']) ?? 0;
    final wholesale = _sqlNumberOrNull(before['wholesale_price_paise']);
    final wholesaleMinQty = _sqlNumberOrNull(before['wholesale_min_qty']);
    await _db.execute(
      "UPDATE products SET name = '$name', name_ta = '$tamil', category = '$category', sku = '$sku', pricing_type = '$pricingType', brand_name = '$brand', retail_price_paise = $retail, wholesale_price_paise = $wholesale, wholesale_min_qty = $wholesaleMinQty, rate = $retail WHERE id = '$escapedItemId'",
    );
  }

  Future<Map<String, dynamic>> _applyInventoryChange(
    Map<String, dynamic> existing,
    _ParsedInventoryRow row,
  ) async {
    final itemId = existing['id'].toString();
    final trackType = PricingType.fromWire(existing['pricing_type']);
    final prevQty = _num(existing['inv_current_qty']) ?? 0;
    final prevWeight = _num(existing['inv_current_weight']) ?? 0;
    final current = trackType == PricingType.weight ? prevWeight : prevQty;
    final requested = row.targetQuantity;
    var newQty = prevQty;
    var newWeight = prevWeight;
    var action = row.actionType;
    if (action == 'SET') {
      if (trackType == PricingType.weight) {
        newWeight = requested;
      } else {
        newQty = requested;
      }
    } else if (action == 'ADD') {
      if (trackType == PricingType.weight) {
        newWeight = current + requested;
      } else {
        newQty = current + requested;
      }
    } else if (action == 'DEDUCT') {
      final next = current - requested;
      if (trackType == PricingType.weight) {
        newWeight = next < 0 ? 0 : next;
      } else {
        newQty = next < 0 ? 0 : next;
      }
    }
    final delta = trackType == PricingType.weight ? newWeight - prevWeight : newQty - prevQty;

    await _db.execute(
      "UPDATE products SET inv_current_qty = $newQty, inv_current_weight = $newWeight WHERE id = '${itemId.replaceAll("'", "''")}'",
    );
    await _db.execute(
      "INSERT INTO inventory_audit (product_id, action_type, qty_delta, weight_delta, prev_qty, new_qty, prev_weight, new_weight, bill_id, reference_id, notes) VALUES ('${itemId.replaceAll("'", "''")}', '${action.toLowerCase()}', ${trackType == PricingType.weight ? 0 : delta}, ${trackType == PricingType.weight ? delta : 0}, $prevQty, $newQty, $prevWeight, $newWeight, NULL, NULL, '${row.notes.replaceAll("'", "''")}')",
    );
    return {
      'trackType': trackType.wire.toLowerCase(),
      'before': {'qty': prevQty, 'weight': prevWeight},
      'after': {'qty': newQty, 'weight': newWeight},
    };
  }

  Future<void> _restoreInventory(
    String itemId,
    Map<String, dynamic> before,
  ) async {
    if (before.isEmpty) {
      return;
    }
    final escapedItemId = itemId.replaceAll("'", "''");
    final qty = _num(before['qty']) ?? 0;
    final weight = _num(before['weight']) ?? 0;
    await _db.execute(
      "UPDATE products SET inv_current_qty = $qty, inv_current_weight = $weight WHERE id = '$escapedItemId'",
    );
  }

  Future<void> _insertBatch({
    required BulkOperationType type,
    required int rowCount,
    required int processedCount,
    required int insertedCount,
    required int updatedCount,
    required int successCount,
    required int failedCount,
    required int skippedCount,
    required List<Map<String, dynamic>> itemsJson,
  }) async {
    final batchId = 'bulk_${DateTime.now().microsecondsSinceEpoch}';
    final items = jsonEncode(itemsJson);
    await _db.execute(
      "INSERT INTO bulk_batches (batch_id, operation_type, file_name, started_at, applied_at, row_count, processed_count, inserted_count, updated_count, success_count, failed_count, skipped_count, items_json, reverted, created_at, updated_at) VALUES ('$batchId', '${type.wire}', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, $rowCount, $processedCount, $insertedCount, $updatedCount, $successCount, $failedCount, $skippedCount, '${items.replaceAll("'", "''")}', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
    );
  }

  _ParsedItemImport _parseItemRows(List<int> bytes) {
    final rows = _parseCsv(utf8.decode(bytes, allowMalformed: true));
    if (rows.isEmpty) {
      return const _ParsedItemImport(rows: []);
    }
    final headers = _headerMap(rows.first);
    final parsedRows = <_ParsedItemRow>[];
    final seenSkus = <String>{};
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (_rowIsBlank(row)) continue;
      final parsed = _parseItemRow(i + 1, headers, row);
      if (parsed.sku.isNotEmpty && !seenSkus.add(parsed.sku)) {
        parsedRows.add(parsed.copyWithWarning('Duplicate SKU in file.'));
      } else {
        parsedRows.add(parsed);
      }
    }
    return _ParsedItemImport(rows: parsedRows);
  }

  _ParsedInventoryImport _parseInventoryRows(List<int> bytes) {
    final rows = _parseCsv(utf8.decode(bytes, allowMalformed: true));
    if (rows.isEmpty) {
      return const _ParsedInventoryImport(rows: []);
    }
    final headers = _headerMap(rows.first);
    final parsedRows = <_ParsedInventoryRow>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (_rowIsBlank(row)) continue;
      parsedRows.add(_parseInventoryRow(i + 1, headers, row));
    }
    return _ParsedInventoryImport(rows: parsedRows);
  }

  _ParsedItemRow _parseItemRow(
    int rowNumber,
    Map<String, int> headers,
    List<String> row,
  ) {
    final slno = _cell(headers, row, ['slno', 'sl_no', 'serial_no', 'sno']);
    final sku = _normalizeSku(
      _cell(headers, row, ['sku']),
    );
    final itemName = _cell(headers, row, ['item_name', 'name', 'product_name']);
    final brandName = _normalizeBrand(
      _cell(headers, row, ['brand_name', 'brand']),
    );
    final tamilName = _cell(
      headers,
      row,
      ['item_tamil_name', 'name_ta', 'tamil_name'],
    );
    final category = _normalizeCategory(
      _cell(headers, row, ['category']),
    );
    final pricingLabel = _cell(
      headers,
      row,
      ['weight_or_qty', 'pricing_type', 'track_type'],
    );
    final pricingType = _pricingTypeFromLabel(pricingLabel);
    final wholesaleMinQtyRaw =
        _cell(headers, row, ['wholesale_min_qty', 'wholesale_min', 'min_qty']);
    final wholesalePriceRaw = _cell(
      headers,
      row,
      ['wholesale_price', 'wholesale_price_paise', 'wholesale_rate'],
    );
    final retailPriceRaw = _cell(
      headers,
      row,
      ['retail_price', 'retail_price_paise', 'retail_rate'],
    );

    final messages = <String>[];
    BulkRowStatus status = BulkRowStatus.ok;
    if (sku.isEmpty) {
      status = BulkRowStatus.error;
      messages.add('SKU is required.');
    } else if (!ItemFormData.skuPattern.hasMatch(sku)) {
      status = BulkRowStatus.error;
      messages.add('SKU may contain only A-Z, 0-9, and hyphens.');
    }
    if (itemName.trim().isEmpty) {
      status = BulkRowStatus.error;
      messages.add('Item name is required.');
    }
    if (retailPriceRaw.trim().isEmpty || Money.parseInrToPaise(retailPriceRaw) <= 0) {
      status = BulkRowStatus.error;
      messages.add('Retail price must be greater than 0.');
    }

    final hasWholesalePrice = wholesalePriceRaw.trim().isNotEmpty;
    final hasWholesaleMinQty = wholesaleMinQtyRaw.trim().isNotEmpty;
    if (hasWholesalePrice != hasWholesaleMinQty) {
      status = BulkRowStatus.error;
      messages.add('Wholesale price and minimum qty must both be provided.');
    }
    if (hasWholesalePrice && Money.parseInrToPaise(wholesalePriceRaw) <= 0) {
      status = BulkRowStatus.error;
      messages.add('Wholesale price must be greater than 0.');
    }
    final wholesaleMinQty =
        hasWholesaleMinQty ? num.tryParse(wholesaleMinQtyRaw.trim()) : null;
    if (hasWholesaleMinQty && (wholesaleMinQty == null || wholesaleMinQty <= 0)) {
      status = BulkRowStatus.error;
      messages.add('Wholesale minimum qty must be greater than 0.');
    }
    if (pricingType == PricingType.unit &&
        wholesaleMinQty != null &&
        wholesaleMinQty != wholesaleMinQty.roundToDouble()) {
      status = BulkRowStatus.error;
      messages.add('Wholesale minimum qty must be a whole number for QTY items.');
    }

    if (messages.isEmpty) {
      messages.add('Ready to apply.');
    }

    return _ParsedItemRow(
      rowNumber: rowNumber,
      slno: slno.isEmpty ? '$rowNumber' : slno,
      sku: sku,
      itemName: itemName,
      brandName: brandName,
      tamilName: tamilName,
      category: category,
      pricingType: pricingType,
      wholesaleMinQty: wholesaleMinQty,
      wholesalePricePaise:
          hasWholesalePrice ? Money.parseInrToPaise(wholesalePriceRaw) : null,
      retailPricePaise: Money.parseInrToPaise(retailPriceRaw),
      status: status,
      messages: messages,
      operation: 'CREATE',
      existing: false,
    );
  }

  _ParsedInventoryRow _parseInventoryRow(
    int rowNumber,
    Map<String, int> headers,
    List<String> row,
  ) {
    final slno = _cell(headers, row, ['slno', 'sl_no', 'serial_no', 'sno']);
    final sku = _normalizeSku(
      _cell(headers, row, ['sku', 'item_id', 'product_id']),
    );
    final actionRaw = _cell(
      headers,
      row,
      ['action_type', 'action'],
    );
    final quantityRaw = _cell(
      headers,
      row,
      ['quantity', 'weight', 'qty', 'value'],
    );
    final notes = _cell(
      headers,
      row,
      ['notes', 'reason', 'remarks'],
    );

    final messages = <String>[];
    BulkRowStatus status = BulkRowStatus.ok;
    if (sku.isEmpty) {
      status = BulkRowStatus.error;
      messages.add('SKU is required.');
    }
    final actionType = _normalizeInventoryAction(actionRaw);
    if (actionRaw.trim().isEmpty) {
      status = BulkRowStatus.warning;
      messages.add('Action defaulted to SET.');
    }
    final quantity = num.tryParse(quantityRaw.trim().replaceAll(',', ''));
    if (quantity == null || quantity < 0) {
      status = BulkRowStatus.error;
      messages.add('Quantity must be 0 or greater.');
    }
    if (messages.isEmpty) {
      messages.add('Ready to apply.');
    }

    return _ParsedInventoryRow(
      rowNumber: rowNumber,
      slno: slno.isEmpty ? '$rowNumber' : slno,
      sku: sku,
      actionType: actionType,
      targetQuantity: quantity ?? 0,
      notes: notes,
      status: status,
      messages: messages,
      trackType: PricingType.unit,
    );
  }

  String _normalizeInventoryAction(String value) {
    final v = value.trim().toUpperCase();
    if (v == 'ADD' || v == 'DEDUCT' || v == 'SET') return v;
    if (v.isEmpty) return 'SET';
    return 'SET';
  }

  PricingType _pricingTypeFromLabel(String value) {
    final v = value.trim().toLowerCase();
    if (v.contains('weight') || v == 'kg' || v == 'w') {
      return PricingType.weight;
    }
    return PricingType.unit;
  }

  bool _isLowStock(Map<String, dynamic> row) {
    final pricingType = PricingType.fromWire(row['pricing_type']);
    final current = pricingType == PricingType.weight
        ? _num(row['inv_current_weight']) ?? 0
        : _num(row['inv_current_qty']) ?? 0;
    final min = pricingType == PricingType.weight
        ? _num(row['inv_min_weight']) ?? 0
        : _num(row['inv_min_qty']) ?? 0;
    return current > 0 && current <= min;
  }

  List<List<String>> _parseCsv(String text) {
    final normalized = text.replaceFirst('\uFEFF', '');
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;

    void flushCell() {
      currentRow.add(cell.toString().trim());
      cell.clear();
    }

    void flushRow() {
      flushCell();
      final hasContent = currentRow.any((v) => v.trim().isNotEmpty);
      if (hasContent) {
        rows.add(List<String>.of(currentRow));
      }
      currentRow.clear();
    }

    for (var i = 0; i < normalized.length; i++) {
      final ch = normalized[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < normalized.length && normalized[i + 1] == '"') {
          cell.write('"');
          i += 1;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (ch == ',' && !inQuotes) {
        flushCell();
        continue;
      }
      if ((ch == '\n' || ch == '\r') && !inQuotes) {
        if (ch == '\r' && i + 1 < normalized.length && normalized[i + 1] == '\n') {
          i += 1;
        }
        flushRow();
        continue;
      }
      cell.write(ch);
    }
    if (cell.isNotEmpty || currentRow.isNotEmpty) {
      flushRow();
    }
    return rows;
  }

  Map<String, int> _headerMap(List<String> headerRow) {
    final map = <String, int>{};
    for (var i = 0; i < headerRow.length; i++) {
      map[_normalizeHeader(headerRow[i])] = i;
    }
    return map;
  }

  String _cell(Map<String, int> headers, List<String> row, List<String> aliases) {
    for (final alias in aliases) {
      final idx = headers[_normalizeHeader(alias)];
      if (idx != null && idx < row.length) {
        return row[idx].trim();
      }
    }
    return '';
  }

  bool _rowIsBlank(List<String> row) => row.every((cell) => cell.trim().isEmpty);

  String _normalizeHeader(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(
            RegExp(r'^_+|_+$'),
            '',
          );

  String _normalizeSku(String value) =>
      ItemFormData.normalizeSku(value);

  String _normalizeCategory(String value) {
    final normalized = value
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9 -]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    return normalized.isEmpty ? 'OTHER' : normalized;
  }

  String _normalizeBrand(String value) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  List<String> _itemExportRow(Map<String, dynamic> row, {required int slno}) {
    final pricingType = PricingType.fromWire(row['pricing_type']);
    return [
      '$slno',
      _str(row['sku']),
      _str(row['name']),
      _str(row['brand_name']),
      _str(row['name_ta']),
      _str(row['category']),
      pricingType == PricingType.weight ? 'WEIGHT' : 'QTY',
      _formatOptionalNumber(row['wholesale_min_qty']),
      _formatMoney(row['wholesale_price_paise']),
      _formatMoney(row['retail_price_paise']),
    ];
  }

  List<String> _inventoryExportRow(Map<String, dynamic> row, {required int slno}) {
    final pricingType = PricingType.fromWire(row['pricing_type']);
    final current = pricingType == PricingType.weight
        ? _formatOptionalNumber(row['inv_current_weight'], showZero: true)
        : _formatOptionalNumber(row['inv_current_qty'], showZero: true);
    return [
      '$slno',
      _str(row['sku']),
      'SET',
      current,
      '',
    ];
  }

  String _toCsv(List<List<String>> rows) => rows.map(_csvRow).join('\n');

  String _csvRow(List<String> row) =>
      row.map((cell) => _csvCell(cell)).join(',');

  String _csvCell(String value) {
    final needsQuotes = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  String _str(Object? v) => v == null ? '' : v.toString();

  num? _num(Object? v) => v is num ? v : num.tryParse('${v ?? ''}');

  num? _nestedNum(Object? value, String key) {
    if (value is Map) return _num(value[key]);
    return null;
  }

  String _sqlNumberOrNull(Object? value) {
    final n = _num(value);
    return n == null ? 'NULL' : n.toString();
  }

  String _formatOptionalNumber(Object? value, {bool showZero = false}) {
    final n = _num(value);
    if (n == null) return '';
    if (!showZero && n == 0) return '';
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toString();
  }

  String _formatMoney(Object? value) {
    final n = _num(value);
    if (n == null || n == 0) return '';
    return Money.toRupees(n);
  }

  List<Map<String, dynamic>> _asList(Object? value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return const [];
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return const <String, dynamic>{};
  }
}

class _ParsedItemImport {
  const _ParsedItemImport({required this.rows});
  final List<_ParsedItemRow> rows;
}

class _ParsedItemRow {
  const _ParsedItemRow({
    required this.rowNumber,
    required this.slno,
    required this.sku,
    required this.itemName,
    required this.brandName,
    required this.tamilName,
    required this.category,
    required this.pricingType,
    required this.wholesaleMinQty,
    required this.wholesalePricePaise,
    required this.retailPricePaise,
    required this.status,
    required this.messages,
    required this.operation,
    required this.existing,
  });

  final int rowNumber;
  final String slno;
  final String sku;
  final String itemName;
  final String brandName;
  final String tamilName;
  final String category;
  final PricingType pricingType;
  final num? wholesaleMinQty;
  final int? wholesalePricePaise;
  final int retailPricePaise;
  final BulkRowStatus status;
  final List<String> messages;
  final String operation;
  final bool existing;

  _ParsedItemRow copyWithWarning(String message) {
    return _ParsedItemRow(
      rowNumber: rowNumber,
      slno: slno,
      sku: sku,
      itemName: itemName,
      brandName: brandName,
      tamilName: tamilName,
      category: category,
      pricingType: pricingType,
      wholesaleMinQty: wholesaleMinQty,
      wholesalePricePaise: wholesalePricePaise,
      retailPricePaise: retailPricePaise,
      status: BulkRowStatus.warning,
      messages: [...messages, message],
      operation: operation,
      existing: existing,
    );
  }

  Map<String, dynamic> toApplyChange({
    required String outcome,
    String? operation,
    String? message,
    String? itemId,
    Map<String, dynamic>? before,
  }) {
    return {
      'rowNumber': rowNumber,
      'slno': slno,
      'sku': sku,
      'itemName': itemName,
      'brandName': brandName,
      'tamilName': tamilName,
      'category': category,
      'pricingType': pricingType.wire,
      'wholesaleMinQty': wholesaleMinQty,
      'wholesalePricePaise': wholesalePricePaise,
      'retailPricePaise': retailPricePaise,
      'operation': operation ?? this.operation,
      'outcome': outcome,
      'message': message ?? messages.join('; '),
      'itemId': itemId,
      'before': before,
    };
  }
}

class _ParsedInventoryImport {
  const _ParsedInventoryImport({required this.rows});
  final List<_ParsedInventoryRow> rows;
}

class _ParsedInventoryRow {
  const _ParsedInventoryRow({
    required this.rowNumber,
    required this.slno,
    required this.sku,
    required this.actionType,
    required this.targetQuantity,
    required this.notes,
    required this.status,
    required this.messages,
    required this.trackType,
  });

  final int rowNumber;
  final String slno;
  final String sku;
  final String actionType;
  final num targetQuantity;
  final String notes;
  final BulkRowStatus status;
  final List<String> messages;
  final PricingType trackType;

  Map<String, dynamic> toApplyChange({
    required String outcome,
    String? itemId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
    String? trackType,
    String? message,
  }) {
    return {
      'rowNumber': rowNumber,
      'slno': slno,
      'sku': sku,
      'actionType': actionType,
      'targetQuantity': targetQuantity,
      'notes': notes,
      'outcome': outcome,
      'message': message ?? messages.join('; '),
      'itemId': itemId,
      'before': before,
      'after': after,
      'trackType': trackType ?? this.trackType.wire,
    };
  }
}

final bulkRepositoryProvider = Provider<BulkRepository>(
  (ref) => BulkRepository(ref.watch(dbConnectionProvider)),
);
