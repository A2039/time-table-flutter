import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/models/dashboard_metrics.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/day_type_chip.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/status_badge.dart';

/// Rich analytics and visualization dashboard based strictly on real API response data
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(dashboardSelectedDateProvider);
    final dashboardAsync = ref.watch(dashboardProvider(selectedDate));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Analytics & Dashboard',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_rounded),
            tooltip: 'Jump to Today',
            onPressed: () {
              ref
                  .read(dashboardSelectedDateProvider.notifier)
                  .setDate(AppDateUtils.todayDateString());
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Pick Date',
            onPressed: () async {
              final initial = AppDateUtils.parseDate(selectedDate);
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                ref
                    .read(dashboardSelectedDateProvider.notifier)
                    .setDate(AppDateUtils.formatDate(picked));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selection strip
          _buildDateHeader(context, ref, selectedDate),
          const Divider(height: 1),

          Expanded(
            child: dashboardAsync.when(
              loading: () =>
                  const AppLoading(message: 'Calculating dashboard metrics...'),
              error: (err, stack) => AppErrorView(
                error: err,
                customTitle: 'Unable to Load Dashboard',
                onRetry: () => ref.invalidate(dashboardProvider(selectedDate)),
              ),
              data: (dashboard) {
                if (!dashboard.hasSavedStatus &&
                    dashboard.metrics.totalRecorded == 0) {
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(dashboardProvider(selectedDate)),
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 60),
                        EmptyState(
                          icon: Icons.bar_chart_rounded,
                          title:
                              'No Data for ${AppDateUtils.formatShort(selectedDate)}',
                          subtitle:
                              'No activity status has been recorded yet for this date. '
                              'Record activities in the Timetable tab to see metrics and charts.',
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(dashboardProvider(selectedDate)),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    children: [
                      // Header Badge & Date
                      Row(
                        children: [
                          DayTypeChip(dayType: dashboard.dayType),
                          const Spacer(),
                          Text(
                            '${dashboard.metrics.totalActivities} Total Activities',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // KPI Cards Grid
                      _buildKpiGrid(context, dashboard.metrics),
                      const SizedBox(height: 20),

                      // Pie / Donut Chart Breakdown
                      _buildChartCard(context, dashboard.metrics),
                      const SizedBox(height: 20),

                      // Remark card if present
                      if (dashboard.remark.trim().isNotEmpty) ...[
                        _buildDailyRemarkCard(context, dashboard.remark),
                        const SizedBox(height: 20),
                      ],

                      // Activity Status Breakdown
                      if (dashboard.activities.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Activity Breakdown (${dashboard.activities.length})',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${dashboard.metrics.totalCompleted} Completed',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...dashboard.activities.map(
                          (act) => _buildActivityStatusItem(context, act),
                        ),
                      ],
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

  Widget _buildDateHeader(
    BuildContext context,
    WidgetRef ref,
    String selectedDate,
  ) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () {
              ref
                  .read(dashboardSelectedDateProvider.notifier)
                  .setDate(AppDateUtils.addDays(selectedDate, -1));
            },
          ),
          Expanded(
            child: Column(
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
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () {
              ref
                  .read(dashboardSelectedDateProvider.notifier)
                  .setDate(AppDateUtils.addDays(selectedDate, 1));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(BuildContext context, DashboardMetrics metrics) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'Completion Rate',
                value: '${metrics.completionPercentage.toStringAsFixed(1)}%',
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF10B981),
                subtitle:
                    '${metrics.totalCompleted} of ${metrics.totalActivities} completed',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                title: 'Recorded Rate',
                value: '${metrics.recordedPercentage.toStringAsFixed(1)}%',
                icon: Icons.edit_note_rounded,
                color: const Color(0xFF3B82F6),
                subtitle:
                    '${metrics.totalRecorded} of ${metrics.totalActivities} logged',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'Late Minutes',
                value: '${metrics.totalLateMinutes} m',
                icon: Icons.timer_outlined,
                color: const Color(0xFFF59E0B),
                subtitle: '${metrics.completedLate} activities delayed',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                title: 'Not Completed',
                value: '${metrics.notCompleted}',
                icon: Icons.cancel_outlined,
                color: const Color(0xFFEF4444),
                subtitle: 'Missed activities',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartCard(BuildContext context, DashboardMetrics metrics) {
    final theme = Theme.of(context);
    final total = metrics.totalActivities;

    final onTimeVal = metrics.completedOnTime.toDouble();
    final lateVal = metrics.completedLate.toDouble();
    final notCompVal = metrics.notCompleted.toDouble();
    final unrecVal = metrics.notRecorded.toDouble();

    final sections = <PieChartSectionData>[];

    if (onTimeVal > 0) {
      sections.add(
        PieChartSectionData(
          color: const Color(0xFF10B981),
          value: onTimeVal,
          title: '${(onTimeVal / total * 100).toStringAsFixed(0)}%',
          radius: 46,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    if (lateVal > 0) {
      sections.add(
        PieChartSectionData(
          color: const Color(0xFFF59E0B),
          value: lateVal,
          title: '${(lateVal / total * 100).toStringAsFixed(0)}%',
          radius: 46,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    if (notCompVal > 0) {
      sections.add(
        PieChartSectionData(
          color: const Color(0xFFEF4444),
          value: notCompVal,
          title: '${(notCompVal / total * 100).toStringAsFixed(0)}%',
          radius: 46,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    if (unrecVal > 0) {
      sections.add(
        PieChartSectionData(
          color: const Color(0xFF94A3B8),
          value: unrecVal,
          title: '${(unrecVal / total * 100).toStringAsFixed(0)}%',
          radius: 46,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Status Breakdown',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: sections.isEmpty
                ? const Center(child: Text('No data recorded'))
                : PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 40,
                      sectionsSpace: 3,
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildLegendItem(
                'On Time (${metrics.completedOnTime})',
                const Color(0xFF10B981),
              ),
              _buildLegendItem(
                'Late (${metrics.completedLate})',
                const Color(0xFFF59E0B),
              ),
              _buildLegendItem(
                'Not Done (${metrics.notCompleted})',
                const Color(0xFFEF4444),
              ),
              _buildLegendItem(
                'Unrecorded (${metrics.notRecorded})',
                const Color(0xFF94A3B8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildDailyRemarkCard(BuildContext context, String remark) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notes_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Reflection Note',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(remark, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildActivityStatusItem(BuildContext context, DashboardActivity act) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                '${act.srno}',
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
                    act.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
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
                          act.category,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                          ),
                        ),
                      ),
                      if (act.time.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              act.time,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (act.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      act.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(statusValue: act.status, compact: true),
          ],
        ),
      ),
    );
  }
}
