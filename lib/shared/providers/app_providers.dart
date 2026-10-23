import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/redirect_aware_client.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/result_extensions.dart';
import '../../features/admin/data/admin_repository.dart';
import '../../features/daily_status/data/status_repository.dart';
import '../../features/dashboard/data/dashboard_repository.dart';
import '../../features/history/data/history_repository.dart';
import '../../features/settings/data/health_repository.dart';
import '../../features/timetable/data/timetable_repository.dart';
import '../models/daily_status.dart';
import '../models/dashboard_metrics.dart';
import '../models/health_response.dart';
import '../models/history_record.dart';
import '../models/timetable_activity.dart';
import '../services/storage_service.dart';

// ==========================================
// Base Infrastructure Providers
// ==========================================

/// Storage service provider (overridden in main after async initialization)
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError(
    'StorageService must be initialized and overridden in ProviderScope',
  );
});

/// Shared API Client provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ApiClient(httpClient: RedirectAwareClient(), storageService: storage);
});

/// Theme Mode state provider using Riverpod 3 Notifier
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final storage = ref.watch(storageServiceProvider);
    return storage.getThemeMode();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final storage = ref.read(storageServiceProvider);
    await storage.saveThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

// ==========================================
// Repositories
// ==========================================

final timetableRepositoryProvider = Provider<TimetableRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return TimetableRepository(client);
});

final statusRepositoryProvider = Provider<StatusRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return StatusRepository(client);
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return DashboardRepository(client);
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return HistoryRepository(client);
});

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return HealthRepository(client);
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return AdminRepository(client);
});

// ==========================================
// Today State (getToday endpoint)
// ==========================================

/// AsyncNotifier managing today's schedule and status with cache invalidation
class TodayNotifier extends AsyncNotifier<TodayResponse> {
  @override
  Future<TodayResponse> build() async {
    final repo = ref.watch(timetableRepositoryProvider);
    return repo.getToday();
  }

  /// Manually refresh today's data
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(timetableRepositoryProvider);
      return repo.getToday();
    });
  }

  /// Update single activity status and refresh
  Future<void> updateActivityStatus(int activityNo, dynamic status) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final statusRepo = ref.read(statusRepositoryProvider);
    final updatedDailyStatus = await statusRepo.updateActivity(
      date: current.date,
      activityNo: activityNo,
      status: status,
    );

    // Update state directly and invalidate related date providers
    state = AsyncValue.data(
      TodayResponse(
        date: current.date,
        dayType: current.dayType,
        timetable: current.timetable,
        status: updatedDailyStatus,
      ),
    );

    // Invalidate dashboard and history caches
    ref.invalidate(dashboardProvider(current.date));
    ref.invalidate(historyProvider);
  }

  /// Update daily remark and refresh
  Future<void> updateRemark(String remark) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final statusRepo = ref.read(statusRepositoryProvider);
    final updatedDailyStatus = await statusRepo.updateRemark(
      date: current.date,
      remark: remark,
    );

    state = AsyncValue.data(
      TodayResponse(
        date: current.date,
        dayType: current.dayType,
        timetable: current.timetable,
        status: updatedDailyStatus,
      ),
    );

    ref.invalidate(dashboardProvider(current.date));
    ref.invalidate(historyProvider);
  }
}

final todayProvider = AsyncNotifierProvider<TodayNotifier, TodayResponse>(
  TodayNotifier.new,
);

// ==========================================
// Date Picker & Timetable for Selected Date
// ==========================================

class SelectedDateNotifier extends Notifier<String> {
  @override
  String build() => AppDateUtils.todayDateString();

  void setDate(String date) => state = date;
}

/// Currently selected date string (YYYY-MM-DD)
final selectedDateProvider = NotifierProvider<SelectedDateNotifier, String>(
  SelectedDateNotifier.new,
);

/// Timetable for a given date
final timetableForDateProvider =
    FutureProvider.family<TimetableResponse, String>((ref, date) async {
      final repo = ref.watch(timetableRepositoryProvider);
      return repo.getTimetable(date);
    });

/// Daily status for a given date
final statusForDateProvider = FutureProvider.family<DailyStatus, String>((
  ref,
  date,
) async {
  final repo = ref.watch(statusRepositoryProvider);
  return repo.getStatus(date);
});

// ==========================================
// Dashboard Provider
// ==========================================

class DashboardDateNotifier extends Notifier<String> {
  @override
  String build() => AppDateUtils.todayDateString();

  void setDate(String date) => state = date;
}

final dashboardSelectedDateProvider =
    NotifierProvider<DashboardDateNotifier, String>(DashboardDateNotifier.new);

final dashboardProvider = FutureProvider.family<DashboardResponse, String>((
  ref,
  date,
) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getDashboard(date);
});

// ==========================================
// History Filters and Provider
// ==========================================

class HistoryFilterState {
  final String from;
  final String to;
  final String dayType; // 'all', 'weekday', 'weekend'
  final int page;
  final int pageSize;

  const HistoryFilterState({
    required this.from,
    required this.to,
    this.dayType = 'all',
    this.page = 1,
    this.pageSize = 20,
  });

  HistoryFilterState copyWith({
    String? from,
    String? to,
    String? dayType,
    int? page,
    int? pageSize,
  }) {
    return HistoryFilterState(
      from: from ?? this.from,
      to: to ?? this.to,
      dayType: dayType ?? this.dayType,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

class HistoryFilterNotifier extends Notifier<HistoryFilterState> {
  @override
  HistoryFilterState build() {
    final today = AppDateUtils.todayDateString();
    final past30Days = AppDateUtils.addDays(today, -30);
    return HistoryFilterState(
      from: past30Days,
      to: today,
      dayType: 'all',
      page: 1,
      pageSize: 20,
    );
  }

  void updateFilter(HistoryFilterState newState) => state = newState;
}

final historyFilterStateProvider =
    NotifierProvider<HistoryFilterNotifier, HistoryFilterState>(
      HistoryFilterNotifier.new,
    );

final historyProvider = FutureProvider<HistoryResponse>((ref) async {
  final filter = ref.watch(historyFilterStateProvider);
  final repo = ref.watch(historyRepositoryProvider);
  return repo.getHistory(
    from: filter.from,
    to: filter.to,
    page: filter.page,
    pageSize: filter.pageSize,
    dayType: filter.dayType == 'all' ? null : filter.dayType,
  );
});

// ==========================================
// Health & Connectivity Provider
// ==========================================

final healthProvider = FutureProvider<HealthResponse>((ref) async {
  final repo = ref.watch(healthRepositoryProvider);
  return repo.checkHealth();
});
