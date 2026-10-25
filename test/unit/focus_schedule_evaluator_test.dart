import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/features/focus/domain/focus_models.dart';
import 'package:timetable/features/focus/domain/focus_schedule_evaluator.dart';

void main() {
  group('FocusScheduleEvaluator Interval & Math Tests', () {
    test('isWithinInterval handles standard same-day intervals', () {
      const start = FocusTime(5, 0);
      const end = FocusTime(9, 0);

      expect(
        FocusScheduleEvaluator.isWithinInterval(
          start,
          end,
          const FocusTime(4, 59),
        ),
        isFalse,
      );
      expect(
        FocusScheduleEvaluator.isWithinInterval(
          start,
          end,
          const FocusTime(5, 0),
        ),
        isTrue,
      );
      expect(
        FocusScheduleEvaluator.isWithinInterval(
          start,
          end,
          const FocusTime(7, 30),
        ),
        isTrue,
      );
      expect(
        FocusScheduleEvaluator.isWithinInterval(
          start,
          end,
          const FocusTime(8, 59),
        ),
        isTrue,
      );
      expect(
        FocusScheduleEvaluator.isWithinInterval(
          start,
          end,
          const FocusTime(9, 0),
        ),
        isFalse,
      );
      expect(
        FocusScheduleEvaluator.isWithinInterval(
          start,
          end,
          const FocusTime(12, 0),
        ),
        isFalse,
      );
    });

    test('isWithinInterval handles cross-midnight intervals', () {
      const start = FocusTime(22, 15);
      const end = FocusTime(5, 15);

      // Evening portion
      expect(
        FocusScheduleEvaluator.isWithinInterval(
          start,
          end,
          const FocusTime(22, 14),
        ),
        isFalse,
      );
      expect(
        FocusScheduleEvaluator.isWithinInterval(
          start,
          end,
          const FocusTime(22, 15),
        ),
        isTrue,
      );
      expect(
        FocusScheduleEvaluator.isWithinInterval(
          start,
          end,
          const FocusTime(23, 59),
        ),
        isTrue,
      );

      // Midnight & Early morning portion
      expect(
        FocusScheduleEvaluator.isWithinInterval(
          start,
          end,
          const FocusTime(0, 0),
        ),
        isTrue,
      );
      expect(
        FocusScheduleEvaluator.isWithinInterval(
          start,
          end,
          const FocusTime(3, 30),
        ),
        isTrue,
      );
      expect(
        FocusScheduleEvaluator.isWithinInterval(
          start,
          end,
          const FocusTime(5, 14),
        ),
        isTrue,
      );
      expect(
        FocusScheduleEvaluator.isWithinInterval(
          start,
          end,
          const FocusTime(5, 15),
        ),
        isFalse,
      );
      expect(
        FocusScheduleEvaluator.isWithinInterval(
          start,
          end,
          const FocusTime(6, 0),
        ),
        isFalse,
      );
    });

    test('PhaseInterval durationMinutes computes correctly for normal and cross-midnight', () {
      const normal = PhaseInterval(
        start: FocusTime(5, 0),
        end: FocusTime(9, 0),
      );
      expect(normal.crossesMidnight, isFalse);
      expect(normal.durationMinutes, 240); // 4 hours

      const overnight = PhaseInterval(
        start: FocusTime(22, 15),
        end: FocusTime(5, 15),
      );
      expect(overnight.crossesMidnight, isTrue);
      expect(
        overnight.durationMinutes,
        420,
      ); // 7 hours (1h 45m before midnight + 5h 15m after)
    });
  });

  group('FocusScheduleEvaluator Phase Determination & 05:00-05:15 Overlap Tests', () {
    final defaultSchedule = FocusSchedule.defaults();

    test(
      'Default schedule resolves 05:00 - 05:15 overlap to Sleep Focus priority',
      () {
        expect(defaultSchedule.overlapPriority, FocusPhase.sleep);

        // In overlap interval
        expect(
          FocusScheduleEvaluator.evaluatePhase(
            defaultSchedule,
            const FocusTime(5, 0),
          ),
          FocusPhase.sleep,
        );
        expect(
          FocusScheduleEvaluator.evaluatePhase(
            defaultSchedule,
            const FocusTime(5, 7),
          ),
          FocusPhase.sleep,
        );
        expect(
          FocusScheduleEvaluator.evaluatePhase(
            defaultSchedule,
            const FocusTime(5, 14),
          ),
          FocusPhase.sleep,
        );

        // Exactly at 05:15, Sleep ends and Morning continues
        expect(
          FocusScheduleEvaluator.evaluatePhase(
            defaultSchedule,
            const FocusTime(5, 15),
          ),
          FocusPhase.morning,
        );
      },
    );

    test('Configured Morning Focus priority resolves 05:00 - 05:15 overlap to Morning Focus', () {
      final morningPrioritySchedule = defaultSchedule.copyWith(
        overlapPriority: FocusPhase.morning,
      );

      expect(
        FocusScheduleEvaluator.evaluatePhase(
          morningPrioritySchedule,
          const FocusTime(5, 0),
        ),
        FocusPhase.morning,
      );
      expect(
        FocusScheduleEvaluator.evaluatePhase(
          morningPrioritySchedule,
          const FocusTime(5, 10),
        ),
        FocusPhase.morning,
      );
      expect(
        FocusScheduleEvaluator.evaluatePhase(
          morningPrioritySchedule,
          const FocusTime(5, 15),
        ),
        FocusPhase.morning,
      );
    });

    test('isOverlap detects 05:00-05:15 accurately', () {
      expect(
        FocusScheduleEvaluator.isOverlap(
          defaultSchedule,
          const FocusTime(4, 59),
        ),
        isFalse,
      );
      expect(
        FocusScheduleEvaluator.isOverlap(
          defaultSchedule,
          const FocusTime(5, 0),
        ),
        isTrue,
      );
      expect(
        FocusScheduleEvaluator.isOverlap(
          defaultSchedule,
          const FocusTime(5, 14),
        ),
        isTrue,
      );
      expect(
        FocusScheduleEvaluator.isOverlap(
          defaultSchedule,
          const FocusTime(5, 15),
        ),
        isFalse,
      );
      expect(
        FocusScheduleEvaluator.isOverlap(
          defaultSchedule,
          const FocusTime(8, 0),
        ),
        isFalse,
      );
    });

    test('Evaluates all 24 hours correctly across day phases', () {
      // 00:00 to 05:00 -> Sleep
      expect(
        FocusScheduleEvaluator.evaluatePhase(
          defaultSchedule,
          const FocusTime(0, 0),
        ),
        FocusPhase.sleep,
      );
      expect(
        FocusScheduleEvaluator.evaluatePhase(
          defaultSchedule,
          const FocusTime(2, 30),
        ),
        FocusPhase.sleep,
      );
      expect(
        FocusScheduleEvaluator.evaluatePhase(
          defaultSchedule,
          const FocusTime(4, 59),
        ),
        FocusPhase.sleep,
      );

      // 05:00 to 05:15 -> Sleep (due to default priority)
      expect(
        FocusScheduleEvaluator.evaluatePhase(
          defaultSchedule,
          const FocusTime(5, 0),
        ),
        FocusPhase.sleep,
      );
      expect(
        FocusScheduleEvaluator.evaluatePhase(
          defaultSchedule,
          const FocusTime(5, 14),
        ),
        FocusPhase.sleep,
      );

      // 05:15 to 09:00 -> Morning
      expect(
        FocusScheduleEvaluator.evaluatePhase(
          defaultSchedule,
          const FocusTime(5, 15),
        ),
        FocusPhase.morning,
      );
      expect(
        FocusScheduleEvaluator.evaluatePhase(
          defaultSchedule,
          const FocusTime(7, 0),
        ),
        FocusPhase.morning,
      );
      expect(
        FocusScheduleEvaluator.evaluatePhase(
          defaultSchedule,
          const FocusTime(8, 59),
        ),
        FocusPhase.morning,
      );

      // 09:00 to 20:30 -> None (Off schedule)
      expect(
        FocusScheduleEvaluator.evaluatePhase(
          defaultSchedule,
          const FocusTime(9, 0),
        ),
        FocusPhase.none,
      );
      expect(
        FocusScheduleEvaluator.evaluatePhase(
          defaultSchedule,
          const FocusTime(12, 0),
        ),
        FocusPhase.none,
      );
      expect(
        FocusScheduleEvaluator.evaluatePhase(
          defaultSchedule,
          const FocusTime(20, 29),
        ),
        FocusPhase.none,
      );

      // 20:30 to 22:15 -> Night
      expect(
        FocusScheduleEvaluator.evaluatePhase(
          defaultSchedule,
          const FocusTime(20, 30),
        ),
        FocusPhase.night,
      );
      expect(
        FocusScheduleEvaluator.evaluatePhase(
          defaultSchedule,
          const FocusTime(21, 15),
        ),
        FocusPhase.night,
      );
      expect(
        FocusScheduleEvaluator.evaluatePhase(
          defaultSchedule,
          const FocusTime(22, 14),
        ),
        FocusPhase.night,
      );

      // 22:15 to 23:59 -> Sleep
      expect(
        FocusScheduleEvaluator.evaluatePhase(
          defaultSchedule,
          const FocusTime(22, 15),
        ),
        FocusPhase.sleep,
      );
      expect(
        FocusScheduleEvaluator.evaluatePhase(
          defaultSchedule,
          const FocusTime(23, 59),
        ),
        FocusPhase.sleep,
      );
    });
  });

  group('FocusScheduleEvaluator Next Transition Calculation Tests', () {
    final schedule = FocusSchedule.defaults();

    test('Computes next transition during daytime off-schedule', () {
      final now = DateTime(2026, 10, 24, 14, 0); // 14:00
      final transition = FocusScheduleEvaluator.getNextTransition(
        schedule,
        now,
      );

      expect(transition.fromPhase, FocusPhase.none);
      expect(transition.toPhase, FocusPhase.night);
      expect(transition.transitionTime, DateTime(2026, 10, 24, 20, 30));
      expect(transition.label, contains('Night Focus starts at 20:30'));
    });

    test('Computes next transition during Night Focus', () {
      final now = DateTime(2026, 10, 24, 21, 0); // 21:00
      final transition = FocusScheduleEvaluator.getNextTransition(
        schedule,
        now,
      );

      expect(transition.fromPhase, FocusPhase.night);
      expect(transition.toPhase, FocusPhase.sleep);
      expect(transition.transitionTime, DateTime(2026, 10, 24, 22, 15));
      expect(transition.label, contains('Night Focus ends at 22:15'));
    });

    test(
      'Computes next transition during Sleep Focus (cross-midnight to 05:15)',
      () {
        final now = DateTime(2026, 10, 24, 23, 0); // 23:00
        final transition = FocusScheduleEvaluator.getNextTransition(
          schedule,
          now,
        );

        expect(transition.fromPhase, FocusPhase.sleep);
        expect(transition.toPhase, FocusPhase.morning);
        expect(transition.transitionTime, DateTime(2026, 10, 25, 5, 15));
        expect(transition.label, contains('Sleep Focus ends at 05:15'));
      },
    );

    test('Computes next transition during Morning Focus (05:15 to 09:00)', () {
      final now = DateTime(2026, 10, 24, 6, 30); // 06:30
      final transition = FocusScheduleEvaluator.getNextTransition(
        schedule,
        now,
      );

      expect(transition.fromPhase, FocusPhase.morning);
      expect(transition.toPhase, FocusPhase.none);
      expect(transition.transitionTime, DateTime(2026, 10, 24, 9, 0));
      expect(transition.label, contains('Morning Focus ends at 09:00'));
    });
  });

  group('Four Phases & isFullRestriction Properties', () {
    final schedule = FocusSchedule.defaults();

    test('Phase 1: Morning Phase (05:00 - 09:00) is Full Restriction (0-sec grace)', () {
      final phase = FocusScheduleEvaluator.evaluatePhase(
        schedule,
        const FocusTime(7, 0),
      );
      expect(phase, FocusPhase.morning);
      expect(phase.isFullRestriction, isTrue);
    });

    test('Phase 2: Daytime Phase (09:00 - 20:30) is Flexible (5-min grace + cooldown)', () {
      final phase = FocusScheduleEvaluator.evaluatePhase(
        schedule,
        const FocusTime(14, 30),
      );
      expect(phase, FocusPhase.none);
      expect(phase.isFullRestriction, isFalse);
    });

    test(
      'Phase 3: Night Phase (20:30 - 22:15) is Full Restriction (0-sec grace)',
      () {
        final phase = FocusScheduleEvaluator.evaluatePhase(
          schedule,
          const FocusTime(21, 0),
        );
        expect(phase, FocusPhase.night);
        expect(phase.isFullRestriction, isTrue);
      },
    );

    test('Phase 4: Sleeping Phase (22:15 - 05:15) is Full Restriction across midnight', () {
      final phaseBeforeMidnight = FocusScheduleEvaluator.evaluatePhase(
        schedule,
        const FocusTime(23, 30),
      );
      final phaseAfterMidnight = FocusScheduleEvaluator.evaluatePhase(
        schedule,
        const FocusTime(3, 30),
      );
      expect(phaseBeforeMidnight, FocusPhase.sleep);
      expect(phaseBeforeMidnight.isFullRestriction, isTrue);
      expect(phaseAfterMidnight, FocusPhase.sleep);
      expect(phaseAfterMidnight.isFullRestriction, isTrue);
    });

    test(
      'Seamless 0-gap transition at 05:00 - 05:15 (Morning / Sleep overlap)',
      () {
        final phaseAt505 = FocusScheduleEvaluator.evaluatePhase(
          schedule,
          const FocusTime(5, 5),
        );
        // Regardless of priority, both Morning and Sleep are Full Restriction phases
        expect(phaseAt505.isFullRestriction, isTrue);
      },
    );
  });
}
