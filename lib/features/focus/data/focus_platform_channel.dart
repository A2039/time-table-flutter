import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/focus_models.dart';

/// Service interfacing with native platform APIs (Usage Access on Android, Screen Time / Reminders on iOS)
/// Guarantees strict adherence to truth-in-enforcement without deceptive claims.
class FocusPlatformChannel {
  static const MethodChannel _channel = MethodChannel(
    'com.timetable.app/focus_mode',
  );

  const FocusPlatformChannel();

  /// Inspects truthful platform capability based on current OS and user permissions
  Future<FocusCapability> checkCapability() async {
    if (kIsWeb) {
      return FocusCapability.reminderOnly;
    }

    try {
      if (Platform.isAndroid) {
        final bool isUsageGranted = await isUsagePermissionGranted();
        if (!isUsageGranted) {
          return FocusCapability.needsPermission;
        }

        final bool isOverlayGranted = await isOverlayPermissionGranted();
        if (!isOverlayGranted) {
          return FocusCapability.needsPermission;
        }

        // Check notification capability
        final notifStatus = await checkNotificationStatus();
        final bool notifGranted =
            notifStatus['runtimePermissionGranted'] as bool? ?? true;
        final bool notifEnabled =
            notifStatus['notificationsEnabled'] as bool? ?? true;
        final String channel =
            notifStatus['channelStatus'] as String? ?? 'created_enabled';

        if (!notifGranted || !notifEnabled || channel == 'blocked') {
          return FocusCapability.needsPermission;
        }

        return FocusCapability.active;
      } else if (Platform.isIOS) {
        // Standard iOS consumer apps do not have the Apple FamilyControls entitlement.
        // Truthfully declare Reminder-Only capability.
        return FocusCapability.reminderOnly;
      } else {
        // Windows Desktop, macOS, Linux
        return FocusCapability.reminderOnly;
      }
    } catch (_) {
      // If native channel is not yet wired (or in desktop debug mode), fallback gracefully
      return FocusCapability.reminderOnly;
    }
  }

  /// Detailed capability breakdown for diagnostics and truthful UI status reporting
  Future<FocusDetailedCapability> checkDetailedCapability({
    bool monitoringRunning = false,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return FocusDetailedCapability(
        usageAccessGranted: false,
        usageQueryWorking: false,
        notificationPermission: NotificationPermissionStatus.notRequired,
        notificationChannel: NotificationChannelStatus.notCreated,
        overlayPermissionGranted: false,
        enforcementServiceRunning: false,
        monitoringRunning: monitoringRunning,
        enforcementMode: 'Reminder-only (Desktop / Web / Unsupported)',
      );
    }

    try {
      final usageGranted = await isUsagePermissionGranted();
      final queryWorking = usageGranted ? await testUsageQuery() : false;
      final overlayGranted = await isOverlayPermissionGranted();
      final serviceRunning = await isEnforcementServiceRunning();
      final notifMap = await checkNotificationStatus();

      final runtimeGranted =
          notifMap['runtimePermissionGranted'] as bool? ?? true;
      final notifEnabled = notifMap['notificationsEnabled'] as bool? ?? true;
      final channelStr =
          notifMap['channelStatus'] as String? ?? 'created_enabled';

      final notifPerm = (!runtimeGranted || !notifEnabled)
          ? NotificationPermissionStatus.denied
          : NotificationPermissionStatus.granted;

      final notifChan = channelStr == 'blocked'
          ? NotificationChannelStatus.blocked
          : (channelStr == 'not_created'
                ? NotificationChannelStatus.notCreated
                : NotificationChannelStatus.enabled);

      return FocusDetailedCapability(
        usageAccessGranted: usageGranted,
        usageQueryWorking: queryWorking,
        notificationPermission: notifPerm,
        notificationChannel: notifChan,
        overlayPermissionGranted: overlayGranted,
        enforcementServiceRunning: serviceRunning,
        monitoringRunning: monitoringRunning,
        lastHeartbeat: DateTime.now(),
        lastUsageQuery: usageGranted ? DateTime.now() : null,
        enforcementMode: serviceRunning
            ? 'Active Enforcement Service ("The Bouncer")'
            : 'Service Stopped / Manual Standby',
      );
    } catch (_) {
      return FocusDetailedCapability(
        usageAccessGranted: false,
        usageQueryWorking: false,
        notificationPermission: NotificationPermissionStatus.denied,
        notificationChannel: NotificationChannelStatus.notCreated,
        overlayPermissionGranted: false,
        enforcementServiceRunning: false,
        monitoringRunning: monitoringRunning,
      );
    }
  }

