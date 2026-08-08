import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysql_client/mysql_client.dart';

import '../../../core/config/app_config.dart';
import '../../../core/logging/app_logger.dart';

/// Persistent key/value used by the admin auth flow, backed by the shared
/// `settings` table. Only the `text` and `number` types the auth flow needs are
/// exposed.
abstract class AuthSettingsStore {
  Future<String?> getText(String id);
  Future<int?> getNumber(String id);
  Future<void> setText(String id, String value);
  Future<void> setNumber(String id, int value);
}

/// Direct-to-MySQL implementation. Opens a lazy connection from
/// [AppConfig.databaseUrl] and reads/writes the `settings` table.
class MySqlAuthSettingsStore implements AuthSettingsStore {
  MySqlAuthSettingsStore({required this.config, required this.logger});

  final AppConfig config;
  final AppLogger logger;

  MySQLConnection? _connection;
  Future<MySQLConnection>? _pending;

  Future<MySQLConnection> _connect() async {
    final existing = _connection;
    if (existing != null && existing.connected) return existing;
    return _pending ??= _open();
  }

  Future<MySQLConnection> _open() async {
    try {
      final uri = Uri.parse(config.databaseUrl);
      final userInfo = uri.userInfo.split(':');

      final connection = await MySQLConnection.createConnection(
        host: uri.host.isNotEmpty ? uri.host : 'localhost',
        port: uri.hasPort ? uri.port : 3306,
        databaseName: uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'mysql',
        userName: userInfo.isNotEmpty && userInfo[0].isNotEmpty ? userInfo[0] : 'root',
        password: userInfo.length > 1 && userInfo[1].isNotEmpty ? userInfo[1] : 'MysqlRoot',
      );

      await connection.connect();

      // Ensure settings table exists
      await connection.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          id VARCHAR(255) PRIMARY KEY,
          type ENUM('text','number','boolean','json') NOT NULL,
          value TEXT NOT NULL,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
      ''');

      _connection = connection;
      return connection;
    } catch (error) {
      logger.error('MySQL connect failed', scope: 'auth', error: error);
      throw Exception('Unable to reach the database: $error');
    } finally {
      _pending = null;
    }
  }

  Future<String?> _rawValue(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) return null;
    try {
      final connection = await _connect();
      final result = await connection.execute(
        'SELECT value FROM settings WHERE id = :id LIMIT 1',
        {'id': normalized},
      );
      if (result.rows.isEmpty) return null;
      return result.rows.first.assoc()['value'];
    } catch (error) {
      throw Exception('Failed to read a setting: $error');
    }
  }

  Future<void> _setRaw(String id, String type, String value) async {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      throw Exception('Setting ID is required.');
    }
    try {
      final connection = await _connect();
      await connection.execute(
        '''
        INSERT INTO settings (id, type, value, created_at, updated_at)
        VALUES (:id, :type, :value, NOW(), NOW())
        ON DUPLICATE KEY UPDATE
          type = VALUES(type),
          value = VALUES(value),
          updated_at = NOW()
        ''',
        {'id': normalized, 'type': type, 'value': value},
      );
    } catch (error) {
      throw Exception('Failed to save a setting: $error');
    }
  }

  @override
  Future<String?> getText(String id) => _rawValue(id);

  @override
  Future<int?> getNumber(String id) async {
    final raw = await _rawValue(id);
    if (raw == null) return null;
    return int.tryParse(raw) ?? double.tryParse(raw)?.toInt();
  }

  @override
  Future<void> setText(String id, String value) => _setRaw(id, 'text', value);

  @override
  Future<void> setNumber(String id, int value) =>
      _setRaw(id, 'number', value.toString());

  Future<void> dispose() async {
    final connection = _connection;
    _connection = null;
    if (connection != null && connection.connected) {
      await connection.close();
    }
  }
}

final authSettingsStoreProvider = Provider<AuthSettingsStore>((ref) {
  final store = MySqlAuthSettingsStore(
    config: ref.watch(appConfigProvider),
    logger: ref.watch(loggerProvider),
  );
  ref.onDispose(store.dispose);
  return store;
});
