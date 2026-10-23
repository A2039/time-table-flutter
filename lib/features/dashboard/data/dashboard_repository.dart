import '../../../core/network/api_client.dart';
import '../../../shared/models/dashboard_metrics.dart';

/// Repository for dashboard metrics and analytics
class DashboardRepository {
  final ApiClient _apiClient;

  DashboardRepository(this._apiClient);

  /// Fetch dashboard metrics and activity breakdown for a date
  Future<DashboardResponse> getDashboard(String date) async {
    return _apiClient.get<DashboardResponse>(
      action: 'getDashboard',
      queryParams: {'date': date},
      fromJson: (data) =>
          DashboardResponse.fromJson(data as Map<String, dynamic>),
    );
  }
}