  /// Checks if AppOps usage stats permission is granted
  Future<bool> isUsagePermissionGranted() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isUsagePermissionGranted') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Tests if UsageStatsManager.queryEvents actually returns data
  Future<bool> testUsageQuery() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('testUsageQuery') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks notification permission and channel status
  Future<Map<String, dynamic>> checkNotificationStatus() async {
    if (kIsWeb || !Platform.isAndroid) {
      return {
        'notificationsEnabled': true,
        'runtimePermissionGranted': true,
        'channelStatus': 'created_enabled',
      };
    }
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'checkNotificationPermission',
      );
      if (result == null) return {};
      return Map<String, dynamic>.from(result);
    } catch (_) {
      return {};
    }
  }

  /// Requests runtime POST_NOTIFICATIONS permission on Android 13+
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'requestNotificationPermission',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Queries native UsageEvents for distracting apps over the specified timeframe
  Future<Map<String, dynamic>> queryDistractingUsage({
    required int sinceEpochMs,
    required List<String> distractingPackages,
    required List<String> allowlistPackages,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return {
        'querySuccessful': false,
        'packageDurations': <String, int>{},
        'activePackage': null,
      };
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'queryDistractingUsage',
        {
          'sinceEpochMs': sinceEpochMs,
          'distractingPackages': distractingPackages,
          'allowlistPackages': allowlistPackages,
        },
      );

      if (result == null) {
        return {'querySuccessful': false, 'packageDurations': <String, int>{}};
      }

      final rawDurations = result['packageDurations'] as Map<dynamic, dynamic>?;
      final durations = <String, int>{};
      if (rawDurations != null) {
        rawDurations.forEach((key, value) {
          if (key is String && value is num) {
            durations[key] = value.toInt();
          }
        });
      }

      return {
        'querySuccessful': result['querySuccessful'] as bool? ?? false,
        'activePackage': result['activePackage'] as String?,
        'packageDurations': durations,
        'lastEventTimestamp': result['lastEventTimestamp'] as num? ?? 0,
      };
    } catch (e) {
      return {
        'querySuccessful': false,
        'error': e.toString(),
        'packageDurations': <String, int>{},
      };
    }
  }

  /// Posts a high-priority distraction notification
  Future<bool> postDistractionNotification({
    required String packageName,
    required String appName,
    required int usedMinutes,
    required int graceMinutes,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('postDistractionNotification', {
            'packageName': packageName,
            'appName': appName,
            'usedMinutes': usedMinutes,
            'graceMinutes': graceMinutes,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Posts a test notification to verify delivery
  Future<bool> postTestNotification() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('postTestNotification') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Cancels any active distraction notifications
  Future<bool> cancelDistractionNotifications() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'cancelDistractionNotifications',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves comprehensive device diagnostics
  Future<Map<String, dynamic>> getSystemDiagnostics() async {
    if (kIsWeb || !Platform.isAndroid) {
      return {
        'manufacturer': 'Generic',
        'model': kIsWeb ? 'Web Browser' : Platform.operatingSystem,
        'sdkInt': 0,
        'androidVersion': 'N/A',
        'usageAccessGranted': false,
        'usageQueryWorking': false,
        'notificationsEnabled': true,
        'runtimePermissionGranted': true,
        'channelStatus': 'created_enabled',
        'batteryOptimizationIgnored': true,
      };
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getSystemDiagnostics',
      );
      if (result == null) return {};
      return Map<String, dynamic>.from(result);
    } catch (_) {
      return {};
    }
  }

  /// Opens Android System Settings for Usage Access
  Future<bool> openUsageSettings() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final success =
          await _channel.invokeMethod<bool>('openUsageSettings') ?? false;
      return success;
    } catch (_) {
      return false;
    }
  }

  /// Opens System Notification Settings
  Future<bool> openNotificationSettings() async {
    if (kIsWeb) return false;
    try {
      final success =
          await _channel.invokeMethod<bool>('openNotificationSettings') ??
          false;
      return success;
    } catch (_) {
      return false;
    }
  }

  /// Opens General App Details in System Settings
  Future<bool> openAppSettings() async {
    if (kIsWeb) return false;
    try {
      final success =
          await _channel.invokeMethod<bool>('openAppSettings') ?? false;
      return success;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------------------------
  // Display Over Other Apps (Overlay) & Background Enforcement Service ("The Bouncer")
  // ---------------------------------------------------------------------------------------------

  /// Checks if SYSTEM_ALERT_WINDOW (Display over other apps) permission is granted
  Future<bool> isOverlayPermissionGranted() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('isOverlayPermissionGranted') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android Settings for Display Over Other Apps
  Future<bool> openOverlaySettings() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openOverlaySettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if the native FocusEnforcementService is actively running in foreground
  Future<bool> isEnforcementServiceRunning() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isEnforcementServiceRunning') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Starts the native FocusEnforcementService
  Future<bool> startEnforcementService() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('startEnforcementService') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Stops the native FocusEnforcementService
  Future<bool> stopEnforcementService() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('stopEnforcementService') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Synchronizes full configuration with native SharedPreferences and updates the service
  Future<bool> syncEnforcementConfig(Map<String, dynamic> config) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'syncEnforcementConfig',
            config,
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves live enforcement status, active cooldowns, today's blocks count
  Future<Map<String, dynamic>> getEnforcementLiveState() async {
    if (kIsWeb || !Platform.isAndroid) {
      return {
        'isServiceRunning': false,
        'isOverlayPermissionGranted': true,
        'isUsagePermissionGranted': true,
        'currentPhase': 'disabled',
        'todayBlocksCount': 0,
        'activeCooldowns': <String, int>{},
      };
    }
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getEnforcementLiveState',
      );
      if (result == null) return {};

      final rawCooldowns = result['activeCooldowns'] as Map<dynamic, dynamic>?;
      final activeCooldowns = <String, int>{};
      if (rawCooldowns != null) {
        rawCooldowns.forEach((k, v) {
          if (k is String && v is num) {
            activeCooldowns[k] = v.toInt();
          }
        });
      }

      return {
        'isServiceRunning': result['isServiceRunning'] as bool? ?? false,
        'isOverlayPermissionGranted':
            result['isOverlayPermissionGranted'] as bool? ?? false,
        'isUsagePermissionGranted':
            result['isUsagePermissionGranted'] as bool? ?? false,
        'currentPhase': result['currentPhase'] as String? ?? 'disabled',
        'todayBlocksCount': (result['todayBlocksCount'] as num?)?.toInt() ?? 0,
        'activeCooldowns': activeCooldowns,
      };
    } catch (_) {
      return {};
    }
  }

  /// Triggers test block shield demonstration activity
  Future<bool> showTestBlockShield({
    String appName = 'Instagram',
    String packageName = 'com.instagram.android',
    String reason = 'Demonstration Mode — 5-Minute Grace Limit Exceeded',
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('showTestBlockShield', {
            'appName': appName,
            'packageName': packageName,
            'reason': reason,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Queries all installed launcher apps on device for the App Picker
  Future<List<InstalledAppInfo>> getInstalledApps() async {
    if (kIsWeb || !Platform.isAndroid) return [];
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getInstalledApps',
      );
      if (result == null) return [];
      return result
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => InstalledAppInfo.fromJson(m))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
