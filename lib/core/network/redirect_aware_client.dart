import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';

/// HTTP Client adapter specialized in handling Google Apps Script Web App redirects,
/// enforcing strict domain allowlists, bounded redirect depth, HTML response detection,
/// and sensitive token redaction.
class RedirectAwareClient {
  final http.Client _innerClient;
  final int maxRedirects;

  RedirectAwareClient({
    http.Client? innerClient,
    this.maxRedirects = AppConfig.maxRedirects,
  }) : _innerClient = innerClient ?? http.Client();

  /// Allowed redirect host suffixes
  static const List<String> _allowedHostSuffixes = [
    'script.google.com',
    'script.googleusercontent.com',
    'google.com',
    'googleusercontent.com',
  ];

  /// Redact sensitive query parameters and headers from logs and error strings
  static String redactSecrets(String input) {
    var result = input;
    // Redact token in query string: token=XYZ -> token=***
    result = result.replaceAllMapped(
      RegExp(
        r'(token|api_token|apiToken|key|secret)=([^& \r\n]+)',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}=***REDACTED***',
    );
    // Redact Bearer tokens in headers
    result = result.replaceAllMapped(
      RegExp(r'(Bearer\s+)([A-Za-z0-9_\-\.]+)', caseSensitive: false),
      (match) => '${match.group(1)}***REDACTED***',
    );
    return result;
  }

  /// Check if the target URI host is in the allowlist
  static bool isHostAllowed(Uri uri) {
    final host = uri.host.toLowerCase();
    for (final allowed in _allowedHostSuffixes) {
      if (host == allowed || host.endsWith('.$allowed')) {
        return true;
      }
    }
    return false;
  }

  /// Execute an HTTP request following Google Apps Script redirects safely
  Future<http.Response> sendWithRedirects({
    required String method,
    required Uri url,
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(milliseconds: AppConfig.receiveTimeoutMs),
  }) async {
    Uri currentUrl = url;
    String currentMethod = method.toUpperCase();
    Object? currentBody = body;
    int redirectCount = 0;

    final baseHeaders = <String, String>{
      'Accept': 'application/json, text/plain, */*',
      ...?headers,
    };

    while (redirectCount <= maxRedirects) {
      if (AppConfig.isDevelopment) {
        developer.log(
          'HTTP $currentMethod ${redactSecrets(currentUrl.toString())} (Redirect #$redirectCount)',
          name: 'RedirectAwareClient',
        );
      }

      http.Request request = http.Request(currentMethod, currentUrl);
      request.headers.addAll(baseHeaders);

      if (currentBody != null &&
          (currentMethod == 'POST' ||
              currentMethod == 'PUT' ||
              currentMethod == 'PATCH')) {
        if (currentBody is String) {
          request.body = currentBody;
          if (!request.headers.containsKey('Content-Type')) {
            request.headers['Content-Type'] = 'text/plain;charset=utf-8';
          }
        } else if (currentBody is List<int>) {
          request.bodyBytes = currentBody;
        } else if (currentBody is Map) {
          request.body = jsonEncode(currentBody);
          if (!request.headers.containsKey('Content-Type')) {
            request.headers['Content-Type'] = 'text/plain;charset=utf-8';
          }
        }
      }

      http.StreamedResponse streamedResponse;
      try {
        final future = _innerClient.send(request);
        streamedResponse = await future.timeout(
          timeout,
          onTimeout: () => throw TimeoutException(
            'Request to ${redactSecrets(currentUrl.toString())} timed out',
          ),
        );
      } on TimeoutException {
        throw ApiException.timeout();
      } catch (e) {
        if (e is ApiException) rethrow;
        throw ApiException.networkError(e);
      }

      final statusCode = streamedResponse.statusCode;

      // Handle HTTP redirects (301, 302, 303, 307, 308)
      if (statusCode == 301 ||
          statusCode == 302 ||
          statusCode == 303 ||
          statusCode == 307 ||
          statusCode == 308) {
        final location = streamedResponse.headers['location'];
        if (location == null || location.isEmpty) {
          // No location header; return the response as is
          return await http.Response.fromStream(streamedResponse);
        }

        final targetUri = Uri.parse(location);
        final resolvedUri = currentUrl.resolveUri(targetUri);

        // Security check: Validate redirect target host
        if (!isHostAllowed(resolvedUri)) {
          developer.log(
            'Blocked redirect to untrusted host: ${resolvedUri.host}',
            name: 'RedirectAwareClient',
            level: 900,
          );
          throw ApiException.untrustedRedirect(resolvedUri.host);
        }

        redirectCount++;
        if (redirectCount > maxRedirects) {
          throw ApiException.redirectLimitExceeded(maxRedirects);
        }

        // For Apps Script: POST redirects with 302/303 to a GET on echo endpoint
        if (statusCode == 302 || statusCode == 303) {
          currentMethod = 'GET';
          currentBody = null;
          // Remove Content-Type and Content-Length on GET redirect (case-insensitive)
          baseHeaders.removeWhere(
            (k, _) =>
                k.toLowerCase() == 'content-type' ||
                k.toLowerCase() == 'content-length',
          );
        }

        currentUrl = resolvedUri;
        continue;
      }

      // Final response reached
      final response = await http.Response.fromStream(streamedResponse);

      // Inspect Content-Type: Detect unexpected HTML
      final contentType = response.headers['content-type'] ?? '';
      final bodyTrimmed = response.body.trim();

      if (contentType.toLowerCase().contains('text/html') ||
          bodyTrimmed.startsWith('<!DOCTYPE html>') ||
          bodyTrimmed.startsWith('<html') ||
          bodyTrimmed.contains('<title>Google Accounts</title>')) {
        developer.log(
          'Unexpected HTML response received from ${redactSecrets(currentUrl.toString())}',
          name: 'RedirectAwareClient',
          level: 1000,
        );
        throw ApiException.unexpectedContentType(
          contentType.isEmpty ? 'text/html' : contentType,
          preview: bodyTrimmed.length > 200
              ? bodyTrimmed.substring(0, 200)
              : bodyTrimmed,
        );
      }

      return response;
    }

    throw ApiException.redirectLimitExceeded(maxRedirects);
  }

  void close() {
    _innerClient.close();
  }
}
