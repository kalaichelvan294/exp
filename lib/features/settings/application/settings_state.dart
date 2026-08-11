import 'package:flutter/foundation.dart';

import '../domain/app_settings.dart';

enum SettingsMessageType { info, success, error }

@immutable
class SettingsMessage {
  const SettingsMessage(this.text, this.type);
  final String text;
  final SettingsMessageType type;

  static const none = SettingsMessage('', SettingsMessageType.info);

  bool get isEmpty => text.isEmpty;
  bool get isError => type == SettingsMessageType.error;
  bool get isSuccess => type == SettingsMessageType.success;
}

/// Immutable state for the Settings page. Holds the loaded settings plus working
/// copies of the editable category/brand lists (applied on save).
@immutable
class SettingsState {
  const SettingsState({
    this.settings = const AppSettings(),
    this.invControlEnabled = false,
    this.cleanupTrainingImagesAfterEmbedding = false,
    this.embeddingRefreshRunning = false,
    this.embeddingRefreshDialogVisible = false,
    this.embeddingTotalProducts = 0,
    this.embeddingProcessedProducts = 0,
    this.embeddingProductsIndexed = 0,
    this.embeddingImagesIndexed = 0,
    this.embeddingProductsSkipped = 0,
    this.embeddingBarcodeUpdates = 0,
    this.embeddingCurrentSku = '',
    this.embeddingCurrentStage = '',
    this.embeddingResult = '',
    this.categories = const [],
    this.brands = const [],
    this.loaded = false,
    this.message = SettingsMessage.none,
  });

  final AppSettings settings;
  final bool invControlEnabled;
  final bool cleanupTrainingImagesAfterEmbedding;
  final bool embeddingRefreshRunning;
  final bool embeddingRefreshDialogVisible;
  final int embeddingTotalProducts;
  final int embeddingProcessedProducts;
  final int embeddingProductsIndexed;
  final int embeddingImagesIndexed;
  final int embeddingProductsSkipped;
  final int embeddingBarcodeUpdates;
  final String embeddingCurrentSku;
  final String embeddingCurrentStage;
  final String embeddingResult;

  /// Working copies (user edits before saving item config).
  final List<String> categories;
  final List<String> brands;

  final bool loaded;
  final SettingsMessage message;

  SettingsState copyWith({
    AppSettings? settings,
    bool? invControlEnabled,
    bool? cleanupTrainingImagesAfterEmbedding,
    bool? embeddingRefreshRunning,
    bool? embeddingRefreshDialogVisible,
    int? embeddingTotalProducts,
    int? embeddingProcessedProducts,
    int? embeddingProductsIndexed,
    int? embeddingImagesIndexed,
    int? embeddingProductsSkipped,
    int? embeddingBarcodeUpdates,
    String? embeddingCurrentSku,
    String? embeddingCurrentStage,
    String? embeddingResult,
    List<String>? categories,
    List<String>? brands,
    bool? loaded,
    SettingsMessage? message,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      invControlEnabled: invControlEnabled ?? this.invControlEnabled,
      cleanupTrainingImagesAfterEmbedding:
          cleanupTrainingImagesAfterEmbedding ??
          this.cleanupTrainingImagesAfterEmbedding,
      embeddingRefreshRunning:
          embeddingRefreshRunning ?? this.embeddingRefreshRunning,
      embeddingRefreshDialogVisible:
          embeddingRefreshDialogVisible ?? this.embeddingRefreshDialogVisible,
      embeddingTotalProducts:
          embeddingTotalProducts ?? this.embeddingTotalProducts,
      embeddingProcessedProducts:
          embeddingProcessedProducts ?? this.embeddingProcessedProducts,
      embeddingProductsIndexed:
          embeddingProductsIndexed ?? this.embeddingProductsIndexed,
      embeddingImagesIndexed:
          embeddingImagesIndexed ?? this.embeddingImagesIndexed,
      embeddingProductsSkipped:
          embeddingProductsSkipped ?? this.embeddingProductsSkipped,
      embeddingBarcodeUpdates:
          embeddingBarcodeUpdates ?? this.embeddingBarcodeUpdates,
      embeddingCurrentSku: embeddingCurrentSku ?? this.embeddingCurrentSku,
      embeddingCurrentStage:
          embeddingCurrentStage ?? this.embeddingCurrentStage,
      embeddingResult: embeddingResult ?? this.embeddingResult,
      categories: categories ?? this.categories,
      brands: brands ?? this.brands,
      loaded: loaded ?? this.loaded,
      message: message ?? this.message,
    );
  }
}
