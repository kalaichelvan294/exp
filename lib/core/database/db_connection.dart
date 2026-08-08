import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../logging/app_logger.dart';
import 'db_connection_native.dart';
import 'db_connection_web.dart';
import 'db_interface.dart';

/// MySQL connection manager factory.
/// Returns platform-specific implementation:
/// - Windows (native): Direct TCP connection using MySQL client
/// - Web: HTTP proxy to backend API
class DbConnection {
  DbConnection({required AppConfig config, required AppLogger logger})
    : _impl = kIsWeb
          ? DbConnectionWeb(config: config, logger: logger)
          : DbConnectionNative(config: config, logger: logger);

  final DbInterface _impl;

  /// Initialize database connection.
  Future<void> connect() => _impl.connect();

  /// Execute a query and return rows as maps.
  /// Parameters are embedded directly in the SQL string.
  Future<List<Map<String, dynamic>>> query(String sql) => _impl.query(sql);

  /// Execute a command (INSERT/UPDATE/DELETE) and return affected row count.
  /// Parameters should be embedded in the SQL string directly.
  Future<int> execute(String sql) => _impl.execute(sql);

  /// Begin a transaction.
  Future<void> begin() => _impl.begin();

  /// Commit a transaction.
  Future<void> commit() => _impl.commit();

  /// Rollback a transaction.
  Future<void> rollback() => _impl.rollback();

  /// Close the connection.
  Future<void> close() => _impl.close();
}
