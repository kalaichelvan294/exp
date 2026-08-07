import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_294_flutter/features/bulk/domain/bulk_batch.dart';
import 'package:pos_294_flutter/features/bulk/domain/bulk_enums.dart';
import 'package:pos_294_flutter/features/bulk/domain/bulk_file.dart';
import 'package:pos_294_flutter/features/bulk/domain/bulk_preview.dart';
import 'package:pos_294_flutter/features/bulk/domain/bulk_result.dart';

void main() {
  group('BulkOperationType', () {
    test('round-trips wire values', () {
      expect(BulkOperationType.itemImport.wire, 'item_import');
      expect(BulkOperationType.inventoryUpdate.wire, 'inventory_update');
      expect(BulkOperationType.fromWire('inventory_update'),
          BulkOperationType.inventoryUpdate);
      expect(BulkOperationType.fromWire('item_import'),
          BulkOperationType.itemImport);
      // Unknown / null falls back to item import.
      expect(BulkOperationType.fromWire('nope'), BulkOperationType.itemImport);
      expect(BulkOperationType.fromWire(null), BulkOperationType.itemImport);
    });
  });

  group('BulkPreview.fromJson', () {
    test('parses item rows, summary, and autoDetectMode', () {
      final preview = BulkPreview.fromJson({
        'autoDetectMode': true,
        'summary': {
          'readyCount': 3,
          'warningCount': 1,
          'errorCount': 1,
          'skippedCount': 0,
        },
        'rows': [
          {
            'rowNumber': 2,
            'slno': '1001',
            'sku': 'CHW-500',
            'name': 'Chiwda',
            'operation': 'create',
            'status': 'ok',
            'messages': [],
          },
          {
            'rowNumber': 3,
            'sku': 'CSH-250',
            'status': 'error',
            'messages': ['Invalid SKU', 'Missing name'],
          },
        ],
      });

      expect(preview.autoDetectMode, isTrue);
      expect(preview.rows, hasLength(2));
      expect(preview.rows.first.status, BulkRowStatus.ok);
      expect(preview.rows.first.operation, 'create');
      expect(preview.rows[1].status, BulkRowStatus.error);
      expect(preview.rows[1].detail, 'Invalid SKU; Missing name');
      expect(preview.summary.label, '3 ready · 1 warnings · 1 error');
      expect(preview.summary.hasErrors, isTrue);
      expect(preview.summary.hasWarnings, isTrue);
    });

    test('parses inventory qty/weight display', () {
      final preview = BulkPreview.fromJson({
        'autoDetectMode': false,
        'summary': {'readyCount': 2},
        'rows': [
          {'rowNumber': 2, 'sku': 'A', 'action': 'add', 'quantity': 50,
            'status': 'ok', 'messages': []},
          {'rowNumber': 3, 'sku': 'B', 'action': 'replace', 'weight_kg': 25.5,
            'status': 'warning', 'messages': ['low']},
        ],
      });

      expect(preview.rows[0].quantityDisplay, '50');
      expect(preview.rows[1].quantityDisplay, '25.5 kg');
      expect(preview.rows[1].detail, 'low');
      // Empty summary counter fields default to 0.
      expect(preview.summary.errorCount, 0);
    });

    test('pluralizes error label correctly at 0', () {
      const summary = BulkPreviewSummary(readyCount: 1);
      expect(summary.label, '1 ready · 0 warnings · 0 errors');
    });
  });

  group('BulkApplyResult.fromJson', () {
    test('item import summary shows inserted + updated', () {
      final result = BulkApplyResult.fromJson(BulkOperationType.itemImport, {
        'inserted': 4,
        'updated': 2,
        'failed': 0,
        'rows': [
          {'rowNumber': 2, 'slno': '1', 'sku': 'A', 'name': 'X',
            'operation': 'create', 'outcome': 'applied', 'message': ''},
        ],
      });
      expect(result.summaryLabel, 'Inserted: 4 · Updated: 2');
      expect(result.rows.single.outcome, BulkRowOutcome.applied);
    });

    test('inventory summary shows updated only, appends failed', () {
      final result =
          BulkApplyResult.fromJson(BulkOperationType.inventoryUpdate, {
        'updated': 5,
        'failed': 1,
        'rows': [
          {'rowNumber': 2, 'sku': 'A', 'action': 'add', 'trackType': 'weight',
            'prevWeight': 10, 'newWeight': 15.5, 'outcome': 'applied'},
          {'rowNumber': 3, 'sku': 'B', 'action': 'deduct',
            'trackType': 'quantity', 'prevQty': 8, 'newQty': 3,
            'outcome': 'failed', 'message': 'boom'},
        ],
      });
      expect(result.summaryLabel, 'Updated: 5 · Failed: 1');
      expect(result.rows[0].beforeDisplay, '10 kg');
      expect(result.rows[0].afterDisplay, '15.5 kg');
      expect(result.rows[1].beforeDisplay, '8 units');
      expect(result.rows[1].afterDisplay, '3 units');
      expect(result.rows[1].outcome, BulkRowOutcome.failed);
    });
  });

  group('BulkBatch.tryFromJson', () {
    test('returns null for empty / data-null payloads', () {
      expect(BulkBatch.tryFromJson(null), isNull);
      expect(BulkBatch.tryFromJson(const {}), isNull);
      expect(BulkBatch.tryFromJson(const {'data': null}), isNull);
      expect(BulkBatch.tryFromJson(const {'batchId': ''}), isNull);
    });

    test('parses a batch payload', () {
      final batch = BulkBatch.tryFromJson(const {
        'batchId': 'item_import-123',
        'operationType': 'item_import',
        'appliedAt': '2026-01-01T00:00:00.000Z',
        'rowCount': 12,
        'reverted': false,
      });
      expect(batch, isNotNull);
      expect(batch!.batchId, 'item_import-123');
      expect(batch.operationType, BulkOperationType.itemImport);
      expect(batch.rowCount, 12);
      expect(batch.reverted, isFalse);
    });
  });

  group('BulkRevertResult.fromJson', () {
    test('parses reverted count and skipped rows', () {
      final result = BulkRevertResult.fromJson(const {
        'revertedCount': 3,
        'skippedRows': [
          {'sku': 'A', 'reason': 'product already deleted — skipped'},
        ],
      });
      expect(result.revertedCount, 3);
      expect(result.skippedRows.single.sku, 'A');
    });
  });

  group('BulkFile', () {
    test('decodes base64 bytes', () {
      final file = BulkFile.fromJson({
        'fileName': 'x.xlsx',
        'base64': base64Encode([1, 2, 3]),
        'contentType': 'application/octet-stream',
      });
      expect(file.bytes, [1, 2, 3]);
      expect(file.fileName, 'x.xlsx');
    });
  });
}
