import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_exception.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/settings/domain/app_settings.dart';

/// App-wide appearance derived from persisted settings (parity with
/// appearance.js: theme mode + UI size scale).
@immutable
class AppearanceState {
  const AppearanceState({
    this.themeMode = 'light',
    this.uiSizeVariant = 'md',
  });

  final String themeMode; // 'light' | 'dark'
  final String uiSizeVariant; // xs..xxl

  bool get isDark => themeMode == 'dark';
  double get fontScale => kUiSizeScales[uiSizeVariant] ?? 1.0;

  AppearanceState copyWith({String? themeMode, String? uiSizeVariant}) {
    return AppearanceState(
      themeMode: themeMode ?? this.themeMode,
      uiSizeVariant: uiSizeVariant ?? this.uiSizeVariant,
    );
  }
}

/// Holds and refreshes the appearance used by [PosApp]. Loads persisted
/// settings on startup and is updated when the user saves appearance settings.
class AppearanceController extends Notifier<AppearanceState> {
  @override
  AppearanceState build() {
    Future.microtask(load);
    return const AppearanceState();
  }

  Future<void> load() async {
    try {
      final settings = await ref.read(settingsRepositoryProvider).loadSettings();
      state = AppearanceState(
        themeMode: settings.themeMode,
        uiSizeVariant: settings.uiSizeVariant,
      );
    } on ApiException {
      // Keep defaults when settings are unavailable (parity with the
      // appearance.js fallback to an empty settings object).
    }
  }

  void apply({required String themeMode, required String uiSizeVariant}) {
    state = state.copyWith(
      themeMode: AppSettings.normalizeThemeMode(themeMode),
      uiSizeVariant: AppSettings.normalizeUiSizeVariant(uiSizeVariant),
    );
  }
}

final appearanceControllerProvider =
    NotifierProvider<AppearanceController, AppearanceState>(
        AppearanceController.new);
