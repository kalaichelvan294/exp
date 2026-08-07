import 'dart:async';
import 'dart:io';

import 'api_exception.dart';

/// Maps transport/HTTP failures onto the frozen [ApiErrorCode] contract so the
/// rest of the app sees a single, consistent error type.
class ErrorMapper {
  const ErrorMapper();

  ApiException fromStatus(
    int statusCode, {
    Map<String, dynamic>? body,
  }) {
    final serverMessage = _extractMessage(body);
    final details = _extractDetails(body);
    final code = _codeForStatus(statusCode);
    return ApiException(
      code: code,
      message: serverMessage,
      statusCode: statusCode,
      details: details,
    );
  }

  ApiException fromException(Object error, [StackTrace? stackTrace]) {
    if (error is ApiException) return error;
    if (error is TimeoutException) {
      return ApiException(code: ApiErrorCode.timeout, cause: error);
    }
    if (error is SocketException || error is HttpException) {
      return ApiException(code: ApiErrorCode.network, cause: error);
    }
    return ApiException(code: ApiErrorCode.unknown, cause: error);
  }

  ApiErrorCode _codeForStatus(int status) {
    if (status == 400) return ApiErrorCode.badRequest;
    if (status == 401) return ApiErrorCode.unauthorized;
    if (status == 403) return ApiErrorCode.forbidden;
    if (status == 404) return ApiErrorCode.notFound;
    if (status == 409) return ApiErrorCode.conflict;
    if (status == 422) return ApiErrorCode.validation;
    if (status >= 500) return ApiErrorCode.server;
    if (status >= 400) return ApiErrorCode.badRequest;
    return ApiErrorCode.unknown;
  }

  String? _extractMessage(Map<String, dynamic>? body) {
    if (body == null) return null;
    final value = body['message'] ?? body['error'];
    return value is String ? value : null;
  }

  Map<String, dynamic>? _extractDetails(Map<String, dynamic>? body) {
    if (body == null) return null;
    final value = body['details'] ?? body['errors'];
    return value is Map<String, dynamic> ? value : null;
  }
}
