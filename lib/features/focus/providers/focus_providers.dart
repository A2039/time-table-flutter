import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';
import '../data/focus_platform_channel.dart';
import '../data/focus_storage.dart';
import '../domain/focus_models.dart';
import '../domain/focus_schedule_evaluator.dart';

/// Provider for FocusStorage (wraps shared preferences from app_providers)
final focusStorageProvider = Provider<FocusStorage>((ref) {
  try {
    final storageService = ref.watch(storageServiceProvider);
    return FocusStorage(storageService.prefs);
  } catch (_) {
    return FocusStorage(null);
  }
});

/// Provider for native FocusPlatformChannel
final focusPlatformChannelProvider = Provider<FocusPlatformChannel>((ref) {
  return const FocusPlatformChannel();
});

/// Riverpod notifier managing active Focus Mode state, timers, schedules, allowlist, and distracting usage detection
class FocusModeNotifier extends Notifier<FocusState>
    with WidgetsBindingObserver {
  Timer? _ticker;

  @override
  FocusState build() {
    WidgetsBinding.instance.addObserver(this);

    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _ticker?.cancel();
    });

    final storage = ref.watch(focusStorageProvider);
    final initial = storage.loadState();

    // Kick off platform capability check and initial evaluation
    Future.microtask(() async {
      await refreshCapability();
      _evaluateCurrentPhase();
      _restartTickerIfNeeded();
    });

    return initial;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Immediately refresh permissions and trigger usage check upon returning from Android Settings or external apps
      refreshCapability();
      if (this.state.isFocusActive) {
        checkUsageNow();
      }
    }
  }

  void _restartTickerIfNeeded() {
    _ticker?.cancel();
    if (state.enabled) {
      _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
        _onTick();
      });
    }
  }

  void _onTick() {
    if (!state.enabled) return;

    final now = DateTime.now();

    // Check emergency override expiry
    if (state.isOverrideActive && state.overrideExpiresAt != null) {
      if (now.isAfter(state.overrideExpiresAt!)) {
        cancelEmergencyOverride();
        return;
      }
    }

    _evaluateCurrentPhase();

    // If focus is currently active, query native usage detection
    if (state.isFocusActive) {
      checkUsageNow();
    }
  }

  void _evaluateCurrentPhase() {
    final now = DateTime.now();
    final currentTime = FocusTime(now.hour, now.minute);
    final evaluated = FocusScheduleEvaluator.evaluatePhase(
      state.schedule,
      currentTime,
    );

    if (evaluated != state.currentPhase) {
      state = state.copyWith(currentPhase: evaluated);
    }
  }

  int _getCurrentPhaseStartEpochMs() {
    final now = DateTime.now();
    if (state.isManualFocus && state.manualFocusStartedAt != null) {
      return state.manualFocusStartedAt!.millisecondsSinceEpoch;
    }

    final schedule = state.schedule;
    PhaseInterval? activeInterval;
    switch (state.currentPhase) {
      case FocusPhase.morning:
        activeInterval = schedule.morning;
        break;
      case FocusPhase.night:
        activeInterval = schedule.night;
        break;
      case FocusPhase.sleep:
        activeInterval = schedule.sleep;
        break;
      case FocusPhase.none:
        return now.subtract(const Duration(hours: 4)).millisecondsSinceEpoch;
    }

    if (activeInterval.crossesMidnight) {
      if (now.hour < activeInterval.end.hour ||
          (now.hour == activeInterval.end.hour &&
              now.minute < activeInterval.end.minute)) {
        // Morning part of midnight-crossing interval
        final yesterday = now.subtract(const Duration(days: 1));
        return DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          activeInterval.start.hour,
          activeInterval.start.minute,
        ).millisecondsSinceEpoch;
      } else {
        return DateTime(
          now.year,
          now.month,
          now.day,
          activeInterval.start.hour,
          activeInterval.start.minute,
        ).millisecondsSinceEpoch;
      }
    } else {
      return DateTime(
        now.year,
        now.month,
        now.day,
        activeInterval.start.hour,
        activeInterval.start.minute,
      ).millisecondsSinceEpoch;
    }
  }

  /// Triggers an immediate usage detection query and evaluates grace period thresholds
  Future<void> checkUsageNow() async {
    if (!state.isFocusActive) return;

    final platform = ref.read(focusPlatformChannelProvider);
    final sinceEpochMs = _getCurrentPhaseStartEpochMs();
    final distractingPackages = state.distractingApps
        .where((a) => a.isTracked)
        .map((a) => a.packageName)
        .toList();
    final allowlistPackages = state.allowlist
        .where((a) => a.isAllowed)
        .map((a) => a.packageName)
        .toList();

    final result = await platform.queryDistractingUsage(
      sinceEpochMs: sinceEpochMs,
      distractingPackages: distractingPackages,
      allowlistPackages: allowlistPackages,
    );

    final bool querySuccess = result['querySuccessful'] as bool? ?? false;
    final durations = (result['packageDurations'] as Map<String, int>?) ?? {};
    final activePkg = result['activePackage'] as String?;

    // Check grace period threshold and notify
    final now = DateTime.now();
    final graceLimitSeconds = state.gracePeriodMinutes * 60;
    final updatedNotifiedMap = Map<String, DateTime>.from(
      state.lastDistractionNotifiedAt,
    );

    if (state.notificationsEnabled &&
        state.detailedCapability.areNotificationsFunctional) {
      for (final app in state.distractingApps) {
        if (!app.isTracked) continue;
        final usedSec = durations[app.packageName] ?? 0;
        if (usedSec >= graceLimitSeconds) {
          final lastNotified = updatedNotifiedMap[app.packageName];
          final shouldNotify =
              lastNotified == null ||
              now.difference(lastNotified).inMinutes >= 15;
          if (shouldNotify) {
            final usedMin = (usedSec / 60).round();
            await platform.postDistractionNotification(
              packageName: app.packageName,
              appName: app.name,
              usedMinutes: usedMin > 0 ? usedMin : state.gracePeriodMinutes,
              graceMinutes: state.gracePeriodMinutes,
            );
            updatedNotifiedMap[app.packageName] = now;
          }
        }
      }
    }

    state = state.copyWith(
      distractingAppDurationsSeconds: durations,
      activeForegroundPackage: activePkg,
      lastDistractionNotifiedAt: updatedNotifiedMap,
      detailedCapability: state.detailedCapability.copyWith(
        usageQueryWorking: querySuccess,
        lastUsageQuery: now,
        lastHeartbeat: now,
      ),
    );
  }

  /// Synchronizes full settings payload with the native SharedPreferences & starts/stops enforcement service
  Future<void> _syncWithNativeService() async {
    final platform = ref.read(focusPlatformChannelProvider);
    final vipList = state.allowlist
        .where((a) => a.isAllowed)
        .map((a) => a.packageName)
        .toList();
    final distractingList = state.distractingApps
        .where((a) => a.isTracked)
        .map((a) => a.packageName)
        .toList();

    await platform.syncEnforcementConfig({
      'masterEnabled': state.enabled,
      'scheduledRestrictionEnabled': state.scheduledRestrictionEnabled,
      'daytimeGraceEnabled': state.daytimeGraceEnabled,
      'strictWhitelistMode': state.strictWhitelistMode,
      'browserLoopholeProtection': state.browserLoopholeProtection,
      'youtubeStudyCheck': state.youtubeStudyCheck,
      'graceMinutes': state.gracePeriodMinutes,
      'cooldownMinutes': state.cooldownMinutes,
      'vipPackages': vipList,
      'distractingPackages': distractingList,
    });
  }

  /// Toggle Focus Mode on or off with anti-impulse protection
  Future<void> toggleFocusMode(
    bool enabled, {
    bool bypassAntiImpulse = false,
  }) async {
    if (!enabled && state.isAntiImpulseLocked && !bypassAntiImpulse) {
      // Prevent impulsive disabling during Full Restriction phases or active cooldowns
      return;
    }

    final storage = ref.read(focusStorageProvider);
    final platform = ref.read(focusPlatformChannelProvider);
    await storage.saveEnabled(enabled);

    state = state.copyWith(
      enabled: enabled,
      isManualFocus: enabled ? state.isManualFocus : false,
      isOverrideActive: enabled ? state.isOverrideActive : false,
      overrideExpiresAt: null,
      distractingAppDurationsSeconds: enabled
          ? state.distractingAppDurationsSeconds
          : const {},
      activeForegroundPackage: enabled ? state.activeForegroundPackage : null,
    );

    await _syncWithNativeService();

    if (enabled) {
      await refreshCapability();
      _evaluateCurrentPhase();
      _restartTickerIfNeeded();
      if (state.isFocusActive) {
        await checkUsageNow();
      }
    } else {
      _ticker?.cancel();
      _ticker = null;
      await platform.cancelDistractionNotifications();
    }
  }

  /// Start a manual focus session outside scheduled hours
  void startManualFocus() {
    state = state.copyWith(
      isManualFocus: true,
      manualFocusStartedAt: DateTime.now(),
      isOverrideActive: false,
      overrideExpiresAt: null,
    );
    checkUsageNow();
  }

  /// End manual focus session and record minutes
  Future<void> endManualFocus() async {
    final start = state.manualFocusStartedAt;
    if (start != null) {
      final elapsed = DateTime.now().difference(start).inMinutes;
      if (elapsed > 0) {
        final storage = ref.read(focusStorageProvider);
        await storage.recordFocusMinutes(elapsed);
        await storage.incrementCompletedSessions();
        state = state.copyWith(
          todayFocusMinutes: state.todayFocusMinutes + elapsed,
          completedSessionsToday: state.completedSessionsToday + 1,
        );
      }
    }

    state = state.copyWith(isManualFocus: false, manualFocusStartedAt: null);
  }

  /// Activate an emergency override break (e.g. 5 or 10 minutes)
  Future<void> activateEmergencyOverride([Duration? duration]) async {
    final dur = duration ?? Duration(minutes: state.overrideDurationMinutes);
    final now = DateTime.now();
    final expires = now.add(dur);

    final storage = ref.read(focusStorageProvider);
    final platform = ref.read(focusPlatformChannelProvider);
    await storage.incrementOverridesUsed();
    await platform.cancelDistractionNotifications();

    state = state.copyWith(
      isOverrideActive: true,
      overrideExpiresAt: expires,
      lastOverrideAt: now,
      overridesUsedToday: state.overridesUsedToday + 1,
    );
  }

  /// Cancel emergency override break immediately
  void cancelEmergencyOverride() {
    state = state.copyWith(isOverrideActive: false, overrideExpiresAt: null);
    if (state.isFocusActive) {
      checkUsageNow();
    }
  }

  /// Update focus schedule intervals
  Future<void> updateSchedule(FocusSchedule newSchedule) async {
    final storage = ref.read(focusStorageProvider);
    await storage.saveSchedule(newSchedule);
    state = state.copyWith(schedule: newSchedule);
    _evaluateCurrentPhase();
  }

  /// Restore default schedule (Morning: 05:00-09:00, Night: 20:30-22:15, Sleep: 22:15-05:15)
  Future<void> restoreDefaultSchedule() async {
    final defaults = FocusSchedule.defaults();
    await updateSchedule(defaults);
  }

  /// Update overlap resolution priority for 05:00 - 05:15 interval
  Future<void> updateOverlapPriority(FocusPhase priority) async {
    final updated = state.schedule.copyWith(overlapPriority: priority);
    await updateSchedule(updated);
  }

  /// Toggle an allowlist app on or off
  Future<void> toggleAllowlistApp(String id, bool isAllowed) async {
    final updatedList = state.allowlist.map((app) {
      if (app.id == id) {
        return app.copyWith(isAllowed: isAllowed);
      }
      return app;
    }).toList();

    final storage = ref.read(focusStorageProvider);
    await storage.saveAllowlist(updatedList);
    state = state.copyWith(allowlist: updatedList);
    await _syncWithNativeService();
  }

  /// Add a user-defined custom allowlist app
  Future<void> addCustomAllowlistApp({
    required String name,
    required String packageName,
    required AllowlistCategory category,
  }) async {
    final newApp = FocusAllowlistApp(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      packageName: packageName,
      category: category,
      isAllowed: true,
      isCustom: true,
    );

    final updated = [...state.allowlist, newApp];
    final storage = ref.read(focusStorageProvider);
    await storage.saveAllowlist(updated);
    state = state.copyWith(allowlist: updated);
    await _syncWithNativeService();
  }

  /// Remove a user-defined custom allowlist app
  Future<void> removeCustomAllowlistApp(String id) async {
    final updated = state.allowlist.where((app) => app.id != id).toList();
    final storage = ref.read(focusStorageProvider);
    await storage.saveAllowlist(updated);
    state = state.copyWith(allowlist: updated);
    await _syncWithNativeService();
  }

  /// Toggle tracking for a distracting app (e.g. Instagram, Facebook)
  Future<void> toggleDistractingApp(String id, bool isTracked) async {
    final updatedList = state.distractingApps.map((app) {
      if (app.id == id) {
        return app.copyWith(isTracked: isTracked);
      }
      return app;
    }).toList();

    final storage = ref.read(focusStorageProvider);
    await storage.saveDistractingApps(updatedList);
    state = state.copyWith(distractingApps: updatedList);
    await _syncWithNativeService();
  }

  /// Add a user-defined custom distracting app
  Future<void> addCustomDistractingApp({
    required String name,
    required String packageName,
  }) async {
    final newApp = DistractingApp(
      id: 'custom_distraction_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      packageName: packageName,
      isTracked: true,
      isCustom: true,
    );

    final updated = [...state.distractingApps, newApp];
    final storage = ref.read(focusStorageProvider);
    await storage.saveDistractingApps(updated);
    state = state.copyWith(distractingApps: updated);
    await _syncWithNativeService();
  }

  /// Remove a user-defined custom distracting app
  Future<void> removeCustomDistractingApp(String id) async {
    final updated = state.distractingApps.where((app) => app.id != id).toList();
    final storage = ref.read(focusStorageProvider);
    await storage.saveDistractingApps(updated);
    state = state.copyWith(distractingApps: updated);
    await _syncWithNativeService();
  }

  /// Set distracting app grace period (0, 1, 3, 5, 10 min)
  Future<void> setGracePeriod(int minutes) async {
    final storage = ref.read(focusStorageProvider);
    await storage.saveGracePeriod(minutes);
    state = state.copyWith(gracePeriodMinutes: minutes);
    await _syncWithNativeService();
  }

  /// Set cooldown period duration (30, 60, 120 mins)
  Future<void> setCooldownMinutes(int minutes) async {
    final storage = ref.read(focusStorageProvider);
    await storage.saveCooldownMinutes(minutes);
    state = state.copyWith(cooldownMinutes: minutes);
    await _syncWithNativeService();
  }

  /// Toggle scheduled restriction (Morning, Night, Sleeping phases)
  Future<void> toggleScheduledRestriction(bool enabled) async {
    final storage = ref.read(focusStorageProvider);
    await storage.saveScheduledRestrictionEnabled(enabled);
    state = state.copyWith(scheduledRestrictionEnabled: enabled);
    await _syncWithNativeService();
  }

  /// Toggle daytime 5-minute grace + cooldown timer
  Future<void> toggleDaytimeGrace(bool enabled) async {
    final storage = ref.read(focusStorageProvider);
    await storage.saveDaytimeGraceEnabled(enabled);
    state = state.copyWith(daytimeGraceEnabled: enabled);
    await _syncWithNativeService();
  }

  /// Toggle strict whitelist mode vs blocking only listed distracting apps
  Future<void> toggleStrictWhitelistMode(bool enabled) async {
    final storage = ref.read(focusStorageProvider);
    await storage.saveStrictWhitelistMode(enabled);
    state = state.copyWith(strictWhitelistMode: enabled);
    await _syncWithNativeService();
  }

  /// Toggle browser loophole protection (treats browsers with 5m grace during Full Restriction)
  Future<void> toggleBrowserLoopholeProtection(bool enabled) async {
    final storage = ref.read(focusStorageProvider);
    await storage.saveBrowserLoopholeProtection(enabled);
    state = state.copyWith(browserLoopholeProtection: enabled);
    await _syncWithNativeService();
  }

  /// Toggle YouTube 30-minute study check-in
  Future<void> toggleYoutubeStudyCheck(bool enabled) async {
    final storage = ref.read(focusStorageProvider);
    await storage.saveYoutubeStudyCheck(enabled);
    state = state.copyWith(youtubeStudyCheck: enabled);
    await _syncWithNativeService();
  }

  /// Set emergency override break duration (5, 10 min)
  Future<void> setOverrideDuration(int minutes) async {
    final storage = ref.read(focusStorageProvider);
    await storage.saveOverrideDuration(minutes);
    state = state.copyWith(overrideDurationMinutes: minutes);
  }

  /// Set notification preferences
  Future<void> setNotificationsEnabled(bool enabled) async {
    final storage = ref.read(focusStorageProvider);
    await storage.saveNotificationsEnabled(enabled);
    state = state.copyWith(notificationsEnabled: enabled);
  }

  /// Re-check native capability and permissions
  Future<void> refreshCapability() async {
    final platform = ref.read(focusPlatformChannelProvider);
    final isMonitoring = state.enabled && _ticker != null;
    final detailed = await platform.checkDetailedCapability(
      monitoringRunning: isMonitoring,
    );
    final capability = await platform.checkCapability();

    // Query native live state (service running, overlay permission, active cooldowns, today's blocks)
    final liveState = await platform.getEnforcementLiveState();
    final bool overlayGranted =
        liveState['isOverlayPermissionGranted'] as bool? ??
        detailed.overlayPermissionGranted;
    final bool serviceRunning =
        liveState['isServiceRunning'] as bool? ??
        detailed.enforcementServiceRunning;
    final int todayBlocks =
        (liveState['todayBlocksCount'] as num?)?.toInt() ?? 0;
    final activeCooldowns =
        (liveState['activeCooldowns'] as Map<String, int>?) ?? const {};

    state = state.copyWith(
      capability: capability,
      detailedCapability: detailed.copyWith(
        overlayPermissionGranted: overlayGranted,
        enforcementServiceRunning: serviceRunning,
      ),
      overlayPermissionGranted: overlayGranted,
      enforcementServiceRunning: serviceRunning,
      todayBlocksCount: todayBlocks,
      activeCooldowns: activeCooldowns,
    );
  }

  /// Runs comprehensive native diagnostics and generates a structured report
  Future<FocusDiagnosticsReport> runDiagnostics() async {
    final platform = ref.read(focusPlatformChannelProvider);
    final map = await platform.getSystemDiagnostics();
    final isMonitoring = state.enabled && _ticker != null;
    return FocusDiagnosticsReport.fromMap(map, isMonitoring);
  }

  /// Sends a test notification to verify channel importance and system delivery
  Future<bool> sendTestNotification() async {
    final platform = ref.read(focusPlatformChannelProvider);
    return await platform.postTestNotification();
  }

  /// Requests runtime notification permission on Android 13+
  Future<bool> requestNotificationPermission() async {
    final platform = ref.read(focusPlatformChannelProvider);
    final granted = await platform.requestNotificationPermission();
    await refreshCapability();
    return granted;
  }

  /// Opens Android System Settings for Usage Access
  Future<bool> openUsageSettings() async {
    final platform = ref.read(focusPlatformChannelProvider);
    return await platform.openUsageSettings();
  }

  /// Opens Android System Settings for Display Over Other Apps (Overlay)
  Future<bool> openOverlaySettings() async {
    final platform = ref.read(focusPlatformChannelProvider);
    return await platform.openOverlaySettings();
  }

  /// Triggers a test block shield demonstration immediately
  Future<bool> showTestBlockShield({
    String appName = 'Instagram',
    String packageName = 'com.instagram.android',
    String reason = 'Demonstration Mode — 5-Minute Grace Limit Exceeded',
  }) async {
    final platform = ref.read(focusPlatformChannelProvider);
    return await platform.showTestBlockShield(
      appName: appName,
      packageName: packageName,
      reason: reason,
    );
  }

  /// Queries all installed launcher apps on device for the App Picker
  Future<List<InstalledAppInfo>> getInstalledApps() async {
    final platform = ref.read(focusPlatformChannelProvider);
    return await platform.getInstalledApps();
  }

  /// Opens System Notification Settings
  Future<bool> openNotificationSettings() async {
    final platform = ref.read(focusPlatformChannelProvider);
    return await platform.openNotificationSettings();
  }

  /// Opens App Settings in System Settings
  Future<bool> openAppSettings() async {
    final platform = ref.read(focusPlatformChannelProvider);
    return await platform.openAppSettings();
  }

  /// Clear local on-device focus history and metrics
  Future<void> clearFocusHistory() async {
    final storage = ref.read(focusStorageProvider);
    await storage.clearHistory();
    state = state.copyWith(
      todayFocusMinutes: 0,
      completedSessionsToday: 0,
      overridesUsedToday: 0,
    );
  }
}

/// Active FocusMode provider
final focusModeProvider = NotifierProvider<FocusModeNotifier, FocusState>(
  FocusModeNotifier.new,
);

/// Next schedule transition provider
final focusNextTransitionProvider = Provider<ScheduleTransition>((ref) {
  final focus = ref.watch(focusModeProvider);
  return FocusScheduleEvaluator.getNextTransition(
    focus.schedule,
    DateTime.now(),
  );
});
