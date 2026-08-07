import 'package:flutter/foundation.dart';

import '../domain/billing_enums.dart';
import '../domain/cart_line.dart';
import '../domain/product.dart';

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
  const HeldBillChip({required this.holdId, required this.label, required this.amountPaise});
  final String holdId;
  final String label;
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
    this.cart = const [],
    this.selectedCartIndex = -1,
    this.paymentMode = PaymentMode.cash,
    this.discountMode = DiscountMode.percent,
    this.discountValue = 0,
    this.pendingBillId = '',
    this.editingBillId = '',
    this.editingCreatedAt = '',
    this.wholesaleAutoApply = true,
    this.previewVisible = false,
    this.heldBills = const [],
    this.holdsLeft = 3,
    this.message = BillingMessage.empty,
    this.searching = false,
    this.submitting = false,
  });

  final String query;
  final List<Product> matches;
  final int selectedMatchIndex;
  final bool searchDropdownOpen;

  final List<CartLine> cart;
  final int selectedCartIndex;

  final PaymentMode paymentMode;
  final DiscountMode discountMode;
  final num discountValue;
  final String pendingBillId;

  /// Non-empty when editing an existing saved bill (parity with the Electron
  /// billing-edit-controller). Drives update-vs-save on checkout.
  final String editingBillId;

  /// Original `createdAt` of the bill being edited, preserved on update.
  final String editingCreatedAt;

  final bool wholesaleAutoApply;

  final bool previewVisible;
  final List<HeldBillChip> heldBills;
  final int holdsLeft;

  final BillingMessage message;
  final bool searching;
  final bool submitting;

  bool get cartEmpty => cart.isEmpty;
  bool get canCheckout => cart.isNotEmpty && !submitting;
  bool get canHold => cart.isNotEmpty && !previewVisible && !submitting;

  /// True when an existing saved bill is loaded for editing.
  bool get isEditing => editingBillId.trim().isNotEmpty;

  BillingState copyWith({
    String? query,
    List<Product>? matches,
    int? selectedMatchIndex,
    bool? searchDropdownOpen,
    List<CartLine>? cart,
    int? selectedCartIndex,
    PaymentMode? paymentMode,
    DiscountMode? discountMode,
    num? discountValue,
    String? pendingBillId,
    String? editingBillId,
    String? editingCreatedAt,
    bool? wholesaleAutoApply,
    bool? previewVisible,
    List<HeldBillChip>? heldBills,
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
      cart: cart ?? this.cart,
      selectedCartIndex: selectedCartIndex ?? this.selectedCartIndex,
      paymentMode: paymentMode ?? this.paymentMode,
      discountMode: discountMode ?? this.discountMode,
      discountValue: discountValue ?? this.discountValue,
      pendingBillId: pendingBillId ?? this.pendingBillId,
      editingBillId: editingBillId ?? this.editingBillId,
      editingCreatedAt: editingCreatedAt ?? this.editingCreatedAt,
      wholesaleAutoApply: wholesaleAutoApply ?? this.wholesaleAutoApply,
      previewVisible: previewVisible ?? this.previewVisible,
      heldBills: heldBills ?? this.heldBills,
      holdsLeft: holdsLeft ?? this.holdsLeft,
      message: message ?? this.message,
      searching: searching ?? this.searching,
      submitting: submitting ?? this.submitting,
    );
  }
}
