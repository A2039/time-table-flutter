import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../shared/models/daily_status.dart';
import '../../../shared/models/timetable_activity.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/day_type_chip.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../daily_status/presentation/remark_editor_bottom_sheet.dart';
import '../../daily_status/presentation/status_editor_dialog.dart';

/// Main Home / Today screen displaying today's schedule, completion progress, and activities
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Timetable',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              AppDateUtils.formatDisplay(AppDateUtils.todayDateString()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.read(todayProvider.notifier).refresh(),
          ),
        ],
      ),
      body: todayAsync.when(
        loading: () => const AppLoading(
          message: 'Loading today\'s schedule and progress...',
        ),
        error: (err, stack) => AppErrorView(
          error: err,
          customTitle: 'Could Not Load Schedule',
          onRetry: () => ref.read(todayProvider.notifier).refresh(),
        ),
        data: (today) {
          if (today.timetable.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(todayProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 100),
                  EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'No Activities Scheduled',
                    subtitle: 'There are no activities configured in the timetable for today.',
                  ),
                ],
              ),
            );
          }

          // Calculate summary metrics
          final total = today.timetable.length;
          int onTime = 0;
          int late = 0;
          int notCompleted = 0;
          int unrecorded = 0;

          for (final activity in today.timetable) {
            final val = today.status.statuses[activity.srno.toString()];
            if (val == 'y' || val == 'Y') {
              onTime++;
            } else if (val == 'n' || val == 'N') {
              notCompleted++;
            } else if (val is int && val > 0) {
              late++;
            } else {
              unrecorded++;
            }
          }

          final completed = onTime + late;
          final completionPct = total > 0 ? (completed / total * 100.0) : 0.0;

          return RefreshIndicator(
            onRefresh: () => ref.read(todayProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Overview & Progress Card
                _buildProgressCard(
                  context: context,
                  today: today,
                  completionPct: completionPct,
                  onTime: onTime,
                  late: late,
                  notCompleted: notCompleted,
                  unrecorded: unrecorded,
                  total: total,
                ),
                const SizedBox(height: 16),

                // Daily Reflection / Remark Card
                _buildRemarkCard(context, ref, today),
                const SizedBox(height: 20),

                // Section Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Activities (${today.timetable.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Tap card to update status',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Activity List
                ...today.timetable.map((activity) {
                  final statusVal =
                      today.status.statuses[activity.srno.toString()];
                  return _buildActivityCard(
                    context,
                    ref,
                    activity,
                    statusVal,
                    today.date,
                  );
                }),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressCard({
    required BuildContext context,
    required TodayResponse today,
    required double completionPct,
    required int onTime,
    required int late,
    required int notCompleted,
    required int unrecorded,
    required int total,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              DayTypeChip(dayType: today.dayType),
              const Spacer(),
              if (!today.status.exists)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'No status recorded yet',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ProgressRing(
                percentage: completionPct,
                size: 96,
                strokeWidth: 8,
                subtitle: 'Completed',
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatRow(
                      context,
                      label: 'On Time',
                      count: onTime,
                      color: const Color(0xFF10B981),
                      icon: Icons.check_circle_rounded,
                    ),
                    const SizedBox(height: 6),
                    _buildStatRow(
                      context,
                      label: 'Completed Late',
                      count: late,
                      color: const Color(0xFFF59E0B),
                      icon: Icons.schedule_rounded,
                    ),
                    const SizedBox(height: 6),
                    _buildStatRow(
                      context,
                      label: 'Not Done',
                      count: notCompleted,
                      color: const Color(0xFFEF4444),
                      icon: Icons.cancel_rounded,
                    ),
                    const SizedBox(height: 6),
                    _buildStatRow(
                      context,
                      label: 'Unrecorded',
                      count: unrecorded,
                      color: const Color(0xFF64748B),
                      icon: Icons.radio_button_unchecked_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context, {
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          '$count',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRemarkCard(
    BuildContext context,
    WidgetRef ref,
    TodayResponse today,
  ) {
    final theme = Theme.of(context);
    final hasRemark = today.status.remark.trim().isNotEmpty;

    return InkWell(
      onTap: () {
        RemarkEditorBottomSheet.show(
          context: context,
          date: today.date,
          currentRemark: today.status.remark,
          onSave: (newRemark) async {
            await ref.read(todayProvider.notifier).updateRemark(newRemark);
          },
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Reflection',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasRemark ? today.status.remark : 'Tap to add your thoughts or reflections for today...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: hasRemark
                          ? FontStyle.normal
                          : FontStyle.italic,
                      color: hasRemark
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.edit_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(
    BuildContext context,
    WidgetRef ref,
    TimetableActivity activity,
    dynamic statusVal,
    String date,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          StatusEditorDialog.show(
            context: context,
            activityNo: activity.srno,
            activityTitle: activity.title,
            category: activity.category,
            time: activity.time,
            currentStatus: statusVal,
            onSave: (newStatus) async {
              await ref
                  .read(todayProvider.notifier)
                  .updateActivityStatus(activity.srno, newStatus);
            },
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      '${activity.srno}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                activity.category,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              activity.time,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                              ),
                            ),
                            if (activity.duration.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                '(${activity.duration})',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(statusValue: statusVal),
                ],
              ),
              if (activity.description.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 38),
                  child: Text(
                    activity.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
