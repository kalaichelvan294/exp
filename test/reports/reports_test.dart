import 'package:flutter_test/flutter_test.dart';
import 'package:pos_294_flutter/features/reports/domain/analytics.dart';
import 'package:pos_294_flutter/features/reports/domain/report_filters.dart';

void main() {
  group('ReportPeriod.fromWire', () {
    test('maps known values, defaults to monthly', () {
      expect(ReportPeriod.fromWire('daily'), ReportPeriod.daily);
      expect(ReportPeriod.fromWire('WEEKLY'), ReportPeriod.weekly);
      expect(ReportPeriod.fromWire('custom'), ReportPeriod.custom);
      expect(ReportPeriod.fromWire('bogus'), ReportPeriod.monthly);
    });
  });

  group('ReportDates helpers', () {
    test('today is yyyy-MM-dd', () {
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(ReportDates.today()),
          isTrue);
    });

    test('currentMonth is yyyy-MM', () {
      expect(RegExp(r'^\d{4}-\d{2}$').hasMatch(ReportDates.currentMonth()),
          isTrue);
    });

    test('currentWeek is yyyy-Www', () {
      expect(
          RegExp(r'^\d{4}-W\d{2}$').hasMatch(ReportDates.currentWeek()), isTrue);
    });
  });

  group('ReportFilters.buildPayload', () {
    test('monthly falls back to current month when empty', () {
      final payload = const ReportFilters().buildPayload();
      expect(payload['period'], 'monthly');
      expect(RegExp(r'^\d{4}-\d{2}$').hasMatch(payload['month'] as String),
          isTrue);
    });

    test('monthly keeps provided month', () {
      final payload = const ReportFilters(
        period: ReportPeriod.monthly,
        month: '2026-03',
      ).buildPayload();
      expect(payload['month'], '2026-03');
    });

    test('daily uses provided day', () {
      final payload = const ReportFilters(
        period: ReportPeriod.daily,
        day: '2026-08-04',
      ).buildPayload();
      expect(payload, {'period': 'daily', 'day': '2026-08-04'});
    });

    test('custom requires both dates', () {
      expect(
        () => const ReportFilters(period: ReportPeriod.custom, dateFrom: '2026-01-01')
            .buildPayload(),
        throwsA(isA<ReportFilterException>()),
      );
    });

    test('custom rejects reversed range', () {
      expect(
        () => const ReportFilters(
          period: ReportPeriod.custom,
          dateFrom: '2026-02-01',
          dateTo: '2026-01-01',
        ).buildPayload(),
        throwsA(isA<ReportFilterException>()),
      );
    });

    test('custom accepts valid range', () {
      final payload = const ReportFilters(
        period: ReportPeriod.custom,
        dateFrom: '2026-01-01',
        dateTo: '2026-01-31',
      ).buildPayload();
      expect(payload,
          {'period': 'custom', 'dateFrom': '2026-01-01', 'dateTo': '2026-01-31'});
    });
  });

  group('Analytics.fromJson', () {
    test('parses full payload', () {
      final analytics = Analytics.fromJson({
        'period': 'daily',
        'kpis': {
          'totalSalesPaise': 12500,
          'totalBills': 3,
          'totalDiscountPaise': 500,
          'avgBillPaise': 4166,
        },
        'trend': [
          {'label': '09:00', 'totalSalesPaise': 5000, 'billCount': 1},
          {'label': '10:00', 'totalSalesPaise': 7500, 'billCount': 2},
        ],
        'topSoldItems': [
          {
            'name': 'Rice',
            'pricingType': 'UNIT',
            'totalQty': 4,
            'totalSalesPaise': 8000,
          },
          {
            'name': 'Sugar',
            'pricingType': 'WEIGHT',
            'totalQty': 2.5,
            'totalSalesPaise': 4500,
          },
        ],
        'salesByHour': [],
        'salesByWeekday': [],
        'insights': {'peakHour': '10:00', 'peakWeekday': 'MON'},
      });
      expect(analytics.period, 'daily');
      expect(analytics.kpis.totalSalesPaise, 12500);
      expect(analytics.trend.length, 2);
      expect(analytics.trend.last.label, '10:00');
      expect(analytics.peakHour, '10:00');
      expect(analytics.peakWeekday, 'MON');
      expect(analytics.topSoldItems.first.qtyDisplay, '4');
      expect(analytics.topSoldItems.last.qtyDisplay, '2.500');
      expect(analytics.topSoldItems.last.isWeight, isTrue);
    });

    test('applies defaults for missing fields', () {
      final analytics = Analytics.fromJson({});
      expect(analytics.period, 'monthly');
      expect(analytics.kpis.totalBills, 0);
      expect(analytics.trend, isEmpty);
      expect(analytics.peakHour, '-');
    });
  });
}
