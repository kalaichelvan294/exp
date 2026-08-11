import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../printing/data/receipt_print_service.dart';
import '../../printing/domain/preview_outcome.dart';
import '../../printing/domain/receipt_html_builder.dart';
import '../../printing/domain/receipt_models.dart';
import '../../image_search/data/product_embedding_repository.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/domain/app_settings.dart';
import '../data/billing_repository.dart';
import '../domain/bill_data.dart';
import '../domain/bill_id.dart';
import '../domain/bill_totals.dart';
import '../domain/billing_enums.dart';
import '../domain/cart_line.dart';
import '../domain/product.dart';
import 'billing_state.dart';

const _searchDebounce = Duration(milliseconds: 100);
const _maxHolds = 3;

/// Sales Desk controller. Ports the interaction model from the Electron
/// `sales-page-controller.js` (+ search/cart/checkout controllers) onto an
/// immutable Riverpod state.
class BillingController extends Notifier<BillingState> {
  Timer? _searchDebounce0;
  int _searchToken = 0;
  CameraController? _cameraController;

  BillingRepository get _repo => ref.read(billingRepositoryProvider);

  @override
  BillingState build() {
    ref.onDispose(() {
      _searchDebounce0?.cancel();
      final controller = _cameraController;
      _cameraController = null;
      if (controller != null) {
        unawaited(controller.dispose());
      }
    });
    // Kick off async side-loads without blocking first frame.
    Future.microtask(() async {
      await loadHeldBills();
      await loadRecentBills();
      await ensureCameraReady();
    });
    return const BillingState();
  }

  BillTotals get totals =>
      Totals.compute(state.cart, state.discountMode, state.discountValue);

  // ── Search ────────────────────────────────────────────────────────────

  bool _shouldRunSearch(String query) => query.trim().isNotEmpty;

  void onQueryChanged(String query) {
    state = state.copyWith(query: query, searchDropdownOpen: true);
    _searchDebounce0?.cancel();
    if (!_shouldRunSearch(query)) {
      state = state.copyWith(matches: const [], selectedMatchIndex: -1);
      return;
    }
    _searchDebounce0 = Timer(_searchDebounce, () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final token = ++_searchToken;
    state = state.copyWith(searching: true);
    try {
      final matches = await _repo.searchProducts(query, limit: 8);
      if (token != _searchToken) return;
      state = state.copyWith(
        matches: matches,
        selectedMatchIndex: matches.isNotEmpty ? 0 : -1,
        searching: false,
      );
    } catch (e) {
      if (token != _searchToken) return;
      state = state.copyWith(
        matches: const [],
        selectedMatchIndex: -1,
        searching: false,
        message: BillingMessage(
          'Search failed: ${e.toString()}',
          isError: true,
        ),
      );
    }
  }

  Future<void> ensureCameraReady() async {
    if (!Platform.isWindows) {
      state = state.copyWith(
        cameraConnected: false,
        cameraLive: false,
        cameraBusy: false,
        cameraStatus: 'Camera is Windows-only',
      );
      return;
    }

    final existing = _cameraController;
    if (existing != null && existing.value.isInitialized) {
      state = state.copyWith(
        cameraConnected: true,
        cameraLive: true,
        cameraBusy: state.cameraBusy,
        cameraStatus: 'Camera live',
      );
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        state = state.copyWith(
          cameraConnected: false,
          cameraLive: false,
          cameraBusy: false,
          cameraStatus: 'No camera detected',
        );
        return;
      }

      final controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      final previous = _cameraController;
      _cameraController = controller;
      if (previous != null) {
        unawaited(previous.dispose());
      }
      state = state.copyWith(
        cameraConnected: true,
        cameraLive: true,
        cameraBusy: state.cameraBusy,
        cameraStatus: 'Camera live',
      );
    } on CameraException catch (e) {
      state = state.copyWith(
        cameraConnected: false,
        cameraLive: false,
        cameraBusy: false,
        cameraStatus: 'Camera unavailable',
        message: BillingMessage(
          'Camera setup failed: ${e.toString()}',
          isError: true,
        ),
      );
    }
  }

