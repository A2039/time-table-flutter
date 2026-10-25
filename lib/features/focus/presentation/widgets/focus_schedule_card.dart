import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/focus_models.dart';
import '../../providers/focus_providers.dart';

/// Card displaying the 3 daily focus schedules, 05:00-05:15 overlap priority resolution, and edit dialogs
class FocusScheduleCard extends ConsumerWidget {
  const FocusScheduleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(focusModeProvider);
    final schedule = focus.schedule;
    final theme = Theme.of(context);

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
            // Header
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Daily Focus Schedules',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      _showEditScheduleDialog(context, ref, schedule),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Schedule Rows (4 Phases)
            _buildPhaseRow(
              context: context,
              phase: FocusPhase.morning,
              interval: schedule.morning,
              note: 'Full Restriction (0-second grace)',
            ),
            const Divider(height: 16),
            _buildDaytimeRow(
              context: context,
              theme: theme,
              start: schedule.morning.end.formatted,
              end: schedule.night.start.formatted,
              note: '5-Minute Grace Timer + Cooldown Lock',
            ),
            const Divider(height: 16),
            _buildPhaseRow(
              context: context,
              phase: FocusPhase.night,
              interval: schedule.night,
              note: 'Full Restriction (0-second grace)',
            ),
            const Divider(height: 16),
            _buildPhaseRow(
              context: context,
              phase: FocusPhase.sleep,
              interval: schedule.sleep,
              note: 'Full Restriction (Crosses midnight into Morning)',
            ),

            const SizedBox(height: 16),

            // Overlap Resolution Box (05:00 - 05:15)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.merge_type_rounded,
                        size: 18,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '05:00 – 05:15 Overlap Resolution',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.secondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Morning Focus (05:00–09:00) and Sleep Focus (22:15–05:15) coincide between 05:00 and 05:15. '
                    'Resolved to ${schedule.overlapPriority.displayName} priority by default.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Priority:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<FocusPhase>(
                          segments: const [
                            ButtonSegment<FocusPhase>(
                              value: FocusPhase.sleep,
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Sleep Focus'),
                              ),
                              icon: Icon(Icons.bedtime_outlined, size: 14),
                            ),
                            ButtonSegment<FocusPhase>(
                              value: FocusPhase.morning,
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Morning Focus'),
                              ),
                              icon: Icon(Icons.wb_sunny_outlined, size: 14),
                            ),
                          ],
                          selected: {schedule.overlapPriority},
                          onSelectionChanged: (newSelection) {
                            ref
                                .read(focusModeProvider.notifier)
                                .updateOverlapPriority(newSelection.first);
                          },
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _confirmRestoreDefaults(context, ref),
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('Restore Default Schedule'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseRow({
    required BuildContext context,
    required FocusPhase phase,
    required PhaseInterval interval,
    required String? note,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: phase.color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(phase.icon, size: 18, color: phase.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                phase.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (note != null)
                Text(
                  note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${interval.start.formatted} – ${interval.end.formatted}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaytimeRow({
    required BuildContext context,
    required ThemeData theme,
    required String start,
    required String end,
    required String note,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.wb_twilight_rounded,
            size: 18,
            color: Colors.teal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daytime Flexible Phase',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$start – $end',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showEditScheduleDialog(
    BuildContext context,
    WidgetRef ref,
    FocusSchedule current,
  ) {
    FocusTime mStart = current.morning.start;
    FocusTime mEnd = current.morning.end;
    FocusTime nStart = current.night.start;
    FocusTime nEnd = current.night.end;
    FocusTime sStart = current.sleep.start;
    FocusTime sEnd = current.sleep.end;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Focus Schedules'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTimePickerRow(
                    ctx: context,
                    title: 'Morning Focus',
                    color: FocusPhase.morning.color,
                    start: mStart,
                    end: mEnd,
                    onStartChanged: (t) => setState(() => mStart = t),
                    onEndChanged: (t) => setState(() => mEnd = t),
                  ),
                  const Divider(height: 24),
                  _buildTimePickerRow(
                    ctx: context,
                    title: 'Night Focus',
                    color: FocusPhase.night.color,
                    start: nStart,
                    end: nEnd,
                    onStartChanged: (t) => setState(() => nStart = t),
                    onEndChanged: (t) => setState(() => nEnd = t),
                  ),
                  const Divider(height: 24),
                  _buildTimePickerRow(
                    ctx: context,
                    title: 'Sleep Focus',
                    color: FocusPhase.sleep.color,
                    start: sStart,
                    end: sEnd,
                    onStartChanged: (t) => setState(() => sStart = t),
                    onEndChanged: (t) => setState(() => sEnd = t),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final updated = current.copyWith(
                    morning: PhaseInterval(start: mStart, end: mEnd),
                    night: PhaseInterval(start: nStart, end: nEnd),
                    sleep: PhaseInterval(start: sStart, end: sEnd),
                  );
                  ref.read(focusModeProvider.notifier).updateSchedule(updated);
                  Navigator.pop(ctx);
                },
                child: const Text('Save Schedule'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimePickerRow({
    required BuildContext ctx,
    required String title,
    required Color color,
    required FocusTime start,
    required FocusTime end,
    required ValueChanged<FocusTime> onStartChanged,
    required ValueChanged<FocusTime> onEndChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: start.toTimeOfDay(),
                  );
                  if (picked != null) {
                    onStartChanged(FocusTime.fromTimeOfDay(picked));
                  }
                },
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Start: ${start.formatted}'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('to'),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: end.toTimeOfDay(),
                  );
                  if (picked != null) {
                    onEndChanged(FocusTime.fromTimeOfDay(picked));
                  }
                },
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('End: ${end.formatted}'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _confirmRestoreDefaults(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Default Schedules?'),
        content: const Text(
          'This will reset your schedules to:\n'
          '• Morning: 05:00 – 09:00\n'
          '• Night: 20:30 – 22:15\n'
          '• Sleep: 22:15 – 05:15\n'
          '• 05:00–05:15 Overlap: Sleep Priority',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(focusModeProvider.notifier).restoreDefaultSchedule();
              Navigator.pop(ctx);
            },
            child: const Text('Restore Defaults'),
          ),
        ],
      ),
    );
  }
}
