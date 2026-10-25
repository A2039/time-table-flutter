import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/focus_models.dart';
import '../../providers/focus_providers.dart';

/// Interactive modal dialog displaying system diagnostics, permission statuses, and test tools
class FocusDiagnosticsDialog extends ConsumerStatefulWidget {
  const FocusDiagnosticsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => const FocusDiagnosticsDialog(),
    );
  }

  @override
  ConsumerState<FocusDiagnosticsDialog> createState() =>
      _FocusDiagnosticsDialogState();
}

class _FocusDiagnosticsDialogState
    extends ConsumerState<FocusDiagnosticsDialog> {
  FocusDiagnosticsReport? _report;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final report = await ref
          .read(focusModeProvider.notifier)
          .runDiagnostics();
      if (mounted) {
        setState(() {
          _report = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendTestNotification() async {
    final success = await ref
        .read(focusModeProvider.notifier)
        .sendTestNotification();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Test notification posted! Check your notification shade.' : 'Failed to post test notification. Check notification permissions & channel status.',
        ),
        backgroundColor: success ? Colors.teal : Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _copyReport() async {
    if (_report == null) return;
    await Clipboard.setData(
      ClipboardData(text: _report!.toFormattedMarkdown()),
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Diagnostic report copied to clipboard (zero personal data included).',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focus = ref.watch(focusModeProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.troubleshoot_rounded,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Focus Diagnostics', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const SizedBox(
                height: 180,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Inspecting Android APIs & Permissions...',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            : _errorMessage != null
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('Error running diagnostics: $_errorMessage'),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Device info box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDeviceRow(
                            'Device',
                            '${_report!.manufacturer} ${_report!.model}',
                          ),
                          const SizedBox(height: 4),
                          _buildDeviceRow(
                            'Android OS',
                            'API ${_report!.sdkInt} (Android ${_report!.androidVersion})',
                          ),
                          const SizedBox(height: 4),
                          _buildDeviceRow(
                            'Grace Limit',
                            '${focus.gracePeriodMinutes} mins per app in focus window',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Checks list
                    _buildCheckItem(
                      label: 'Usage Access (AppOps)',
                      status: _report!.usageAccessGranted
                          ? 'Granted'
                          : 'Not Granted',
                      isSuccess: _report!.usageAccessGranted,
                      description: _report!.usageAccessGranted
                          ? 'System permits foreground app observation.'
                          : 'Grant access in Android Usage Settings.',
                    ),
                    const SizedBox(height: 8),

                    _buildCheckItem(
                      label: 'Usage Events Query',
                      status: _report!.usageQueryWorking
                          ? 'Working'
                          : 'No Data / Restricted',
                      isSuccess: _report!.usageQueryWorking,
                      description: _report!.usageQueryWorking
                          ? 'UsageStatsManager.queryEvents returns real events.'
                          : 'Requires Usage Access permission to read events.',
                    ),
                    const SizedBox(height: 8),

                    _buildCheckItem(
                      label: 'POST_NOTIFICATIONS (Android 13+)',
                      status: _report!.runtimePermissionGranted
                          ? 'Granted'
                          : 'Denied / Missing',
                      isSuccess: _report!.runtimePermissionGranted,
                      description: _report!.runtimePermissionGranted
                          ? 'App can post heads-up notification alerts.'
                          : 'Notification runtime permission is required.',
                    ),
                    const SizedBox(height: 8),

                    _buildCheckItem(
                      label: 'Display Over Apps (Overlay)',
                      status: _report!.overlayPermissionGranted
                          ? 'Granted'
                          : 'Not Granted',
                      isSuccess: _report!.overlayPermissionGranted,
                      description: _report!.overlayPermissionGranted
                          ? 'Overlay granted. Immediate full-screen block shield is operational.'
                          : 'Required for forceful auto-close and block shield on Android 10+.',
                    ),
                    const SizedBox(height: 8),

                    _buildCheckItem(
                      label: 'Enforcement Service ("The Bouncer")',
                      status: _report!.enforcementServiceRunning
                          ? 'Running'
                          : 'Stopped / Standby',
                      isSuccess: _report!.enforcementServiceRunning,
                      description: _report!.enforcementServiceRunning
                          ? 'Background enforcement active with 1.5s tick and screen-off battery preservation.'
                          : 'Service runs whenever Restriction Mode is enabled.',
                    ),
                    const SizedBox(height: 8),

                    _buildCheckItem(
                      label: "Today's Blocks & Cooldowns",
                      status:
                          '${_report!.todayBlocksCount} blocks / ${_report!.activeCooldownsCount} active cooldowns',
                      isSuccess: true,
                      neutralColor: Colors.blueAccent,
                      description: 'Auto-closed sessions recorded strictly locally on device.',
                    ),
                    const SizedBox(height: 8),

                    _buildCheckItem(
                      label: 'Notification Channel',
                      status: _report!.channelStatus,
                      isSuccess: _report!.channelStatus == 'created_enabled',
                      description: _report!.channelStatus == 'created_enabled'
                          ? 'High-importance focus channel is active.'
                          : 'Channel is blocked or disabled in system settings.',
                    ),
                    const SizedBox(height: 8),

                    _buildCheckItem(
                      label: 'Battery Restrictions',
                      status: _report!.batteryOptimizationIgnored
                          ? 'Unrestricted'
                          : 'Standard (Optimized)',
                      isSuccess: true, // Non-fatal
                      neutralColor: Colors.blueGrey,
                      description: _report!.batteryOptimizationIgnored
                          ? 'OEM battery manager will not kill background tasks.'
                          : 'Standard battery optimization. Background tracking may pause if phone is in deep sleep.',
                    ),

                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            await ref
                                .read(focusModeProvider.notifier)
                                .showTestBlockShield(
                                  appName: 'Instagram',
                                  packageName: 'com.instagram.android',
                                  reason:
                                      'Test Block Shield — Demonstration Mode',
                                );
                          },
                          icon: const Icon(Icons.shield_rounded, size: 16),
                          label: const Text('Test Block Shield Now'),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _sendTestNotification,
                          icon: const Icon(
                            Icons.notifications_active_outlined,
                            size: 16,
                          ),
                          label: const Text('Send Test Notification'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        if (_report != null)
          TextButton.icon(
            onPressed: _copyReport,
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Report'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDeviceRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckItem({
    required String label,
    required String status,
    required bool isSuccess,
    required String description,
    Color? neutralColor,
  }) {
    final color =
        neutralColor ??
        (isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444));
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              description,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
