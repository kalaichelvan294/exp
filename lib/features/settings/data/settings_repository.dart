import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_providers.dart';
import '../../inventory/domain/inventory_settings.dart';
import '../domain/app_settings.dart';

/// API-bridge data source for the Settings module. Wraps `system:settings`
/// (partial-merge save), inventory settings, and brand propagation.
class SettingsRepository {
  SettingsRepository(this._api);

  final ApiClient _api;

  Future<AppSettings> loadSettings() async {
    final response = await _api.getJson(ApiEndpoints.loadSettings);
    return AppSettings.fromJson(response);
  }

  /// Persists a partial settings patch (parity with saveSettings merge).
  Future<void> saveSettings(Map<String, dynamic> patch) async {
    await _api.postJson(ApiEndpoints.saveSettings, body: patch);
  }

  Future<InventorySettings> loadInventorySettings() async {
    final response = await _api.getJson(ApiEndpoints.loadInventorySettings);
    return InventorySettings.fromJson(response);
  }

  Future<void> saveInventorySettings({required bool invControlEnabled}) async {
    await _api.postJson(
      ApiEndpoints.saveInventorySettings,
      body: {'invControlEnabled': invControlEnabled},
    );
  }

  /// Scans the catalog and returns the unique brand list (parity with
  /// propagateBrands).
  Future<List<String>> propagateBrands() async {
    final response = await _api.postJson(ApiEndpoints.propagateBrands);
    final raw = response['brands'];
    return AppSettings.normalizeBrands(raw);
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(apiClientProvider)),
);
