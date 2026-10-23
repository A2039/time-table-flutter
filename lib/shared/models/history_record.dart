import 'daily_status.dart';

/// Pagination metadata for history responses
class PaginationInfo {
  final int totalRecords;
  final int totalPages;
  final int currentPage;
  final int pageSize;
  final bool hasNext;
  final bool hasPrev;

  const PaginationInfo({
    this.totalRecords = 0,
    this.totalPages = 0,
    this.currentPage = 1,
    this.pageSize = 20,
    this.hasNext = false,
    this.hasPrev = false,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PaginationInfo();
    return PaginationInfo(
      totalRecords: json['totalRecords'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      currentPage: json['currentPage'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 20,
      hasNext: json['hasNext'] as bool? ?? false,
      hasPrev: json['hasPrev'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'totalRecords': totalRecords,
    'totalPages': totalPages,
    'currentPage': currentPage,
    'pageSize': pageSize,
    'hasNext': hasNext,
    'hasPrev': hasPrev,
  };
}

/// History query filter settings
class HistoryFilter {
  final String from;
  final String to;
  final String? dayType;

  const HistoryFilter({required this.from, required this.to, this.dayType});

  factory HistoryFilter.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HistoryFilter(from: '', to: '');
    return HistoryFilter(
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      dayType: json['dayType'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    if (dayType != null) 'dayType': dayType,
  };
}

/// A historical daily record with parsed status
class HistoryRecord {
  final String date;
  final String dayType;
  final DailyStatus status;
  final int completedOnTime;
  final int completedLate;
  final int notCompleted;
  final int notRecorded;
  final double completionPercentage;

  const HistoryRecord({
    required this.date,
    required this.dayType,
    required this.status,
    this.completedOnTime = 0,
    this.completedLate = 0,
    this.notCompleted = 0,
    this.notRecorded = 0,
    this.completionPercentage = 0.0,
  });

  factory HistoryRecord.fromJson(Map<String, dynamic> json) {
    final date = json['date'] as String? ?? '';
    final dayType = json['dayType'] as String? ?? 'weekday';
    final dailyStatus = DailyStatus.fromJson(
      json,
      fallbackDate: date,
      fallbackDayType: dayType,
    );

    // Compute or parse summary counts
    int onTime = json['completedOnTime'] as int? ?? 0;
    int late = json['completedLate'] as int? ?? 0;
    int notComp = json['notCompleted'] as int? ?? 0;
    int unrec = json['notRecorded'] as int? ?? 0;

    if (onTime == 0 &&
        late == 0 &&
        notComp == 0 &&
        unrec == 0 &&
        dailyStatus.statuses.isNotEmpty) {
      for (final val in dailyStatus.statuses.values) {
        if (val == 'y' || val == 'Y') {
          onTime++;
        } else if (val == 'n' || val == 'N') {
          notComp++;
        } else if (val is int && val > 0) {
          late++;
        } else if (val == null) {
          unrec++;
        }
      }
    }

    final total = onTime + late + notComp + unrec;
    final pct = total > 0
        ? ((onTime + late) / total * 100.0)
        : (json['completionPercentage'] as num?)?.toDouble() ?? 0.0;

    return HistoryRecord(
      date: date,
      dayType: dayType,
      status: dailyStatus,
      completedOnTime: onTime,
      completedLate: late,
      notCompleted: notComp,
      notRecorded: unrec,
      completionPercentage: pct,
    );
  }
}

/// Full history response with pagination
class HistoryResponse {
  final List<HistoryRecord> records;
  final PaginationInfo pagination;
  final HistoryFilter filter;

  const HistoryResponse({
    required this.records,
    required this.pagination,
    required this.filter,
  });

  factory HistoryResponse.fromJson(Map<String, dynamic> json) {
    final recordsRaw = json['records'] as List<dynamic>? ?? [];
    final records = recordsRaw
        .whereType<Map<String, dynamic>>()
        .map(HistoryRecord.fromJson)
        .toList();

    return HistoryResponse(
      records: records,
      pagination: PaginationInfo.fromJson(
        json['pagination'] as Map<String, dynamic>?,
      ),
      filter: HistoryFilter.fromJson(json['filter'] as Map<String, dynamic>?),
    );
  }
}
