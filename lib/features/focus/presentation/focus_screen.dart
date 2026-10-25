import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_header_logo.dart';
import 'widgets/focus_allowlist_card.dart';
import 'widgets/focus_distracting_apps_card.dart';
import 'widgets/focus_grace_period_card.dart';
import 'widgets/focus_permissions_card.dart';
import 'widgets/focus_privacy_card.dart';
import 'widgets/focus_schedule_card.dart';
import 'widgets/focus_status_card.dart';

/// Screen providing comprehensive configuration and monitoring for Digital Wellbeing & Focus Mode
class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const AppHeaderLogo(),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'About Focus Mode',
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Title
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.self_improvement_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Digital Wellbeing & Focus Mode',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // 1. Status & Master Toggle
            const FocusStatusCard(),
            const SizedBox(height: 16),

            // 2. Schedule & Overlap Resolution
            const FocusScheduleCard(),
            const SizedBox(height: 16),

            // 3. Essential App Allowlist
            const FocusAllowlistCard(),
            const SizedBox(height: 16),

            // 4. Tracked Distracting Apps (Instagram, Facebook, etc.)
            const FocusDistractingAppsCard(),
            const SizedBox(height: 16),

            // 5. Grace Period & Break Settings
            const FocusGracePeriodCard(),
            const SizedBox(height: 16),

            // 6. Platform Capability & Permissions Setup
            const FocusPermissionsCard(),
            const SizedBox(height: 16),

            // 7. Privacy & Local Session History
            const FocusPrivacyCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('TimeTable Focus Mode'),
        content: const SingleChildScrollView(
          child: Text(
            'Focus Mode helps you maintain deep focus and restful sleep according to your personal timetable:\n\n'
            '• Morning Focus (05:00 – 09:00): Prepares you for the day with distraction-free morning study and exercise.\n'
            '• Night Focus (20:30 – 22:15): Evening wind-down to step away from screens and reflect.\n'
            '• Sleep Focus (22:15 – 05:15): Deep rest interval with overnight quiet hours.\n\n'
            'Overlap Priority: At 05:00–05:15, Morning and Sleep coincide. By default, Sleep Focus is prioritized to ensure you wake up naturally.\n\n'
            'Essential Apps: Calls, messaging, clock, maps, study tools (including YouTube), and banking remain permitted throughout focus hours.\n\n'
            'Distracting Apps: Time spent in Instagram, Facebook, and other monitored apps counts toward your grace period limit (default 5 mins). Once exceeded, a high-priority heads-up reminder invites you back to TimeTable.',
            style: TextStyle(fontSize: 13, height: 1.45),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }
}
