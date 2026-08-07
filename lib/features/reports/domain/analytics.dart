// Analytics models mirroring the `reports:analytics` (getPeriodAnalytics)
// response shape from the database adapter. All money is integer paise.

/// A single pointin a sales trend / hour / weekday series.
class SalesPoint {
  const SalesPoint({
    required this.label,
    required this.totalSalesPaise,
    required this.billCount,
  });

  final String label;
  final int totalSalesPaise;
  final int billCount;

  factory SalesPoint.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is num ? v.round() : int.tryParse('$v') ?? 0;
    return SalesPoint(
      label: (json['label'] ?? '-').toString(),
      totalSalesPaise: asInt(json['totalSalesPaise']),
      billCount: asInt(json['billCount']),
    );
  }
}

/// A row in the top-sold-items table.
class TopSoldItem {
  const TopSoldItem({
    required this.name,
    required this.pricingType,
    required this.totalQty,
    required this.totalSalesPaise,
    this.category = 'OTHER',
  });

  final String name;

  /// 'UNIT' or 'WEIGHT' (wire values, kept as strings for display parity).
  final String pricingType;
  final num totalQty;
  final int totalSalesPaise;
  final String category;

  bool get isWeight => pricingType == 'WEIGHT';

  /// Weight items show 3 decimals, unit items show whole numbers (parity).
  String get qtyDisplay =>
      isWeight ? totalQty.toStringAsFixed(3) : totalQty.toStringAsFixed(0);

  factory TopSoldItem.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is num ? v.round() : int.tryParse('$v') ?? 0;
    num asNum(Object? v) => v is num ? v : num.tryParse('$v') ?? 0;
    return TopSoldItem(
      name: (json['name'] ?? '-').toString(),
      pricingType: json['pricingType'] == 'WEIGHT' ? 'WEIGHT' : 'UNIT',
      totalQty: asNum(json['totalQty']),
      totalSalesPaise: asInt(json['totalSalesPaise']),
      category: (json['category'] ?? 'OTHER').toString(),
    );
  }
}

/// KPI summary for the selected period.
class AnalyticsKpis {
  const AnalyticsKpis({
    this.totalSalesPaise = 0,
    this.totalBills = 0,
    this.totalDiscountPaise = 0,
    this.avgBillPaise = 0,
  });

  final int totalSalesPaise;
  final int totalBills;
  final int totalDiscountPaise;
  final int avgBillPaise;

  factory AnalyticsKpis.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is num ? v.round() : int.tryParse('$v') ?? 0;
    return AnalyticsKpis(
      totalSalesPaise: asInt(json['totalSalesPaise']),
      totalBills: asInt(json['totalBills']),
      totalDiscountPaise: asInt(json['totalDiscountPaise']),
      avgBillPaise: asInt(json['avgBillPaise']),
    );
  }
}

/// Full analytics payload for a reporting period.
class Analytics {
  const Analytics({
    required this.period,
    required this.kpis,
    required this.trend,
    required this.topSoldItems,
    required this.salesByHour,
    required this.salesByWeekday,
    required this.peakHour,
    required this.peakWeekday,
  });

  final String period;
  final AnalyticsKpis kpis;
  final List<SalesPoint> trend;
  final List<TopSoldItem> topSoldItems;
  final List<SalesPoint> salesByHour;
  final List<SalesPoint> salesByWeekday;
  final String peakHour;
  final String peakWeekday;

  factory Analytics.fromJson(Map<String, dynamic> json) {
    List<T> mapList<T>(Object? v, T Function(Map<String, dynamic>) fromJson) =>
        (v is List ? v : const [])
            .whereType<Map<String, dynamic>>()
            .map(fromJson)
            .toList();
    final insights = json['insights'];
    final insightsMap =
        insights is Map<String, dynamic> ? insights : const {};
    final kpis = json['kpis'];
    return Analytics(
      period: (json['period'] ?? 'monthly').toString(),
      kpis: AnalyticsKpis.fromJson(
          kpis is Map<String, dynamic> ? kpis : const {}),
      trend: mapList(json['trend'], SalesPoint.fromJson),
      topSoldItems: mapList(json['topSoldItems'], TopSoldItem.fromJson),
      salesByHour: mapList(json['salesByHour'], SalesPoint.fromJson),
      salesByWeekday: mapList(json['salesByWeekday'], SalesPoint.fromJson),
      peakHour: (insightsMap['peakHour'] ?? '-').toString(),
      peakWeekday: (insightsMap['peakWeekday'] ?? '-').toString(),
    );
  }
}