  Future<void> captureCameraSearch() async {
    state = state.copyWith(cameraBusy: true, cameraStatus: 'Capturing frame...');
    try {
      await ensureCameraReady();
      final controller = _cameraController;
      if (controller == null || !controller.value.isInitialized) {
        state = state.copyWith(
          cameraBusy: false,
          cameraLive: false,
          cameraStatus: 'Camera unavailable',
        );
        return;
      }

      final capture = await controller.takePicture();
      final embeddingRepo = ref.read(productEmbeddingRepositoryProvider);
      final barcode = await embeddingRepo.decodeBarcodeFromImageFile(
        File(capture.path),
      );
      final normalizedBarcode = barcode?.trim() ?? '';
      final barcodeMatch = normalizedBarcode.isEmpty
          ? null
          : await _repo.findExactProduct(normalizedBarcode);
      final match = barcodeMatch != null
          ? ImageSearchMatch(
              product: barcodeMatch,
              similarity: 1,
              imageUrl: 'barcode:$normalizedBarcode',
            )
          : await embeddingRepo.findBestMatchFromImageFile(File(capture.path));
      if (match == null) {
        state = state.copyWith(
          query: '',
          matches: const [],
          selectedMatchIndex: -1,
          searchDropdownOpen: true,
          cameraBusy: false,
          cameraStatus: 'No match found',
          message: const BillingMessage('No product matched the camera image.'),
        );
        return;
      }

        state = state.copyWith(
          query: '',
          matches: [match.product],
          selectedMatchIndex: 0,
          searchDropdownOpen: true,
          cameraBusy: false,
          cameraStatus: barcodeMatch != null
              ? 'Barcode match: ${match.product.displayName}'
              : 'Best match: ${match.product.displayName}',
          message: BillingMessage(
            barcodeMatch != null
                ? 'Barcode match: ${match.product.displayName}'
                : 'Camera match: ${match.product.displayName} '
                    '(${(match.similarity * 100).toStringAsFixed(1)}%)',
          ),
        );
    } on CameraException catch (e) {
      state = state.copyWith(
        cameraBusy: false,
        cameraLive: false,
        cameraStatus: 'Camera search failed',
        message: BillingMessage(
          'Camera search failed: ${e.description ?? e.toString()}',
          isError: true,
        ),
      );
    } on StateError catch (e) {
      state = state.copyWith(
        cameraBusy: false,
        cameraLive: false,
        cameraStatus: 'Camera search failed',
        message: BillingMessage(
          'Camera search failed: ${e.toString()}',
          isError: true,
        ),
      );
    }
  }

  /// Re-runs the current search and opens the dropdown (global / focus action).
  Future<void> refreshSearch() async {
    state = state.copyWith(searchDropdownOpen: true);
    if (_shouldRunSearch(state.query)) {
      await _runSearch(state.query);
    }
  }

  void moveSelection(int delta) {
    if (state.matches.isEmpty) return;
    final len = state.matches.length;
    final next = state.selectedMatchIndex < 0
        ? (delta > 0 ? 0 : len - 1)
        : (state.selectedMatchIndex + delta) % len;
    state = state.copyWith(
      selectedMatchIndex: next < 0 ? next + len : next,
      searchDropdownOpen: true,
    );
  }

  void moveSelectionGrid({
    required int rowDelta,
    required int columnDelta,
    int columns = 3,
  }) {
    if (state.matches.isEmpty) return;
    final len = state.matches.length;
    var current = state.selectedMatchIndex;
    if (current < 0 || current >= len) current = 0;

    final row = current ~/ columns;
    final col = current % columns;
    var next = current;

    if (columnDelta != 0) {
      final targetCol = col + columnDelta;
      if (targetCol < 0 || targetCol >= columns) return;
      final target = (row * columns) + targetCol;
      if (target < len) next = target;
    } else if (rowDelta != 0) {
      final maxRow = (len - 1) ~/ columns;
      final targetRow = row + rowDelta;
      if (targetRow < 0 || targetRow > maxRow) return;
      var target = (targetRow * columns) + col;
      if (target >= len) target = len - 1;
      next = target;
    } else {
      return;
    }

    state = state.copyWith(selectedMatchIndex: next, searchDropdownOpen: true);
  }

