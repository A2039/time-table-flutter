import 'package:flutter_test/flutter_test.dart';
import 'package:timetable_app/core/utils/date_utils.dart';

void main() {
  group('AppDateUtils Tests', () {
    test('formatDate and parseDate preserve calendar day strictly without time shift', () {
      final date = DateTime(2026, 10, 23);
      final formatted = AppDateUtils.formatDate(date);
      expect(formatted, '2026-10-23');

      final parsed = AppDateUtils.parseDate(formatted);
      expect(parsed.year, 2026);
      expect(parsed.month, 10);
      expect(parsed.day, 23);
    });

    test('todayDateString returns a valid YYYY-MM-DD string', () {
      final today = AppDateUtils.todayDateString();
      expect(AppDateUtils.isValidDate(today), isTrue);
      expect(today, matches(r'^\d{4}-\d{2}-\d{2}$'));
    });

    test('isWeekend correctly identifies Saturday and Sunday', () {
      // 2026-10-24 is Saturday, 2026-10-25 is Sunday
      expect(AppDateUtils.isWeekend('2026-10-24'), isTrue);
      expect(AppDateUtils.isWeekend('2026-10-25'), isTrue);
      expect(AppDateUtils.getDayType('2026-10-24'), 'weekend');

      // 2026-10-23 is Friday
      expect(AppDateUtils.isWeekend('2026-10-23'), isFalse);
      expect(AppDateUtils.getDayType('2026-10-23'), 'weekday');
    });

    test('addDays adds and subtracts calendar days accurately', () {
      expect(AppDateUtils.addDays('2026-10-23', 1), '2026-10-24');
      expect(AppDateUtils.addDays('2026-10-23', -7), '2026-10-16');
      expect(AppDateUtils.addDays('2026-10-31', 1), '2026-11-01');
    });

    test('isValidDate validates date structure and bounds', () {
      expect(AppDateUtils.isValidDate('2026-10-23'), isTrue);
      expect(
        AppDateUtils.isValidDate('2026-02-29'),
        isFalse,
      ); // 2026 is not leap year
      expect(AppDateUtils.isValidDate('invalid-date'), isFalse);
      expect(AppDateUtils.isValidDate('2026-13-01'), isFalse);
    });
  });
}
