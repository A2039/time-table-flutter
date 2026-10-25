# Root Cause Diagnosis: TimeTable Focus Mode

**Target Component:** Digital Wellbeing & Focus Mode  
**Repository:** `D:\coder\projects\apps\time-table\time-table-flutter`  
**Date:** October 25, 2026  

---

## Executive Summary

When using Instagram or Facebook for 30+ minutes while TimeTable Focus Mode is enabled, the app fails to detect usage, post notifications, or interrupt the user. 

An exhaustive source inspection reveals that **Usage Access and notifications were never actually wired to Android system APIs beyond an initial permission check**. The app verified whether the `AppOpsManager` toggle was granted, but contained **zero calls** to Android's `UsageStatsManager`, **zero** usage event queries, **zero** notification channel creation, and **zero** notification posting methods. Consequently, the feature functioned solely as an in-memory schedule clock and preference storage container.

---

## Detailed Root Cause Answers (10 Questions)

### 1. Is the app actually querying foreground usage events, or only checking whether Usage Access is granted?
**Answer: The app ONLY checks whether Usage Access is granted.**
- In `android/app/src/main/kotlin/com/timetable/MainActivity.kt` (lines 70–91), `isUsageAccessGranted()` uses `AppOpsManager.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS)` to test whether the user toggled the switch in system settings.
- There is **no call anywhere in the repository** to `UsageStatsManager.queryEvents()` or `UsageStatsManager.queryUsageStats()`.
- The native method channel (`com.timetable.app/focus_mode`) in `MainActivity.kt` only exposes four methods: `isUsagePermissionGranted`, `openUsageSettings`, `openNotificationSettings`, and `openAppSettings`.

### 2. Is there any code that identifies Instagram/Facebook package names and tracks their foreground duration across app switches?
**Answer: No.**
- The allowlist in `lib/features/focus/domain/focus_models.dart` (lines 350–442) contains default essential apps (phone, dialer, whatsapp, youtube, gpay, etc.).
- There is **no list of distracting apps**, no package definition for Instagram (`com.instagram.android`) or Facebook (`com.facebook.katana`), and no duration accumulator or event state machine tracking app transitions.

### 3. Is a real Android notification channel created?
**Answer: No.**
- There is **no `NotificationChannel` created** in Kotlin (`MainActivity.kt`) or Dart. Searching the repository for `NotificationChannel` yields zero code occurrences.

### 4. Is notification permission checked at runtime on Android 13+ (`POST_NOTIFICATIONS`)?
**Answer: No.**
- Although `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />` is declared in `AndroidManifest.xml` (line 11), there is **zero runtime permission check** (`checkSelfPermission`) or request (`requestPermissions`) in `MainActivity.kt`.

### 5. Is a notification actually posted or scheduled? Which code path invokes it?
**Answer: No notification is ever posted or scheduled.**
- There is no code invoking `NotificationManager.notify()`, `NotificationCompat.Builder`, `AlarmManager`, or `WorkManager`. The app has no notification trigger path when grace periods are exceeded.

### 6. Is the five-minute grace period connected to actual foreground-app duration, or is it only a saved setting?
**Answer: It is only a saved integer.**
- `FocusStorage` stores `_keyGracePeriod = 5` in `SharedPreferences` (`focus_storage.dart` line 94).
- `FocusModeNotifier.setGracePeriod(minutes)` updates this value, but it is never consumed by any timer, threshold comparator, or native query.

### 7. Does the app attempt to force-stop external apps?
**Answer: No, and it should not.**
- The app correctly avoids attempting impossible or malicious force-stop commands (which are prohibited by Android's sandbox model). However, the capability label `"Active (Usage Monitored)"` conveyed misleading expectations that foreground apps were actively being monitored and restricted.

### 8. Does Focus Mode capability incorrectly become `active` solely because Usage Access is granted?
**Answer: YES.**
- In `lib/features/focus/data/focus_platform_channel.dart` (lines 25–32):
  ```dart
  final bool isUsageGranted = await _channel.invokeMethod<bool>('isUsagePermissionGranted') ?? false;
  if (isUsageGranted) {
    return FocusCapability.active;
  } else {
    return FocusCapability.needsPermission;
  }
  ```
- As soon as the AppOps check succeeds, `FocusCapability.active` ("Active (Usage Monitored)") is displayed, despite no monitoring, event querying, or notification delivery occurring.

### 9. What happens when the user opens system settings and returns, changes battery settings, disables permissions, or the OS kills the process?
**Answer:**
- **Returning from Settings:** `focus_permissions_card.dart` (line 130) relied on `await Future.delayed(const Duration(seconds: 1))` while the user was still in Android Settings. No `WidgetsBindingObserver` / `AppLifecycleListener` existed to refresh permissions upon `onResume`.
- **Process kill:** The in-memory Dart `Timer.periodic` (every 15s in `FocusModeNotifier`) terminates with the process. Because there was no persistent background service or query catch-up, all tracking ceased immediately upon backgrounding or process termination.
- **Battery optimization:** OEM battery killers restrict background execution unless explicitly configured.

### 10. Are the notification settings shown in the app consistent with the real OS permission and channel state?
**Answer: No.**
- `FocusState.notificationsEnabled` was simply an unvalidated boolean flag in local `SharedPreferences`. It did not check `NotificationManagerCompat.areNotificationsEnabled()` or whether the channel was blocked by the user.

---

## Action Plan Implemented

1. **Native Android Layer (`MainActivity.kt`):**
   - Implement `UsageStatsManager.queryEvents` to process foreground/background transitions (`ACTIVITY_RESUMED`, `ACTIVITY_PAUSED`, `SCREEN_NON_INTERACTIVE`, `KEYGUARD_SHOWN`).
   - Calculate cumulative foreground duration per distracting app (Instagram `com.instagram.android`, Facebook `com.facebook.katana`, etc.) within the active focus window.
   - Automatically initialize a high-importance `NotificationChannel` (`"timetable_focus_channel"`).
   - Check and request `POST_NOTIFICATIONS` runtime permission on Android 13+.
   - Implement native `postDistractionNotification()` with direct intent returning to TimeTable.
   - Add native `getSystemDiagnostics()` providing detailed hardware, OS, AppOps, query, and channel statuses.

2. **Domain & Data Layer:**
   - Introduce `DistractingApp` model with default support for Instagram and Facebook.
   - Exclude essential apps and allowlisted apps (including YouTube for study) from distraction tracking.
   - Separate capability reporting into distinct, truthful fields:
     - Usage Access (granted / not granted)
     - Usage Event Query (functional / failing)
     - Notification Permission (granted / denied / not required)
     - Notification Channel (enabled / blocked)
     - Usage Monitoring (running / stopped / permission needed)
     - Last Query Heartbeat timestamp
   - Wire the 5-minute grace period to cumulative per-app usage within the active focus window, with cooldown deduplication.
   - Add `AppLifecycleListener` to refresh permissions and sync usage immediately when resuming from system settings.

3. **Diagnostics & Transparency:**
   - Add "Run Focus Diagnostics" bottom sheet with live status checks, test notification delivery, and copyable report.
   - Clearly label enforcement as "Usage Alerts & Mindful Reminders" rather than misleading "App Blocking".
