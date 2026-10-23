/// Summary counts for database validation
class ValidationSummary {
  final int totalErrors;
  final int totalWarnings;

  const ValidationSummary({this.totalErrors = 0, this.totalWarnings = 0});

  factory ValidationSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ValidationSummary();
    return ValidationSummary(
      totalErrors: json['totalErrors'] as int? ?? 0,
      totalWarnings: json['totalWarnings'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'totalErrors': totalErrors,
    'totalWarnings': totalWarnings,
  };
}

/// A specific database validation check result
class ValidationCheck {
  final String name;
  final String status;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, dynamic> metadata;

  const ValidationCheck({
    required this.name,
    required this.status,
    this.errors = const [],
    this.warnings = const [],
    this.metadata = const {},
  });

  bool get isPassed =>
      status.toUpperCase() == 'PASSED' || status.toUpperCase() == 'OK';

  factory ValidationCheck.fromJson(String name, Map<String, dynamic> json) {
    return ValidationCheck(
      name: name,
      status: json['status'] as String? ?? 'UNKNOWN',
      errors: (json['errors'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      warnings: (json['warnings'] as List<dynamic>? ?? [])
          .map((w) => w.toString())
          .toList(),
      metadata: json,
    );
  }
}

/// Admin-only database validation report
class DatabaseValidationResponse {
  final String overallStatus;
  final ValidationSummary summary;
  final List<ValidationCheck> checks;

  const DatabaseValidationResponse({
    required this.overallStatus,
    required this.summary,
    required this.checks,
  });

  bool get isSuccess =>
      overallStatus.toUpperCase() == 'PASSED' ||
      overallStatus.toUpperCase() == 'OK';

  factory DatabaseValidationResponse.fromJson(Map<String, dynamic> json) {
    final checksList = <ValidationCheck>[];
    final checksMap = json['checks'] as Map<String, dynamic>?;
    if (checksMap != null) {
      for (final entry in checksMap.entries) {
        if (entry.value is Map<String, dynamic>) {
          checksList.add(
            ValidationCheck.fromJson(
              entry.key,
              entry.value as Map<String, dynamic>,
            ),
          );
        }
      }
    }

    return DatabaseValidationResponse(
      overallStatus: json['overallStatus'] as String? ?? 'UNKNOWN',
      summary: ValidationSummary.fromJson(
        json['summary'] as Map<String, dynamic>?,
      ),
      checks: checksList,
    );
  }
}
