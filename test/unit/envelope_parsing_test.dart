import 'package:flutter_test/flutter_test.dart';
import 'package:timetable_app/core/network/api_exception.dart';
import 'package:timetable_app/shared/models/api_envelope.dart';

void main() {
  group('ApiEnvelope Parsing Tests', () {
    test('parses success envelope correctly with data and meta', () {
      final json = {
        'success': true,
        'message': 'Request completed successfully',
        'data': {'key': 'value', 'count': 42},
        'meta': {
          'requestId': 'req-abc-123',
          'timestamp': '2026-10-23T14:30:00Z',
        },
      };

      final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
        json,
        (data) => data as Map<String, dynamic>,
      );

      expect(envelope.success, isTrue);
      expect(envelope.message, 'Request completed successfully');
      expect(envelope.data?['key'], 'value');
      expect(envelope.data?['count'], 42);
      expect(envelope.meta.requestId, 'req-abc-123');
      expect(envelope.meta.timestamp, '2026-10-23T14:30:00Z');
      expect(envelope.error, isNull);
    });

    test('parses error envelope correctly with code and details', () {
      final json = {
        'success': false,
        'message': 'Validation failed for one or more fields.',
        'error': {
          'code': 'VALIDATION_ERROR',
          'details': [
            'Field "date" is required',
            'Field "statuses" must be an object',
          ],
        },
        'meta': {
          'requestId': 'req-err-456',
          'timestamp': '2026-10-23T14:30:05Z',
        },
      };

      final envelope = ApiEnvelope<dynamic>.fromJson(json, (data) => data);

      expect(envelope.success, isFalse);
      expect(envelope.message, 'Validation failed for one or more fields.');
      expect(envelope.data, isNull);
      expect(envelope.error?.code, 'VALIDATION_ERROR');
      expect(envelope.error?.details.length, 2);
      expect(envelope.error?.details[0], 'Field "date" is required');
      expect(envelope.meta.requestId, 'req-err-456');
    });

    test('handles absent meta and error gracefully', () {
      final json = {'success': true, 'message': 'OK', 'data': 'simple string'};

      final envelope = ApiEnvelope<String>.fromJson(
        json,
        (data) => data.toString(),
      );

      expect(envelope.success, isTrue);
      expect(envelope.data, 'simple string');
      expect(envelope.meta.requestId, isNull);
      expect(envelope.error, isNull);
    });

    test('ApiException handles error codes and retry flags properly', () {
      const lockError = ApiException(
        message: 'Could not obtain lock',
        code: 'LOCK_TIMEOUT',
      );
      expect(lockError.isLockTimeout, isTrue);
      expect(lockError.isRetryable, isTrue);

      const unauthError = ApiException(
        message: 'Invalid token',
        code: 'UNAUTHORIZED',
      );
      expect(unauthError.isUnauthorized, isTrue);
      expect(unauthError.isRetryable, isFalse);

      const forbiddenError = ApiException(
        message: 'Admin only',
        code: 'FORBIDDEN',
      );
      expect(forbiddenError.isForbidden, isTrue);
    });
  });
}
