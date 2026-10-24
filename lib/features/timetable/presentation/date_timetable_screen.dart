import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../../core/utils/result_extensions.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/models/daily_status.dart';
import '../../../shared/models/timetable_activity.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/day_type_chip.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../daily_status/presentation/remark_editor_bottom_sheet.dart';
import '../../daily_status/presentation/status_editor_dialog.dart';

/// Screen allowing the user to browse timetable and status for any selected calendar date
class DateTimetableScreen extends ConsumerWidget {
  const DateTimetableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final timetableAsync = ref.watch(timetableForDateProvider(selectedDate));
    final statusAsync = ref.watch(statusForDateProvider(selectedDate));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Date Timetable',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              ref
                  .read(selectedDateProvider.notifier)
                  .setDate(AppDateUtils.todayDateString());
            },
            icon: const Icon(Icons.today_rounded, size: 16),
            label: const Text('Today'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Selector Bar
          _buildDateSelectorBar(context, ref, selectedDate),
          const Divider(height: 1),

          // Main Content
          Expanded(
            child: timetableAsync.when(
              loading: () => const AppLoading(
                message: 'Loading timetable for selected date...',
              ),
              error: (err, stack) => AppErrorView(
                error: err,
                customTitle: 'Unable to Load Timetable',
                onRetry: () {
                  ref.invalidate(timetableForDateProvider(selectedDate));
                  ref.invalidate(statusForDateProvider(selectedDate));
                },
              ),
              data: (timetableResp) {
                if (timetableResp.activities.isEmpty) {
                  return const EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'No Timetable Found',
                    subtitle:
                        'No schedule activities were found for this date.',
                  );
                }

                // Daily Status Data
                final dailyStatus =
                    statusAsync.valueOrNull ??
                    DailyStatus(
                      exists: false,
                      date: selectedDate,
                      dayType: timetableResp.dayType,
                    );

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(timetableForDateProvider(selectedDate));
                    ref.invalidate(statusForDateProvider(selectedDate));
                  },
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    children: [
                      // Header info
                      Row(
                        children: [
                          DayTypeChip(dayType: timetableResp.dayType),
                          const SizedBox(width: 8),
                          Text(
                            '${timetableResp.totalActivities} activities',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          if (!dailyStatus.exists)
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'No saved record',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Remark section
                      _buildRemarkCard(context, ref, selectedDate, dailyStatus),
                      const SizedBox(height: 16),

                      // Activities
                      ...timetableResp.activities.map((activity) {
                        final statusVal =
                            dailyStatus.statuses[activity.srno.toString()];
                        return _buildActivityCard(
                          context,
                          ref,
                          activity,
                          statusVal,
                          selectedDate,
                          dailyStatus,
                        );
                      }),
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelectorBar(
    BuildContext context,
    WidgetRef ref,
    String selectedDate,
  ) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous Day',
            onPressed: () {
              final prev = AppDateUtils.addDays(selectedDate, -1);
              ref.read(selectedDateProvider.notifier).setDate(prev);
            },
          ),
          Flexible(
            child: InkWell(
              onTap: () async {
                final initial = AppDateUtils.parseDate(selectedDate);
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  ref
                      .read(selectedDateProvider.notifier)
                      .setDate(AppDateUtils.formatDate(picked));
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppDateUtils.formatDisplay(selectedDate),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            selectedDate,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down_rounded),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next Day',
            onPressed: () {
              final next = AppDateUtils.addDays(selectedDate, 1);
              ref.read(selectedDateProvider.notifier).setDate(next);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRemarkCard(
    BuildContext context,
    WidgetRef ref,
    String date,
    DailyStatus status,
  ) {
    final theme = Theme.of(context);
    final hasRemark = status.remark.trim().isNotEmpty;

    return InkWell(
      onTap: () {
        RemarkEditorBottomSheet.show(
          context: context,
          date: date,
          currentRemark: status.remark,
          onSave: (newRemark) async {
            final repo = ref.read(statusRepositoryProvider);
            await repo.updateRemark(date: date, remark: newRemark);
            ref.invalidate(statusForDateProvider(date));
            ref.invalidate(todayProvider);
            ref.invalidate(dashboardProvider(date));
            ref.invalidate(historyProvider);
          },
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.notes_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasRemark
                    ? status.remark
                    : 'No daily reflection recorded (tap to add)',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: hasRemark ? FontStyle.normal : FontStyle.italic,
                  color: hasRemark
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.edit_outlined,
              size: 16,
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
    DailyStatus currentDailyStatus,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
              final repo = ref.read(statusRepositoryProvider);
              await repo.updateActivity(
                date: date,
                activityNo: activity.srno,
                status: newStatus,
              );
              ref.invalidate(statusForDateProvider(date));
              ref.invalidate(todayProvider);
              ref.invalidate(dashboardProvider(date));
              ref.invalidate(historyProvider);
            },
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${activity.category} • ${activity.time}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (activity.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        activity.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(statusValue: statusVal),
            ],
          ),
        ),
      ),
    );
  }
}
