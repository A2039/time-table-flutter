import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../shared/models/database_validation.dart';
import '../../../shared/providers/app_providers.dart';

/// Admin-only screen providing read-only database structure and schema integrity reports
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final TextEditingController _adminTokenController = TextEditingController();
  bool _isLoading = false;
  DatabaseValidationResponse? _auditResult;
  dynamic _error;

  @override
  void dispose() {
    _adminTokenController.dispose();
    super.dispose();
  }

  Future<void> _runAudit() async {
    final token = _adminTokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the Admin API Token (apiAdminToken)'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _auditResult = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      final result = await repo.validateDatabase(adminToken: token);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _auditResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Database Audit (Admin)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Security Notice Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.security_rounded, color: theme.colorScheme.tertiary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Administrative Access Only',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This screen performs a deep read-only inspection of the Google Sheets database structure. '
                        'Requires ADMIN_API_TOKEN. This token is never hardcoded, bundled into normal builds, or exposed in logs.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Admin Token Input & Run Button
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _adminTokenController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Admin API Token',
                      hintText: 'Enter ADMIN_API_TOKEN',
                      prefixIcon: Icon(Icons.key_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _runAudit,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: const Text('Run Database Integrity Audit'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Loading State
          if (_isLoading)
            const AppLoading(
              message: 'Validating sheets, formulas, and schema...',
            ),

          // Error State
          if (_error != null)
            AppErrorView(
              error: _error,
              customTitle: 'Audit Execution Failed',
              onRetry: _runAudit,
            ),

          // Results View
          if (_auditResult != null) ...[
            _buildAuditSummaryCard(context, _auditResult!),
            const SizedBox(height: 16),
            Text(
              'Detailed Checks (${_auditResult!.checks.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ..._auditResult!.checks.map(
              (check) => _buildCheckCard(context, check),
            ),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }

  Widget _buildAuditSummaryCard(
    BuildContext context,
    DatabaseValidationResponse audit,
  ) {
    final isPassed = audit.isSuccess;
    final color = isPassed ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isPassed
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: color,
                size: 28,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Status: ${audit.overallStatus}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    '${audit.summary.totalErrors} Errors • ${audit.summary.totalWarnings} Warnings',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckCard(BuildContext context, ValidationCheck check) {
    final theme = Theme.of(context);
    final isPassed = check.isPassed;
    final statusColor = isPassed
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Icon(
          isPassed
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
          color: statusColor,
        ),
        title: Text(
          check.name,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Status: ${check.status} (${check.errors.length} errors, ${check.warnings.length} warnings)',
          style: TextStyle(color: statusColor, fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (check.errors.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Errors:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 4),
            ...check.errors.map(
              (e) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text('• $e', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
          if (check.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Warnings:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 4),
            ...check.warnings.map(
              (w) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text('• $w', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
