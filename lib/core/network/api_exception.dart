/// Typed domain exception hierarchy for the Time Table API
class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final String? requestId;
  final List<dynamic>? details;
  final dynamic originalError;

  const ApiException({
    required this.message,
    this.code,
    this.statusCode,
    this.requestId,
    this.details,
    this.originalError,
  });

  bool get isUnauthorized => code == 'UNAUTHORIZED' || statusCode == 401;
  bool get isForbidden => code == 'FORBIDDEN' || statusCode == 403;
  bool get isValidationError =>
      code == 'VALIDATION_ERROR' ||
      code == 'INVALID_DATE' ||
      code == 'INVALID_ACTIVITY' ||
      code == 'INVALID_STATUS';
  bool get isLockTimeout => code == 'LOCK_TIMEOUT';
  bool get isServerMisconfigured => code == 'SERVER_MISCONFIGURED';
  bool get isRetryable => isLockTimeout || originalError is TimeoutException;

  @override
  String toString() {
    final buffer = StringBuffer('ApiException: $message');
    if (code != null) buffer.write(' (Code: $code)');
    if (statusCode != null) buffer.write(' [Status: $statusCode]');
    if (requestId != null) buffer.write(' {ReqId: $requestId}');
    return buffer.toString();
  }

  factory ApiException.networkError(dynamic err) {
    return ApiException(
      message:
          'Network connection failed. Please check your internet connection.',
      code: 'NETWORK_ERROR',
      originalError: err,
    );
  }

  factory ApiException.timeout() {
    return const ApiException(
      message: 'The request timed out. Please try again.',
      code: 'TIMEOUT',
    );
  }

  factory ApiException.unexpectedContentType(
    String contentType, {
    String? preview,
  }) {
    final previewMsg = preview != null && preview.isNotEmpty
        ? ' Content preview: ${preview.length > 100 ? '${preview.substring(0, 100)}...' : preview}'
        : '';
    return ApiException(
      message:
          'Received HTML/unexpected response instead of JSON ($contentType). '
          'This usually indicates a Google Sign-in prompt, an incorrect Web App deployment URL, '
          'or insufficient deployment permissions (must be "Execute as me" and "Anyone has access").$previewMsg',
      code: 'UNEXPECTED_CONTENT_TYPE',
    );
  }

  factory ApiException.redirectLimitExceeded(int maxRedirects) {
    return ApiException(
      message: 'Redirect limit exceeded ($maxRedirects redirects).',
      code: 'REDIRECT_LIMIT_EXCEEDED',
    );
  }

  factory ApiException.untrustedRedirect(String url) {
    return ApiException(
      message: 'Redirect blocked to untrusted domain.',
      code: 'UNTRUSTED_REDIRECT',
    );
  }

  factory ApiException.fromEnvelope({
    required String message,
    String? code,
    String? requestId,
    List<dynamic>? details,
    int? statusCode,
  }) {
    return ApiException(
      message: message,
      code: code ?? 'API_ERROR',
      requestId: requestId,
      details: details,
      statusCode: statusCode,
    );
  }
}

class TimeoutException implements Exception {
  final String message;
  const TimeoutException([this.message = 'Operation timed out']);
  @override
  String toString() => 'TimeoutException: $message';
}
