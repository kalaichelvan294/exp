/// Stable, user-safe error codes for the API bridge contract.
///
/// These mirror the semantics the Electron renderer relied on so error
/// messaging stays consistent after migration. Codes are frozen (Phase 0).
enum ApiErrorCode {
  network,
  timeout,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  validation,
  server,
  unknown,
}

extension ApiErrorCodeX on ApiErrorCode {
  /// Default user-safe message. Feature code may override with a more specific
  /// message where the contract defines one.
  String get userMessage {
    switch (this) {
      case ApiErrorCode.network:
        return 'Unable to reach the server. Check the connection and retry.';
      case ApiErrorCode.timeout:
        return 'The request took too long. Please try again.';
      case ApiErrorCode.badRequest:
        return 'The request could not be processed.';
      case ApiErrorCode.unauthorized:
        return 'You are not authorized to perform this action.';
      case ApiErrorCode.forbidden:
        return 'This action is not permitted.';
      case ApiErrorCode.notFound:
        return 'The requested record was not found.';
      case ApiErrorCode.conflict:
        return 'This change conflicts with the current data.';
      case ApiErrorCode.validation:
        return 'Some fields need attention before you can continue.';
      case ApiErrorCode.server:
        return 'Something went wrong on the server. Please try again.';
      case ApiErrorCode.unknown:
        return 'An unexpected error occurred.';
    }
  }
}

/// Exception raised by the API client / mapped by [ErrorMapper].
class ApiException implements Exception {
  ApiException({
    required this.code,
    String? message,
    this.statusCode,
    this.details,
    this.cause,
  }) : message = message ?? code.userMessage;

  final ApiErrorCode code;
  final String message;
  final int? statusCode;

  /// Field-level validation details, keyed by field name where available.
  final Map<String, dynamic>? details;
  final Object? cause;

  @override
  String toString() =>
      'ApiException(${code.name}, status: $statusCode, message: $message)';
}
