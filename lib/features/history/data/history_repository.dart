import '../../../core/network/api_client.dart';
import '../../../shared/models/history_record.dart';

/// Repository for paginated timetable history queries
class HistoryRepository {
  final ApiClient _apiClient;

  HistoryRepository(this._apiClient);

  /// Fetch paginated history records for a date range
  Future<HistoryResponse> getHistory({
    required String from,
    required String to,
    int page = 1,
    int pageSize = 20,
    String? dayType,
  }) async {
    final queryParams = <String, String>{
      'from': from,
      'to': to,
      'page': page.toString(),
      'pageSize': pageSize.clamp(1, 100).toString(),
      if (dayType != null && dayType.isNotEmpty && dayType != 'all')
        'dayType': dayType,
    };

    return _apiClient.get<HistoryResponse>(
      action: 'getHistory',
      queryParams: queryParams,
      fromJson: (data) =>
          HistoryResponse.fromJson(data as Map<String, dynamic>),
    );
  }
}
