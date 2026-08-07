// Reporting period selection and filter inputs (parity with reports.js
// buildPayload + the date helpers). Date strings use UTC to match the Electron
// renderer, which derives values from `toISOString()`.

enum ReportPeriod {
  daily('daily'),
  weekly('weekly'),
  monthly('monthly'),
  custom('custom');

  const ReportPeriod(this.wire);
  final String wire;

  static ReportPeriod fromWire(Object? value) {
    final v = value?.toString().toLowerCase();
    return ReportPeriod.values.firstWhere(
      (p) => p.wire == v,
      orElse: () => ReportPeriod.monthly,
    );
  }
}

/// Thrown when [ReportFilters.buildPayload] cannot produce a valid request
/// (parity with the errors thrown in reports.js buildPayload).
class ReportFilterException implements Exception {
  const ReportFilterException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ReportDates {
  const ReportDates._();

  /// Today as `yyyy-MM-dd` (UTC).
  static String today() => _utcNow().toIso8601String().substring(0, 10);

  /// Current month as `yyyy-MM` (UTC).
  static String currentMonth() => _utcNow().toIso8601String().substring(0, 7);

  /// Current ISO week as `yyyy-Www` (parity with getCurrentWeekValue).
  static String currentWeek() {
    final now = _utcNow();
    var utc = DateTime.utc(now.year, now.month, now.day);
    final day = utc.weekday; // Mon=1..Sun=7
    utc = utc.add(Duration(days: 4 - day));
    final yearStart = DateTime.utc(utc.year, 1, 1);
    final weekNo =
        (((utc.difference(yearStart).inMilliseconds / 86400000) + 1) / 7)
            .ceil();
    return '${utc.year}-W${weekNo.toString().padLeft(2, '0')}';
  }

  static DateTime _utcNow() => DateTime.now().toUtc();
}

class ReportFilters {
  const ReportFilters({
    this.period = ReportPeriod.monthly,
    this.month = '',
    this.day = '',
    this.week = '',
    this.dateFrom = '',
    this.dateTo = '',
  });

  final ReportPeriod period;
  final String month;
  final String day;
  final String week;
  final String dateFrom;
  final String dateTo;

  ReportFilters copyWith({
    ReportPeriod? period,
    String? month,
    String? day,
    String? week,
    String? dateFrom,
    String? dateTo,
  }) {
    return ReportFilters(
      period: period ?? this.period,
      month: month ?? this.month,
      day: day ?? this.day,
      week: week ?? this.week,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
    );
  }

  /// Builds the `reports:analytics` request payload, applying the same defaults
  /// and validation as reports.js. Throws [ReportFilterException] for invalid
  /// custom ranges.
  Map<String, dynamic> buildPayload() {
    switch (period) {
      case ReportPeriod.monthly:
        return {
          'period': period.wire,
          'month': month.isNotEmpty ? month : ReportDates.currentMonth(),
        };
      case ReportPeriod.daily:
        return {
          'period': period.wire,
          'day': day.isNotEmpty ? day : ReportDates.today(),
        };
      case ReportPeriod.weekly:
        return {
          'period': period.wire,
          'week': week.isNotEmpty ? week : ReportDates.currentWeek(),
        };
      case ReportPeriod.custom:
        if (dateFrom.isEmpty || dateTo.isEmpty) {
          throw const ReportFilterException(
              'Custom range requires both From and To dates.');
        }
        if (dateFrom.compareTo(dateTo) > 0) {
          throw const ReportFilterException(
              'From date cannot be after To date.');
        }
        return {
          'period': period.wire,
          'dateFrom': dateFrom,
          'dateTo': dateTo,
        };
    }
  }
}
