import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/focus_models.dart';

/// Local on-device persistence for Focus Mode settings and session history
/// Strictly preserves privacy: zero telemetry or usage records sent to any server.
class FocusStorage {
  final SharedPreferences? _prefs;

  static const String _keyEnabled = 'focus_mode_enabled';
  static const String _keySchedule = 'focus_mode_schedule';
  static const String _keyAllowlist = 'focus_mode_allowlist';
  static const String _keyDistractingApps = 'focus_mode_distracting_apps';
  static const String _keyGracePeriod = 'focus_mode_grace_period';
  static const String _keyOverrideDuration = 'focus_mode_override_duration';
  static const String _keyNotifications = 'focus_mode_notifications';
  static const String _keyScheduledRestriction =
      'focus_mode_scheduled_restriction';
  static const String _keyDaytimeGrace = 'focus_mode_daytime_grace';
  static const String _keyCooldownMinutes = 'focus_mode_cooldown_minutes';
  static const String _keyStrictWhitelist = 'focus_mode_strict_whitelist';
  static const String _keyBrowserLoophole = 'focus_mode_browser_loophole';
  static const String _keyYoutubeStudyCheck = 'focus_mode_youtube_study_check';
  static const String _keyTodayMinutes = 'focus_mode_today_minutes';
  static const String _keyCompletedSessions = 'focus_mode_completed_sessions';
  static const String _keyOverridesUsed = 'focus_mode_overrides_used';
  static const String _keyLastDate = 'focus_mode_last_date';

  FocusStorage([this._prefs]);

