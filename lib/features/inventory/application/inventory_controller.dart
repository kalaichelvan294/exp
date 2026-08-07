import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../items/data/items_repository.dart';
import '../../items/domain/item.dart';
import '../domain/inventory_adjust.dart';
import 'inventory_state.dart';

/// Inventory module controller. Ports inventory-controller.js: settings gating,
/// item listing with client-side trackType + threshold filters, pagination, and
/// stock adjustments.
class InventoryController extends Notifier<InventoryState> {
  ItemsRepository get _repo => ref.read(itemsRepositoryProvider);

  @override
  InventoryState build() {
    Future.microtask(_bootstrap);
    return const InventoryState();
  }

  Future<void> _bootstrap() async {
    try {
      final settings = await _repo.loadInventorySettings();
      state = state.copyWith(settings: settings, settingsLoaded: true);
      if (settings.invControlEnabled) {
        await loadItems();
      }
    } on ApiException catch (e) {
      state = state.copyWith(settingsLoaded: true, error: e.message);
    }
  }

  Future<void> loadItems() async {
    if (!state.enabled) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await _repo.listItems(
        query: state.query,
        page: state.page,
        pageSize: state.pageSize,
      );
      final filtered = _applyFilters(result.rows);
      state = state.copyWith(
        items: filtered,
        total: filtered.length,
        loading: false,
        error: null,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
          loading: false, items: const [], error: e.message);
    }
  }

  List<Item> _applyFilters(List<Item> rows) {
    var items = rows;
    final trackType = state.trackTypeFilter;
    if (trackType.isNotEmpty) {
      items = items.where((i) => i.trackType == trackType).toList();
    }
    final qty = state.qtyThreshold;
    final weight = state.weightThreshold;
    if (qty != null || weight != null) {
      items = items.where((i) {
        if (i.trackType == 'quantity' && qty != null) {
          return i.invCurrentQty <= qty;
        }
        if (i.trackType == 'weight' && weight != null) {
          return i.invCurrentWeight <= weight;
        }
        return true;
      }).toList();
    }
    return items;
  }

  Future<void> applyFilters({
    required String query,
    required String trackTypeFilter,
    num? qtyThreshold,
    num? weightThreshold,
  }) async {
    state = state.copyWith(
      query: query.trim(),
      trackTypeFilter: trackTypeFilter,
      qtyThreshold: qtyThreshold,
      weightThreshold: weightThreshold,
      page: 1,
    );
    await loadItems();
  }

  Future<void> resetFilters() async {
    state = state.copyWith(
      query: '',
      trackTypeFilter: '',
      qtyThreshold: null,
      weightThreshold: null,
      page: 1,
    );
    await loadItems();
  }

  Future<void> nextPage() async {
    if (!state.canNext) return;
    state = state.copyWith(page: state.page + 1);
    await loadItems();
  }

  Future<void> prevPage() async {
    if (!state.canPrev) return;
    state = state.copyWith(page: state.page - 1);
    await loadItems();
  }

  /// Applies a stock adjustment. Returns true on success.
  Future<bool> adjust(String itemId, InventoryAdjustment adjustment) async {
    try {
      await _repo.adjustInventory(itemId, adjustment);
      await loadItems();
      return true;
    } on ApiException {
      return false;
    }
  }
}

final inventoryControllerProvider =
    NotifierProvider<InventoryController, InventoryState>(
        InventoryController.new);
