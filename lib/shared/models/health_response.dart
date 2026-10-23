/// Database reachability and schema presence info
class DatabaseStatus {
  final bool connected;
  final bool expectedSheetsPresent;
  final String message;

  const DatabaseStatus({
    required this.connected,
    required this.expectedSheetsPresent,
    required this.message,
  });

  factory DatabaseStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const DatabaseStatus(
        connected: false,
        expectedSheetsPresent: false,
        message: 'No database information available',
      );
    }
    return DatabaseStatus(
      connected: json['connected'] as bool? ?? false,
      expectedSheetsPresent: json['expectedSheetsPresent'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'connected': connected,
    'expectedSheetsPresent': expectedSheetsPresent,
    'message': message,
  };
}

/// Health response model for backend and database diagnostics
class HealthResponse {
  final String status;
  final String environment;
  final String timeZone;
  final DatabaseStatus database;

  const HealthResponse({
    required this.status,
    required this.environment,
    required this.timeZone,
    required this.database,
  });

  bool get isHealthy => status.toLowerCase() == 'ok' && database.connected;

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(
      status: json['status'] as String? ?? 'unknown',
      environment: json['environment'] as String? ?? 'development',
      timeZone: json['timeZone'] as String? ?? 'Asia/Kolkata',
      database: DatabaseStatus.fromJson(
        json['database'] as Map<String, dynamic>?,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'environment': environment,
    'timeZone': timeZone,
    'database': database.toJson(),
  };
}
