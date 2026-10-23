import 'package:intl/intl.dart';

/// Explicit date-only manipulation utilities to prevent UTC/local timezone
/// off-by-one errors when serializing calendar days.
/// Default timezone context matches the backend: Asia/Kolkata (UTC+05:30).
class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayFormat = DateFormat('EEEE, MMM d, yyyy');
  static final DateFormat _shortDisplayFormat = DateFormat('MMM d, yyyy');
  static final DateFormat _monthDayFormat = DateFormat('MMM d');

  /// Kolkata timezone offset (+05:30)
  static const Duration kolkataOffset = Duration(hours: 5, minutes: 30);

  /// Returns today's date formatted as YYYY-MM-DD in Asia/Kolkata timezone
  static String todayDateString() {
    final nowUtc = DateTime.now().toUtc();
    final kolkataTime = nowUtc.add(kolkataOffset);
    return formatDate(kolkataTime);
  }

  /// Format a DateTime object to strict YYYY-MM-DD string
  static String formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Parse a strict YYYY-MM-DD string into a local Date without time component
  static DateTime parseDate(String yyyyMmDd) {
    try {
      final parts = yyyyMmDd.trim().split('-');
      if (parts.length != 3) {
        throw FormatException(
          'Invalid date format (expected YYYY-MM-DD): $yyyyMmDd',
        );
      }
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      return DateTime(year, month, day);
    } catch (e) {
      // Fallback to intl parse if needed
      return _dateFormat.parseStrict(yyyyMmDd);
    }
  }

  /// Check whether a given date string (YYYY-MM-DD) is valid
  static bool isValidDate(String yyyyMmDd) {
    try {
      final parts = yyyyMmDd.trim().split('-');
      if (parts.length != 3) return false;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year == null || month == null || day == null) return false;
      if (year < 2000 || year > 2100) return false;
      if (month < 1 || month > 12) return false;
      if (day < 1 || day > 31) return false;
      final dt = DateTime(year, month, day);
      return dt.year == year && dt.month == month && dt.day == day;
    } catch (_) {
      return false;
    }
  }

  /// Format YYYY-MM-DD to human-readable date e.g. "Wednesday, Oct 21, 2026"
  static String formatDisplay(String yyyyMmDd) {
    try {
      final dt = parseDate(yyyyMmDd);
      return _displayFormat.format(dt);
    } catch (_) {
      return yyyyMmDd;
    }
  }

  /// Format YYYY-MM-DD to short display e.g. "Oct 21, 2026"
  static String formatShort(String yyyyMmDd) {
    try {
      final dt = parseDate(yyyyMmDd);
      return _shortDisplayFormat.format(dt);
    } catch (_) {
      return yyyyMmDd;
    }
  }

  /// Format YYYY-MM-DD to month/day e.g. "Oct 21"
  static String formatMonthDay(String yyyyMmDd) {
    try {
      final dt = parseDate(yyyyMmDd);
      return _monthDayFormat.format(dt);
    } catch (_) {
      return yyyyMmDd;
    }
  }

  /// Determine if a date is a weekend (Saturday or Sunday)
  static bool isWeekend(dynamic date) {
    if (date is String) {
      try {
        final dt = parseDate(date);
        return dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday;
      } catch (_) {
        return false;
      }
    } else if (date is DateTime) {
      return date.weekday == DateTime.saturday ||
          date.weekday == DateTime.sunday;
    }
    return false;
  }

  /// Get day type string: 'weekend' or 'weekday'
  static String getDayType(dynamic date) {
    return isWeekend(date) ? 'weekend' : 'weekday';
  }

  /// Add days to a YYYY-MM-DD string
  static String addDays(String yyyyMmDd, int days) {
    final dt = parseDate(yyyyMmDd);
    final next = dt.add(Duration(days: days));
    return formatDate(next);
  }

  /// Calculate days difference between two dates (b - a)
  static int daysBetween(String dateA, String dateB) {
    final a = parseDate(dateA);
    final b = parseDate(dateB);
    return b.difference(a).inDays;
  }
}
