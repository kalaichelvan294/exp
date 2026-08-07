import 'package:flutter/foundation.dart';

import '../../items/domain/item.dart';
import '../domain/inventory_settings.dart';

/// Immutable state for the Inventory module. Filtering mirrors
/// inventory-controller.js: the server page is fetched, then trackType and
/// low-stock thresholds are applied client-side (total = filtered count).
@immutable
class InventoryState {
  const InventoryState({
    this.settings = InventorySettings.disabled,
    this.settingsLoaded = false,
    this.items = const [],
    this.query = '',
    this.trackTypeFilter = '',
    this.qtyThreshold,
    this.weightThreshold,
    this.page = 1,
    this.pageSize = 12,
    this.total = 0,
    this.loading = false,
    this.error,
  });

  final InventorySettings settings;
  final bool settingsLoaded;

  final List<Item> items;
  final String query;

  /// '', 'quantity', or 'weight'.
  final String trackTypeFilter;
  final num? qtyThreshold;
  final num? weightThreshold;

  final int page;
  final int pageSize;
  final int total;
  final bool loading;
  final String? error;

  bool get enabled => settings.invControlEnabled;

  int get totalPages => total <= 0 ? 1 : ((total + pageSize - 1) ~/ pageSize);
  bool get canPrev => page > 1;
  bool get canNext => page < totalPages;
  bool get isEmptyResult => !loading && error == null && items.isEmpty;

  InventoryState copyWith({
    InventorySettings? settings,
    bool? settingsLoaded,
    List<Item>? items,
    String? query,
    String? trackTypeFilter,
    Object? qtyThreshold = _sentinel,
    Object? weightThreshold = _sentinel,
    int? page,
    int? pageSize,
    int? total,
    bool? loading,
    Object? error = _sentinel,
  }) {
    return InventoryState(
      settings: settings ?? this.settings,
      settingsLoaded: settingsLoaded ?? this.settingsLoaded,
      items: items ?? this.items,
      query: query ?? this.query,
      trackTypeFilter: trackTypeFilter ?? this.trackTypeFilter,
      qtyThreshold: identical(qtyThreshold, _sentinel)
          ? this.qtyThreshold
          : qtyThreshold as num?,
      weightThreshold: identical(weightThreshold, _sentinel)
          ? this.weightThreshold
          : weightThreshold as num?,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      total: total ?? this.total,
      loading: loading ?? this.loading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  static const _sentinel = Object();
}
