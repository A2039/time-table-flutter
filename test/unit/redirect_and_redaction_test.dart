import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timetable/core/network/api_exception.dart';
import 'package:timetable/core/network/redirect_aware_client.dart';

void main() {
  group('RedirectAwareClient & Secret Redaction Tests', () {
    test('redactSecrets sanitizes token in query parameter', () {
      const url =
          'https://script.google.com/macros/s/xyz/exec?action=getToday&token=secret_user_token_12345';
      final redacted = RedirectAwareClient.redactSecrets(url);
      expect(redacted, isNot(contains('secret_user_token_12345')));
      expect(redacted, contains('token=***REDACTED***'));
    });

    test('redactSecrets sanitizes Bearer token headers', () {
      const header = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.secret';
      final redacted = RedirectAwareClient.redactSecrets(header);
      expect(redacted, isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')));
      expect(redacted, contains('Bearer ***REDACTED***'));
    });

    test('isHostAllowed permits google script domains and blocks third-party hosts', () {
      expect(
        RedirectAwareClient.isHostAllowed(
          Uri.parse('https://script.google.com/macros/s/123/exec'),
        ),
        isTrue,
      );
      expect(
        RedirectAwareClient.isHostAllowed(
          Uri.parse('https://script.googleusercontent.com/macros/echo'),
        ),
        isTrue,
      );
      expect(
        RedirectAwareClient.isHostAllowed(
          Uri.parse('https://evil-phishing-site.com/steal?token=123'),
        ),
        isFalse,
      );
    });

    test(
      'throws unexpectedContentType when response is HTML Google login prompt',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            '<!DOCTYPE html><html><head><title>Google Accounts</title></head><body>Sign In</body></html>',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        });

        final client = RedirectAwareClient(innerClient: mockClient);

        expect(
          () => client.sendWithRedirects(
            method: 'GET',
            url: Uri.parse(
              'https://script.google.com/macros/s/xyz/exec?action=health',
            ),
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'UNEXPECTED_CONTENT_TYPE',
            ),
          ),
        );
      },
    );

    test('follows 302 redirect from Google Apps Script correctly', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          // First response: 302 redirect to echo URL
          return http.Response(
            '',
            302,
            headers: {
              'location': 'https://script.googleusercontent.com/macros/echo?user_content_key=abc',
            },
          );
        } else {
          // Second response: actual JSON payload
          return http.Response(
            '{"success":true,"message":"OK","data":{"status":"ok"},"meta":{}}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
      });

      final client = RedirectAwareClient(innerClient: mockClient);
      final response = await client.sendWithRedirects(
        method: 'POST',
        url: Uri.parse(
          'https://script.google.com/macros/s/xyz/exec?action=saveStatus',
        ),
        body: {'date': '2026-10-23'},
      );

      expect(requestCount, 2);
      expect(response.statusCode, 200);
      expect(response.body, contains('"status":"ok"'));
    });

    test(
      'throws untrustedRedirect when redirect points outside Google allowlist',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            '',
            302,
            headers: {
              'location': 'https://malicious-external-domain.com/collect',
            },
          );
        });

        final client = RedirectAwareClient(innerClient: mockClient);

        expect(
          () => client.sendWithRedirects(
            method: 'GET',
            url: Uri.parse('https://script.google.com/macros/s/xyz/exec'),
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'UNTRUSTED_REDIRECT',
            ),
          ),
        );
      },
    );
  });
}