  void setSearchDropdownOpen(bool open) =>
      state = state.copyWith(searchDropdownOpen: open);

  /// Enter key: resolve the best match (exact → highlighted → first) and add.
  Future<void> addBestMatch() async {
    final query = state.query;
    try {
      final selected =
          state.selectedMatchIndex >= 0 &&
              state.selectedMatchIndex < state.matches.length
          ? state.matches[state.selectedMatchIndex]
          : null;
      final exact = await _repo.findExactProduct(query);
      final product =
          selected ??
          exact ??
          (state.matches.isNotEmpty ? state.matches.first : null);
      if (product == null) {
        state = state.copyWith(
          message: const BillingMessage(
            'No item added. Enter a valid item name or SKU.',
          ),
        );
        return;
      }
      addProduct(product, 'MANUAL_SEARCH');
    } catch (e) {
      state = state.copyWith(
        message: BillingMessage(
          'Search failed: ${e.toString()}',
          isError: true,
        ),
      );
    }
  }

  // ── Cart ──────────────────────────────────────────────────────────────

  void addProduct(Product product, String entryMethod) {
    final line = CartLine.fromProduct(product, entryMethod)
      ..applyLinePricing(state.wholesaleAutoApply);
    final cart = [...state.cart, line];
    state = state.copyWith(
      cart: cart,
      selectedCartIndex: cart.length - 1,
      qtyFocusRequestToken: state.qtyFocusRequestToken + 1,
      // Reset search after add.
      query: '',
      matches: const [],
      selectedMatchIndex: -1,
      searchDropdownOpen: false,
      message: BillingMessage('Added: ${product.name}'),
    );
  }

  void mergeDuplicateLines() {
    if (!state.hasMergeableDuplicates) return;

    final merged = <CartLine>[];
    final indexByKey = <String, int>{};
    var selectedMergedIndex = -1;
    for (
      var originalIndex = 0;
      originalIndex < state.cart.length;
      originalIndex++
    ) {
      final line = state.cart[originalIndex];
      final key = line.mergeKey;
      final existingIndex = indexByKey[key];
      if (existingIndex == null) {
        indexByKey[key] = merged.length;
        merged.add(line);
        if (originalIndex == state.selectedCartIndex) {
          selectedMergedIndex = merged.length - 1;
        }
        continue;
      }

      final target = merged[existingIndex];
      target.qty += line.qty;
      target.applyLinePricing(state.wholesaleAutoApply);
      if (originalIndex == state.selectedCartIndex) {
        selectedMergedIndex = existingIndex;
      }
    }

    state = state.copyWith(
      cart: merged,
      selectedCartIndex: selectedMergedIndex >= 0
          ? selectedMergedIndex
          : (merged.isEmpty ? -1 : 0),
      message: const BillingMessage('Merged duplicate items'),
    );
  }

  void selectCartLine(int index) {
    if (index < 0 || index >= state.cart.length) return;
    state = state.copyWith(selectedCartIndex: index);
  }

  /// Sets a line quantity. When [commit] is true, UNIT quantities are rounded.
  void updateQty(int index, Object? value, {required bool commit}) {
    if (index < 0 || index >= state.cart.length) return;
    final line = state.cart[index];
    final parsed = _parsePositive(value);
    if (line.pricingType == PricingType.unit) {
      line.qty = commit ? parsed.round().toDouble() : parsed;
    } else {
      line.qty = parsed;
    }
    line.applyLinePricing(state.wholesaleAutoApply);
    _emitCart();
  }

  void bumpQty(int index, num delta) {
    if (index < 0 || index >= state.cart.length) return;
    final line = state.cart[index];
    if (line.pricingType == PricingType.weight) {
      final currentGrams = ((line.qty) * 1000).round();
      final nextGrams = (currentGrams + (delta * 1000).round());
      line.qty = (nextGrams < 0 ? 0 : nextGrams) / 1000;
    } else {
      final next = (line.qty + delta).round();
      line.qty = (next < 0 ? 0 : next).toDouble();
    }
    line.applyLinePricing(state.wholesaleAutoApply);
    _emitCart();
  }

