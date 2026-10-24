import 'timetable_activity.dart';

/// Represents daily activity execution status record for a single date
class DailyStatus {
  final bool exists;
  final dynamic srno;
  final String date;
  final String dayType;
  final Map<String, dynamic> statuses;
  final dynamic srno14;
  final dynamic srno15;
  final String remark;

  const DailyStatus({
    this.exists = false,
    this.srno,
    required this.date,
    required this.dayType,
    this.statuses = const {},
    this.srno14,
    this.srno15,
    this.remark = '',
  });

  /// Check if activity at slot [activityNo] is completed on time ("y")
  bool isOnTime(int activityNo) {
    final val = statuses[activityNo.toString()];
    return val == 'y' || val == 'Y';
  }

  /// Check if activity at slot [activityNo] is not completed ("n")
  bool isNotCompleted(int activityNo) {
    final val = statuses[activityNo.toString()];
    return val == 'n' || val == 'N';
  }

  /// Check if activity at slot [activityNo] is completed late (positive integer minutes)
  bool isLate(int activityNo) {
    final val = statuses[activityNo.toString()];
    if (val is int) return val > 0;
    if (val is String) {
      final parsed = int.tryParse(val);
      return parsed != null && parsed > 0;
    }
    return false;
  }

  /// Get late minutes for activity slot [activityNo], returns 0 if not late
  int getLateMinutes(int activityNo) {
    final val = statuses[activityNo.toString()];
    if (val is int) return val > 0 ? val : 0;
    if (val is String) {
      final parsed = int.tryParse(val);
      return (parsed != null && parsed > 0) ? parsed : 0;
    }
    return 0;
  }

  /// Check if activity at slot [activityNo] is unrecorded (null or absent)
  bool isUnrecorded(int activityNo) {
    final key = activityNo.toString();
    if (!statuses.containsKey(key)) return true;
    final val = statuses[key];
    return val == null;
  }

  /// Get raw status value for activity slot [activityNo]
  dynamic getStatusValue(int activityNo) {
    return statuses[activityNo.toString()];
  }

  /// Create a copy with an updated status value for one activity slot
  DailyStatus copyWithUpdatedActivity(int activityNo, dynamic newStatus) {
    final newStatuses = Map<String, dynamic>.from(statuses);
    if (newStatus == null) {
      newStatuses[activityNo.toString()] = null;
    } else {
      newStatuses[activityNo.toString()] = newStatus;
    }
    return DailyStatus(
      exists: true,
      srno: srno,
      date: date,
      dayType: dayType,
      statuses: newStatuses,
      srno14: srno14,
      srno15: srno15,
      remark: remark,
    );
  }

  /// Create a copy with an updated remark
  DailyStatus copyWithRemark(String newRemark) {
    return DailyStatus(
      exists: true,
      srno: srno,
      date: date,
      dayType: dayType,
      statuses: statuses,
      srno14: srno14,
      srno15: srno15,
      remark: newRemark,
    );
  }

  factory DailyStatus.fromJson(
    Map<String, dynamic> json, {
    String? fallbackDate,
    String? fallbackDayType,
  }) {
    final rawStatuses = json['statuses'];
    final Map<String, dynamic> parsedStatuses = {};

    if (rawStatuses is Map) {
      for (final entry in rawStatuses.entries) {
        final key = entry.key.toString();
        final dynamic val = entry.value;
        if (val == null) {
          parsedStatuses[key] = null;
        } else if (val is int) {
          parsedStatuses[key] = val;
        } else if (val is String) {
          final trimmed = val.trim();
          final intVal = int.tryParse(trimmed);
          if (intVal != null) {
            parsedStatuses[key] = intVal;
          } else {
            parsedStatuses[key] = trimmed.toLowerCase();
          }
        } else {
          parsedStatuses[key] = val;
        }
      }
    }

    return DailyStatus(
      exists:
          json['exists'] as bool? ??
          (json.containsKey('date') && json['date'] != null),
      srno: json['srno'],
      date: json['date'] as String? ?? fallbackDate ?? '',
      dayType: json['dayType'] as String? ?? fallbackDayType ?? 'weekday',
      statuses: parsedStatuses,
      srno14: json['srno14'],
      srno15: json['srno15'],
      remark: json['remark'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'exists': exists,
    if (srno != null) 'srno': srno,
    'date': date,
    'dayType': dayType,
    'statuses': statuses,
    if (srno14 != null) 'srno14': srno14,
    if (srno15 != null) 'srno15': srno15,
    'remark': remark,
  };
}

/// Response returned by getToday endpoint combining timetable and saved status
class TodayResponse {
  final String date;
  final String dayType;
  final List<TimetableActivity> timetable;
  final DailyStatus status;

  const TodayResponse({
    required this.date,
    required this.dayType,
    required this.timetable,
    required this.status,
  });

  factory TodayResponse.fromJson(Map<String, dynamic> json) {
    final date = json['date'] as String? ?? '';
    final dayType = json['dayType'] as String? ?? 'weekday';

    List<dynamic> timetableRaw = const [];
    if (json['timetable'] is List) {
      timetableRaw = json['timetable'] as List<dynamic>;
    } else if (json['timetable'] is Map) {
      final ttMap = json['timetable'] as Map<String, dynamic>;
      if (ttMap['activities'] is List) {
        timetableRaw = ttMap['activities'] as List<dynamic>;
      }
    }

    final timetable = timetableRaw
        .whereType<Map<String, dynamic>>()
        .map(TimetableActivity.fromJson)
        .toList();

    final statusJson = json['status'] as Map<String, dynamic>?;
    final status = statusJson != null
        ? DailyStatus.fromJson(
            statusJson,
            fallbackDate: date,
            fallbackDayType: dayType,
          )
        : DailyStatus(exists: false, date: date, dayType: dayType);

    return TodayResponse(
      date: date,
      dayType: dayType,
      timetable: timetable,
      status: status,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'dayType': dayType,
    'timetable': timetable.map((t) => t.toJson()).toList(),
    'status': status.toJson(),
  };
}
