import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_294_flutter/features/bulk/application/bulk_controller.dart';
import 'package:pos_294_flutter/features/bulk/data/bulk_file_service.dart';
import 'package:pos_294_flutter/features/bulk/data/bulk_repository.dart';
import 'package:pos_294_flutter/features/bulk/domain/bulk_batch.dart';
import 'package:pos_294_flutter/features/bulk/domain/bulk_enums.dart';
import 'package:pos_294_flutter/features/bulk/domain/bulk_file.dart';
import 'package:pos_294_flutter/features/bulk/domain/bulk_preview.dart';
import 'package:pos_294_flutter/features/bulk/domain/bulk_result.dart';
import 'package:pos_294_flutter/features/inventory/domain/inventory_settings.dart';
import 'package:pos_294_flutter/features/settings/data/settings_repository.dart';
import 'package:pos_294_flutter/features/settings/domain/app_settings.dart';

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({this.invEnabled = true});

  final bool invEnabled;

  @override
  Future<AppSettings> loadSettings() async => AppSettings.fromJson({
        'itemCategories': ['SNACKS', 'NUTS'],
        'itemBrands': ['ACME', 'HOUSE'],
      });

  @override
  Future<InventorySettings> loadInventorySettings() async =>
      InventorySettings.fromJson({'invControlEnabled': invEnabled});

  @override
  Future<void> saveSettings(Map<String, dynamic> patch) async {}

  @override
  Future<void> saveInventorySettings({required bool invControlEnabled}) async {}

  @override
  Future<List<String>> propagateBrands() async => const [];
}

class _FakeFileService implements BulkFileService {
  _FakeFileService({this.picked, this.savePath = 'C:/downloads/out.xlsx'});

  PickedFile? picked;
  String? savePath;
  BulkFile? lastSaved;

  @override
  Future<PickedFile?> pickSpreadsheet() async => picked;

  @override
  Future<String?> saveDownload(BulkFile file) async {
    lastSaved = file;
    return savePath;
  }
}

class _FakeBulkRepository implements BulkRepository {
  BulkPreview? itemPreview;
  BulkApplyResult? itemApply;
  BulkBatch? itemBatch;
  BulkRevertResult revertResult = const BulkRevertResult();
  int getLastBatchCalls = 0;
  bool reverted = false;

  BulkFile get _file =>
      const BulkFile(fileName: 'f.xlsx', base64: '', contentType: 'x');

  @override
  Future<BulkFile> downloadItemTemplate() async => _file;
  @override
  Future<BulkFile> downloadAllItems() async => _file;
  @override
  Future<BulkFile> downloadFilteredItems({
    required List<String> brandNames,
    required List<String> categories,
  }) async =>
      _file;
  @override
  Future<BulkFile> downloadInventoryTemplate() async => _file;
  @override
  Future<BulkFile> downloadCurrentInventory({
    required String trackType,
    required bool lowStockOnly,
  }) async =>
      _file;

  @override
  Future<BulkPreview> previewItems(List<int> bytes) async => itemPreview!;
  @override
  Future<BulkPreview> previewInventory(List<int> bytes) async => itemPreview!;

  @override
  Future<BulkApplyResult> applyItems(List<int> bytes) async => itemApply!;
  @override
  Future<BulkApplyResult> applyInventory(List<int> bytes) async => itemApply!;

  @override
  Future<BulkBatch?> getLastBatch(BulkOperationType type) async {
    getLastBatchCalls++;
    if (reverted && itemBatch != null) {
      return BulkBatch(
        batchId: itemBatch!.batchId,
        operationType: itemBatch!.operationType,
        rowCount: itemBatch!.rowCount,
        reverted: true,
        appliedAt: itemBatch!.appliedAt,
      );
    }
    return itemBatch;
  }

  @override
  Future<BulkRevertResult> revert(String batchId) async {
    reverted = true;
    return revertResult;
  }

  @override
  Future<BulkFile> downloadErrorReport(String batchId) async => _file;
}

