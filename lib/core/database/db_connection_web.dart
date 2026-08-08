import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../logging/app_logger.dart';
import 'db_interface.dart';

/// MySQL-compatible backend API connection manager for web platform.
/// Uses HTTP requests to a backend API that proxies database queries.
///
/// Expected backend API endpoints:
/// - POST /api/db/query: Execute SELECT queries
/// - POST /api/db/execute: Execute INSERT/UPDATE/DELETE commands
/// - POST /api/db/begin: Begin transaction
/// - POST /api/db/commit: Commit transaction
/// - POST /api/db/rollback: Rollback transaction
/// 
/// For development without a backend API, set POS_DATABASE_URL to an endpoint
/// that serves a proxy API or mock responses.
class DbConnectionWeb implements DbInterface {
  DbConnectionWeb({
    required AppConfig config,
    required this._logger,
  })  : _baseUrl = _buildBaseUrl(config),
        _inTransaction = false;

  final AppLogger _logger;
  final String _baseUrl;
  bool _inTransaction;

  static String _buildBaseUrl(AppConfig config) {
    // Extract base URL from database connection string
    // For web, we assume a backend API is running at the same host on port 3000
    // Format: postgres://user:pass@host:port/database
    // Convert to: http://host:3000/api
    final host = config.databaseHost;
    // Backend API runs on port 3000, not the database port
    return 'http://$host:3000/api';
  }

  /// Initialize database connection (web validation only).
  /// On web, we assume the API will be available when actually needed.
  /// This allows the app to start even if the backend isn't ready yet.
  @override
  Future<void> connect() async {
    try {
      _logger.info('Connecting to backend API at $_baseUrl...', scope: 'db');
      
      // Try health check but don't fail if it's not available
      // This allows graceful degradation in development
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/health'),
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          _logger.info('Backend API connection established', scope: 'db');
        } else {
          _logger.warning(
            'Backend API health check returned ${response.statusCode}. Proceeding with caution.',
            scope: 'db',
          );
        }
      } on Exception catch (e) {
        // Backend API not available, but continue anyway
        // The app can still function if queries are mocked or handled gracefully
        _logger.warning(
          'Backend API not available: $e. Queries will fail if API is not available.',
          scope: 'db',
        );
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Connection initialization failed',
        scope: 'db',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Execute a query and return rows as maps via HTTP.
  @override
  Future<List<Map<String, dynamic>>> query(String sql) async {
    try {
      _logger.debug('Query (via HTTP): $sql', scope: 'db');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/db/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sql': sql}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as List<dynamic>;
        return result.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Query failed: ${response.statusCode} ${response.body}');
      }
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

  /// Execute a command via HTTP.
  @override
  Future<int> execute(String sql) async {
    try {
      _logger.debug('Execute (via HTTP): $sql', scope: 'db');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/db/execute'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sql': sql}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        return (result['affectedRows'] ?? 0) as int;
      } else {
        throw Exception('Execute failed: ${response.statusCode} ${response.body}');
      }
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

  /// Begin a transaction via HTTP.
  @override
  Future<void> begin() async {
    try {
      _logger.debug('BEGIN transaction', scope: 'db');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/db/begin'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _inTransaction = true;
      } else {
        throw Exception('BEGIN failed: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      _logger.error(
        'BEGIN failed',
        scope: 'db',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Commit a transaction via HTTP.
  @override
  Future<void> commit() async {
    try {
      _logger.debug('COMMIT transaction', scope: 'db');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/db/commit'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _inTransaction = false;
      } else {
        throw Exception('COMMIT failed: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      _logger.error(
        'COMMIT failed',
        scope: 'db',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Rollback a transaction via HTTP.
  @override
  Future<void> rollback() async {
    try {
      _logger.debug('ROLLBACK transaction', scope: 'db');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/db/rollback'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _inTransaction = false;
      } else {
        throw Exception('ROLLBACK failed: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      _logger.error(
        'ROLLBACK failed',
        scope: 'db',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Close the connection (noop for HTTP).
  @override
  Future<void> close() async {
    if (_inTransaction) {
      await rollback();
    }
    _logger.info('Backend API connection closed', scope: 'db');
  }
}