  void removeLine(int index) {
    if (index < 0 || index >= state.cart.length) return;
    final cart = [...state.cart]..removeAt(index);
    var selected = state.selectedCartIndex;
    if (cart.isEmpty) {
      selected = -1;
    } else if (selected >= cart.length) {
      selected = cart.length - 1;
    }
    state = state.copyWith(cart: cart, selectedCartIndex: selected);
  }

  bool removeSelectedLine() {
    if (state.selectedCartIndex < 0) return false;
    removeLine(state.selectedCartIndex);
    return true;
  }

  void _emitCart() => state = state.copyWith(cart: [...state.cart]);

  // ── Checkout inputs ─────────────────────────────────────────────────────

  void setPaymentMode(PaymentMode mode) =>
      state = state.copyWith(paymentMode: mode);

  void setDiscountMode(DiscountMode mode) =>
      state = state.copyWith(discountMode: mode);

  void setDiscountValue(Object? value) =>
      state = state.copyWith(discountValue: _parsePositive(value));

  // ── Preview ─────────────────────────────────────────────────────────────

  void showPreview() {
    if (state.cart.isEmpty) {
      state = state.copyWith(
        message: const BillingMessage(
          'Add items to the cart before previewing.',
        ),
      );
      return;
    }
    _ensurePendingBillId();
    state = state.copyWith(previewVisible: true);
  }

  void hidePreview() => state = state.copyWith(previewVisible: false);

  String _ensurePendingBillId() {
    if (state.pendingBillId.trim().isNotEmpty) return state.pendingBillId;
    final id = BillId.generate();
    state = state.copyWith(pendingBillId: id);
    return id;
  }

  // ── New bill / hold / resume ──────────────────────────────────────────────

  void startNewBill() {
    if (state.cart.isEmpty && !state.isEditing) {
      state = state.copyWith(
        message: const BillingMessage('Bill is already empty.'),
      );
      return;
    }
    state = state.copyWith(
      cart: const [],
      selectedCartIndex: -1,
      pendingBillId: '',
      activeHoldId: '',
      editingBillId: '',
      editingCreatedAt: '',
      discountValue: 0,
      previewVisible: false,
      message: const BillingMessage('Started a new bill.'),
    );
  }

  Future<void> holdCurrentBill() async {
    if (state.cart.isEmpty) {
      state = state.copyWith(
        message: const BillingMessage(
          'Cannot hold an empty bill.',
          isError: true,
        ),
      );
      return;
    }
    final billId = _ensurePendingBillId();
    final bill = BillData.fromCart(
      billId: billId,
      paymentMode: state.paymentMode,
      discountMode: state.discountMode,
      discountValue: state.discountValue,
      cart: state.cart,
      totals: totals,
    );
    try {
      final result = await _repo.holdBill(bill);
      state = state.copyWith(
        cart: const [],
        selectedCartIndex: -1,
        pendingBillId: '',
        activeHoldId: '',
        discountValue: 0,
        previewVisible: false,
        heldBills: [
          HeldBillChip(
            holdId: result.holdId,
            label: bill.billId,
            amountPaise: bill.grandTotalPaise,
          ),
          ...state.heldBills.where((chip) => chip.holdId != result.holdId),
        ],
        message: BillingMessage(
          'Bill held successfully. Holds left: ${result.holdsLeft}.',
        ),
      );
      await loadHeldBills();
    } catch (e) {
      state = state.copyWith(
        message: BillingMessage(
          'Failed to hold bill: ${e.toString()}',
          isError: true,
        ),
      );
      await loadHeldBills();
    }
  }

