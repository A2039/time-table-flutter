import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/core/widgets/app_error_view.dart';
import 'package:timetable/core/widgets/empty_state.dart';
import 'package:timetable/core/widgets/progress_ring.dart';
import 'package:timetable/features/daily_status/presentation/status_editor_dialog.dart';
import 'package:timetable/features/home/presentation/home_screen.dart';
import 'package:timetable/shared/models/daily_status.dart';
import 'package:timetable/shared/models/timetable_activity.dart';
import 'package:timetable/shared/providers/app_providers.dart';
import 'package:timetable/shared/widgets/app_header_logo.dart';
import 'package:timetable/shared/widgets/status_badge.dart';

void main() {
  group('Widget Tests', () {
    testWidgets(
      'StatusBadge displays correct text and icons for all 4 states',
      (tester) async {
        // 1. On time ('y')
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: StatusBadge(statusValue: 'y')),
          ),
        );
        expect(find.text('On Time'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

        // 2. Not completed ('n')
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: StatusBadge(statusValue: 'n')),
          ),
        );
        expect(find.text('Not Done'), findsOneWidget);
        expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);

        // 3. Late (15 min)
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: StatusBadge(statusValue: 15))),
        );
        expect(find.text('+15 min'), findsOneWidget);
        expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

        // 4. Unrecorded (null)
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: StatusBadge(statusValue: null)),
          ),
        );
        expect(find.text('Unrecorded'), findsOneWidget);
      },
    );

    testWidgets('ProgressRing renders percentage label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProgressRing(percentage: 85.0, subtitle: 'Done'),
          ),
        ),
      );

      expect(find.text('85%'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('AppErrorView renders message and triggers onRetry', (
      tester,
    ) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorView(
              error: 'Failed to fetch timetable',
              customTitle: 'Connection Error',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Connection Error'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      expect(retried, isTrue);
    });

    testWidgets('EmptyState displays icon, title, and subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.history_rounded,
              title: 'No History',
              subtitle: 'No records found for this range',
            ),
          ),
        ),
      );

      expect(find.text('No History'), findsOneWidget);
      expect(find.text('No records found for this range'), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    testWidgets(
      'StatusEditorDialog displays all 4 choices and selects late minutes',
      (tester) async {
        dynamic savedStatus;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    StatusEditorDialog.show(
                      context: ctx,
                      activityNo: 1,
                      activityTitle: 'Morning Yoga',
                      category: 'Physical',
                      time: '06:00 - 07:00',
                      currentStatus: 'y',
                      onSave: (val) async {
                        savedStatus = val;
                      },
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Morning Yoga'), findsOneWidget);
        expect(find.text('Completed On Time'), findsOneWidget);
        expect(find.text('Completed Late'), findsOneWidget);
        expect(find.text('Not Completed'), findsOneWidget);
        expect(find.text('Not Recorded / Reset'), findsOneWidget);

        // Select 'Completed Late'
        await tester.tap(find.text('Completed Late'));
        await tester.pumpAndSettle();

        expect(find.text('Late Duration:'), findsOneWidget);

        // Tap 15 m choice chip
        await tester.tap(find.text('15 m'));
        await tester.pumpAndSettle();

        // Save
        await tester.tap(find.text('Save Status'));
        await tester.pumpAndSettle();

        expect(savedStatus, 15);
      },
    );

    testWidgets('HomeScreen renders with mocked todayProvider data', (
      tester,
    ) async {
      const mockToday = TodayResponse(
        date: '2026-10-23',
        dayType: 'weekday',
        timetable: [
          TimetableActivity(
            srno: 1,
            category: 'Physical',
            time: '06:00 - 07:00',
            duration: '60 min',
            timePeriod: 'Morning Exercise',
            description: 'Stretching and cardio',
          ),
          TimetableActivity(
            srno: 2,
            category: 'Study',
            time: '08:00 - 10:00',
            duration: '120 min',
            timePeriod: 'Dart & Flutter Architecture',
            description: 'Build enterprise application',
          ),
        ],
        status: DailyStatus(
          exists: true,
          date: '2026-10-23',
          dayType: 'weekday',
          statuses: {'1': 'y', '2': 10},
          remark: 'Focused and productive today',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayProvider.overrideWith(() => _MockTodayNotifier(mockToday)),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppHeaderLogo), findsOneWidget);
      expect(find.text('Morning Exercise'), findsOneWidget);
      expect(find.text('Dart & Flutter Architecture'), findsOneWidget);
      expect(find.text('On Time'), findsAtLeastNWidgets(1));
      expect(find.text('+10 min'), findsOneWidget);
      expect(find.text('Focused and productive today'), findsOneWidget);
      expect(find.text('Weekday'), findsOneWidget);
    });
  });
}

class _MockTodayNotifier extends TodayNotifier {
  final TodayResponse _data;
  _MockTodayNotifier(this._data);

  @override
  Future<TodayResponse> build() async => _data;
}
