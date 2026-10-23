/// A single timetable activity slot
class TimetableActivity {
  final int srno;
  final String category;
  final String time;
  final String duration;
  final String? timePeriod;
  final String? activity;
  final String description;
  final String? startTime;
  final String? endTime;

  const TimetableActivity({
    required this.srno,
    required this.category,
    required this.time,
    required this.duration,
    this.timePeriod,
    this.activity,
    required this.description,
    this.startTime,
    this.endTime,
  });

  /// Display title combining timePeriod (weekday) or activity (weekend)
  String get title {
    if (timePeriod != null && timePeriod!.trim().isNotEmpty) {
      return timePeriod!.trim();
    }
    if (activity != null && activity!.trim().isNotEmpty) {
      return activity!.trim();
    }
    return 'Activity #$srno';
  }

  factory TimetableActivity.fromJson(Map<String, dynamic> json) {
    return TimetableActivity(
      srno: json['srno'] is int
          ? json['srno'] as int
          : int.tryParse(json['srno']?.toString() ?? '0') ?? 0,
      category: json['category'] as String? ?? 'General',
      time: json['time'] as String? ?? '',
      duration: json['duration']?.toString() ?? '',
      timePeriod: json['timePeriod'] as String?,
      activity: json['activity'] as String?,
      description: json['description'] as String? ?? '',
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'srno': srno,
    'category': category,
    'time': time,
    'duration': duration,
    if (timePeriod != null) 'timePeriod': timePeriod,
    if (activity != null) 'activity': activity,
    'description': description,
    if (startTime != null) 'startTime': startTime,
    if (endTime != null) 'endTime': endTime,
  };
}

/// Timetable response wrapper
class TimetableResponse {
  final String date;
  final String dayType;
  final bool isDayTypeOverridden;
  final int totalActivities;
  final List<TimetableActivity> activities;

  const TimetableResponse({
    required this.date,
    required this.dayType,
    this.isDayTypeOverridden = false,
    required this.totalActivities,
    required this.activities,
  });

  bool get isWeekend => dayType.toLowerCase() == 'weekend';

  factory TimetableResponse.fromJson(Map<String, dynamic> json) {
    final activitiesRaw = json['activities'] as List<dynamic>? ?? [];
    final parsedActivities = activitiesRaw
        .whereType<Map<String, dynamic>>()
        .map(TimetableActivity.fromJson)
        .toList();

    return TimetableResponse(
      date: json['date'] as String? ?? '',
      dayType: json['dayType'] as String? ?? 'weekday',
      isDayTypeOverridden: json['isDayTypeOverridden'] as bool? ?? false,
      totalActivities: json['totalActivities'] is int
          ? json['totalActivities'] as int
          : parsedActivities.length,
      activities: parsedActivities,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'dayType': dayType,
    'isDayTypeOverridden': isDayTypeOverridden,
    'totalActivities': totalActivities,
    'activities': activities.map((a) => a.toJson()).toList(),
  };
}
