import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetable_app/core/widgets/app_error_view.dart';
import 'package:timetable_app/core/widgets/skeleton/skeleton.dart';
import 'package:timetable_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:timetable_app/features/history/presentation/history_screen.dart';
import 'package:timetable_app/features/home/presentation/home_screen.dart';
import 'package:timetable_app/features/settings/presentation/settings_screen.dart';
import 'package:timetable_app/features/timetable/presentation/date_timetable_screen.dart';
import 'package:timetable_app/shared/models/daily_status.dart';
import 'package:timetable_app/shared/models/dashboard_metrics.dart';
import 'package:timetable_app/shared/models/health_response.dart';
import 'package:timetable_app/shared/models/history_record.dart';
import 'package:timetable_app/shared/models/timetable_activity.dart';
import 'package:timetable_app/shared/providers/app_providers.dart';

void main() {
  group('Skeleton Primitive & Core Components', () {
    testWidgets(
      'SkeletonBox renders with specified width, height, and radius',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Shimmer(
                child: SkeletonBox(
                  width: 120,
                  height: 40,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        );

        final boxFinder = find.byType(SkeletonBox);
        expect(boxFinder, findsOneWidget);
        final size = tester.getSize(boxFinder);
        expect(size.width, 120);
        expect(size.height, 40);
      },
    );

    testWidgets('SkeletonCircle renders as circular shape', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Shimmer(child: SkeletonCircle(size: 64))),
        ),
      );

      final circleFinder = find.byType(SkeletonCircle);
      expect(circleFinder, findsOneWidget);
      final size = tester.getSize(circleFinder);
      expect(size.width, 64);
      expect(size.height, 64);
    });

    testWidgets('SkeletonText renders single and multiple lines', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Shimmer(
              child: Column(
                children: [
                  SkeletonText(lines: 1, width: 100, lineHeight: 16),
                  SkeletonText(lines: 3, width: 200, lineHeight: 14),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonText), findsNWidgets(2));
      expect(find.byType(SkeletonBox), findsAtLeastNWidgets(4));
    });

    testWidgets('SkeletonCard and SkeletonListItem render correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Shimmer(
              child: Column(
                children: [
                  SkeletonCard(child: Text('Card Content')),
                  SkeletonListItem(),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonCard), findsAtLeastNWidgets(2));
      expect(find.byType(SkeletonListItem), findsOneWidget);
    });

    testWidgets('Reduced motion stops animation and uses static placeholder', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: Shimmer(child: SkeletonBox(width: 80, height: 20)),
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonBox), findsOneWidget);
      // Advance frames without throwing
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SkeletonBox), findsOneWidget);
    });

    testWidgets('Shimmer provides accessibility semantic label', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Shimmer(
              semanticLabel: 'Loading content',
              child: SkeletonBox(width: 100, height: 20),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Loading content'), findsOneWidget);
    });

    testWidgets('Adapts to Dark theme without throwing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: Shimmer(child: SkeletonBox(width: 100, height: 20)),
          ),
        ),
      );

      expect(find.byType(SkeletonBox), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Page-level Skeletons', () {
    testWidgets('HomeSkeleton renders overview ring, stats, and list items', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeSkeleton())),
      );

      expect(find.byType(HomeSkeleton), findsOneWidget);
      expect(find.byType(SkeletonCircle), findsAtLeastNWidgets(2));
      expect(find.byType(SkeletonListItem), findsNWidgets(4));
    });

    testWidgets(
      'TimetableSkeleton renders header, reflection, and list items',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: TimetableSkeleton())),
        );

        expect(find.byType(TimetableSkeleton), findsOneWidget);
        expect(find.byType(SkeletonListItem), findsNWidgets(5));
      },
    );

    testWidgets(
      'DashboardSkeleton renders KPI grid, chart ring, and breakdown',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: DashboardSkeleton())),
        );

        expect(find.byType(DashboardSkeleton), findsOneWidget);
        expect(find.byType(SkeletonCard), findsAtLeastNWidgets(5));
        expect(find.byType(SkeletonListItem), findsNWidgets(3));
      },
    );

    testWidgets('HistorySkeleton renders range summary and history cards', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HistorySkeleton())),
      );

      expect(find.byType(HistorySkeleton), findsOneWidget);
      expect(find.byType(SkeletonCard), findsNWidgets(5));
    });

    testWidgets(
      'HealthStatusSkeleton and PaginationLoadingFooter render properly',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [HealthStatusSkeleton(), PaginationLoadingFooter()],
              ),
            ),
          ),
        );

        expect(find.byType(HealthStatusSkeleton), findsOneWidget);
        expect(find.byType(PaginationLoadingFooter), findsOneWidget);
      },
    );

    testWidgets('AdminAuditSkeleton renders summary card and audit checks', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AdminAuditSkeleton())),
      );

      expect(find.byType(AdminAuditSkeleton), findsOneWidget);
      expect(find.byType(SkeletonCard), findsNWidgets(5));
    });
  });

  group('Screen State Integration Tests', () {
    testWidgets(
      'HomeScreen displays HomeSkeleton while todayProvider is loading, then content',
      (tester) async {
        final completer = Completer<TodayResponse>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              todayProvider.overrideWith(
                () => _CompleterTodayNotifier(completer.future),
              ),
            ],
            child: const MaterialApp(home: HomeScreen()),
          ),
        );

        // Verify initial loading state shows HomeSkeleton
        expect(find.byType(HomeSkeleton), findsOneWidget);
        expect(find.text('Morning Exercise'), findsNothing);

        // Complete data
        completer.complete(
          const TodayResponse(
            date: '2026-10-24',
            dayType: 'weekday',
            timetable: [
              TimetableActivity(
                srno: 1,
                category: 'Physical',
                time: '06:00 - 07:00',
                duration: '60 min',
                timePeriod: 'Morning Exercise',
                description: 'Daily workout',
              ),
            ],
            status: DailyStatus(
              exists: true,
              date: '2026-10-24',
              dayType: 'weekday',
              statuses: {'1': 'y'},
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify skeleton is gone and content is displayed
        expect(find.byType(HomeSkeleton), findsNothing);
        expect(find.text('Morning Exercise'), findsOneWidget);
      },
    );

    testWidgets('HomeScreen displays AppErrorView with retry on error', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayProvider.overrideWith(
              () => _ErrorTodayNotifier('Network timeout'),
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(HomeSkeleton), findsNothing);
      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('Could Not Load Schedule'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets(
      'DateTimetableScreen displays TimetableSkeleton while loading',
      (tester) async {
        final completer = Completer<TimetableResponse>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              timetableForDateProvider('2026-10-24')
                  .overrideWith((ref) => completer.future),
            ],
            child: const MaterialApp(home: DateTimetableScreen()),
          ),
        );

        expect(find.byType(TimetableSkeleton), findsOneWidget);
      },
    );

    testWidgets('DashboardScreen displays DashboardSkeleton while loading', (
      tester,
    ) async {
      final completer = Completer<DashboardResponse>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardProvider('2026-10-24')
                .overrideWith((ref) => completer.future),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );

      expect(find.byType(DashboardSkeleton), findsOneWidget);
    });

    testWidgets('HistoryScreen displays HistorySkeleton while loading', (
      tester,
    ) async {
      final completer = Completer<HistoryResponse>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [historyProvider.overrideWith((ref) => completer.future)],
          child: const MaterialApp(home: HistoryScreen()),
        ),
      );

      expect(find.byType(HistorySkeleton), findsOneWidget);
    });

    testWidgets(
      'SettingsScreen displays HealthStatusSkeleton during health check',
      (tester) async {
        final completer = Completer<HealthResponse>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              themeModeProvider.overrideWith(_MockThemeModeNotifier.new),
              healthProvider.overrideWith((ref) => completer.future),
            ],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );

        expect(find.byType(HealthStatusSkeleton), findsOneWidget);
      },
    );
  });
}

class _MockThemeModeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.system;
}

class _CompleterTodayNotifier extends TodayNotifier {
  final Future<TodayResponse> _future;
  _CompleterTodayNotifier(this._future);

  @override
  Future<TodayResponse> build() => _future;
}

class _ErrorTodayNotifier extends TodayNotifier {
  final String _error;
  _ErrorTodayNotifier(this._error);

  @override
  Future<TodayResponse> build() async => throw Exception(_error);
}
