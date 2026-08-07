import 'package:flutter_test/flutter_test.dart';
import 'package:pos_294_flutter/features/bills/application/bills_state.dart';
import 'package:pos_294_flutter/features/bills/domain/bill_filters.dart';
import 'package:pos_294_flutter/features/bills/domain/bill_summary.dart';

void main() {
  group('BillSummary.fromRow (parity with billing:list projection)', () {
    test('maps a full row with nested billData', () {
      final summary = BillSummary.fromRow({
        'billId': '04-aug-2026-165703319',
        'createdAt': '2026-08-04T11:27:03.319Z',
        'billData': {
          'billId': '04-aug-2026-165703319',
          'paymentMode': 'GPAY',
          'itemCount': 3,
          'subtotalPaise': 12500,
          'discountPaise': 500,
          'grandTotalPaise': 12000,
        },
      });

      expect(summary.billId, '04-aug-2026-165703319');
      expect(summary.createdAt, '2026-08-04T11:27:03.319Z');
      expect(summary.paymentMode, 'GPAY');
      expect(summary.itemCount, 3);
      expect(summary.subtotalPaise, 12500);
      expect(summary.discountPaise, 500);
      expect(summary.grandTotalPaise, 12000);
    });

    test('falls back to defaults for a sparse row', () {
      final summary = BillSummary.fromRow({'billId': 'X-1'});
      expect(summary.billId, 'X-1');
      expect(summary.createdAt, '');
      expect(summary.paymentMode, '-');
      expect(summary.itemCount, 0);
      expect(summary.grandTotalPaise, 0);
    });

    test('coerces numeric strings to int paise', () {
      final summary = BillSummary.fromRow({
        'billId': 'Y-2',
        'billData': {'grandTotalPaise': '9900', 'itemCount': '2'},
      });
      expect(summary.grandTotalPaise, 9900);
      expect(summary.itemCount, 2);
    });
  });

  group('BillsState pagination (parity with getTotalPages / prev-next)', () {
    test('totalPages uses ceil(total / pageSize) with a floor of 1', () {
      expect(const BillsState(total: 0, pageSize: 10).totalPages, 1);
      expect(const BillsState(total: 1, pageSize: 10).totalPages, 1);
      expect(const BillsState(total: 10, pageSize: 10).totalPages, 1);
      expect(const BillsState(total: 11, pageSize: 10).totalPages, 2);
      expect(const BillsState(total: 25, pageSize: 10).totalPages, 3);
    });

    test('canPrev/canNext reflect current page bounds', () {
      const first = BillsState(page: 1, total: 25, pageSize: 10);
      expect(first.canPrev, isFalse);
      expect(first.canNext, isTrue);

      const middle = BillsState(page: 2, total: 25, pageSize: 10);
      expect(middle.canPrev, isTrue);
      expect(middle.canNext, isTrue);

      const last = BillsState(page: 3, total: 25, pageSize: 10);
      expect(last.canPrev, isTrue);
      expect(last.canNext, isFalse);
    });

    test('isEmptyResult only when loaded, no error, and no rows', () {
      expect(const BillsState().isEmptyResult, isTrue);
      expect(const BillsState(loading: true).isEmptyResult, isFalse);
      expect(const BillsState(error: 'boom').isEmptyResult, isFalse);
    });

    test('copyWith can explicitly clear the error', () {
      const withError = BillsState(error: 'boom');
      expect(withError.copyWith(error: null).error, isNull);
      // Omitting error preserves it.
      expect(withError.copyWith(page: 2).error, 'boom');
    });
  });

  group('BillFilters', () {
    test('empty filter is detected', () {
      expect(BillFilters.empty.isEmpty, isTrue);
      expect(const BillFilters(paymentMode: 'CASH').isEmpty, isFalse);
    });

    test('copyWith and equality', () {
      const base = BillFilters(billId: 'A');
      final updated = base.copyWith(paymentMode: 'CARD');
      expect(updated.billId, 'A');
      expect(updated.paymentMode, 'CARD');
      expect(updated, const BillFilters(billId: 'A', paymentMode: 'CARD'));
    });
  });
}
