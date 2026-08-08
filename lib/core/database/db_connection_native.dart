import 'package:mysql_client/mysql_client.dart';

import '../config/app_config.dart';
import '../logging/app_logger.dart';
import 'db_interface.dart';

/// MySQL connection manager for Windows (native) platform.
/// Uses direct TCP socket connection to MySQL.
class DbConnectionNative implements DbInterface {
  DbConnectionNative({
    required this._config,
    required this._logger,
  })  : _connection = null;

  final AppConfig _config;
  final AppLogger _logger;
  MySQLConnection? _connection;
  Future<void>? _pendingConnect;

  /// Initialize database connection.
  @override
  Future<void> connect() async {
    final existing = _connection;
    if (existing != null && existing.connected) return;
    final pending = _pendingConnect;
    if (pending != null) return pending;

    final future = _open();
    _pendingConnect = future;
    try {
      await future;
    } finally {
      _pendingConnect = null;
    }
  }

  Future<void> _open() async {
    try {
      _logger.info('Connecting to MySQL...', scope: 'db');

      final connection = await MySQLConnection.createConnection(
        host: _config.databaseHost,
        port: _config.databasePort,
        databaseName: _config.databaseName,
        userName: _config.databaseUser,
        password: _config.databasePassword,
      );

      await connection.connect();
      _connection = connection;

      _logger.info('MySQL connection established', scope: 'db');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to connect to MySQL',
        scope: 'db',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Execute a query and return rows as maps.
  @override
  Future<List<Map<String, dynamic>>> query(String sql) async {
    await _ensureConnected();
    try {
      _logger.debug('Query: $sql', scope: 'db');
      final result = await _connection!.execute(sql);
      return result.rows.map((row) => row.assoc()).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Query failed: $sql',
        scope: 'db',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Execute a command (INSERT/UPDATE/DELETE).
  @override
  Future<int> execute(String sql) async {
    await _ensureConnected();
    try {
      _logger.debug('Execute: $sql', scope: 'db');
      final result = await _connection!.execute(sql);
      return result.affectedRows.toInt();
    } catch (e, stackTrace) {
      _logger.error(
        'Execute failed: $sql',
        scope: 'db',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Begin a transaction.
  @override
  Future<void> begin() async {
    await _ensureConnected();
    await _connection!.execute('START TRANSACTION');
  }

  /// Commit a transaction.
  @override
  Future<void> commit() async {
    await _ensureConnected();
    await _connection!.execute('COMMIT');
  }

  /// Rollback a transaction.
  @override
  Future<void> rollback() async {
    await _ensureConnected();
    await _connection!.execute('ROLLBACK');
  }

  /// Close the connection.
  @override
  Future<void> close() async {
    if (_connection != null) {
      await _connection!.close();
      _connection = null;
      _logger.info('MySQL connection closed', scope: 'db');
    }
  }

  Future<void> _ensureConnected() async {
    final conn = _connection;
    if (conn == null || !conn.connected) {
      await connect();
    }
  }
}
