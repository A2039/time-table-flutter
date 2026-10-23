import '../../../core/network/api_client.dart';
import '../../../shared/models/health_response.dart';

/// Repository for backend and database health checks
class HealthRepository {
  final ApiClient _apiClient;

  HealthRepository(this._apiClient);

  /// Check backend and database reachability (public/optional authentication)
  Future<HealthResponse> checkHealth() async {
    return _apiClient.get<HealthResponse>(
      action: 'health',
      requiresAuth: false,
      fromJson: (data) => HealthResponse.fromJson(data as Map<String, dynamic>),
    );
  }
}
