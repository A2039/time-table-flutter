import 'dart:convert';
import 'dart:developer' as developer;

import '../config/app_config.dart';
import '../../shared/models/api_envelope.dart';
import '../../shared/services/storage_service.dart';
import 'api_exception.dart';
import 'redirect_aware_client.dart';

/// Centralized API Client managing Google Apps Script Web App requests,
/// envelope validation, authentication, and error mapping.
class ApiClient {
  final RedirectAwareClient _httpClient;
  final StorageService? _storageService;

  ApiClient({RedirectAwareClient? httpClient, this._storageService})
    : _httpClient = httpClient ?? RedirectAwareClient();

  /// Resolve current active Base URL
  String get baseUrl => _storageService?.getBaseUrl() ?? AppConfig.apiBaseUrl;

  /// Resolve current active user API token
  Future<String> _resolveToken({String? explicitToken}) async {
    if (explicitToken != null && explicitToken.isNotEmpty) {
      return explicitToken;
    }
    if (_storageService != null) {
      final token = await _storageService.getApiToken();
      if (token.isNotEmpty) return token;
    }
    return AppConfig.defaultApiToken;
  }

  /// Construct target URI with query parameters and optional authentication token
  Uri _buildUri({
    required String action,
    Map<String, String>? queryParams,
    String? token,
  }) {
    final baseUri = Uri.parse(baseUrl);
    final mergedParams = <String, String>{
      'action': action,
      ...?queryParams,
      if (token != null && token.isNotEmpty) 'token': token,
    };

    return baseUri.replace(queryParameters: mergedParams);
  }

  /// Generic GET request with automatic envelope unpacking
  Future<T> get<T>({
    required String action,
    Map<String, String>? queryParams,
    required T Function(dynamic dataJson) fromJson,
    bool requiresAuth = true,
    String? explicitToken,
    Duration timeout = const Duration(milliseconds: AppConfig.receiveTimeoutMs),
  }) async {
    final token = requiresAuth
        ? await _resolveToken(explicitToken: explicitToken)
        : null;
    final uri = _buildUri(
      action: action,
      queryParams: queryParams,
      token: token,
    );

    try {
      final response = await _httpClient.sendWithRedirects(
        method: 'GET',
        url: uri,
        timeout: timeout,
      );

      return _processResponse<T>(response.body, response.statusCode, fromJson);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.networkError(e);
    }
  }

  /// Generic POST request with JSON payload and envelope unpacking
  Future<T> post<T>({
    required String action,
    required Map<String, dynamic> body,
    required T Function(dynamic dataJson) fromJson,
    bool requiresAuth = true,
    String? explicitToken,
    Duration timeout = const Duration(milliseconds: AppConfig.receiveTimeoutMs),
  }) async {
    final token = requiresAuth
        ? await _resolveToken(explicitToken: explicitToken)
        : null;
    final uri = _buildUri(action: action);

    final payload = Map<String, dynamic>.from(body);
    if (token != null && token.isNotEmpty) {
      payload['token'] = token;
    }

    try {
      final response = await _httpClient.sendWithRedirects(
        method: 'POST',
        url: uri,
        body: payload,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        timeout: timeout,
      );

      return _processResponse<T>(response.body, response.statusCode, fromJson);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.networkError(e);
    }
  }

  /// Process response body and decode JSON envelope
  T _processResponse<T>(
    String responseBody,
    int statusCode,
    T Function(dynamic dataJson) fromJson,
  ) {
    dynamic decoded;
    try {
      decoded = jsonDecode(responseBody);
    } catch (e) {
      developer.log(
        'JSON format error on response body: ${RedirectAwareClient.redactSecrets(responseBody)}',
        name: 'ApiClient',
        level: 900,
      );
      throw ApiException(
        message: 'Invalid response format from server. Expected JSON envelope.',
        code: 'FORMAT_ERROR',
        statusCode: statusCode,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        message: 'Invalid response envelope: expected JSON object.',
        code: 'FORMAT_ERROR',
        statusCode: statusCode,
      );
    }

    final envelope = ApiEnvelope<T>.fromJson(decoded, fromJson);

    if (!envelope.success) {
      developer.log(
        'API Error returned: code=${envelope.error?.code}, message=${envelope.message}',
        name: 'ApiClient',
        level: 900,
      );
      throw ApiException.fromEnvelope(
        message: envelope.message,
        code: envelope.error?.code,
        requestId: envelope.meta.requestId,
        details: envelope.error?.details,
        statusCode: statusCode,
      );
    }

    // Success response
    if (envelope.data != null) {
      return envelope.data!;
    }

    // Allow null/empty data when T is dynamic or nullable or void-like
    return null as T;
  }
}
