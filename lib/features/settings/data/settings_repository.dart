import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/db_connection.dart';
import '../../../core/database/db_providers.dart';
import '../../inventory/domain/inventory_settings.dart';
import '../domain/app_settings.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final DbConnection _db;

  Future<AppSettings> loadSettings() async {
    final result = await _db.query(
      'SELECT `key`, `value` FROM app_settings ORDER BY `key`',
    );

    final settings = <String, dynamic>{};
    for (final row in result) {
      final key = (row['key'] ?? '').toString();
      final value = row['value'];

      if (key == 'itemCategories' ||
          key == 'itemBrands' ||
          key == 'billingPaymentModes') {
        if (value is String) {
          try {
            settings[key] = value
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          } catch (_) {
            settings[key] = [];
          }
        } else if (value is List) {
          settings[key] = value;
        } else {
          settings[key] = [];
        }
      } else if (key == 'itemsWholesaleAutoApply') {
        if (value is bool) {
          settings[key] = value;
        } else {
          final str = (value ?? '').toString().trim().toLowerCase();
          if (str == 'true' || str == '1') {
            settings[key] = true;
          } else if (str == 'false' || str == '0') {
            settings[key] = false;
          } else {
            settings[key] = value;
          }
        }
      } else {
        settings[key] = value;
      }
    }

    return AppSettings.fromJson(settings);
  }

  Future<void> saveSettings(Map<String, dynamic> patch) async {
    for (final entry in patch.entries) {
      final value = entry.value is List
          ? (entry.value as List).join(',')
          : '${entry.value}';
      final escapedKey = entry.key.replaceAll("'", "''");
      final escapedValue = value.replaceAll("'", "''");

      await _db.execute(
        "INSERT INTO app_settings (`key`, `value`) VALUES ('$escapedKey', '$escapedValue') "
        "ON DUPLICATE KEY UPDATE `value` = '$escapedValue'",
      );
    }
  }

  Future<InventorySettings> loadInventorySettings() async {
    final result = await _db.query(
      'SELECT inv_control_enabled, inv_low_stock_qty, inv_low_stock_weight FROM inventory_settings LIMIT 1',
    );
    if (result.isEmpty) return InventorySettings();
    final row = result.first;
    final val = row['inv_control_enabled'];
    final isEnabled = val == 1 ||
        val == true ||
        val?.toString() == '1' ||
        val?.toString().toLowerCase() == 'true';
    return InventorySettings(
      invControlEnabled: isEnabled,
      invLowStockQty: num.tryParse(
            row['inv_low_stock_qty']?.toString() ?? '10',
          ) ??
          10,
      invLowStockWeight: num.tryParse(
            row['inv_low_stock_weight']?.toString() ?? '5.0',
          ) ??
          5.0,
    );
  }

  Future<void> saveInventorySettings({required bool invControlEnabled}) async {
    final val = invControlEnabled ? 1 : 0;
    final count = await _db.execute(
      'UPDATE inventory_settings SET inv_control_enabled = $val',
    );
    if (count == 0) {
      try {
        await _db.execute(
          'INSERT INTO inventory_settings (inv_control_enabled, inv_low_stock_qty, inv_low_stock_weight) '
          'VALUES ($val, 10.000, 5.000)',
        );
      } catch (_) {
        await _db.execute(
          'INSERT INTO inventory_settings (id, inv_control_enabled, inv_low_stock_qty, inv_low_stock_weight) '
          'VALUES (1, $val, 10.000, 5.000) '
          'ON DUPLICATE KEY UPDATE inv_control_enabled = $val',
        );
      }
    }
  }

  Future<List<String>> propagateBrands() async {
    final result = await _db.query(
      "SELECT DISTINCT UPPER(REGEXP_REPLACE(brand_name, '[^A-Z0-9 ]', '')) as brand "
      "FROM products WHERE brand_name IS NOT NULL ORDER BY brand",
    );
    final brands = result
        .map((row) => (row['brand'] ?? '').toString())
        .where((b) => b.isNotEmpty)
        .toList();

    await saveSettings({'itemBrands': brands});
    return brands;
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(dbConnectionProvider)),
);
