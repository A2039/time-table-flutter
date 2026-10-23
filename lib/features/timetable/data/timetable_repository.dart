import '../../../core/network/api_client.dart';
import '../../../shared/models/daily_status.dart';
import '../../../shared/models/timetable_activity.dart';

/// Repository for timetable schedule queries
class TimetableRepository {
  final ApiClient _apiClient;

  TimetableRepository(this._apiClient);

  /// Fetch timetable for a specified date (defaults to today if date is empty)
  Future<TimetableResponse> getTimetable(String date, {String? dayType}) async {
    final queryParams = <String, String>{
      if (date.isNotEmpty) 'date': date,
      if (dayType != null && dayType.isNotEmpty) 'day_type': dayType,
    };

    return _apiClient.get<TimetableResponse>(
      action: 'getTimetable',
      queryParams: queryParams,
      fromJson: (data) =>
          TimetableResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Fetch today's schedule and saved status combined in one request
  Future<TodayResponse> getToday() async {
    return _apiClient.get<TodayResponse>(
      action: 'getToday',
      fromJson: (data) => TodayResponse.fromJson(data as Map<String, dynamic>),
    );
  }
}
