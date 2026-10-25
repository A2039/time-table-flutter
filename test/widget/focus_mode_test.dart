import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/features/focus/data/focus_storage.dart';
import 'package:timetable/features/focus/domain/focus_models.dart';
import 'package:timetable/features/focus/presentation/focus_screen.dart';
import 'package:timetable/features/focus/presentation/widgets/anti_impulse_dialog.dart';
import 'package:timetable/features/focus/presentation/widgets/focus_allowlist_card.dart';
import 'package:timetable/features/focus/presentation/widgets/focus_distracting_apps_card.dart';
import 'package:timetable/features/focus/presentation/widgets/focus_grace_period_card.dart';
import 'package:timetable/features/focus/presentation/widgets/focus_permissions_card.dart';
import 'package:timetable/features/focus/presentation/widgets/focus_privacy_card.dart';
import 'package:timetable/features/focus/presentation/widgets/focus_schedule_card.dart';
import 'package:timetable/features/focus/presentation/widgets/focus_status_card.dart';
import 'package:timetable/features/focus/presentation/widgets/installed_app_picker_dialog.dart';
import 'package:timetable/features/focus/providers/focus_providers.dart';
import 'package:timetable/features/settings/presentation/settings_screen.dart';
import 'package:timetable/shared/models/health_response.dart';
import 'package:timetable/shared/providers/app_providers.dart';

