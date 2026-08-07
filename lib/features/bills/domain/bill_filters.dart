import 'package:flutter/foundation.dart';

/// Bills-list filter inputs. Mirrors the filter state in
/// `bills-page-controller.js` (billId doubles as an amount search).
@immutable
class BillFilters {
  const BillFilters({
    this.billId = '',
    this.paymentMode = '',
    this.dateFrom = '',
    this.dateTo = '',
  });

  /// Bill ID or amount search term.
  final String billId;

  /// Empty means "All Payment Modes".
  final String paymentMode;
  final String dateFrom;
  final String dateTo;

  static const empty = BillFilters();

  bool get isEmpty =>
      billId.isEmpty &&
      paymentMode.isEmpty &&
      dateFrom.isEmpty &&
      dateTo.isEmpty;

  BillFilters copyWith({
    String? billId,
    String? paymentMode,
    String? dateFrom,
    String? dateTo,
  }) {
    return BillFilters(
      billId: billId ?? this.billId,
      paymentMode: paymentMode ?? this.paymentMode,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BillFilters &&
      other.billId == billId &&
      other.paymentMode == paymentMode &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo;

  @override
  int get hashCode => Object.hash(billId, paymentMode, dateFrom, dateTo);
}
