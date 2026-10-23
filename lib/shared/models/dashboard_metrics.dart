/// Dashboard summary metrics returned by getDashboard
class DashboardMetrics {
  final int totalActivities;
  final int completedOnTime;
  final int completedLate;
  final int notCompleted;
  final int notRecorded;
  final int totalCompleted;
  final int totalRecorded;
  final int totalLateMinutes;
  final double completionPercentage;
  final double recordedPercentage;

  const DashboardMetrics({
    this.totalActivities = 0,
    this.completedOnTime = 0,
    this.completedLate = 0,
    this.notCompleted = 0,
    this.notRecorded = 0,
    this.totalCompleted = 0,
    this.totalRecorded = 0,
    this.totalLateMinutes = 0,
    this.completionPercentage = 0.0,
    this.recordedPercentage = 0.0,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DashboardMetrics();

    final totalActivities = _parseInt(json['totalActivities']);
    final completedOnTime = _parseInt(json['completedOnTime']);
    final completedLate = _parseInt(json['completedLate']);
    final notCompleted = _parseInt(json['notCompleted']);
    final notRecorded = _parseInt(json['notRecorded']);
    final totalCompleted = _parseInt(
      json['totalCompleted'],
      fallback: completedOnTime + completedLate,
    );
    final totalRecorded = _parseInt(
      json['totalRecorded'],
      fallback: totalActivities - notRecorded,
    );
    final totalLateMinutes = _parseInt(json['totalLateMinutes']);

    // Parse percentages or compute accurately
    double completionPct = _parseDouble(json['completionPercentage']);
    if (completionPct == 0.0 && totalActivities > 0) {
      completionPct =
          (completedOnTime + completedLate) / totalActivities * 100.0;
    }

    double recordedPct = _parseDouble(json['recordedPercentage']);
    if (recordedPct == 0.0 && totalActivities > 0) {
      recordedPct = (totalActivities - notRecorded) / totalActivities * 100.0;
    }

    return DashboardMetrics(
      totalActivities: totalActivities,
      completedOnTime: completedOnTime,
      completedLate: completedLate,
      notCompleted: notCompleted,
      notRecorded: notRecorded,
      totalCompleted: totalCompleted,
      totalRecorded: totalRecorded,
      totalLateMinutes: totalLateMinutes,
      completionPercentage: completionPct.clamp(0.0, 100.0),
      recordedPercentage: recordedPct.clamp(0.0, 100.0),
    );
  }

  static int _parseInt(dynamic val, {int fallback = 0}) {
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      return int.tryParse(val) ?? fallback;
    }
    return fallback;
  }

  static double _parseDouble(dynamic val) {
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() => {
    'totalActivities': totalActivities,
    'completedOnTime': completedOnTime,
    'completedLate': completedLate,
    'notCompleted': notCompleted,
    'notRecorded': notRecorded,
    'totalCompleted': totalCompleted,
    'totalRecorded': totalRecorded,
    'totalLateMinutes': totalLateMinutes,
    'completionPercentage': completionPercentage,
    'recordedPercentage': recordedPercentage,
  };
}

/// An activity enriched with status details in the dashboard
class DashboardActivity {
  final int srno;
  final String category;
  final String time;
  final String? timePeriod;
  final String? activity;
  final String description;
  final dynamic status;
  final String statusLabel;
  final int lateMinutes;

  const DashboardActivity({
    required this.srno,
    required this.category,
    required this.time,
    this.timePeriod,
    this.activity,
    required this.description,
    this.status,
    required this.statusLabel,
    this.lateMinutes = 0,
  });

  String get title {
    if (timePeriod != null && timePeriod!.trim().isNotEmpty) {
      return timePeriod!.trim();
    }
    if (activity != null && activity!.trim().isNotEmpty) {
      return activity!.trim();
    }
    return 'Activity #$srno';
  }

  factory DashboardActivity.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    int lateMin = 0;
    if (status is int && status > 0) {
      lateMin = status;
    } else if (json['lateMinutes'] is int) {
      lateMin = json['lateMinutes'] as int;
    }

    String label = json['statusLabel'] as String? ?? '';
    if (label.isEmpty) {
      if (status == 'y' || status == 'Y') {
        label = 'Completed On Time';
      } else if (status == 'n' || status == 'N') {
        label = 'Not Completed';
      } else if (lateMin > 0) {
        label = 'Completed Late ($lateMin m)';
      } else {
        label = 'Not Recorded';
      }
    }

    return DashboardActivity(
      srno: json['srno'] is int
          ? json['srno'] as int
          : int.tryParse(json['srno']?.toString() ?? '0') ?? 0,
      category: json['category'] as String? ?? 'General',
      time: json['time'] as String? ?? '',
      timePeriod: json['timePeriod'] as String?,
      activity: json['activity'] as String?,
      description: json['description'] as String? ?? '',
      status: status,
      statusLabel: label,
      lateMinutes: lateMin,
    );
  }

  Map<String, dynamic> toJson() => {
    'srno': srno,
    'category': category,
    'time': time,
    if (timePeriod != null) 'timePeriod': timePeriod,
    if (activity != null) 'activity': activity,
    'description': description,
    'status': status,
    'statusLabel': statusLabel,
    'lateMinutes': lateMinutes,
  };
}

/// Full dashboard response returned by getDashboard
class DashboardResponse {
  final String date;
  final String dayType;
  final bool hasSavedStatus;
  final DashboardMetrics metrics;
  final String remark;
  final List<DashboardActivity> activities;

  const DashboardResponse({
    required this.date,
    required this.dayType,
    required this.hasSavedStatus,
    required this.metrics,
    this.remark = '',
    this.activities = const [],
  });

  factory DashboardResponse.fromJson(Map<String, dynamic> json) {
    final activitiesRaw = json['activities'] as List<dynamic>? ?? [];
    final activities = activitiesRaw
        .whereType<Map<String, dynamic>>()
        .map(DashboardActivity.fromJson)
        .toList();

    return DashboardResponse(
      date: json['date'] as String? ?? '',
      dayType: json['dayType'] as String? ?? 'weekday',
      hasSavedStatus: json['hasSavedStatus'] as bool? ?? false,
      metrics: DashboardMetrics.fromJson(
        json['metrics'] as Map<String, dynamic>?,
      ),
      remark: json['remark'] as String? ?? '',
      activities: activities,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'dayType': dayType,
    'hasSavedStatus': hasSavedStatus,
    'metrics': metrics.toJson(),
    'remark': remark,
    'activities': activities.map((a) => a.toJson()).toList(),
  };
}
