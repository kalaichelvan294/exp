import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/items_repository.dart';
import '../domain/item_form.dart';
import 'items_state.dart';

const _skuDebounce = Duration(milliseconds: 250);

/// Items module controller. Ports items-page-controller.js: list/search/
/// paginate, delete, debounced SKU validation, and create/update.
class ItemsController extends Notifier<ItemsState> {
  Timer? _skuTimer;
  int _skuToken = 0;

  ItemsRepository get _repo => ref.read(itemsRepositoryProvider);

  @override
  ItemsState build() {
    ref.onDispose(() => _skuTimer?.cancel());
    Future.microtask(_bootstrap);
    return const ItemsState();
  }

  Future<void> _bootstrap() async {
    await Future.wait([loadOptions(), loadItems()]);
  }

  Future<void> loadOptions() async {
    try {
      final results = await Future.wait([
        _repo.loadCategories(),
        _repo.loadBrands(),
      ]);
      state = state.copyWith(categories: results[0], brands: results[1]);
    } catch (_) {
      // Options are non-critical; leave existing values.
    }
  }

  Future<void> loadItems() async {
    state = state.copyWith(loading: true);
    try {
      final result = await _repo.listItems(
        query: state.query,
        page: state.page,
        pageSize: state.pageSize,
      );
      final totalPages = result.total <= 0
          ? 1
          : ((result.total + state.pageSize - 1) ~/ state.pageSize);
      if (state.page > totalPages) {
        state = state.copyWith(page: totalPages);
        return loadItems();
      }
      state = state.copyWith(
        items: result.rows,
        total: result.total,
        loading: false,
        message: ItemsMessage('${result.total} item(s) found.'),
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        items: const [],
        message: ItemsMessage(
          'Failed to load items: ${e.toString()}',
          isError: true,
        ),
      );
    }
  }

  Future<void> search(String query) async {
    state = state.copyWith(query: query.trim(), page: 1);
    await loadItems();
  }

  Future<void> clearFilter() async {
    state = state.copyWith(query: '', page: 1);
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

  Future<void> deleteItem(String itemId) async {
    try {
      await _repo.deleteItem(itemId);
      state = state.copyWith(message: const ItemsMessage('Item deleted.'));
      await loadItems();
    } catch (e) {
      state = state.copyWith(
        message: ItemsMessage(
          'Failed to delete item: ${e.toString()}',
          isError: true,
        ),
      );
    }
  }

  // ── SKU validation ────────────────────────────────────────────────────────

  /// Resets validation state when a form is opened.
  void resetSkuValidation() {
    _skuTimer?.cancel();
    _skuToken++;
    state = state.copyWith(
      skuValidation: SkuValidation.requiredSku,
      skuChecking: false,
    );
  }

  /// Debounced SKU validation (parity with `scheduleSkuValidation`).
  void scheduleSkuValidation(String rawSku, {String excludeItemId = ''}) {
    _skuTimer?.cancel();
    final sku = ItemFormData.normalizeSku(rawSku);
    if (sku.isEmpty) {
      state = state.copyWith(
        skuValidation: SkuValidation.requiredSku,
        skuChecking: false,
      );
      return;
    }
    state = state.copyWith(
      skuChecking: true,
      skuValidation: const SkuValidation(
        valid: false,
        message: 'Checking SKU...',
      ),
    );
    _skuTimer = Timer(
      _skuDebounce,
      () => _runSkuValidation(sku, excludeItemId: excludeItemId),
    );
  }

  Future<SkuValidation> _runSkuValidation(
    String sku, {
    String excludeItemId = '',
  }) async {
    final token = ++_skuToken;
    try {
      final result = await _repo.validateSku(sku, excludeItemId: excludeItemId);
      if (token != _skuToken) return result;
      state = state.copyWith(skuValidation: result, skuChecking: false);
      return result;
    } catch (e) {
      final failed = SkuValidation(
        valid: false,
        message: 'SKU validation failed: ${e.toString()}',
      );
      if (token == _skuToken) {
        state = state.copyWith(skuValidation: failed, skuChecking: false);
      }
      return failed;
    }
  }

  // ── Save (create/update) ──────────────────────────────────────────────────

  /// Validates and saves the item. Returns true on success so the dialog can
  /// close. Sets an error message otherwise.
  Future<bool> saveItem(
    ItemFormData form, {
    String editingItemId = '',
  }) async {
    final clientError = form.validate();
    if (clientError != null) {
      state = state.copyWith(message: ItemsMessage(clientError, isError: true));
      return false;
    }

    state = state.copyWith(submitting: true);
    // Final server-side SKU check (parity: validateSku before save).
    final skuResult = await _runSkuValidation(
      ItemFormData.normalizeSku(form.sku),
      excludeItemId: editingItemId,
    );
    if (!skuResult.valid) {
      state = state.copyWith(
        submitting: false,
        message: ItemsMessage(
          skuResult.message.isEmpty ? 'SKU is invalid.' : skuResult.message,
          isError: true,
        ),
      );
      return false;
    }

    try {
      if (editingItemId.isNotEmpty) {
        await _repo.updateItem(editingItemId, form.toPayload());
        state = state.copyWith(
          submitting: false,
          message: const ItemsMessage('Item updated.'),
        );
      } else {
        await _repo.createItem(form.toPayload());
        state = state.copyWith(
          submitting: false,
          message: const ItemsMessage('Item added.'),
        );
      }
      await loadItems();
      return true;
    } catch (e) {
      state = state.copyWith(
        submitting: false,
        message: ItemsMessage(
          'Failed to save item: ${e.toString()}',
          isError: true,
        ),
      );
      return false;
    }
  }

}

final itemsControllerProvider = NotifierProvider<ItemsController, ItemsState>(
  ItemsController.new,
);