  Future<void> loadHeldBills() async {
    try {
      final page = await _repo.listHeldBills(limit: _maxHolds);
      state = state.copyWith(
        heldBills: page.rows
            .map(
              (r) => HeldBillChip(
                holdId: r.holdId,
                label: r.billId,
                amountPaise: r.grandTotalPaise,
              ),
            )
            .toList(),
        holdsLeft: page.holdsLeft,
      );
    } catch (_) {
      state = state.copyWith(heldBills: const [], holdsLeft: _maxHolds);
    }
  }

  Future<void> loadRecentBills() async {
    try {
      final result = await _repo.listBills(pageSize: 2);
      final recent = <RecentBillChip>[];
      for (final row in result.rows) {
        final id = _asString(row['billId'] ?? row['bill_id']);
        final data = _asMap(row['billData'] ?? row['bill_data']);
        final grandTotal = _asInt(data['grandTotalPaise']);
        if (id.isNotEmpty) {
          recent.add(RecentBillChip(billId: id, amountPaise: grandTotal));
        }
      }
      state = state.copyWith(recentBills: recent);
    } catch (_) {
      state = state.copyWith(recentBills: const []);
    }
  }

  Future<void> resumeHeldBill(String holdId) async {
    try {
      final data = await _repo.resumeHeldBill(holdId);
      final items = (data['items'] as List?) ?? const [];
      final cart = items
          .whereType<Map<String, dynamic>>()
          .map((line) => _cartLineFromBillItem(line))
          .toList();
      state = state.copyWith(
        paymentMode: PaymentMode.fromWire(data['paymentMode']),
        discountMode: DiscountMode.fromWire(data['discountMode']),
        discountValue: _parsePositive(data['discountValue']),
        pendingBillId: '',
        activeHoldId: holdId,
        editingBillId: '',
        editingCreatedAt: '',
        cart: cart,
        selectedCartIndex: -1,
        message: BillingMessage(
          'Resumed held bill ${data['billId'] ?? holdId}. A new bill id will be generated on save.',
        ),
      );
      await loadHeldBills();
    } catch (e) {
      state = state.copyWith(
        message: BillingMessage(
          'Failed to resume held bill: $e',
          isError: true,
        ),
      );
      await loadHeldBills();
    }
  }

  Future<void> deleteHeldBill(String holdId) async {
    try {
      await _repo.deleteHeldBill(holdId);
      state = state.copyWith(
        message: const BillingMessage('Held bill removed.'),
      );
      await loadHeldBills();
    } catch (e) {
      state = state.copyWith(
        message: BillingMessage(
          'Failed to remove held bill: ${e.toString()}',
          isError: true,
        ),
      );
    }
  }

  // ── Edit existing bill (Phase 3) ──────────────────────────────────────────

  /// Loads a saved bill into the Sales Desk for editing (parity with
  /// billing-edit-controller `loadIntoBillingUi`).
  Future<void> loadBillForEdit(String billId) async {
    final id = billId.trim();
    if (id.isEmpty) return;
    if (state.editingBillId == id && state.cart.isNotEmpty) return;
    try {
      final data = await _repo.getBill(id);
      final items = (data['items'] as List?) ?? const [];
      final cart = items
          .whereType<Map<String, dynamic>>()
          .map((line) => _cartLineFromBillItem(line, entryMethod: 'BILL_EDIT'))
          .toList();
      state = state.copyWith(
        paymentMode: PaymentMode.fromWire(data['paymentMode']),
        discountMode: DiscountMode.fromWire(data['discountMode']),
        discountValue: _parsePositive(data['discountValue']),
        pendingBillId: id,
        activeHoldId: '',
        editingBillId: id,
        editingCreatedAt: (data['createdAt'] ?? '').toString(),
        cart: cart,
        selectedCartIndex: -1,
        previewVisible: false,
        message: BillingMessage(
          'Editing bill $id. Update and press F4 to save changes.',
        ),
      );
    } catch (e) {
      state = state.copyWith(
        message: BillingMessage('Failed to load bill $id: $e', isError: true),
      );
    }
  }

