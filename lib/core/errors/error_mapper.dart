import '../network/api_exception.dart';

/// User-friendly error message mapper converting technical exceptions
/// into actionable guidance for UI presentation.
class ErrorMapper {
  ErrorMapper._();

  static String toUserMessage(dynamic error) {
    if (error is ApiException) {
      if (error.code != null) {
        switch (error.code) {
          case 'UNAUTHORIZED':
            return 'Authentication required. Your API token is invalid or missing. Please check your token in Settings.';
          case 'FORBIDDEN':
            return 'Access denied. You do not have permission for this operation.';
          case 'VALIDATION_ERROR':
            final detailMsg = error.details != null && error.details!.isNotEmpty
                ? ': ${error.details!.join(', ')}'
                : '';
            return 'Validation error${error.message.isNotEmpty ? ': ${error.message}' : detailMsg}.';
          case 'INVALID_DATE':
            return 'Invalid date specified. Please select a valid date in YYYY-MM-DD format.';
          case 'INVALID_ACTIVITY':
            return 'Invalid activity number selected.';
          case 'INVALID_STATUS':
            return 'Unsupported status value. Must be on-time ("y"), not completed ("n"), or positive late minutes.';
          case 'LOCK_TIMEOUT':
            return 'Spreadsheet is temporarily locked by another update. Please retry your save in a moment.';
          case 'SERVER_MISCONFIGURED':
            return 'Server setup error: Google Apps Script Properties are misconfigured. Please check backend settings.';
          case 'INTERNAL_ERROR':
            final req = error.requestId != null
                ? ' (Req: ${error.requestId})'
                : '';
            return 'Server internal error. Please try again later$req.';
          case 'UNEXPECTED_CONTENT_TYPE':
            return error.message;
          case 'REDIRECT_LIMIT_EXCEEDED':
            return 'Too many redirects occurred while contacting the server.';
          case 'UNTRUSTED_REDIRECT':
            return 'Security warning: Redirect to an untrusted external host was blocked.';
          case 'TIMEOUT':
            return 'The request timed out. Please check your connection and try again.';
          case 'NETWORK_ERROR':
            return 'Cannot reach the server. Please verify your internet connection.';
          default:
            return error.message.isNotEmpty
                ? error.message
                : 'An unexpected error occurred.';
        }
      }
      return error.message;
    }

    if (error is TimeoutException) {
      return 'Request timed out. Please check your connection.';
    }

    return 'An unexpected error occurred: ${error.toString()}';
  }

  /// Suggest whether user should be shown a retry button
  static bool isRetryable(dynamic error) {
    if (error is ApiException) {
      return error.isRetryable ||
          error.code == 'TIMEOUT' ||
          error.code == 'NETWORK_ERROR' ||
          error.code == 'LOCK_TIMEOUT';
    }
    return error is TimeoutException;
  }
}
