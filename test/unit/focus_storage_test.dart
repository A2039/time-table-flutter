import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/features/focus/data/focus_storage.dart';
import 'package:timetable/features/focus/domain/focus_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FocusStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = FocusStorage(prefs);
  });

  group('FocusStorage Persistence Tests', () {
    test('Loads defaults when storage is empty', () {
      final state = storage.loadState();

      expect(state.enabled, isFalse);
      expect(state.gracePeriodMinutes, 5);
      expect(state.overrideDurationMinutes, 5);
      expect(state.notificationsEnabled, isTrue);
      expect(state.schedule.overlapPriority, FocusPhase.sleep);
      expect(state.schedule.morning.start, const FocusTime(5, 0));
      expect(state.schedule.morning.end, const FocusTime(9, 0));
      expect(state.schedule.night.start, const FocusTime(20, 30));
      expect(state.schedule.night.end, const FocusTime(22, 15));
      expect(state.schedule.sleep.start, const FocusTime(22, 15));
      expect(state.schedule.sleep.end, const FocusTime(5, 15));
      expect(state.allowlist, isNotEmpty);
      expect(state.todayFocusMinutes, 0);
      expect(state.completedSessionsToday, 0);
      expect(state.overridesUsedToday, 0);
    });

    test('Saves and loads enabled state', () async {
      await storage.saveEnabled(true);
      expect(storage.loadState().enabled, isTrue);

      await storage.saveEnabled(false);
      expect(storage.loadState().enabled, isFalse);
    });

    test('Saves and loads modified schedule and overlap priority', () async {
      final customSchedule = FocusSchedule(
        morning: const PhaseInterval(
          start: FocusTime(6, 0),
          end: FocusTime(8, 30),
        ),
        night: const PhaseInterval(
          start: FocusTime(21, 0),
          end: FocusTime(22, 0),
        ),
        sleep: const PhaseInterval(
          start: FocusTime(22, 0),
          end: FocusTime(6, 0),
        ),
        overlapPriority: FocusPhase.morning,
      );

      await storage.saveSchedule(customSchedule);
      final loaded = storage.loadState().schedule;

      expect(loaded.morning.start, const FocusTime(6, 0));
      expect(loaded.morning.end, const FocusTime(8, 30));
      expect(loaded.night.start, const FocusTime(21, 0));
      expect(loaded.night.end, const FocusTime(22, 0));
      expect(loaded.sleep.start, const FocusTime(22, 0));
      expect(loaded.sleep.end, const FocusTime(6, 0));
      expect(loaded.overlapPriority, FocusPhase.morning);
    });

    test('Saves and loads allowlist with custom apps', () async {
      final customList = [
        const FocusAllowlistApp(
          id: 'custom_1',
          name: 'My Study Tool',
          packageName: 'com.example.study',
          category: AllowlistCategory.study,
          isAllowed: true,
          isCustom: true,
        ),
      ];

      await storage.saveAllowlist(customList);
      final loaded = storage.loadState().allowlist;

      expect(loaded.length, 1);
      expect(loaded.first.id, 'custom_1');
      expect(loaded.first.name, 'My Study Tool');
      expect(loaded.first.packageName, 'com.example.study');
      expect(loaded.first.isCustom, isTrue);
    });

    test('Saves grace period and override duration', () async {
      await storage.saveGracePeriod(10);
      expect(storage.loadState().gracePeriodMinutes, 10);

      await storage.saveOverrideDuration(10);
      expect(storage.loadState().overrideDurationMinutes, 10);
    });

    test('Records daily metrics and clearHistory resets them', () async {
      await storage.recordFocusMinutes(45);
      await storage.recordFocusMinutes(30);
      await storage.incrementCompletedSessions();
      await storage.incrementCompletedSessions();
      await storage.incrementOverridesUsed();

      var state = storage.loadState();
      expect(state.todayFocusMinutes, 75);
      expect(state.completedSessionsToday, 2);
      expect(state.overridesUsedToday, 1);

      await storage.clearHistory();
      state = storage.loadState();
      expect(state.todayFocusMinutes, 0);
      expect(state.completedSessionsToday, 0);
      expect(state.overridesUsedToday, 0);
    });
  });
}
