import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/redirect_aware_client.dart';
import '../../../shared/providers/app_providers.dart';
import '../../admin/presentation/admin_screen.dart';

/// Application settings, theme preferences, API connectivity test, and secure token configuration
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _secretTapCount = 0;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final healthAsync = ref.watch(healthProvider);
    final storage = ref.watch(storageServiceProvider);
    final theme = Theme.of(context);

    final showAdminEntry = AppConfig.enableAdmin || _secretTapCount >= 7;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings & Preferences',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section: Appearance
          _buildSectionHeader('Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: RadioGroup<ThemeMode>(
                groupValue: themeMode,
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  }
                },
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      title: Text('System Default'),
                      subtitle: Text('Matches your device light/dark appearance'),
                      secondary: Icon(Icons.brightness_auto_rounded),
                    ),
                    Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      title: Text('Light Mode'),
                      secondary: Icon(Icons.light_mode_rounded),
                    ),
                    Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      title: Text('Dark Mode'),
                      secondary: Icon(Icons.dark_mode_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section: Backend Connectivity
          _buildSectionHeader('Backend & Database Connectivity'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.cloud_done_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'API Health Check',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        tooltip: 'Check Connection',
                        onPressed: () => ref.invalidate(healthProvider),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  healthAsync.when(
                    loading: () => const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Checking backend and database reachability...'),
                      ],
                    ),
                    error: (err, _) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: theme.colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Connection check failed: $err',
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    data: (health) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHealthRow(
                          'Overall Status',
                          health.status.toUpperCase(),
                          health.isHealthy
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                        const SizedBox(height: 6),
                        _buildHealthRow(
                          'Google Sheets Database',
                          health.database.connected
                              ? 'Connected'
                              : 'Disconnected',
                          health.database.connected
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                        const SizedBox(height: 6),
                        _buildHealthRow(
                          'Expected Sheets Present',
                          health.database.expectedSheetsPresent
                              ? 'Yes (Verified)'
                              : 'Missing sheets',
                          health.database.expectedSheetsPresent
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(height: 6),
                        _buildHealthRow(
                          'Environment',
                          health.environment,
                          theme.colorScheme.onSurface,
                        ),
                        const SizedBox(height: 6),
                        _buildHealthRow(
                          'Timezone',
                          health.timeZone,
                          theme.colorScheme.onSurface,
                        ),
                        if (health.database.message.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            health.database.message,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section: API Configuration
          _buildSectionHeader('API Configuration'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.key_rounded),
                  title: const Text('User API Token'),
                  subtitle: const Text(
                    'Stored securely in platform encrypted storage',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showTokenDialog(storage),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.link_rounded),
                  title: const Text('Web App Base URL'),
                  subtitle: Text(
                    RedirectAwareClient.redactSecrets(storage.getBaseUrl()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showBaseUrlDialog(context, storage),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Admin Diagnostics (Conditional)
          if (showAdminEntry) ...[
            _buildSectionHeader('Administration'),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Color(0xFF4F46E5),
                ),
                title: const Text('Database Integrity Audit'),
                subtitle: const Text(
                  'Run full read-only database schema & sheet validation',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // App Information
          GestureDetector(
            onTap: () {
              setState(() {
                _secretTapCount++;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(
                    'Time Table App v1.0.0',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Environment: ${AppConfig.environment} • Timezone: ${AppConfig.appTimeZone}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Backend: Google Apps Script Web App & Google Sheets',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildHealthRow(String label, String value, Color statusColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
        ),
      ],
    );
  }

  Future<void> _showTokenDialog(dynamic storage) async {
    final current = await storage.getApiToken();
    if (!mounted) return;

    final controller = TextEditingController(text: current);
    bool obscure = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('User API Token'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the personal user API token configured in your backend Script Properties (API_TOKEN).',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'API Token',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await storage.saveApiToken(controller.text.trim());
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('API Token saved securely.')),
                  );
                  ref.invalidate(todayProvider);
                  ref.invalidate(historyProvider);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBaseUrlDialog(BuildContext context, dynamic storage) async {
    final current = storage.getBaseUrl();
    final controller = TextEditingController(text: current);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Web App Base URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the Google Apps Script Web App URL ending with /exec:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Deployment URL',
                hintText: 'https://script.google.com/macros/s/.../exec',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await storage.resetBaseUrl();
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Base URL reset to default.')),
                );
              }
            },
            child: const Text('Reset Default'),
          ),
          FilledButton(
            onPressed: () async {
              await storage.saveBaseUrl(controller.text.trim());
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Base URL updated.')),
                );
                ref.invalidate(todayProvider);
                ref.invalidate(healthProvider);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
