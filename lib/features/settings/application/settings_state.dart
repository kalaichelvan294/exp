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
    this.categories = const [],
    this.brands = const [],
    this.loaded = false,
    this.message = SettingsMessage.none,
  });

  final AppSettings settings;
  final bool invControlEnabled;
  final bool cleanupTrainingImagesAfterEmbedding;

  /// Working copies (user edits before saving item config).
  final List<String> categories;
  final List<String> brands;

  final bool loaded;
  final SettingsMessage message;

  SettingsState copyWith({
    AppSettings? settings,
    bool? invControlEnabled,
    bool? cleanupTrainingImagesAfterEmbedding,
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
      categories: categories ?? this.categories,
      brands: brands ?? this.brands,
      loaded: loaded ?? this.loaded,
      message: message ?? this.message,
    );
  }
}
