import 'api_exception.dart';

/// Sealed result wrapper for API responses
sealed class ApiResult<T> {
  const ApiResult();

  factory ApiResult.success(T data) = ApiSuccess<T>;
  factory ApiResult.failure(ApiException exception) = ApiFailure<T>;

  bool get isSuccess => this is ApiSuccess<T>;
  bool get isFailure => this is ApiFailure<T>;

  T? get dataOrNull => switch (this) {
    ApiSuccess<T>(data: final data) => data,
    ApiFailure<T>() => null,
  };

  ApiException? get errorOrNull => switch (this) {
    ApiSuccess<T>() => null,
    ApiFailure<T>(exception: final exception) => exception,
  };

  R when<R>({
    required R Function(T data) success,
    required R Function(ApiException error) failure,
  }) {
    return switch (this) {
      ApiSuccess<T>(data: final data) => success(data),
      ApiFailure<T>(exception: final exception) => failure(exception),
    };
  }

  ApiResult<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      ApiSuccess<T>(data: final data) => ApiSuccess<R>(transform(data)),
      ApiFailure<T>(exception: final exception) => ApiFailure<R>(exception),
    };
  }
}

class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  const ApiSuccess(this.data);

  @override
  String toString() => 'ApiSuccess($data)';
}

class ApiFailure<T> extends ApiResult<T> {
  final ApiException exception;
  const ApiFailure(this.exception);

  @override
  String toString() => 'ApiFailure($exception)';
}