ProviderContainer _container({
  required _FakeBulkRepository repo,
  required _FakeFileService files,
  bool invEnabled = true,
}) {
  final container = ProviderContainer(overrides: [
    bulkRepositoryProvider.overrideWithValue(repo),
    bulkFileServiceProvider.overrideWithValue(files),
    settingsRepositoryProvider
        .overrideWithValue(_FakeSettingsRepository(invEnabled: invEnabled)),
  ]);
  addTearDown(container.dispose);
  return container;
}

BulkPreview _preview({required BulkRowStatus status, int ready = 1}) {
  return BulkPreview(
    rows: [
      BulkPreviewRow(
        rowNumber: 2,
        status: status,
        messages: status == BulkRowStatus.error ? const ['bad'] : const [],
        sku: 'A',
        name: 'Item A',
        operation: 'create',
      ),
    ],
    summary: BulkPreviewSummary(
      readyCount: ready,
      errorCount: status == BulkRowStatus.error ? 1 : 0,
      warningCount: status == BulkRowStatus.warning ? 1 : 0,
    ),
    autoDetectMode: true,
  );
}

void main() {
  const item = BulkOperationType.itemImport;

  test('init loads options and inventory control and last batch', () async {
    final repo = _FakeBulkRepository()
      ..itemBatch = const BulkBatch(
        batchId: 'b1',
        operationType: item,
        rowCount: 5,
        reverted: false,
      );
    final container = _container(repo: repo, files: _FakeFileService());
    container.read(bulkControllerProvider);
    await pumpEventQueue();

    final state = container.read(bulkControllerProvider);
    expect(state.loaded, isTrue);
    expect(state.invControlEnabled, isTrue);
    expect(state.categoryOptions, ['NUTS', 'SNACKS']); // sorted
    expect(state.brandOptions, ['ACME', 'HOUSE']);
    expect(state.tab(item).lastBatch?.batchId, 'b1');
  });

  test('pickAndPreview populates preview; clean preview enables apply',
      () async {
    final repo = _FakeBulkRepository()
      ..itemPreview = _preview(status: BulkRowStatus.ok);
    final files = _FakeFileService(
        picked: const PickedFile(name: 'up.xlsx', bytes: [1, 2, 3]));
    final container = _container(repo: repo, files: files);
    final controller = container.read(bulkControllerProvider.notifier);
    await pumpEventQueue();

    await controller.pickAndPreview(item);
    final tab = container.read(bulkControllerProvider).tab(item);
    expect(tab.fileName, 'up.xlsx');
    expect(tab.preview, isNotNull);
    expect(tab.applyEnabled, isTrue);
    expect(tab.applyLabel, 'Apply 1 row');
  });

  test('preview with errors blocks apply', () async {
    final repo = _FakeBulkRepository()
      ..itemPreview = _preview(status: BulkRowStatus.error);
    final files = _FakeFileService(
        picked: const PickedFile(name: 'up.xlsx', bytes: [9]));
    final container = _container(repo: repo, files: files);
    final controller = container.read(bulkControllerProvider.notifier);
    await pumpEventQueue();

    await controller.pickAndPreview(item);
    final tab = container.read(bulkControllerProvider).tab(item);
    expect(tab.applyEnabled, isFalse);
    expect(tab.applyHint, 'Fix errors to enable Apply');

    // Apply is a no-op when blocked.
    await controller.apply(item);
    expect(container.read(bulkControllerProvider).tab(item).result, isNull);
  });

  test('apply sets result and refreshes last batch', () async {
    final repo = _FakeBulkRepository()
      ..itemPreview = _preview(status: BulkRowStatus.ok)
      ..itemApply = BulkApplyResult.fromJson(item, const {
        'inserted': 1,
        'updated': 0,
        'rows': [
          {'rowNumber': 2, 'sku': 'A', 'outcome': 'applied'},
        ],
      })
      ..itemBatch = const BulkBatch(
          batchId: 'b2', operationType: item, rowCount: 1, reverted: false);
    final files = _FakeFileService(
        picked: const PickedFile(name: 'up.xlsx', bytes: [1]));
    final container = _container(repo: repo, files: files);
    final controller = container.read(bulkControllerProvider.notifier);
    await pumpEventQueue();

    await controller.pickAndPreview(item);
    await controller.apply(item);
    final tab = container.read(bulkControllerProvider).tab(item);
    expect(tab.result, isNotNull);
    expect(tab.result!.summaryLabel, 'Inserted: 1 · Updated: 0');
    expect(tab.busy, isFalse);
  });

  test('pagination advances within bounds', () async {
    final rows = List.generate(
      30,
      (i) => BulkPreviewRow(
          rowNumber: i + 2, status: BulkRowStatus.ok, messages: const []),
    );
    final repo = _FakeBulkRepository()
      ..itemPreview = BulkPreview(
        rows: rows,
        summary: const BulkPreviewSummary(readyCount: 30),
      );
    final files = _FakeFileService(
        picked: const PickedFile(name: 'up.xlsx', bytes: [1]));
    final container = _container(repo: repo, files: files);
    final controller = container.read(bulkControllerProvider.notifier);
    await pumpEventQueue();
    await controller.pickAndPreview(item);

    var tab = container.read(bulkControllerProvider).tab(item);
    expect(tab.totalPages, 2);
    expect(tab.pageRows, hasLength(25));
    expect(tab.pageInfo, 'Showing rows 1–25 of 30');

    controller.nextPage(item);
    tab = container.read(bulkControllerProvider).tab(item);
    expect(tab.previewPage, 2);
    expect(tab.pageRows, hasLength(5));
    expect(tab.canNext, isFalse);

    // Cannot advance past the last page.
    controller.nextPage(item);
    expect(container.read(bulkControllerProvider).tab(item).previewPage, 2);
  });

  test('revert marks batch reverted and toasts success', () async {
    final repo = _FakeBulkRepository()
      ..itemBatch = const BulkBatch(
          batchId: 'b3', operationType: item, rowCount: 2, reverted: false)
      ..revertResult = const BulkRevertResult(revertedCount: 2);
    final container = _container(repo: repo, files: _FakeFileService());
    final controller = container.read(bulkControllerProvider.notifier);
    await pumpEventQueue();

    await controller.revert(item);
    final state = container.read(bulkControllerProvider);
    expect(state.toast?.text, 'Import reverted successfully.');
    expect(state.toast?.isError, isFalse);
    expect(state.tab(item).lastBatch?.reverted, isTrue);
  });

  test('download saves file and toasts the path', () async {
    final files = _FakeFileService(savePath: 'C:/tmp/all_items.xlsx');
    final container = _container(repo: _FakeBulkRepository(), files: files);
    final controller = container.read(bulkControllerProvider.notifier);
    await pumpEventQueue();

    await controller.downloadItems();
    final state = container.read(bulkControllerProvider);
    expect(state.toast?.text, 'Saved to C:/tmp/all_items.xlsx');
    expect(files.lastSaved, isNotNull);
  });

  test('cancelled save produces no toast', () async {
    final files = _FakeFileService(savePath: null);
    final container = _container(repo: _FakeBulkRepository(), files: files);
    final controller = container.read(bulkControllerProvider.notifier);
    await pumpEventQueue();

    await controller.downloadItemTemplate();
    expect(container.read(bulkControllerProvider).toast, isNull);
  });

  test('inventory gate blocks pick when control disabled', () async {
    final repo = _FakeBulkRepository()
      ..itemPreview = _preview(status: BulkRowStatus.ok);
    final files = _FakeFileService(
        picked: const PickedFile(name: 'inv.xlsx', bytes: [1]));
    final container = _container(repo: repo, files: files, invEnabled: false);
    final controller = container.read(bulkControllerProvider.notifier);
    await pumpEventQueue();

    expect(container.read(bulkControllerProvider).invControlEnabled, isFalse);
    await controller.pickAndPreview(BulkOperationType.inventoryUpdate);
    expect(
      container
          .read(bulkControllerProvider)
          .tab(BulkOperationType.inventoryUpdate)
          .preview,
      isNull,
    );
  });
}
