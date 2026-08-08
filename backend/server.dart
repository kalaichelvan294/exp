/// Simple REST API backend that proxies database queries to MySQL.
///
/// Usage:
/// ```
/// dart run backend/server.dart --db-host localhost --db-port 3306 --db-name pos294 --db-user root --db-password MysqlRoot --port 3000
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mysql_client/mysql_client.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

late MySQLConnection _dbConnection;

Future<void> main(List<String> args) async {
  final dbHost = _extractArg(args, '--db-host') ?? 'localhost';
  final dbPort = int.tryParse(_extractArg(args, '--db-port') ?? '3306') ?? 3306;
  final dbName = _extractArg(args, '--db-name') ?? 'pos294';
  final dbUser = _extractArg(args, '--db-user') ?? 'root';
  final dbPassword = _extractArg(args, '--db-password') ?? 'MysqlRoot';
  final port = int.tryParse(_extractArg(args, '--port') ?? '3000') ?? 3000;

  print('Connecting to MySQL at $dbHost:$dbPort/$dbName...');
  try {
    _dbConnection = await MySQLConnection.createConnection(
      host: dbHost,
      port: dbPort,
      databaseName: dbName,
      userName: dbUser,
      password: dbPassword,
    );
    await _dbConnection.connect();
    print('✓ Connected to MySQL');
  } catch (e) {
    print('✗ Failed to connect to MySQL: $e');
    exit(1);
  }

  // Create handler pipeline
  final handler = const Pipeline()
    .addMiddleware(logRequests())
    .addMiddleware(_corsMiddleware)
    .addHandler(_routeHandler);

  // Start server
  final server = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    port,
  );

  print('✓ Server listening on http://0.0.0.0:$port');
  print('✓ Database API available at http://0.0.0.0:$port/api/db/*');
}

// CORS middleware
Middleware _corsMiddleware = (Handler innerHandler) {
  return (Request request) async {
    if (request.method == 'OPTIONS') {
      return Response.ok(null, headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      });
    }

    final response = await innerHandler(request);
    return response.change(headers: {
      'Access-Control-Allow-Origin': '*',
    });
  };
};

// Route handler
FutureOr<Response> _routeHandler(Request request) async {
  final path = request.url.path;

  if (path == 'api/health') {
    return _handleHealth(request);
  } else if (path == 'api/db/query') {
    return await _handleQuery(request);
  } else if (path == 'api/db/execute') {
    return await _handleExecute(request);
  } else if (path == 'api/db/begin') {
    return await _handleBegin(request);
  } else if (path == 'api/db/commit') {
    return await _handleCommit(request);
  } else if (path == 'api/db/rollback') {
    return await _handleRollback(request);
  } else {
    return Response.notFound('Endpoint not found: $path');
  }
}

Response _handleHealth(Request request) {
  return Response.ok(
    jsonEncode({'status': 'ok'}),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<Response> _handleQuery(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final sql = json['sql'] as String?;

    if (sql == null || sql.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'SQL query required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final result = await _dbConnection.execute(sql);
    final rows = result.rows.map((row) => row.assoc()).toList();

    return Response.ok(
      jsonEncode(rows),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

Future<Response> _handleExecute(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final sql = json['sql'] as String?;

    if (sql == null || sql.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'SQL command required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final result = await _dbConnection.execute(sql);

    return Response.ok(
      jsonEncode({'affectedRows': result.affectedRows}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

Future<Response> _handleBegin(Request request) async {
  try {
    await _dbConnection.execute('START TRANSACTION');
    return Response.ok(
      jsonEncode({'status': 'ok'}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

Future<Response> _handleCommit(Request request) async {
  try {
    await _dbConnection.execute('COMMIT');
    return Response.ok(
      jsonEncode({'status': 'ok'}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

Future<Response> _handleRollback(Request request) async {
  try {
    await _dbConnection.execute('ROLLBACK');
    return Response.ok(
      jsonEncode({'status': 'ok'}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

String? _extractArg(List<String> args, String name) {
  for (int i = 0; i < args.length - 1; i++) {
    if (args[i] == name) {
      return args[i + 1];
    }
  }
  return null;
}
