import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/shared/models/daily_status.dart';
import 'package:timetable/shared/models/dashboard_metrics.dart';
import 'package:timetable/shared/models/health_response.dart';
import 'package:timetable/shared/models/history_record.dart';
import 'package:timetable/shared/models/timetable_activity.dart';

void main() {
  group('Model Parsing & Serialization Tests', () {
    test('TimetableActivity parses Hindi and Unicode descriptions cleanly', () {
      final json = {
        'srno': 1,
        'category': 'Physical',
        'time': '06:00 - 07:00',
        'duration': '60 min',
        'timePeriod': 'Morning Yoga & Meditation',
        'description': 'à¤ªà¥à¤°à¤¾à¤£à¤¾à¤¯à¤¾à¤® à¤à¤µà¤‚ à¤§à¥à¤¯à¤¾à¤¨ à¤¸à¤¤à¥à¤° - Daily spiritual and physical well-being practice. ðŸ™',
        'startTime': '06:00',
        'endTime': '07:00',
      };

      final activity = TimetableActivity.fromJson(json);

      expect(activity.srno, 1);
      expect(activity.title, 'Morning Yoga & Meditation');
      expect(
        activity.description,
        contains(
          'à¤ªà¥à¤°à¤¾à¤£à¤¾à¤¯à¤¾à¤® à¤à¤µà¤‚ à¤§à¥à¤¯à¤¾à¤¨ à¤¸à¤¤à¥à¤°',
        ),
      );
      expect(activity.description, contains('ðŸ™'));
      expect(activity.startTime, '06:00');
    });

    test(
      'TimetableActivity prefers activity over timePeriod on weekend schedule',
      () {
        final json = {
          'srno': 2,
          'category': 'Recreation',
          'time': '10:00 - 12:00',
          'duration': '120 min',
          'activity': 'Weekend Outdoor Sports',
          'description': 'Friendly badminton or football',
        };

        final activity = TimetableActivity.fromJson(json);
        expect(activity.title, 'Weekend Outdoor Sports');
      },
    );

    test(
      'DailyStatus handles y, n, late minutes, and unrecorded slots correctly',
      () {
        final json = {
          'exists': true,
          'date': '2026-10-21',
          'dayType': 'weekday',
          'statuses': {
            '1': 'y',
            '2': 'n',
            '3': 15,
            '4': '25', // string number coerced to int
            '5': null,
          },
          'remark': 'Day completed with good energy',
        };

        final status = DailyStatus.fromJson(json);

        // Check slot 1: on time
        expect(status.isOnTime(1), isTrue);
        expect(status.isLate(1), isFalse);
        expect(status.isNotCompleted(1), isFalse);
        expect(status.isUnrecorded(1), isFalse);

        // Check slot 2: not completed
        expect(status.isOnTime(2), isFalse);
        expect(status.isNotCompleted(2), isTrue);

        // Check slot 3: late 15 min
        expect(status.isLate(3), isTrue);
        expect(status.getLateMinutes(3), 15);

        // Check slot 4: late 25 min string parsed
        expect(status.isLate(4), isTrue);
        expect(status.getLateMinutes(4), 25);

        // Check slot 5: unrecorded (null)
        expect(status.isUnrecorded(5), isTrue);
        expect(status.isOnTime(5), isFalse);

        // Check slot 6: absent in map -> unrecorded
        expect(status.isUnrecorded(6), isTrue);

        // Check copyWithUpdatedActivity
        final updated = status.copyWithUpdatedActivity(1, 'n');
        expect(updated.isNotCompleted(1), isTrue);
        expect(updated.isOnTime(1), isFalse);
      },
    );

    test(
      'DashboardMetrics computes completion and recorded percentages properly',
      () {
        final json = {
          'totalActivities': 10,
          'completedOnTime': 6,
          'completedLate': 2,
          'notCompleted': 1,
          'notRecorded': 1,
          'totalLateMinutes': 35,
          'completionPercentage': 80.0,
          'recordedPercentage': 90.0,
        };

        final metrics = DashboardMetrics.fromJson(json);

        expect(metrics.totalActivities, 10);
        expect(metrics.totalCompleted, 8); // 6 on time + 2 late
        expect(metrics.totalRecorded, 9); // 10 - 1 unrecorded
        expect(metrics.completionPercentage, 80.0);
        expect(metrics.recordedPercentage, 90.0);
        expect(metrics.totalLateMinutes, 35);
      },
    );

    test(
      'DashboardMetrics calculates percentages when backend omitted them',
      () {
        final json = {
          'totalActivities': 4,
          'completedOnTime': 2,
          'completedLate': 1,
          'notCompleted': 1,
          'notRecorded': 0,
          'totalLateMinutes': 10,
        };

        final metrics = DashboardMetrics.fromJson(json);

        // (2 + 1) / 4 * 100 = 75%
        expect(metrics.completionPercentage, 75.0);
        // (4 - 0) / 4 * 100 = 100%
        expect(metrics.recordedPercentage, 100.0);
      },
    );

    test('DashboardResponse parses live API format with activities correctly', () {
      final json = {
        'date': '2026-10-21',
        'dayType': 'weekday',
        'hasSavedStatus': true,
        'metrics': {
          'totalActivities': 13,
          'completedOnTime': 11,
          'completedLate': 2,
          'notCompleted': 0,
          'notRecorded': 0,
          'totalCompleted': 13,
          'totalRecorded': 13,
          'totalLateMinutes': 60,
          'completionPercentage': 100,
          'recordedPercentage': 100,
        },
        'remark': 'sleep late 30 mint for doing app work',
        'activities': [
          {
            'activityNo': 1,
            'category': 'Sanskar',
            'title':
                'à¤‰à¤·à¤¾à¤•à¤¾à¤² (à¤¬à¥à¤°à¤¹à¥à¤® à¤®à¥à¤¹à¥‚à¤°à¥à¤¤)',
            'time': '05:15 - 05:45 AM',
            'rawStatus': 30,
            'statusType': 'late',
            'lateMinutes': 30,
          },
          {
            'activityNo': 2,
            'category': 'Fitness',
            'title': 'à¤…à¤–à¤¾à¤¡à¤¼à¤¾ / à¤µà¥à¤¯à¤¾à¤¯à¤¾à¤®',
            'time': '05:45 - 06:30 AM',
            'rawStatus': 'y',
            'statusType': 'on_time',
            'lateMinutes': 0,
          },
          {
            'activityNo': 13,
            'category': 'Sleep',
            'title': 'à¤¯à¥‹à¤—-à¤¨à¤¿à¤¦à¥à¤°à¤¾',
            'time': '10:15 - 05:15 AM',
            'rawStatus': 30,
            'statusType': 'late',
            'lateMinutes': 30,
          },
        ],
      };

      final dashboard = DashboardResponse.fromJson(json);

      expect(dashboard.date, '2026-10-21');
      expect(dashboard.dayType, 'weekday');
      expect(dashboard.hasSavedStatus, isTrue);
      expect(dashboard.remark, 'sleep late 30 mint for doing app work');
      expect(dashboard.activities.length, 3);

      final act1 = dashboard.activities[0];
      expect(act1.activityNo, 1);
      expect(act1.srno, 1);
      expect(
        act1.title,
        'à¤‰à¤·à¤¾à¤•à¤¾à¤² (à¤¬à¥à¤°à¤¹à¥à¤® à¤®à¥à¤¹à¥‚à¤°à¥à¤¤)',
      );
      expect(act1.category, 'Sanskar');
      expect(act1.time, '05:15 - 05:45 AM');
      expect(act1.rawStatus, 30);
      expect(act1.status, 30);
      expect(act1.statusType, 'late');
      expect(act1.lateMinutes, 30);
      expect(act1.isLate, isTrue);

      final act2 = dashboard.activities[1];
      expect(act2.activityNo, 2);
      expect(act2.title, 'à¤…à¤–à¤¾à¤¡à¤¼à¤¾ / à¤µà¥à¤¯à¤¾à¤¯à¤¾à¤®');
      expect(act2.category, 'Fitness');
      expect(act2.status, 'y');
      expect(act2.isOnTime, isTrue);
      expect(act2.lateMinutes, 0);

      final act3 = dashboard.activities[2];
      expect(act3.activityNo, 13);
      expect(act3.title, 'à¤¯à¥‹à¤—-à¤¨à¤¿à¤¦à¥à¤°à¤¾');
      expect(act3.status, 30);
      expect(act3.isLate, isTrue);
    });

    test('HealthResponse parses database status and connectivity', () {
      final json = {
        'status': 'ok',
        'environment': 'production',
        'timeZone': 'Asia/Kolkata',
        'database': {
          'connected': true,
          'expectedSheetsPresent': true,
          'message': 'Connected to Google Spreadsheet successfully',
        },
      };

      final health = HealthResponse.fromJson(json);

      expect(health.isHealthy, isTrue);
      expect(health.timeZone, 'Asia/Kolkata');
      expect(health.database.connected, isTrue);
      expect(health.database.expectedSheetsPresent, isTrue);
    });

    test('HistoryResponse parses pagination and date records', () {
      final json = {
        'records': [
          {
            'date': '2026-10-20',
            'dayType': 'weekday',
            'statuses': {'1': 'y', '2': 10, '3': 'n'},
            'remark': 'Busy afternoon',
            'completedOnTime': 1,
            'completedLate': 1,
            'notCompleted': 1,
            'notRecorded': 0,
            'completionPercentage': 66.6,
          },
        ],
        'pagination': {
          'totalRecords': 25,
          'totalPages': 2,
          'currentPage': 1,
          'pageSize': 20,
          'hasNext': true,
          'hasPrev': false,
        },
        'filter': {
          'from': '2026-10-01',
          'to': '2026-10-23',
          'dayType': 'weekday',
        },
      };

      final history = HistoryResponse.fromJson(json);

      expect(history.records.length, 1);
      expect(history.records[0].date, '2026-10-20');
      expect(history.pagination.totalRecords, 25);
      expect(history.pagination.hasNext, isTrue);
      expect(history.pagination.hasPrev, isFalse);
      expect(history.filter.dayType, 'weekday');
    });

    test('TodayResponse parses both Map with activities and List format', () {
      // Map format (actual live Google Apps Script response)
      final mapFormatJson = {
        'date': '2026-10-24',
        'dayType': 'weekend',
        'timetable': {
          'date': '2026-10-24',
          'dayType': 'weekend',
          'totalActivities': 2,
          'activities': [
            {
              'srno': 1,
              'category': 'Morning',
              'time': '06:00 - 07:00',
              'duration': '60',
              'activity': 'Yoga',
              'description': 'Morning Yoga',
            },
            {
              'srno': 2,
              'category': 'Breakfast',
              'time': '07:00 - 08:00',
              'duration': '60',
              'activity': 'Breakfast',
              'description': 'Healthy breakfast',
            },
          ],
        },
        'status': {
          'exists': true,
          'srno': 8,
          'date': '2026-10-24',
          'dayType': 'weekend',
          'statuses': {'1': 'y', '2': 15},
          'remark': 'All good',
        },
      };

      final todayFromMap = TodayResponse.fromJson(mapFormatJson);
      expect(todayFromMap.date, '2026-10-24');
      expect(todayFromMap.dayType, 'weekend');
      expect(todayFromMap.timetable.length, 2);
      expect(todayFromMap.timetable[0].activity, 'Yoga');
      expect(todayFromMap.status.exists, isTrue);
      expect(todayFromMap.status.isOnTime(1), isTrue);
      expect(todayFromMap.status.isLate(2), isTrue);

      // List format (mock format)
      final listFormatJson = {
        'date': '2026-10-24',
        'dayType': 'weekend',
        'timetable': [
          {
            'srno': 1,
            'category': 'Morning',
            'time': '06:00 - 07:00',
            'duration': '60',
            'activity': 'Running',
            'description': 'Running exercise',
          },
        ],
        'status': null,
      };

      final todayFromList = TodayResponse.fromJson(listFormatJson);
      expect(todayFromList.timetable.length, 1);
      expect(todayFromList.timetable[0].activity, 'Running');
      expect(todayFromList.status.exists, isFalse);
    });
  });
}