  /// Clears edit context and the cart (used when leaving the editor).
  void exitEdit() {
    state = state.copyWith(
      cart: const [],
      selectedCartIndex: -1,
      pendingBillId: '',
      activeHoldId: '',
      editingBillId: '',
      editingCreatedAt: '',
      discountValue: 0,
      previewVisible: false,
    );
  }

  /// Triggers a client-side print preview for the bill being edited. Renders
  /// the receipt HTML and opens it in the WebView preview (parity with the
  /// Electron reprint flow, now driven from the client).
  Future<void> reprintCurrentBill() async {
    final id = state.editingBillId.trim();
    if (id.isEmpty) return;
    final bill = BillData.fromCart(
      billId: id,
      paymentMode: state.paymentMode,
      discountMode: state.discountMode,
      discountValue: state.discountValue,
      cart: state.cart,
      totals: totals,
      createdAt: state.editingCreatedAt.isNotEmpty
          ? state.editingCreatedAt
          : null,
    );
    try {
      final outcome = await _openReceiptPreview(bill);
      state = state.copyWith(
        message: outcome.failed
            ? BillingMessage(
                'Print preview failed for bill $id: ${outcome.error}',
                isError: true,
              )
            : BillingMessage('Print preview opened for bill $id.'),
      );
    } on Object catch (e) {
      state = state.copyWith(
        message: BillingMessage(
          'Failed to open print preview: $e',
          isError: true,
        ),
      );
    }
  }

  /// Deletes the bill being edited. Returns true on success so the UI can
  /// navigate back to the Bills list.
  Future<bool> deleteCurrentBill() async {
    final id = state.editingBillId.trim();
    if (id.isEmpty) return false;
    try {
      await _repo.deleteBill(id);
      exitEdit();
      state = state.copyWith(message: BillingMessage('Bill $id deleted.'));
      return true;
    } catch (e) {
      state = state.copyWith(
        message: BillingMessage(
          'Failed to delete bill: ${e.toString()}',
          isError: true,
        ),
      );
      return false;
    }
  }

  // ── Checkout (save) ───────────────────────────────────────────────────────

