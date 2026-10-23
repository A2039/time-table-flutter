import '../../../core/network/api_client.dart';
import '../../../shared/models/daily_status.dart';

/// Repository for reading and updating daily activity execution status and remarks
class StatusRepository {
  final ApiClient _apiClient;

  StatusRepository(this._apiClient);

  /// Fetch saved daily status for a specific date
  /// If no status is saved yet, backend returns exists: false
  Future<DailyStatus> getStatus(String date) async {
    return _apiClient.get<DailyStatus>(
      action: 'getStatus',
      queryParams: {'date': date},
      fromJson: (data) => DailyStatus.fromJson(
        data as Map<String, dynamic>,
        fallbackDate: date,
      ),
    );
  }

  /// Save daily activity statuses and remark
  /// partial update by default (replaceAll: false)
  Future<DailyStatus> saveStatus({
    required String date,
    required Map<String, dynamic> statuses,
    String? remark,
    bool replaceAll = false,
  }) async {
    final body = <String, dynamic>{
      'date': date,
      'statuses': statuses,
      'replaceAll': replaceAll,
      'remark': ?remark,
    };

    return _apiClient.post<DailyStatus>(
      action: 'saveStatus',
      body: body,
      fromJson: (data) => DailyStatus.fromJson(
        data as Map<String, dynamic>,
        fallbackDate: date,
      ),
    );
  }

  /// Update single activity status without modifying other activities or remark
  Future<DailyStatus> updateActivity({
    required String date,
    required int activityNo,
    required dynamic status,
  }) async {
    final body = <String, dynamic>{
      'date': date,
      'activityNo': activityNo,
      'status': status,
    };

    return _apiClient.post<DailyStatus>(
      action: 'updateActivity',
      body: body,
      fromJson: (data) => DailyStatus.fromJson(
        data as Map<String, dynamic>,
        fallbackDate: date,
      ),
    );
  }

  /// Update daily remark without modifying activity statuses
  Future<DailyStatus> updateRemark({
    required String date,
    required String remark,
  }) async {
    final body = <String, dynamic>{'date': date, 'remark': remark};

    return _apiClient.post<DailyStatus>(
      action: 'updateRemark',
      body: body,
      fromJson: (data) => DailyStatus.fromJson(
        data as Map<String, dynamic>,
        fallbackDate: date,
      ),
    );
  }
}
