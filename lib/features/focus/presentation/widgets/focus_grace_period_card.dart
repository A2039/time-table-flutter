import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/focus_providers.dart';

/// Card configuring distraction Grace Period, Emergency Break duration, and notifications
class FocusGracePeriodCard extends ConsumerWidget {
  const FocusGracePeriodCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(focusModeProvider);
    final theme = Theme.of(context);

    final graceOptions = [1, 3, 5, 10];
    final cooldownOptions = [30, 60, 120];
    final breakOptions = [5, 10];

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
                  Icons.timelapse_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Daytime Guard & Enforcement Rules',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Daytime 5-Minute Grace Timer Toggle
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Daytime 5-Minute Grace Timer',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                'During daytime hours (9:00 AM – 8:30 PM), opening a distracting app gives you 5 minutes before auto-closing and locking into cooldown.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              value: focus.daytimeGraceEnabled,
              onChanged: (val) {
                ref.read(focusModeProvider.notifier).toggleDaytimeGrace(val);
              },
            ),

            if (focus.daytimeGraceEnabled) ...[
              const SizedBox(height: 8),
              Text(
                'Countdown Limit Duration',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: graceOptions.map((mins) {
                  final isSelected = focus.gracePeriodMinutes == mins;
                  return ChoiceChip(
                    label: Text(mins == 5 ? '5m (Default)' : '${mins}m'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        ref
                            .read(focusModeProvider.notifier)
                            .setGracePeriod(mins);
                      }
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),
              Text(
                'Cooldown Lock Duration (After limit expires)',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: cooldownOptions.map((mins) {
                  final isSelected = focus.cooldownMinutes == mins;
                  return ChoiceChip(
                    label: Text(mins == 60 ? '60m (Default)' : '${mins}m'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        ref
                            .read(focusModeProvider.notifier)
                            .setCooldownMinutes(mins);
                      }
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Scheduled Restriction Master Toggle
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Scheduled Full Restriction',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                'Enforces 0-second grace during Morning (5–9 AM), Night (8:30–10:15 PM), and Sleep (10:15 PM–5:15 AM) phases.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              value: focus.scheduledRestrictionEnabled,
              onChanged: (val) {
                ref
                    .read(focusModeProvider.notifier)
                    .toggleScheduledRestriction(val);
              },
            ),

            // Strict Whitelist Mode Toggle
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Strict Whitelist Mode',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                'During Full Restriction phases, block ALL apps except the VIP Exception Allowlist (instead of blocking only listed distracting apps).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              value: focus.strictWhitelistMode,
              onChanged: (val) {
                ref
                    .read(focusModeProvider.notifier)
                    .toggleStrictWhitelistMode(val);
              },
            ),

            // Browser Loophole Protection Toggle
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Browser Loophole Protection',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                'Enforces a 5-minute timer on Chrome & web browsers during Full Restriction to prevent accessing social media via the browser.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              value: focus.browserLoopholeProtection,
              onChanged: (val) {
                ref
                    .read(focusModeProvider.notifier)
                    .toggleBrowserLoopholeProtection(val);
              },
            ),

            // YouTube Study Check-In Toggle
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'YouTube 30-Minute Study Check-In',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                'Prompt every 30 minutes of continuous YouTube use to check whether you are watching a study lecture or scrolling Shorts.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              value: focus.youtubeStudyCheck,
              onChanged: (val) {
                ref
                    .read(focusModeProvider.notifier)
                    .toggleYoutubeStudyCheck(val);
              },
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Emergency Break Duration
            Text(
              'Emergency Break Duration',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Configures duration for deliberate breaks taken via the Emergency Override button.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: breakOptions.map((mins) {
                final isSelected = focus.overrideDurationMinutes == mins;
                return ChoiceChip(
                  label: Text(mins == 5 ? '5 min (Default)' : '$mins min'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      ref
                          .read(focusModeProvider.notifier)
                          .setOverrideDuration(mins);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
