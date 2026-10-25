import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/focus_models.dart';
import '../../providers/focus_providers.dart';
import 'focus_diagnostics_dialog.dart';

/// Card detailing platform permissions, setup steps, capability breakdown, and diagnostics
class FocusPermissionsCard extends ConsumerWidget {
  const FocusPermissionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(focusModeProvider);
    final platform = ref.watch(focusPlatformChannelProvider);
    final theme = Theme.of(context);

    final isAndroid = !kIsWeb && Platform.isAndroid;
    final detailed = focus.detailedCapability;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Capabilities & Setup',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => FocusDiagnosticsDialog.show(context),
                  icon: const Icon(Icons.troubleshoot_rounded, size: 16),
                  tooltip: 'Run Diagnostics',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Truthful Capability Status Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: focus.capability.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: focus.capability.color.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    focus.capability == FocusCapability.active
                        ? Icons.check_circle_rounded
                        : (focus.capability == FocusCapability.needsPermission
                              ? Icons.warning_amber_rounded
                              : Icons.info_rounded),
                    color: focus.capability.color,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          focus.capability.label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: focus.capability.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          focus.capability.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (isAndroid) ...[
              // Separately reported capabilities
              Text(
                'Capability Breakdown',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              _buildCapabilityRow(
                icon: Icons.settings_accessibility_rounded,
                label: 'Usage Access (AppOps)',
                value: detailed.usageAccessGranted ? 'Granted' : 'Not Granted',
                isOk: detailed.usageAccessGranted,
              ),
              const SizedBox(height: 6),

              _buildCapabilityRow(
                icon: Icons.layers_rounded,
                label: 'Display Over Apps (Overlay)',
                value: detailed.overlayPermissionGranted
                    ? 'Granted'
                    : 'Not Granted',
                isOk: detailed.overlayPermissionGranted,
              ),
              const SizedBox(height: 6),

              _buildCapabilityRow(
                icon: Icons.security_rounded,
                label: 'Enforcement Service ("The Bouncer")',
                value: detailed.enforcementServiceRunning
                    ? 'Running (Active)'
                    : 'Stopped / Standby',
                isOk: detailed.enforcementServiceRunning,
              ),
              const SizedBox(height: 6),

              _buildCapabilityRow(
                icon: Icons.query_stats_rounded,
                label: 'Usage Events Query',
                value: detailed.usageQueryWorking
                    ? 'Working'
                    : (detailed.usageAccessGranted
                          ? 'No Events Yet'
                          : 'Blocked'),
                isOk: detailed.usageQueryWorking,
              ),
              const SizedBox(height: 6),

              _buildCapabilityRow(
                icon: Icons.notifications_active_outlined,
                label: 'Notification Permission',
                value: detailed.notificationPermission.label,
                isOk:
                    detailed.notificationPermission !=
                    NotificationPermissionStatus.denied,
              ),
              const SizedBox(height: 6),

              _buildCapabilityRow(
                icon: Icons.notifications_paused_outlined,
                label: 'Notification Channel',
                value: detailed.notificationChannel.label,
                isOk:
                    detailed.notificationChannel ==
                    NotificationChannelStatus.enabled,
              ),

              const SizedBox(height: 14),

              Text(
                'Android Permissions Setup',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '1. Usage Access: Allows TimeTable to detect foreground transitions for distracting apps.\n'
                '2. Display Over Other Apps: Required to auto-close distracting apps after 5 minutes and display the restriction shield.\n'
                '3. Notifications: Displays timely 1-minute warning heads-up alerts.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await platform.openUsageSettings();
                      ref.read(focusModeProvider.notifier).refreshCapability();
                    },
                    icon: const Icon(
                      Icons.settings_accessibility_rounded,
                      size: 16,
                    ),
                    label: const Text('Open Usage Settings'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await ref
                          .read(focusModeProvider.notifier)
                          .openOverlaySettings();
                      ref.read(focusModeProvider.notifier).refreshCapability();
                    },
                    icon: const Icon(Icons.layers_rounded, size: 16),
                    label: const Text('Display Over Apps'),
                  ),
                  if (detailed.notificationPermission ==
                      NotificationPermissionStatus.denied)
                    FilledButton.icon(
                      onPressed: () async {
                        await ref
                            .read(focusModeProvider.notifier)
                            .requestNotificationPermission();
                      },
                      icon: const Icon(
                        Icons.notifications_active_rounded,
                        size: 16,
                      ),
                      label: const Text('Allow Notifications'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => platform.openNotificationSettings(),
                      icon: const Icon(
                        Icons.notifications_active_outlined,
                        size: 16,
                      ),
                      label: const Text('Notification Settings'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => FocusDiagnosticsDialog.show(context),
                    icon: const Icon(Icons.troubleshoot_rounded, size: 16),
                    label: const Text('Run Diagnostics'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => platform.openAppSettings(),
                    icon: const Icon(Icons.app_settings_alt_outlined, size: 16),
                    label: const Text('App Details'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'How to Revoke Permissions:',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You can revoke permissions at any time: Open Android Settings > Apps > Special App Access > Usage Access > TimeTable and turn off access. TimeTable will immediately return to Reminder-Only mode.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ] else ...[
              Text(
                'Operating System Restrictions',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Non-Android operating systems restrict third-party consumer applications from observing or force-closing external processes. '
                'TimeTable honors these platform boundaries by providing schedule-based timers, gentle focus reminders, and session summaries entirely on-device.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => platform.openAppSettings(),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('System Notification Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isOk,
  }) {
    final color = isOk ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