  /// Load persisted focus state or initialize defaults
  FocusState loadState() {
    final prefs = _prefs;
    if (prefs == null) {
      return FocusState.initial();
    }

    final enabled = prefs.getBool(_keyEnabled) ?? false;
    final grace = prefs.getInt(_keyGracePeriod) ?? 5;
    final overrideDur = prefs.getInt(_keyOverrideDuration) ?? 5;
    final notifs = prefs.getBool(_keyNotifications) ?? true;
    final scheduledRestriction =
        prefs.getBool(_keyScheduledRestriction) ?? true;
    final daytimeGrace = prefs.getBool(_keyDaytimeGrace) ?? true;
    final cooldown = prefs.getInt(_keyCooldownMinutes) ?? 60;
    final strictWhitelist = prefs.getBool(_keyStrictWhitelist) ?? true;
    final browserLoophole = prefs.getBool(_keyBrowserLoophole) ?? true;
    final youtubeStudy = prefs.getBool(_keyYoutubeStudyCheck) ?? true;

    // Schedule
    FocusSchedule schedule;
    final scheduleJson = prefs.getString(_keySchedule);
    if (scheduleJson != null) {
      try {
        schedule = FocusSchedule.fromJson(
          jsonDecode(scheduleJson) as Map<String, dynamic>,
        );
      } catch (_) {
        schedule = FocusSchedule.defaults();
      }
    } else {
      schedule = FocusSchedule.defaults();
    }

    // Allowlist
    List<FocusAllowlistApp> allowlist;
    final allowlistJson = prefs.getString(_keyAllowlist);
    if (allowlistJson != null) {
      try {
        final list = jsonDecode(allowlistJson) as List<dynamic>;
        allowlist = list
            .map(
              (item) =>
                  FocusAllowlistApp.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      } catch (_) {
        allowlist = FocusAllowlistApp.defaultApps();
      }
    } else {
      allowlist = FocusAllowlistApp.defaultApps();
    }

    // Distracting Apps
    List<DistractingApp> distractingApps;
    final distractingJson = prefs.getString(_keyDistractingApps);
    if (distractingJson != null) {
      try {
        final list = jsonDecode(distractingJson) as List<dynamic>;
        distractingApps = list
            .map(
              (item) => DistractingApp.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      } catch (_) {
        distractingApps = DistractingApp.defaultApps();
      }
    } else {
      distractingApps = DistractingApp.defaultApps();
    }

    // Daily metrics reset logic
    final today = _getTodayString();
    final lastDate = prefs.getString(_keyLastDate);
    int todayMinutes = 0;
    int completedSessions = 0;
    int overridesUsed = 0;

    if (lastDate == today) {
      todayMinutes = prefs.getInt(_keyTodayMinutes) ?? 0;
      completedSessions = prefs.getInt(_keyCompletedSessions) ?? 0;
      overridesUsed = prefs.getInt(_keyOverridesUsed) ?? 0;
    } else {
      // New day: reset daily metrics
      prefs.setString(_keyLastDate, today);
      prefs.setInt(_keyTodayMinutes, 0);
      prefs.setInt(_keyCompletedSessions, 0);
      prefs.setInt(_keyOverridesUsed, 0);
    }

    return FocusState(
      enabled: enabled,
      schedule: schedule,
      allowlist: allowlist,
      distractingApps: distractingApps,
      gracePeriodMinutes: grace,
      overrideDurationMinutes: overrideDur,
      notificationsEnabled: notifs,
      scheduledRestrictionEnabled: scheduledRestriction,
      daytimeGraceEnabled: daytimeGrace,
      cooldownMinutes: cooldown,
      strictWhitelistMode: strictWhitelist,
      browserLoopholeProtection: browserLoophole,
      youtubeStudyCheck: youtubeStudy,
      todayFocusMinutes: todayMinutes,
      completedSessionsToday: completedSessions,
      overridesUsedToday: overridesUsed,
    );
  }

  Future<void> saveEnabled(bool enabled) async {
    await _prefs?.setBool(_keyEnabled, enabled);
  }

  Future<void> saveScheduledRestrictionEnabled(bool enabled) async {
    await _prefs?.setBool(_keyScheduledRestriction, enabled);
  }

  Future<void> saveDaytimeGraceEnabled(bool enabled) async {
    await _prefs?.setBool(_keyDaytimeGrace, enabled);
  }

  Future<void> saveCooldownMinutes(int minutes) async {
    await _prefs?.setInt(_keyCooldownMinutes, minutes);
  }

  Future<void> saveStrictWhitelistMode(bool enabled) async {
    await _prefs?.setBool(_keyStrictWhitelist, enabled);
  }

  Future<void> saveBrowserLoopholeProtection(bool enabled) async {
    await _prefs?.setBool(_keyBrowserLoophole, enabled);
  }

  Future<void> saveYoutubeStudyCheck(bool enabled) async {
    await _prefs?.setBool(_keyYoutubeStudyCheck, enabled);
  }

  Future<void> saveSchedule(FocusSchedule schedule) async {
    await _prefs?.setString(_keySchedule, jsonEncode(schedule.toJson()));
  }

  Future<void> saveAllowlist(List<FocusAllowlistApp> allowlist) async {
    final list = allowlist.map((app) => app.toJson()).toList();
    await _prefs?.setString(_keyAllowlist, jsonEncode(list));
  }

  Future<void> saveDistractingApps(List<DistractingApp> apps) async {
    final list = apps.map((app) => app.toJson()).toList();
    await _prefs?.setString(_keyDistractingApps, jsonEncode(list));
  }

  Future<void> saveGracePeriod(int minutes) async {
    await _prefs?.setInt(_keyGracePeriod, minutes);
  }

  Future<void> saveOverrideDuration(int minutes) async {
    await _prefs?.setInt(_keyOverrideDuration, minutes);
  }

  Future<void> saveNotificationsEnabled(bool enabled) async {
    await _prefs?.setBool(_keyNotifications, enabled);
  }

  Future<void> recordFocusMinutes(int minutes) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final today = _getTodayString();
    final lastDate = prefs.getString(_keyLastDate);
    int current = 0;
    if (lastDate == today) {
      current = prefs.getInt(_keyTodayMinutes) ?? 0;
    }
    await prefs.setString(_keyLastDate, today);
    await prefs.setInt(_keyTodayMinutes, current + minutes);
  }

  Future<void> incrementCompletedSessions() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final today = _getTodayString();
    final lastDate = prefs.getString(_keyLastDate);
    int current = 0;
    if (lastDate == today) {
      current = prefs.getInt(_keyCompletedSessions) ?? 0;
    }
    await prefs.setString(_keyLastDate, today);
    await prefs.setInt(_keyCompletedSessions, current + 1);
  }

  Future<void> incrementOverridesUsed() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final today = _getTodayString();
    final lastDate = prefs.getString(_keyLastDate);
    int current = 0;
    if (lastDate == today) {
      current = prefs.getInt(_keyOverridesUsed) ?? 0;
    }
    await prefs.setString(_keyLastDate, today);
    await prefs.setInt(_keyOverridesUsed, current + 1);
  }

  /// Completely wipes local focus history & statistics for user privacy
  Future<void> clearHistory() async {
    await _prefs?.remove(_keyTodayMinutes);
    await _prefs?.remove(_keyCompletedSessions);
    await _prefs?.remove(_keyOverridesUsed);
    await _prefs?.remove(_keyLastDate);
  }

  String _getTodayString() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