class _TestThemeModeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.system;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FocusStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = FocusStorage(prefs);
  });

  Widget buildTestScope({required Widget child}) {
    return ProviderScope(
      overrides: [
        focusStorageProvider.overrideWithValue(storage),
        themeModeProvider.overrideWith(_TestThemeModeNotifier.new),
        healthProvider.overrideWith(
          (ref) async => const HealthResponse(
            status: 'OK',
            environment: 'test',
            timeZone: 'Asia/Kolkata',
            database: DatabaseStatus(
              connected: true,
              expectedSheetsPresent: true,
              message: 'Spreadsheet connection active',
            ),
          ),
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('Focus Mode SettingsScreen Integration Tests', () {
    testWidgets(
      'SettingsScreen displays Digital Wellbeing & Focus Mode card with toggle',
      (tester) async {
        await tester.pumpWidget(buildTestScope(child: const SettingsScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Digital Wellbeing & Focus Mode'), findsOneWidget);
        expect(
          find.text('Manage Schedules, Allowlist & Breaks'),
          findsOneWidget,
        );

        // Verify toggle switch exists and toggles
        final switchFinder = find.byType(Switch);
        expect(switchFinder, findsOneWidget);

        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(storage.loadState().enabled, isTrue);
      },
    );

    testWidgets('Tapping Manage Schedules navigates to FocusScreen', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestScope(child: const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage Schedules, Allowlist & Breaks'));
      await tester.pumpAndSettle();

      expect(find.byType(FocusScreen), findsOneWidget);
    });
  });

  group('FocusScreen Component & Interaction Tests', () {
    testWidgets(
      'FocusScreen renders all 7 wellbeing cards including distracting apps',
      (tester) async {
        await tester.pumpWidget(buildTestScope(child: const FocusScreen()));
        await tester.pumpAndSettle();

        expect(find.byType(FocusStatusCard), findsOneWidget);
        expect(find.byType(FocusScheduleCard), findsOneWidget);
        expect(find.byType(FocusAllowlistCard), findsOneWidget);
        expect(find.byType(FocusDistractingAppsCard), findsOneWidget);
        expect(find.byType(FocusGracePeriodCard), findsOneWidget);
        expect(find.byType(FocusPermissionsCard), findsOneWidget);
        expect(find.byType(FocusPrivacyCard), findsOneWidget);
      },
    );

    testWidgets('FocusStatusCard toggles enabled and starts manual focus', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestScope(child: const FocusScreen()));
      await tester.pumpAndSettle();

      // Enable focus
      final switchFinder = find.descendant(
        of: find.byType(FocusStatusCard),
        matching: find.byType(Switch),
      );
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.text('Start Focus Now'), findsOneWidget);

      // Start manual focus
      await tester.tap(find.text('Start Focus Now'));
      await tester.pumpAndSettle();

      expect(find.text('End Focus'), findsOneWidget);
      expect(find.text('Manual Focus Active'), findsOneWidget);

      // End manual focus
      await tester.tap(find.text('End Focus'));
      await tester.pumpAndSettle();

      expect(find.text('Start Focus Now'), findsOneWidget);
    });

    testWidgets(
      'Emergency Override dialog activates break and shows countdown banner',
      (tester) async {
        await storage.saveEnabled(true);

        await tester.pumpWidget(buildTestScope(child: const FocusScreen()));
        await tester.pumpAndSettle();

        // Start manual focus so focus is active
        await tester.tap(find.text('Start Focus Now'));
        await tester.pumpAndSettle();

        // Tap Take Break button
        await tester.tap(find.text('Take 5m Break'));
        await tester.pumpAndSettle();

        expect(find.text('Take Emergency Break?'), findsOneWidget);
        await tester.tap(find.text('Start 5m Break'));
        await tester.pumpAndSettle();

        expect(find.text('Emergency Override Break'), findsOneWidget);
        expect(find.text('Return Now'), findsOneWidget);

        // Cancel override early
        await tester.tap(find.text('Return Now'));
        await tester.pumpAndSettle();

        expect(find.text('Emergency Override Break'), findsNothing);
      },
    );

    testWidgets(
      'FocusScheduleCard renders 05:00-05:15 overlap priority switcher',
      (tester) async {
        await tester.pumpWidget(buildTestScope(child: const FocusScreen()));
        await tester.pumpAndSettle();

        expect(find.textContaining('Overlap Resolution'), findsOneWidget);

        // Tap Morning Focus segment to change overlap priority
        final morningSegment = find.descendant(
          of: find.byType(SegmentedButton<FocusPhase>),
          matching: find.text('Morning Focus'),
        );
        expect(morningSegment, findsOneWidget);

        await tester.scrollUntilVisible(morningSegment, 100);
        await tester.pumpAndSettle();

        await tester.tap(morningSegment);
        await tester.pumpAndSettle();

        expect(
          storage.loadState().schedule.overlapPriority,
          FocusPhase.morning,
        );
      },
    );

    testWidgets(
      'FocusScheduleCard restores default schedule with confirmation',
      (tester) async {
        await tester.pumpWidget(buildTestScope(child: const FocusScreen()));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Restore Default Schedule'),
          100,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Restore Default Schedule'));
        await tester.pumpAndSettle();

        expect(find.text('Restore Default Schedules?'), findsOneWidget);
        await tester.tap(find.text('Restore Defaults'));
        await tester.pumpAndSettle();

        expect(storage.loadState().schedule.overlapPriority, FocusPhase.sleep);
      },
    );

    testWidgets(
      'FocusAllowlistCard toggles allowlisted app and adds custom app',
      (tester) async {
        await tester.pumpWidget(buildTestScope(child: const FocusScreen()));
        await tester.pumpAndSettle();

        // Scroll to allowlist card
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('VIP Exception Allowlist (Always Allowed 24/7)'),
          findsOneWidget,
        );

        // Open Add Custom App dialog in FocusAllowlistCard
        final addBtn = find.descendant(
          of: find.byType(FocusAllowlistCard),
          matching: find.byTooltip('Add Custom App Manually'),
        );
        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        expect(find.text('Add Custom Allowlist App'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextField, 'App Name'),
          'Notion Notes',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Package Name'),
          'notion.id',
        );
        await tester.tap(find.text('Add App'));
        await tester.pumpAndSettle();

        final apps = storage.loadState().allowlist;
        expect(
          apps.any(
            (a) => a.name == 'Notion Notes' && a.packageName == 'notion.id',
          ),
          isTrue,
        );
      },
    );

    testWidgets('FocusGracePeriodCard updates grace period choice chip', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestScope(child: const FocusScreen()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('10m'), 200);
      await tester.pumpAndSettle();

      expect(find.text('Daytime Guard & Enforcement Rules'), findsOneWidget);

      await tester.tap(find.text('10m'));
      await tester.pumpAndSettle();

      expect(storage.loadState().gracePeriodMinutes, 10);
    });

    testWidgets(
      'FocusPrivacyCard displays on-device pledge and clears history',
      (tester) async {
        await storage.recordFocusMinutes(60);

        await tester.pumpWidget(buildTestScope(child: const FocusScreen()));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(find.text('Clear Focus History'), 200);
        await tester.pumpAndSettle();

        expect(
          find.text('100% On-Device & Zero Cloud Transmission'),
          findsOneWidget,
        );
        expect(find.text('60m'), findsOneWidget);

        await tester.tap(find.text('Clear Focus History'));
        await tester.pumpAndSettle();

        expect(find.text('Clear Focus History?'), findsOneWidget);
        await tester.tap(find.text('Clear History'));
        await tester.pumpAndSettle();

        expect(storage.loadState().todayFocusMinutes, 0);
      },
    );

    testWidgets(
      'FocusScreen renders without any RenderFlex overflow on narrow phone screen (320x568)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestScope(child: const FocusScreen()));
        await tester.pumpAndSettle();

        // Verify all key headings render and no exceptions/overflows were thrown
        expect(tester.takeException(), isNull);
        expect(find.text('Daily Focus Schedules'), findsOneWidget);
        expect(find.textContaining('Overlap Resolution'), findsOneWidget);
      },
    );

    testWidgets(
      'FocusDistractingAppsCard displays Instagram and Facebook and toggles tracking',
      (tester) async {
        await tester.pumpWidget(buildTestScope(child: const FocusScreen()));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Distracting Apps (5m Limit + Cooldown)'),
          200,
        );
        await tester.pumpAndSettle();

        expect(find.text('Instagram'), findsOneWidget);
        expect(find.text('Facebook'), findsOneWidget);
        expect(find.text('com.instagram.android'), findsOneWidget);
        expect(find.text('com.facebook.katana'), findsOneWidget);

        // Find switch for Instagram and toggle off
        final cardSwitches = find.descendant(
          of: find.byType(FocusDistractingAppsCard),
          matching: find.byType(Switch),
        );
        expect(cardSwitches, findsWidgets);
        await tester.tap(cardSwitches.first);
        await tester.pumpAndSettle();

        final apps = storage.loadState().distractingApps;
        final instagram = apps.firstWhere((a) => a.id == 'instagram');
        expect(instagram.isTracked, isFalse);
      },
    );

    testWidgets('FocusPermissionsCard opens FocusDiagnosticsDialog', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestScope(child: const FocusScreen()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byTooltip('Run Diagnostics').first,
        200,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Run Diagnostics').first);
      await tester.pumpAndSettle();

      expect(find.text('Focus Diagnostics'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Focus Diagnostics'), findsNothing);
    });

    testWidgets('AntiImpulseDialog requires 30s countdown and phrase match', (
      tester,
    ) async {
      bool confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AntiImpulseDialog.show(
                      context,
                      activeReason:
                          'Night Restriction Phase (8:30 PM - 10:15 PM)',
                      onConfirmed: () {
                        confirmed = true;
                      },
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Anti-Impulse Lock'), findsOneWidget);
      expect(
        find.textContaining('Night Restriction Phase (8:30 PM - 10:15 PM)'),
        findsOneWidget,
      );

      // Button should be disabled initially
      final buttonFinder = find.widgetWithText(
        ElevatedButton,
        'Confirm Unlock',
      );
      expect(buttonFinder, findsOneWidget);
      final ElevatedButton button = tester.widget(buttonFinder);
      expect(button.onPressed, isNull);

      // Enter the confirmation phrase
      await tester.enterText(find.byType(TextField), 'I have an urgent reason');
      await tester.pump();

      // Still disabled because 30 seconds haven't passed
      final ElevatedButton buttonStillDisabled = tester.widget(buttonFinder);
      expect(buttonStillDisabled.onPressed, isNull);

      // Fast-forward 30 seconds
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();

      // Now enabled
      final ElevatedButton buttonEnabled = tester.widget(buttonFinder);
      expect(buttonEnabled.onPressed, isNotNull);

      // Tap confirm
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
    });

    testWidgets(
      'InstalledAppPickerDialog renders dialog header and category chips',
      (tester) async {
        await tester.pumpWidget(
          buildTestScope(
            child: Scaffold(
              body: InstalledAppPickerDialog(
                isForAllowlist: true,
                onSelected: (app, cat) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add VIP Exception App'), findsOneWidget);
        expect(find.text('Select Category for Allowlist:'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      },
    );
  });
}
