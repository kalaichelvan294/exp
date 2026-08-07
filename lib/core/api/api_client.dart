// ignore_for_file: prefer_initializing_formals
//
// Named parameters cannot be private (`this._field`), so initializing formals
// cannot be used here while keeping the fields private.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../logging/app_logger.dart';
import 'api_exception.dart';
import 'error_mapper.dart';

/// Typed HTTP client for the API bridge.
///
/// Responsibilities:
///  - Build absolute URLs from [AppConfig.apiBaseUrl].
///  - Serialize/deserialize JSON.
///  - Normalize all failures into [ApiException] via [ErrorMapper].
///  - Emit diagnostics through [AppLogger].
class ApiClient {
  ApiClient({
    required AppConfig config,
    required AppLogger logger,
    http.Client? httpClient,
    ErrorMapper errorMapper = const ErrorMapper(),
  })  : _config = config,
        _logger = logger,
        _http = httpClient ?? http.Client(),
        _errorMapper = errorMapper;

  final AppConfig _config;
  final AppLogger _logger;
  final http.Client _http;
  final ErrorMapper _errorMapper;

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) =>
      _send('GET', path, query: query);

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) =>
      _send('POST', path, body: body, query: query);

  Future<Map<String, dynamic>> putJson(
    String path, {
    Object? body,
  }) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Object? body,
  }) =>
      _send('DELETE', path, body: body);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final uri = _buildUri(path, query);
    _logger.debug('$method $uri', scope: 'api');
    try {
      final request = http.Request(method, uri)..headers.addAll(_jsonHeaders);
      if (body != null) {
        request.body = jsonEncode(body);
      }
      final streamed = await _http.send(request).timeout(_config.apiTimeout);
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } catch (error, stackTrace) {
      final mapped = _errorMapper.fromException(error, stackTrace);
      _logger.error(
        'Request failed: $method $path',
        scope: 'api',
        error: mapped,
        stackTrace: stackTrace,
      );
      throw mapped;
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final decoded = _decodeBody(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? const {};
    }
    throw _errorMapper.fromStatus(response.statusCode, body: decoded);
  }

  Map<String, dynamic>? _decodeBody(String body) {
    if (body.isEmpty) return null;
    try {
      final value = jsonDecode(body);
      if (value is Map<String, dynamic>) return value;
      return {'data': value};
    } on FormatException {
      return {'message': body};
    }
  }

  Uri _buildUri(String path, Map<String, dynamic>? query) {
    final base = Uri.parse(_config.apiBaseUrl);
    final normalizedPath =
        path.startsWith('/') ? '${base.path}$path' : '${base.path}/$path';
    return base.replace(
      path: normalizedPath,
      queryParameters: query?.map((k, v) => MapEntry(k, '$v')),
    );
  }

  void dispose() => _http.close();
}
