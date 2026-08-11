import 'package:flutter/foundation.dart';

import '../domain/billing_enums.dart';
import '../domain/cart_line.dart';
import '../domain/product.dart';

/// Camera lifecycle states.
enum CameraCaptureMode {
  none, // Camera not in use
  searching, // Capturing for "/" search
  preview, // Live preview in modal
}

/// A user-facing status message shown in the search hint / footer area.
@immutable
class BillingMessage {
  const BillingMessage(this.text, {this.isError = false});
  final String text;
  final bool isError;

  static const empty = BillingMessage('');
}

/// A held-bill chip rendered on the Sales Desk.
@immutable
class HeldBillChip {
  const HeldBillChip({
    required this.holdId,
    required this.label,
    required this.amountPaise,
  });
  final String holdId;
  final String label;
  final int amountPaise;
}

/// A recent-bill chip rendered on the Sales Desk.
@immutable
class RecentBillChip {
  const RecentBillChip({required this.billId, required this.amountPaise});
  final String billId;
  final int amountPaise;
}

/// Immutable Sales Desk UI state.
@immutable
class BillingState {
  const BillingState({
    this.query = '',
    this.matches = const [],
    this.selectedMatchIndex = -1,
    this.searchDropdownOpen = false,
    this.cameraConnected = false,
    this.cameraBusy = false,
    this.cameraTurnedOff = false,
    this.cameraError = '',
    this.cameraStatus = 'Camera unavailable',
    this.cameraModalVisible = false,
    this.cameraCaptureMode = CameraCaptureMode.none,
    this.searchFieldFocused = false,
    this.cameraProcessing = false,
    this.cart = const [],
    this.selectedCartIndex = -1,
    this.qtyFocusRequestToken = 0,
    this.paymentMode = PaymentMode.cash,
    this.discountMode = DiscountMode.percent,
    this.discountValue = 0,
    this.pendingBillId = '',
    this.activeHoldId = '',
    this.editingBillId = '',
    this.editingCreatedAt = '',
    this.wholesaleAutoApply = true,
    this.previewVisible = false,
    this.heldBills = const [],
    this.recentBills = const [],
    this.holdsLeft = 3,
    this.message = BillingMessage.empty,
    this.searching = false,
    this.submitting = false,
  });

  final String query;
  final List<Product> matches;
  final int selectedMatchIndex;
  final bool searchDropdownOpen;
  final bool cameraConnected;
  final bool cameraBusy;
  final bool cameraTurnedOff;
  final String cameraError;
  final String cameraStatus;
  final bool cameraModalVisible;
  final CameraCaptureMode cameraCaptureMode;
  final bool searchFieldFocused;
  final bool cameraProcessing;

  final List<CartLine> cart;
  final int selectedCartIndex;
  final int qtyFocusRequestToken;

  final PaymentMode paymentMode;
  final DiscountMode discountMode;
  final num discountValue;
  final String pendingBillId;
  final String activeHoldId;

  /// Non-empty when editing an existing saved bill (parity with the Electron
  /// billing-edit-controller). Drives update-vs-save on checkout.
  final String editingBillId;

  /// Original `createdAt` of the bill being edited, preserved on update.
  final String editingCreatedAt;

  final bool wholesaleAutoApply;

  final bool previewVisible;
  final List<HeldBillChip> heldBills;
  final List<RecentBillChip> recentBills;
  final int holdsLeft;

  final BillingMessage message;
  final bool searching;
  final bool submitting;

  bool get cartEmpty => cart.isEmpty;
  bool get canCheckout => cart.isNotEmpty && !submitting;
  bool get canHold => cart.isNotEmpty && !previewVisible && !submitting;
  bool get hasMergeableDuplicates {
    final seen = <String>{};
    for (final line in cart) {
      if (!seen.add(line.mergeKey)) return true;
    }
    return false;
  }

  /// True when an existing saved bill is loaded for editing.
  bool get isEditing => editingBillId.trim().isNotEmpty;

  BillingState copyWith({
    String? query,
    List<Product>? matches,
    int? selectedMatchIndex,
    bool? searchDropdownOpen,
    bool? cameraConnected,
    bool? cameraBusy,
    bool? cameraTurnedOff,
    String? cameraError,
    String? cameraStatus,
    bool? cameraModalVisible,
    CameraCaptureMode? cameraCaptureMode,
    bool? searchFieldFocused,
    bool? cameraProcessing,
    List<CartLine>? cart,
    int? selectedCartIndex,
    int? qtyFocusRequestToken,
    PaymentMode? paymentMode,
    DiscountMode? discountMode,
    num? discountValue,
    String? pendingBillId,
    String? activeHoldId,
    String? editingBillId,
    String? editingCreatedAt,
    bool? wholesaleAutoApply,
    bool? previewVisible,
    List<HeldBillChip>? heldBills,
    List<RecentBillChip>? recentBills,
    int? holdsLeft,
    BillingMessage? message,
    bool? searching,
    bool? submitting,
  }) {
    return BillingState(
      query: query ?? this.query,
      matches: matches ?? this.matches,
      selectedMatchIndex: selectedMatchIndex ?? this.selectedMatchIndex,
      searchDropdownOpen: searchDropdownOpen ?? this.searchDropdownOpen,
      cameraConnected: cameraConnected ?? this.cameraConnected,
      cameraBusy: cameraBusy ?? this.cameraBusy,
      cameraTurnedOff: cameraTurnedOff ?? this.cameraTurnedOff,
      cameraError: cameraError ?? this.cameraError,
      cameraStatus: cameraStatus ?? this.cameraStatus,
      cameraModalVisible: cameraModalVisible ?? this.cameraModalVisible,
      cameraCaptureMode: cameraCaptureMode ?? this.cameraCaptureMode,
      searchFieldFocused: searchFieldFocused ?? this.searchFieldFocused,
      cameraProcessing: cameraProcessing ?? this.cameraProcessing,
      cart: cart ?? this.cart,
      selectedCartIndex: selectedCartIndex ?? this.selectedCartIndex,
      qtyFocusRequestToken: qtyFocusRequestToken ?? this.qtyFocusRequestToken,
      paymentMode: paymentMode ?? this.paymentMode,
      discountMode: discountMode ?? this.discountMode,
      discountValue: discountValue ?? this.discountValue,
      pendingBillId: pendingBillId ?? this.pendingBillId,
      activeHoldId: activeHoldId ?? this.activeHoldId,
      editingBillId: editingBillId ?? this.editingBillId,
      editingCreatedAt: editingCreatedAt ?? this.editingCreatedAt,
      wholesaleAutoApply: wholesaleAutoApply ?? this.wholesaleAutoApply,
      previewVisible: previewVisible ?? this.previewVisible,
      heldBills: heldBills ?? this.heldBills,
      recentBills: recentBills ?? this.recentBills,
      holdsLeft: holdsLeft ?? this.holdsLeft,
      message: message ?? this.message,
      searching: searching ?? this.searching,
      submitting: submitting ?? this.submitting,
    );
  }
}
