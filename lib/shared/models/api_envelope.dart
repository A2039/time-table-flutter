/// Envelope metadata returned by every Google Apps Script API response
class ApiMeta {
  final String? requestId;
  final String? timestamp;

  const ApiMeta({this.requestId, this.timestamp});

  factory ApiMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ApiMeta();
    return ApiMeta(
      requestId: json['requestId'] as String?,
      timestamp: json['timestamp'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (requestId != null) 'requestId': requestId,
    if (timestamp != null) 'timestamp': timestamp,
  };
}

/// Error details returned in error envelopes
class ApiErrorPayload {
  final String? code;
  final List<dynamic> details;

  const ApiErrorPayload({this.code, this.details = const []});

  factory ApiErrorPayload.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ApiErrorPayload();
    return ApiErrorPayload(
      code: json['code'] as String?,
      details: (json['details'] as List<dynamic>?) ?? const [],
    );
  }
}

/// Generic API envelope wrapper for all responses
class ApiEnvelope<T> {
  final bool success;
  final String message;
  final T? data;
  final ApiErrorPayload? error;
  final ApiMeta meta;

  const ApiEnvelope({
    required this.success,
    required this.message,
    this.data,
    this.error,
    this.meta = const ApiMeta(),
  });

  factory ApiEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic dataJson) fromDataJson,
  ) {
    final success = json['success'] as bool? ?? false;
    final message =
        json['message'] as String? ?? (success ? 'Success' : 'Error');
    final meta = ApiMeta.fromJson(json['meta'] as Map<String, dynamic>?);
    final error = json['error'] != null
        ? ApiErrorPayload.fromJson(json['error'] as Map<String, dynamic>?)
        : null;

    T? parsedData;
    if (success && json['data'] != null) {
      parsedData = fromDataJson(json['data']);
    }

    return ApiEnvelope<T>(
      success: success,
      message: message,
      data: parsedData,
      error: error,
      meta: meta,
    );
  }
}
