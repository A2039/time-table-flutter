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
  final int activityNo;
  final String title;
  final String category;
  final String time;
  final dynamic rawStatus;
  final String statusType;
  final int lateMinutes;
  final String statusLabel;
  final String description;
  final String? timePeriod;
  final String? activity;

  const DashboardActivity({
    required this.activityNo,
    required this.title,
    required this.category,
    required this.time,
    this.rawStatus,
    this.statusType = 'unrecorded',
    this.lateMinutes = 0,
    required this.statusLabel,
    this.description = '',
    this.timePeriod,
    this.activity,
  });

  /// Backward-compatible alias for activityNo
  int get srno => activityNo;

  /// Backward-compatible alias for rawStatus
  dynamic get status => rawStatus;

  bool get isOnTime => statusType == 'on_time';
  bool get isLate => statusType == 'late';
  bool get isNotCompleted => statusType == 'not_completed';
  bool get isUnrecorded => statusType == 'unrecorded';

  factory DashboardActivity.fromJson(Map<String, dynamic> json) {
    final rawNo = json['activityNo'] ?? json['srno'] ?? json['srNo'];
    final activityNo = rawNo is int
        ? rawNo
        : (int.tryParse(rawNo?.toString() ?? '0') ?? 0);

    final title = (json['title'] as String?)?.trim() ??
        (json['timePeriod'] as String?)?.trim() ??
        (json['activity'] as String?)?.trim() ??
        'Activity #$activityNo';

    final category = (json['category'] as String?)?.trim() ?? 'General';
    final time = (json['time'] as String?)?.trim() ?? '';
    final description = (json['description'] as String?)?.trim() ?? '';

    dynamic rawStatus = json['rawStatus'] ?? json['status'];
    final rawType = (json['statusType'] as String?)?.trim().toLowerCase();

    int lateMin = 0;
    final rawLate = json['lateMinutes'];
    if (rawLate is int) {
      lateMin = rawLate;
    } else if (rawLate is num) {
      lateMin = rawLate.toInt();
    } else if (rawLate is String) {
      lateMin = int.tryParse(rawLate) ?? 0;
    }

    if (rawStatus is int && rawStatus > 0 && lateMin == 0) {
      lateMin = rawStatus;
    } else if (rawStatus is String &&
        int.tryParse(rawStatus) != null &&
        int.parse(rawStatus) > 0 &&
        lateMin == 0) {
      lateMin = int.parse(rawStatus);
    }

    String statusType = rawType ?? '';
    if (statusType.isEmpty) {
      if (rawStatus == 'y' || rawStatus == 'Y') {
        statusType = 'on_time';
      } else if (rawStatus == 'n' || rawStatus == 'N') {
        statusType = 'not_completed';
      } else if (lateMin > 0) {
        statusType = 'late';
      } else {
        statusType = 'unrecorded';
      }
    }

    if (rawStatus == null) {
      if (statusType == 'on_time') {
        rawStatus = 'y';
      } else if (statusType == 'not_completed') {
        rawStatus = 'n';
      } else if (statusType == 'late') {
        rawStatus = lateMin > 0 ? lateMin : 5;
      }
    } else if (statusType == 'late' && rawStatus is! int && lateMin > 0) {
      rawStatus = lateMin;
    }

    String label = (json['statusLabel'] as String?)?.trim() ?? '';
    if (label.isEmpty) {
      switch (statusType) {
        case 'on_time':
          label = 'Completed On Time';
          break;
        case 'late':
          label = lateMin > 0
              ? 'Completed Late (+$lateMin m)'
              : 'Completed Late';
          break;
        case 'not_completed':
          label = 'Not Completed';
          break;
        case 'unrecorded':
        default:
          label = 'Not Recorded';
          break;
      }
    }

    return DashboardActivity(
      activityNo: activityNo,
      title: title,
      category: category,
      time: time,
      rawStatus: rawStatus,
      statusType: statusType,
      lateMinutes: lateMin,
      statusLabel: label,
      description: description,
      timePeriod: json['timePeriod'] as String?,
      activity: json['activity'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'activityNo': activityNo,
    'srno': srno,
    'title': title,
    'category': category,
    'time': time,
    'rawStatus': rawStatus,
    'status': status,
    'statusType': statusType,
    'lateMinutes': lateMinutes,
    'statusLabel': statusLabel,
    'description': description,
    if (timePeriod != null) 'timePeriod': timePeriod,
    if (activity != null) 'activity': activity,
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
        .map((item) {
          if (item is Map<String, dynamic>) {
            return DashboardActivity.fromJson(item);
          } else if (item is Map) {
            return DashboardActivity.fromJson(
              Map<String, dynamic>.from(item),
            );
          }
          return null;
        })
        .whereType<DashboardActivity>()
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