  Future<void> checkout() async {
    if (state.cart.isEmpty) {
      state = state.copyWith(
        message: const BillingMessage(
          'Cannot checkout. Add at least one item.',
          isError: true,
        ),
      );
      return;
    }
    final billId = _ensurePendingBillId();
    final bill = BillData.fromCart(
      billId: billId,
      paymentMode: state.paymentMode,
      discountMode: state.discountMode,
      discountValue: state.discountValue,
      cart: state.cart,
      totals: totals,
      createdAt: state.isEditing && state.editingCreatedAt.isNotEmpty
          ? state.editingCreatedAt
          : null,
    );
    final activeHoldId = state.activeHoldId.trim();
    state = state.copyWith(submitting: true);

    // Edit mode: update the existing bill and stay in the editor (parity).
    if (state.isEditing) {
      try {
        await _repo.updateBill(state.editingBillId, bill);
        state = state.copyWith(
          submitting: false,
          previewVisible: false,
          activeHoldId: '',
          recentBills: [
            RecentBillChip(
              billId: state.editingBillId,
              amountPaise: bill.grandTotalPaise,
            ),
            ...state.recentBills.where(
              (chip) => chip.billId != state.editingBillId,
            ),
          ],
          message: BillingMessage(
            'Bill ${state.editingBillId} updated (${state.paymentMode.wire}) '
            'total ₹${(bill.grandTotalPaise / 100).toStringAsFixed(2)}.',
          ),
        );
        await loadRecentBills();
      } catch (e) {
        state = state.copyWith(
          submitting: false,
          message: BillingMessage(
            'Update failed: ${e.toString()}',
            isError: true,
          ),
        );
      }
      return;
    }

    try {
      final result = await _repo.saveBill(bill);
      // Render + open the receipt preview on the client (parity with the
      // Electron post-save preview, now driven from the Flutter WebView).
      final outcome = await _openReceiptPreview(bill);
      // Auto-start a new bill after save (parity).
      final base = state.copyWith(
        submitting: false,
        cart: const [],
        selectedCartIndex: -1,
        pendingBillId: '',
        activeHoldId: '',
        discountValue: 0,
        previewVisible: false,
        recentBills: [
          RecentBillChip(
            billId: result.billId,
            amountPaise: bill.grandTotalPaise,
          ),
          ...state.recentBills.where((chip) => chip.billId != result.billId),
        ],
      );
      state = base.copyWith(
        message: outcome.failed
            ? BillingMessage(
                'Bill ${result.billId} saved, but preview failed: '
                '${outcome.error}. New bill started.',
                isError: true,
              )
            : BillingMessage(
                'Bill ${result.billId} saved (${state.paymentMode.wire}) — '
                '₹${(bill.grandTotalPaise / 100).toStringAsFixed(2)}. '
                'New bill started.',
              ),
      );
      await loadRecentBills();
      if (activeHoldId.isNotEmpty) {
        try {
          await _repo.deleteHeldBill(activeHoldId);
          await loadHeldBills();
        } catch (e) {
          state = state.copyWith(
            message: BillingMessage(
              'Bill saved, but failed to clear hold $activeHoldId: ${e.toString()}',
              isError: true,
            ),
          );
        }
      }
    } catch (e) {
      state = state.copyWith(
        submitting: false,
        message: BillingMessage(
          'Checkout failed: ${e.toString()}',
          isError: true,
        ),
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Loads the persisted store profile + print language for the receipt,
  /// falling back to defaults when settings are unavailable (parity with the
  /// Electron `storeProfile` defaults).
  Future<AppSettings> _loadReceiptSettings() async {
    try {
      return await ref.read(settingsRepositoryProvider).loadSettings();
    } catch (_) {
      return const AppSettings();
    }
  }

  /// Composes the receipt HTML for [bill] and opens the WebView print preview.
  Future<PreviewOutcome> _openReceiptPreview(BillData bill) async {
    final settings = await _loadReceiptSettings();
    final payload = ReceiptPayload.fromBillData(bill, settings: settings);
    final document = ReceiptHtmlBuilder.document(payload);
    return ref.read(receiptPrintServiceProvider).openPreview(document);
  }

  CartLine _cartLineFromBillItem(
    Map<String, dynamic> line, {
    String entryMethod = 'BILL_HOLD',
  }) {
    num? asNumOrNull(Object? v) =>
        v == null ? null : (v is num ? v : num.tryParse('$v'));
    int asInt(Object? v) => (v is num) ? v.round() : int.tryParse('$v') ?? 0;
    final retail = asInt(line['retailPricePaise'] ?? line['rate']);
    return CartLine(
      id: (line['id'] ?? '').toString(),
      sku: (line['sku'] ?? line['id'] ?? '').toString(),
      name: (line['name'] ?? '').toString(),
      nameTa: (line['nameTa'] ?? '').toString(),
      brandName: (line['brandName'] ?? '').toString(),
      category: (line['category'] ?? 'UNCATEGORIZED').toString(),
      pricingType: PricingType.fromWire(line['pricingType']),
      qty: _parsePositive(line['qty']),
      retailRatePaise: retail,
      wholesaleRatePaise: line['wholesalePricePaise'] == null
          ? null
          : asInt(line['wholesalePricePaise']),
      wholesaleMinQty: asNumOrNull(line['wholesaleMinQty']),
      ratePaise: asInt(line['rate'] ?? retail),
      priceTier: PriceTier.fromWire(line['priceTier']),
      entryMethod: entryMethod,
    );
  }

  num _parsePositive(Object? value) {
    final n = value is num ? value : num.tryParse('${value ?? ''}'.trim());
    if (n != null && n.isFinite && n >= 0) return n;
    return 0;
  }

  int _asInt(Object? value) =>
      value is num ? value.round() : int.tryParse('${value ?? ''}') ?? 0;

  String _asString(Object? value) => value?.toString().trim() ?? '';

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k?.toString() ?? '', v));
    }
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k?.toString() ?? '', v));
      }
    }
    return const <String, dynamic>{};
  }
}

final billingControllerProvider =
    NotifierProvider<BillingController, BillingState>(BillingController.new);
