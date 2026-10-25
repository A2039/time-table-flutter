import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timetable/core/network/api_client.dart';
import 'package:timetable/core/network/redirect_aware_client.dart';
import 'package:timetable/features/daily_status/data/status_repository.dart';
import 'package:timetable/features/dashboard/data/dashboard_repository.dart';
import 'package:timetable/features/history/data/history_repository.dart';
import 'package:timetable/features/settings/data/health_repository.dart';
import 'package:timetable/features/timetable/data/timetable_repository.dart';

void main() {
  group('Repository End-to-End Mock Client Tests', () {
    test(
      'TimetableRepository.getToday returns parsed today timetable and status',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.queryParameters['action'], 'getToday');

          final payload = {
            'success': true,
            'message': 'Success',
            'data': {
              'date': '2026-10-23',
              'dayType': 'weekday',
              'timetable': [
                {
                  'srno': 1,
                  'category': 'Physical',
                  'time': '06:00 - 07:00',
                  'duration': '60 min',
                  'timePeriod': 'Morning Yoga',
                  'description': 'Daily practice',
                },
              ],
              'status': {
                'exists': true,
                'date': '2026-10-23',
                'dayType': 'weekday',
                'statuses': {'1': 'y'},
                'remark': 'Energized morning',
              },
            },
            'meta': {'requestId': 'req-today-1'},
          };

          return http.Response(
            jsonEncode(payload),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final apiClient = ApiClient(
          httpClient: RedirectAwareClient(innerClient: mockClient),
        );
        final repo = TimetableRepository(apiClient);

        final result = await repo.getToday();
        expect(result.date, '2026-10-23');
        expect(result.timetable.length, 1);
        expect(result.timetable.first.title, 'Morning Yoga');
        expect(result.status.isOnTime(1), isTrue);
        expect(result.status.remark, 'Energized morning');
      },
    );

    test('StatusRepository.updateActivity posts payload and returns updated DailyStatus', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['action'], 'updateActivity');
        expect(request.method, 'POST');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['date'], '2026-10-23');
        expect(body['activityNo'], 2);
        expect(body['status'], 15);

        final payload = {
          'success': true,
          'message': 'Activity updated',
          'data': {
            'exists': true,
            'date': '2026-10-23',
            'dayType': 'weekday',
            'statuses': {'1': 'y', '2': 15},
            'remark': '',
          },
          'meta': {'requestId': 'req-update-2'},
        };

        return http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        httpClient: RedirectAwareClient(innerClient: mockClient),
      );
      final repo = StatusRepository(apiClient);

      final result = await repo.updateActivity(
        date: '2026-10-23',
        activityNo: 2,
        status: 15,
      );

      expect(result.isLate(2), isTrue);
      expect(result.getLateMinutes(2), 15);
    });

    test('StatusRepository.updateRemark posts remark only', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['action'], 'updateRemark');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['remark'], 'Completed evening meditation peacefully.');

        final payload = {
          'success': true,
          'message': 'Remark saved',
          'data': {
            'exists': true,
            'date': '2026-10-23',
            'dayType': 'weekday',
            'statuses': {},
            'remark': 'Completed evening meditation peacefully.',
          },
          'meta': {},
        };
        return http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        httpClient: RedirectAwareClient(innerClient: mockClient),
      );
      final repo = StatusRepository(apiClient);

      final result = await repo.updateRemark(
        date: '2026-10-23',
        remark: 'Completed evening meditation peacefully.',
      );

      expect(result.remark, 'Completed evening meditation peacefully.');
    });

    test(
      'DashboardRepository.getDashboard returns metrics and activities',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.queryParameters['action'], 'getDashboard');
          expect(request.url.queryParameters['date'], '2026-10-23');

          final payload = {
            'success': true,
            'message': 'Dashboard loaded',
            'data': {
              'date': '2026-10-23',
              'dayType': 'weekday',
              'hasSavedStatus': true,
              'metrics': {
                'totalActivities': 5,
                'completedOnTime': 3,
                'completedLate': 1,
                'notCompleted': 1,
                'notRecorded': 0,
                'totalLateMinutes': 10,
                'completionPercentage': 80.0,
                'recordedPercentage': 100.0,
              },
              'remark': 'Solid productive day',
              'activities': [
                {
                  'srno': 1,
                  'category': 'Work',
                  'time': '09:00 - 10:00',
                  'timePeriod': 'Standup & Planning',
                  'description': 'Daily coordination',
                  'status': 'y',
                  'statusLabel': 'Completed On Time',
                },
              ],
            },
            'meta': {},
          };

          return http.Response(
            jsonEncode(payload),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final apiClient = ApiClient(
          httpClient: RedirectAwareClient(innerClient: mockClient),
        );
        final repo = DashboardRepository(apiClient);

        final dashboard = await repo.getDashboard('2026-10-23');
        expect(dashboard.hasSavedStatus, isTrue);
        expect(dashboard.metrics.completionPercentage, 80.0);
        expect(dashboard.activities.first.statusLabel, 'Completed On Time');
      },
    );

    test('HistoryRepository.getHistory queries range and returns paginated records', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['action'], 'getHistory');
        expect(request.url.queryParameters['from'], '2026-10-01');
        expect(request.url.queryParameters['to'], '2026-10-23');
        expect(request.url.queryParameters['page'], '1');

        final payload = {
          'success': true,
          'message': 'History retrieved',
          'data': {
            'records': [
              {
                'date': '2026-10-22',
                'dayType': 'weekday',
                'statuses': {'1': 'y'},
                'remark': 'All tasks done',
                'completedOnTime': 1,
                'completionPercentage': 100.0,
              },
            ],
            'pagination': {
              'totalRecords': 1,
              'totalPages': 1,
              'currentPage': 1,
              'pageSize': 20,
              'hasNext': false,
              'hasPrev': false,
            },
            'filter': {'from': '2026-10-01', 'to': '2026-10-23'},
          },
          'meta': {},
        };

        return http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        httpClient: RedirectAwareClient(innerClient: mockClient),
      );
      final repo = HistoryRepository(apiClient);

      final history = await repo.getHistory(
        from: '2026-10-01',
        to: '2026-10-23',
      );
      expect(history.records.length, 1);
      expect(history.records.first.date, '2026-10-22');
      expect(history.pagination.hasNext, isFalse);
    });

    test(
      'HealthRepository.checkHealth returns database reachability',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.queryParameters['action'], 'health');

          final payload = {
            'success': true,
            'message': 'Health status check',
            'data': {
              'status': 'ok',
              'environment': 'production',
              'timeZone': 'Asia/Kolkata',
              'database': {
                'connected': true,
                'expectedSheetsPresent': true,
                'message': 'Database online',
              },
            },
            'meta': {},
          };

          return http.Response(
            jsonEncode(payload),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final apiClient = ApiClient(
          httpClient: RedirectAwareClient(innerClient: mockClient),
        );
        final repo = HealthRepository(apiClient);

        final health = await repo.checkHealth();
        expect(health.isHealthy, isTrue);
        expect(health.database.connected, isTrue);
      },
    );
  });
}
