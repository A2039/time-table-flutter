import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/models/history_record.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/day_type_chip.dart';

/// Screen displaying paginated historical activity logs with date range and schedule filters
class HistoryScreen extends ConsumerWidget {
  final void Function(String date)? onSelectDate;

  const HistoryScreen({super.key, this.onSelectDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(historyFilterStateProvider);
    final historyAsync = ref.watch(historyProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'History & Logs',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_rounded),
            tooltip: 'Filter Range',
            onPressed: () => _showDateRangePicker(context, ref, filter),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips (Presets & DayType)
          _buildFilterBar(context, ref, filter),
          const Divider(height: 1),

          // Main history list
          Expanded(
            child: historyAsync.when(
              loading: () =>
                  const AppLoading(message: 'Loading historical records...'),
              error: (err, stack) => AppErrorView(
                error: err,
                customTitle: 'Could Not Load History',
                onRetry: () => ref.invalidate(historyProvider),
              ),
              data: (historyResp) {
                if (historyResp.records.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(historyProvider),
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: const [
                        SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.history_rounded,
                          title: 'No Records in Date Range',
                          subtitle: 'No activity records match the selected date range and filter.',
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(historyProvider),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    children: [
                      // Range summary
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              'Showing ${historyResp.records.length} of ${historyResp.pagination.totalRecords} records',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Page ${historyResp.pagination.currentPage} of ${historyResp.pagination.totalPages}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // History Items
                      ...historyResp.records.map(
                        (rec) => _buildHistoryCard(context, ref, rec),
                      ),

                      // Pagination Controls
                      const SizedBox(height: 16),
                      _buildPaginationBar(
                        context,
                        ref,
                        historyResp.pagination,
                        filter,
                      ),
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

  Widget _buildFilterBar(
    BuildContext context,
    WidgetRef ref,
    HistoryFilterState filter,
  ) {
    final today = AppDateUtils.todayDateString();
    final past7Days = AppDateUtils.addDays(today, -7);
    final past30Days = AppDateUtils.addDays(today, -30);

    final is7Days = filter.from == past7Days && filter.to == today;
    final is30Days = filter.from == past30Days && filter.to == today;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Quick Range Presets
            FilterChip(
              label: const Text('Past 7 Days'),
              selected: is7Days,
              onSelected: (_) {
                ref
                    .read(historyFilterStateProvider.notifier)
                    .updateFilter(
                      filter.copyWith(from: past7Days, to: today, page: 1),
                    );
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Past 30 Days'),
              selected: is30Days,
              onSelected: (_) {
                ref
                    .read(historyFilterStateProvider.notifier)
                    .updateFilter(
                      filter.copyWith(from: past30Days, to: today, page: 1),
                    );
              },
            ),
            const SizedBox(width: 8),

            // DayType Filter Dropdown/Chips
            ChoiceChip(
              label: const Text('All Days'),
              selected: filter.dayType == 'all',
              onSelected: (_) {
                ref
                    .read(historyFilterStateProvider.notifier)
                    .updateFilter(filter.copyWith(dayType: 'all', page: 1));
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Weekdays'),
              selected: filter.dayType == 'weekday',
              onSelected: (_) {
                ref
                    .read(historyFilterStateProvider.notifier)
                    .updateFilter(filter.copyWith(dayType: 'weekday', page: 1));
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Weekends'),
              selected: filter.dayType == 'weekend',
              onSelected: (_) {
                ref
                    .read(historyFilterStateProvider.notifier)
                    .updateFilter(filter.copyWith(dayType: 'weekend', page: 1));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker(
    BuildContext context,
    WidgetRef ref,
    HistoryFilterState filter,
  ) async {
    final initialStart = AppDateUtils.parseDate(filter.from);
    final initialEnd = AppDateUtils.parseDate(filter.to);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
    );

    if (picked != null) {
      ref
          .read(historyFilterStateProvider.notifier)
          .updateFilter(
            filter.copyWith(
              from: AppDateUtils.formatDate(picked.start),
              to: AppDateUtils.formatDate(picked.end),
              page: 1,
            ),
          );
    }
  }

  Widget _buildHistoryCard(
    BuildContext context,
    WidgetRef ref,
    HistoryRecord rec,
  ) {
    final theme = Theme.of(context);
    final completed = rec.completedOnTime + rec.completedLate;
    final total = completed + rec.notCompleted + rec.notRecorded;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          ref.read(selectedDateProvider.notifier).setDate(rec.date);
          onSelectDate?.call(rec.date);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppDateUtils.formatDisplay(rec.date),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  DayTypeChip(dayType: rec.dayType, compact: true),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${rec.completionPercentage.toStringAsFixed(0)}% Completed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: rec.completionPercentage >= 75
                              ? const Color(0xFF10B981)
                              : rec.completionPercentage >= 50
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '($completed of $total activities)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (rec.completedLate > 0)
                    Text(
                      '${rec.completedLate} late',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              if (rec.status.remark.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Reflection: ${rec.status.remark}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationBar(
    BuildContext context,
    WidgetRef ref,
    PaginationInfo pagination,
    HistoryFilterState filter,
  ) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: pagination.hasPrev
                ? () {
                    ref
                        .read(historyFilterStateProvider.notifier)
                        .updateFilter(
                          filter.copyWith(page: pagination.currentPage - 1),
                        );
                  }
                : null,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Previous'),
          ),
          const SizedBox(width: 16),
          Text(
            'Page ${pagination.currentPage} / ${pagination.totalPages == 0 ? 1 : pagination.totalPages}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: pagination.hasNext
                ? () {
                    ref
                        .read(historyFilterStateProvider.notifier)
                        .updateFilter(
                          filter.copyWith(page: pagination.currentPage + 1),
                        );
                  }
                : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Next'),
          ),
        ],
      ),
    );
  }
}
