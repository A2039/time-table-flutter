import 'focus_models.dart';

/// Information regarding the upcoming schedule transition
class ScheduleTransition {
  final DateTime transitionTime;
  final FocusPhase fromPhase;
  final FocusPhase toPhase;
  final String label;

  const ScheduleTransition({
    required this.transitionTime,
    required this.fromPhase,
    required this.toPhase,
    required this.label,
  });

  Duration timeUntil(DateTime now) {
    final diff = transitionTime.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  String formattedRemaining(DateTime now) {
    final rem = timeUntil(now);
    final hours = rem.inHours;
    final mins = rem.inMinutes % 60;
    if (hours > 0) {
      return '$hours h $mins m';
    }
    return '$mins min';
  }
}

/// Pure business logic evaluator for focus schedules, cross-midnight intervals,
/// 05:00-05:15 overlap resolution, and next-transition predictions.
class FocusScheduleEvaluator {
  const FocusScheduleEvaluator();

  /// Determines whether [target] falls within the half-open interval `[start, end)`.
  /// Handles both same-day intervals (`start < end`) and cross-midnight intervals (`start > end`).
  static bool isWithinInterval(
    FocusTime start,
    FocusTime end,
    FocusTime target,
  ) {
    final s = start.minuteOfDay;
    final e = end.minuteOfDay;
    final t = target.minuteOfDay;

    if (s == e) {
      // Empty / invalid interval
      return false;
    }

    if (s < e) {
      // Standard same-day interval (e.g. 05:00 to 09:00, 20:30 to 22:15)
      return t >= s && t < e;
    } else {
      // Cross-midnight interval (e.g. 22:15 to 05:15)
      // True if after 22:15 up to midnight OR from 00:00 up to 05:15
      return t >= s || t < e;
    }
  }

  /// Evaluates which focus phase is currently active for [target] given [schedule].
  /// Explicitly resolves the 05:00--05:15 overlap by applying [schedule.overlapPriority]
  /// (defaulting to [FocusPhase.sleep]).
  static FocusPhase evaluatePhase(FocusSchedule schedule, FocusTime target) {
    final inMorning = isWithinInterval(
      schedule.morning.start,
      schedule.morning.end,
      target,
    );
    final inNight = isWithinInterval(
      schedule.night.start,
      schedule.night.end,
      target,
    );
    final inSleep = isWithinInterval(
      schedule.sleep.start,
      schedule.sleep.end,
      target,
    );

    // Explicit overlap resolution between Morning and Sleep (e.g. 05:00 - 05:15)
    if (inMorning && inSleep) {
      return schedule.overlapPriority;
    }

    if (inNight && inSleep) {
      return schedule.overlapPriority == FocusPhase.sleep
          ? FocusPhase.sleep
          : FocusPhase.night;
    }

    if (inMorning) return FocusPhase.morning;
    if (inNight) return FocusPhase.night;
    if (inSleep) return FocusPhase.sleep;

    return FocusPhase.none;
  }

  /// Checks if [target] falls into a schedule overlap (e.g. 05:00 to 05:15)
  static bool isOverlap(FocusSchedule schedule, FocusTime target) {
    int activeCount = 0;
    if (isWithinInterval(
      schedule.morning.start,
      schedule.morning.end,
      target,
    )) {
      activeCount++;
    }
    if (isWithinInterval(schedule.night.start, schedule.night.end, target)) {
      activeCount++;
    }
    if (isWithinInterval(schedule.sleep.start, schedule.sleep.end, target)) {
      activeCount++;
    }
    return activeCount > 1;
  }

  /// Calculates the next upcoming transition event based on the current local [now]
  static ScheduleTransition getNextTransition(
    FocusSchedule schedule,
    DateTime now,
  ) {
    final currentFocusTime = FocusTime(now.hour, now.minute);
    final currentPhase = evaluatePhase(schedule, currentFocusTime);

    // List of candidate transition times within a 48-hour window from now
    final candidates = <DateTime>[];

    // Helper to create DateTime for a given FocusTime today, tomorrow, or yesterday
    for (int dayOffset = 0; dayOffset <= 2; dayOffset++) {
      final baseDate = DateTime(now.year, now.month, now.day + dayOffset);
      candidates.add(
        DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          schedule.morning.start.hour,
          schedule.morning.start.minute,
        ),
      );
      candidates.add(
        DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          schedule.morning.end.hour,
          schedule.morning.end.minute,
        ),
      );
      candidates.add(
        DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          schedule.night.start.hour,
          schedule.night.start.minute,
        ),
      );
      candidates.add(
        DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          schedule.night.end.hour,
          schedule.night.end.minute,
        ),
      );
      candidates.add(
        DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          schedule.sleep.start.hour,
          schedule.sleep.start.minute,
        ),
      );
      candidates.add(
        DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          schedule.sleep.end.hour,
          schedule.sleep.end.minute,
        ),
      );
    }

    // Sort ascending
    candidates.sort();

    // Find the first candidate strictly after now
    DateTime? nextTime;
    for (final candidate in candidates) {
      if (candidate.isAfter(now)) {
        // Only consider if the phase at candidate (or 1 second into candidate) differs from currentPhase
        final sampleTime = candidate.add(const Duration(seconds: 1));
        final phaseAtSample = evaluatePhase(
          schedule,
          FocusTime(sampleTime.hour, sampleTime.minute),
        );
        if (phaseAtSample != currentPhase) {
          nextTime = candidate;
          break;
        }
      }
    }

    // Fallback if none found
    nextTime ??= now.add(const Duration(hours: 1));

    final nextPhaseSample = nextTime.add(const Duration(seconds: 1));
    final nextPhase = evaluatePhase(
      schedule,
      FocusTime(nextPhaseSample.hour, nextPhaseSample.minute),
    );

    String label;
    if (currentPhase == FocusPhase.none) {
      label =
          'Next: ${nextPhase.displayName} starts at ${FocusTime(nextTime.hour, nextTime.minute).formatted}';
    } else {
      label =
          '${currentPhase.displayName} ends at ${FocusTime(nextTime.hour, nextTime.minute).formatted}';
      if (nextPhase != FocusPhase.none) {
        label += ' (${nextPhase.displayName} begins)';
      }
    }

    return ScheduleTransition(
      transitionTime: nextTime,
      fromPhase: currentPhase,
      toPhase: nextPhase,
      label: label,
    );
  }
}
