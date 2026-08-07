import 'package:flutter/foundation.dart';

import '../domain/item.dart';
import '../domain/item_form.dart';

/// A transient status message shown on the Items page.
@immutable
class ItemsMessage {
  const ItemsMessage(this.text, {this.isError = false});
  final String text;
  final bool isError;
  static const empty = ItemsMessage('');
}

/// Immutable state for the Items module (list + form/SKU validation).
@immutable
class ItemsState {
  const ItemsState({
    this.items = const [],
    this.query = '',
    this.page = 1,
    this.pageSize = 12,
    this.total = 0,
    this.loading = false,
    this.categories = const [],
    this.brands = const [],
    this.skuValidation = SkuValidation.requiredSku,
    this.skuChecking = false,
    this.submitting = false,
    this.message = ItemsMessage.empty,
  });

  final List<Item> items;
  final String query;
  final int page;
  final int pageSize;
  final int total;
  final bool loading;

  final List<String> categories;
  final List<String> brands;

  final SkuValidation skuValidation;
  final bool skuChecking;
  final bool submitting;
  final ItemsMessage message;

  int get totalPages => total <= 0 ? 1 : ((total + pageSize - 1) ~/ pageSize);
  bool get canPrev => page > 1;
  bool get canNext => page < totalPages;
  bool get isEmptyResult => !loading && items.isEmpty;

  ItemsState copyWith({
    List<Item>? items,
    String? query,
    int? page,
    int? pageSize,
    int? total,
    bool? loading,
    List<String>? categories,
    List<String>? brands,
    SkuValidation? skuValidation,
    bool? skuChecking,
    bool? submitting,
    ItemsMessage? message,
  }) {
    return ItemsState(
      items: items ?? this.items,
      query: query ?? this.query,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      total: total ?? this.total,
      loading: loading ?? this.loading,
      categories: categories ?? this.categories,
      brands: brands ?? this.brands,
      skuValidation: skuValidation ?? this.skuValidation,
      skuChecking: skuChecking ?? this.skuChecking,
      submitting: submitting ?? this.submitting,
      message: message ?? this.message,
    );
  }
}
