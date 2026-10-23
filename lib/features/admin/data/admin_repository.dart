import '../../../core/network/api_client.dart';
import '../../../shared/models/database_validation.dart';

/// Repository for admin-only database structure and integrity audits
class AdminRepository {
  final ApiClient _apiClient;

  AdminRepository(this._apiClient);

  /// Run database validation audit using admin authentication token
  Future<DatabaseValidationResponse> validateDatabase({
    required String adminToken,
  }) async {
    return _apiClient.get<DatabaseValidationResponse>(
      action: 'validateDatabase',
      explicitToken: adminToken,
      fromJson: (data) =>
          DatabaseValidationResponse.fromJson(data as Map<String, dynamic>),
    );
  }
}
