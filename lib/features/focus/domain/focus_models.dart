import 'package:flutter/material.dart';

/// Phase representing the active digital-wellbeing focus interval
enum FocusPhase {
  none,
  morning,
  night,
  sleep;

  String get displayName {
    switch (this) {
      case FocusPhase.morning:
        return 'Morning Focus';
      case FocusPhase.night:
        return 'Night Focus';
      case FocusPhase.sleep:
        return 'Sleep Focus';
      case FocusPhase.none:
        return 'Off Schedule';
    }
  }

  String get description {
    switch (this) {
      case FocusPhase.morning:
        return 'Dedicated quiet time for morning preparation, study, and high-priority work.';
      case FocusPhase.night:
        return 'Evening wind-down to disconnect from daytime notifications and distractions.';
      case FocusPhase.sleep:
        return 'Restorative rest and deep sleep interval with maximum notification suppression.';
      case FocusPhase.none:
        return 'Standard daytime schedule. Focus mode is idle unless started manually.';
    }
  }

  IconData get icon {
    switch (this) {
      case FocusPhase.morning:
        return Icons.wb_sunny_rounded;
      case FocusPhase.night:
        return Icons.nights_stay_rounded;
      case FocusPhase.sleep:
        return Icons.bedtime_rounded;
      case FocusPhase.none:
        return Icons.schedule_rounded;
    }
  }

  Color get color {
    switch (this) {
      case FocusPhase.morning:
        return const Color(0xFFF59E0B); // Amber / Morning Sun
      case FocusPhase.night:
        return const Color(0xFF6366F1); // Indigo / Twilight
      case FocusPhase.sleep:
        return const Color(0xFF8B5CF6); // Purple / Night Sky
      case FocusPhase.none:
        return const Color(0xFF6B7280); // Neutral slate
    }
  }

  /// Whether this phase is a Full-Restriction phase (0-second grace period)
  bool get isFullRestriction => this != FocusPhase.none;
}

/// Truthful platform capability state for digital-wellbeing enforcement
enum FocusCapability {
  active,
  needsPermission,
  reminderOnly,
  unsupported;

  String get label {
    switch (this) {
      case FocusCapability.active:
        return 'Active Enforcement (The Bouncer)';
      case FocusCapability.needsPermission:
        return 'Setup Needed (Grant Permission)';
      case FocusCapability.reminderOnly:
        return 'Reminder-Only Mode';
      case FocusCapability.unsupported:
        return 'Unsupported on Platform';
    }
  }

  String get description {
    switch (this) {
      case FocusCapability.active:
        return 'Persistent Foreground Enforcement Service active. 5-minute daytime grace + cooldown, 0-second morning/night/sleep restriction, and instant auto-close with block shield.';
      case FocusCapability.needsPermission:
        return 'Usage Access or Overlay ("Display over other apps") permission is missing. Tap to grant access in System Settings.';
      case FocusCapability.reminderOnly:
        return 'Consumer operating systems restrict third-party apps from force-closing external apps. TimeTable guides you with scheduled notifications and timely return reminders.';
      case FocusCapability.unsupported:
        return 'Focus monitoring is not supported on this platform architecture.';
    }
  }

  Color get color {
    switch (this) {
      case FocusCapability.active:
        return const Color(0xFF10B981); // Emerald Green
      case FocusCapability.needsPermission:
        return const Color(0xFFF59E0B); // Amber Warning
      case FocusCapability.reminderOnly:
        return const Color(0xFF3B82F6); // Blue Info
      case FocusCapability.unsupported:
        return const Color(0xFFEF4444); // Red
    }
  }
}

/// Hour and minute representation in 24-hour format
class FocusTime {
  final int hour;
  final int minute;

  const FocusTime(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24, 'hour must be between 0 and 23'),
      assert(minute >= 0 && minute < 60, 'minute must be between 0 and 59');

  int get minuteOfDay => hour * 60 + minute;

  String get formatted {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  TimeOfDay toTimeOfDay() => TimeOfDay(hour: hour, minute: minute);

  factory FocusTime.fromTimeOfDay(TimeOfDay time) =>
      FocusTime(time.hour, time.minute);

  factory FocusTime.parse(String timeString) {
    final parts = timeString.split(':');
    if (parts.length != 2) {
      throw FormatException('Invalid time format: $timeString. Expected HH:mm');
    }
    final h = int.parse(parts[0].trim());
    final m = int.parse(parts[1].trim());
    return FocusTime(h, m);
  }

  Map<String, dynamic> toJson() => {'hour': hour, 'minute': minute};

  factory FocusTime.fromJson(Map<String, dynamic> json) =>
      FocusTime(json['hour'] as int, json['minute'] as int);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FocusTime &&
          runtimeType == other.runtimeType &&
          hour == other.hour &&
          minute == other.minute;

  @override
  int get hashCode => hour.hashCode ^ minute.hashCode;

  @override
  String toString() => formatted;
}

/// Start and end interval for a focus phase
class PhaseInterval {
  final FocusTime start;
  final FocusTime end;

  const PhaseInterval({required this.start, required this.end});

  /// True if interval crosses midnight (e.g. 22:15 to 05:15)
  bool get crossesMidnight => end.minuteOfDay < start.minuteOfDay;

  /// Duration of this interval in minutes
  int get durationMinutes {
    if (crossesMidnight) {
      return (1440 - start.minuteOfDay) + end.minuteOfDay;
    }
    return end.minuteOfDay - start.minuteOfDay;
  }

  Map<String, dynamic> toJson() => {
    'start': start.toJson(),
    'end': end.toJson(),
  };

  factory PhaseInterval.fromJson(Map<String, dynamic> json) => PhaseInterval(
    start: FocusTime.fromJson(json['start'] as Map<String, dynamic>),
    end: FocusTime.fromJson(json['end'] as Map<String, dynamic>),
  );
}

/// Full configuration schedule for the three daily focus phases
class FocusSchedule {
  final PhaseInterval morning;
  final PhaseInterval night;
  final PhaseInterval sleep;
  final FocusPhase
  overlapPriority; // FocusPhase.sleep (default) or FocusPhase.morning

  const FocusSchedule({
    required this.morning,
    required this.night,
    required this.sleep,
    this.overlapPriority = FocusPhase.sleep,
  });

  /// Default application schedule conforming strictly to specifications:
  /// - Morning Focus: 05:00 - 09:00
  /// - Night Focus: 20:30 - 22:15
  /// - Sleep Focus: 22:15 - 05:15 (next day)
  /// - Overlap (05:00 - 05:15): Sleep Focus priority by default
  factory FocusSchedule.defaults() {
    return const FocusSchedule(
      morning: PhaseInterval(start: FocusTime(5, 0), end: FocusTime(9, 0)),
      night: PhaseInterval(start: FocusTime(20, 30), end: FocusTime(22, 15)),
      sleep: PhaseInterval(start: FocusTime(22, 15), end: FocusTime(5, 15)),
      overlapPriority: FocusPhase.sleep,
    );
  }

  FocusSchedule copyWith({
    PhaseInterval? morning,
    PhaseInterval? night,
    PhaseInterval? sleep,
    FocusPhase? overlapPriority,
  }) {
    return FocusSchedule(
      morning: morning ?? this.morning,
      night: night ?? this.night,
      sleep: sleep ?? this.sleep,
      overlapPriority: overlapPriority ?? this.overlapPriority,
    );
  }

  Map<String, dynamic> toJson() => {
    'morning': morning.toJson(),
    'night': night.toJson(),
    'sleep': sleep.toJson(),
    'overlapPriority': overlapPriority.name,
  };

  factory FocusSchedule.fromJson(Map<String, dynamic> json) {
    return FocusSchedule(
      morning: PhaseInterval.fromJson(json['morning'] as Map<String, dynamic>),
      night: PhaseInterval.fromJson(json['night'] as Map<String, dynamic>),
      sleep: PhaseInterval.fromJson(json['sleep'] as Map<String, dynamic>),
      overlapPriority: json['overlapPriority'] == 'morning'
          ? FocusPhase.morning
          : FocusPhase.sleep,
    );
  }
}

/// Essential app allowlist category
enum AllowlistCategory {
  phone,
  messaging,
  utilities,
  study,
  payments,
  emergency;

  String get title {
    switch (this) {
      case AllowlistCategory.phone:
        return 'Phone & Calls';
      case AllowlistCategory.messaging:
        return 'Essential Messaging';
      case AllowlistCategory.utilities:
        return 'Clock, Alarms & Maps';
      case AllowlistCategory.study:
        return 'Study & Learning';
      case AllowlistCategory.payments:
        return 'UPI & Banking';
      case AllowlistCategory.emergency:
        return 'Emergency & System';
    }
  }

  IconData get icon {
    switch (this) {
      case AllowlistCategory.phone:
        return Icons.phone_rounded;
      case AllowlistCategory.messaging:
        return Icons.chat_rounded;
      case AllowlistCategory.utilities:
        return Icons.access_alarm_rounded;
      case AllowlistCategory.study:
        return Icons.school_rounded;
      case AllowlistCategory.payments:
        return Icons.account_balance_wallet_rounded;
      case AllowlistCategory.emergency:
        return Icons.health_and_safety_rounded;
    }
  }
}

/// An app or system tool in the essential allowlist
class FocusAllowlistApp {
  final String id;
  final String name;
  final String packageName;
  final AllowlistCategory category;
  final bool isAllowed;
  final bool isCustom;

  const FocusAllowlistApp({
    required this.id,
    required this.name,
    required this.packageName,
    required this.category,
    this.isAllowed = true,
    this.isCustom = false,
  });

  FocusAllowlistApp copyWith({bool? isAllowed}) {
    return FocusAllowlistApp(
      id: id,
      name: name,
      packageName: packageName,
      category: category,
      isAllowed: isAllowed ?? this.isAllowed,
      isCustom: isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'packageName': packageName,
    'category': category.name,
    'isAllowed': isAllowed,
    'isCustom': isCustom,
  };

  factory FocusAllowlistApp.fromJson(Map<String, dynamic> json) {
    return FocusAllowlistApp(
      id: json['id'] as String,
      name: json['name'] as String,
      packageName: json['packageName'] as String,
      category: AllowlistCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => AllowlistCategory.utilities,
      ),
      isAllowed: json['isAllowed'] as bool? ?? true,
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  /// Default recommended VIP essential apps list (Always Allowed 24/7)
  static List<FocusAllowlistApp> defaultApps() {
    return const [
      // Phone & Emergency
      FocusAllowlistApp(
        id: 'phone',
        name: 'Phone & Dialer',
        packageName: 'com.google.android.dialer',
        category: AllowlistCategory.phone,
      ),
      FocusAllowlistApp(
        id: 'phone_samsung',
        name: 'Samsung Dialer',
        packageName: 'com.samsung.android.dialer',
        category: AllowlistCategory.phone,
      ),
      FocusAllowlistApp(
        id: 'emergency',
        name: 'Emergency SOS',
        packageName: 'com.android.emergency',
        category: AllowlistCategory.emergency,
      ),
      // Messaging
      FocusAllowlistApp(
        id: 'sms',
        name: 'Google Messages',
        packageName: 'com.google.android.apps.messaging',
        category: AllowlistCategory.messaging,
      ),
      FocusAllowlistApp(
        id: 'sms_samsung',
        name: 'Samsung Messages',
        packageName: 'com.samsung.android.messaging',
        category: AllowlistCategory.messaging,
      ),
      FocusAllowlistApp(
        id: 'whatsapp',
        name: 'WhatsApp',
        packageName: 'com.whatsapp',
        category: AllowlistCategory.messaging,
      ),
      FocusAllowlistApp(
        id: 'whatsapp_biz',
        name: 'WhatsApp Business',
        packageName: 'com.whatsapp.w4b',
        category: AllowlistCategory.messaging,
      ),
      // Utilities
      FocusAllowlistApp(
        id: 'clock',
        name: 'Clock & Alarms',
        packageName: 'com.google.android.deskclock',
        category: AllowlistCategory.utilities,
      ),
      FocusAllowlistApp(
        id: 'clock_samsung',
        name: 'Samsung Clock',
        packageName: 'com.sec.android.app.clockpackage',
        category: AllowlistCategory.utilities,
      ),
      FocusAllowlistApp(
        id: 'maps',
        name: 'Google Maps & Navigation',
        packageName: 'com.google.android.apps.maps',
        category: AllowlistCategory.utilities,
      ),
      // Study & AI
      FocusAllowlistApp(
        id: 'youtube',
        name: 'YouTube (Study/Educational)',
        packageName: 'com.google.android.youtube',
        category: AllowlistCategory.study,
      ),
      FocusAllowlistApp(
        id: 'chatgpt',
        name: 'ChatGPT',
        packageName: 'com.openai.chatgpt',
        category: AllowlistCategory.study,
      ),
      FocusAllowlistApp(
        id: 'gemini',
        name: 'Google Gemini',
        packageName: 'com.google.android.apps.bard',
        category: AllowlistCategory.study,
      ),
      // Payments & Banking
      FocusAllowlistApp(
        id: 'supermoney',
        name: 'super.money (UPI)',
        packageName: 'money.super.app',
        category: AllowlistCategory.payments,
      ),
      FocusAllowlistApp(
        id: 'supermoney_alt',
        name: 'super.money (in)',
        packageName: 'in.super.money',
        category: AllowlistCategory.payments,
      ),
      FocusAllowlistApp(
        id: 'gpay',
        name: 'Google Pay (GPay)',
        packageName: 'com.google.android.apps.nbu.paisa.user',
        category: AllowlistCategory.payments,
      ),
      FocusAllowlistApp(
        id: 'phonepe',
        name: 'PhonePe',
        packageName: 'com.phonepe.app',
        category: AllowlistCategory.payments,
      ),
      FocusAllowlistApp(
        id: 'paytm',
        name: 'Paytm',
        packageName: 'net.one97.paytm',
        category: AllowlistCategory.payments,
      ),
      FocusAllowlistApp(
        id: 'bhim',
        name: 'BHIM UPI',
        packageName: 'in.org.npci.upiapp',
        category: AllowlistCategory.payments,
      ),
      FocusAllowlistApp(
        id: 'cred',
        name: 'CRED / Pay',
        packageName: 'com.dreamplug.androidapp',
        category: AllowlistCategory.payments,
      ),
      FocusAllowlistApp(
        id: 'sbi_yono',
        name: 'SBI YONO',
        packageName: 'com.sbi.lotusintouch',
        category: AllowlistCategory.payments,
      ),
      FocusAllowlistApp(
        id: 'hdfc',
        name: 'HDFC Mobile Banking',
        packageName: 'com.snapwork.hdfc',
        category: AllowlistCategory.payments,
      ),
      FocusAllowlistApp(
        id: 'icici',
        name: 'ICICI iMobile Pay',
        packageName: 'com.csam.icici.bank.imobile',
        category: AllowlistCategory.payments,
      ),
      FocusAllowlistApp(
        id: 'axis',
        name: 'Axis Mobile',
        packageName: 'com.axis.mobile',
        category: AllowlistCategory.payments,
      ),
      FocusAllowlistApp(
        id: 'kotak',
        name: 'Kotak Mobile Banking',
        packageName: 'com.msf.kbank.mobile',
        category: AllowlistCategory.payments,
      ),
    ];
  }
}

/// Metadata representation for an installed application returned from native package manager
class InstalledAppInfo {
  final String packageName;
  final String appName;
  final bool isSystem;

  const InstalledAppInfo({
    required this.packageName,
    required this.appName,
    this.isSystem = false,
  });

  factory InstalledAppInfo.fromJson(Map<dynamic, dynamic> json) {
    return InstalledAppInfo(
      packageName: json['packageName'] as String? ?? '',
      appName: json['appName'] as String? ?? '',
      isSystem: json['isSystem'] as bool? ?? false,
    );
  }
}

/// A monitored distracting app (e.g. Instagram, Facebook) whose usage during focus mode triggers reminders
class DistractingApp {
  final String id;
  final String name;
  final String packageName;
  final bool isTracked;
  final bool isCustom;

  const DistractingApp({
    required this.id,
    required this.name,
    required this.packageName,
    this.isTracked = true,
    this.isCustom = false,
  });

  DistractingApp copyWith({bool? isTracked}) {
    return DistractingApp(
      id: id,
      name: name,
      packageName: packageName,
      isTracked: isTracked ?? this.isTracked,
      isCustom: isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'packageName': packageName,
    'isTracked': isTracked,
    'isCustom': isCustom,
  };

  factory DistractingApp.fromJson(Map<String, dynamic> json) {
    return DistractingApp(
      id: json['id'] as String,
      name: json['name'] as String,
      packageName: json['packageName'] as String,
      isTracked: json['isTracked'] as bool? ?? true,
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  /// Default distracting apps: Instagram and Facebook confirmed package IDs + common social tools
  static List<DistractingApp> defaultApps() {
    return const [
      DistractingApp(
        id: 'instagram',
        name: 'Instagram',
        packageName: 'com.instagram.android',
      ),
      DistractingApp(
        id: 'facebook',
        name: 'Facebook',
        packageName: 'com.facebook.katana',
      ),
      DistractingApp(
        id: 'twitter',
        name: 'X (Twitter)',
        packageName: 'com.twitter.android',
      ),
      DistractingApp(
        id: 'reddit',
        name: 'Reddit',
        packageName: 'com.reddit.frontpage',
      ),
      DistractingApp(
        id: 'snapchat',
        name: 'Snapchat',
        packageName: 'com.snapchat.android',
      ),
    ];
  }
}

/// Status of the OS notification permission
enum NotificationPermissionStatus {
  granted,
  denied,
  notRequired;

  String get label {
    switch (this) {
      case NotificationPermissionStatus.granted:
        return 'Granted';
      case NotificationPermissionStatus.denied:
        return 'Denied / Not Granted';
      case NotificationPermissionStatus.notRequired:
        return 'Not Required (Android < 13)';
    }
  }
}

/// Status of the TimeTable notification channel on Android
enum NotificationChannelStatus {
  enabled,
  blocked,
  notCreated;

  String get label {
    switch (this) {
      case NotificationChannelStatus.enabled:
        return 'Enabled & Active';
      case NotificationChannelStatus.blocked:
        return 'Blocked in System Settings';
      case NotificationChannelStatus.notCreated:
        return 'Not Created Yet';
    }
  }
}

/// Truthfully and separately reported capability breakdown
class FocusDetailedCapability {
  final bool usageAccessGranted;
  final bool usageQueryWorking;
  final NotificationPermissionStatus notificationPermission;
  final NotificationChannelStatus notificationChannel;
  final bool overlayPermissionGranted;
  final bool enforcementServiceRunning;
  final bool monitoringRunning;
  final DateTime? lastHeartbeat;
  final DateTime? lastUsageQuery;
  final String enforcementMode;

  const FocusDetailedCapability({
    this.usageAccessGranted = false,
    this.usageQueryWorking = false,
    this.notificationPermission = NotificationPermissionStatus.notRequired,
    this.notificationChannel = NotificationChannelStatus.notCreated,
    this.overlayPermissionGranted = false,
    this.enforcementServiceRunning = false,
    this.monitoringRunning = false,
    this.lastHeartbeat,
    this.lastUsageQuery,
    this.enforcementMode = 'Forceful Restriction Service ("The Bouncer")',
  });

  bool get areNotificationsFunctional =>
      notificationPermission != NotificationPermissionStatus.denied &&
      notificationChannel != NotificationChannelStatus.blocked;

  FocusDetailedCapability copyWith({
    bool? usageAccessGranted,
    bool? usageQueryWorking,
    NotificationPermissionStatus? notificationPermission,
    NotificationChannelStatus? notificationChannel,
    bool? overlayPermissionGranted,
    bool? enforcementServiceRunning,
    bool? monitoringRunning,
    DateTime? lastHeartbeat,
    DateTime? lastUsageQuery,
    String? enforcementMode,
  }) {
    return FocusDetailedCapability(
      usageAccessGranted: usageAccessGranted ?? this.usageAccessGranted,
      usageQueryWorking: usageQueryWorking ?? this.usageQueryWorking,
      notificationPermission:
          notificationPermission ?? this.notificationPermission,
      notificationChannel: notificationChannel ?? this.notificationChannel,
      overlayPermissionGranted:
          overlayPermissionGranted ?? this.overlayPermissionGranted,
      enforcementServiceRunning:
          enforcementServiceRunning ?? this.enforcementServiceRunning,
      monitoringRunning: monitoringRunning ?? this.monitoringRunning,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      lastUsageQuery: lastUsageQuery ?? this.lastUsageQuery,
      enforcementMode: enforcementMode ?? this.enforcementMode,
    );
  }
}

/// Hardware, OS, and permission diagnostics report
class FocusDiagnosticsReport {
  final String manufacturer;
  final String model;
  final int sdkInt;
  final String androidVersion;
  final bool usageAccessGranted;
  final bool usageQueryWorking;
  final bool notificationsEnabled;
  final bool runtimePermissionGranted;
  final String channelStatus;
  final bool batteryOptimizationIgnored;
  final bool overlayPermissionGranted;
  final bool enforcementServiceRunning;
  final int todayBlocksCount;
  final int activeCooldownsCount;
  final bool monitoringRunning;
  final DateTime timestamp;

  const FocusDiagnosticsReport({
    required this.manufacturer,
    required this.model,
    required this.sdkInt,
    required this.androidVersion,
    required this.usageAccessGranted,
    required this.usageQueryWorking,
    required this.notificationsEnabled,
    required this.runtimePermissionGranted,
    required this.channelStatus,
    required this.batteryOptimizationIgnored,
    this.overlayPermissionGranted = false,
    this.enforcementServiceRunning = false,
    this.todayBlocksCount = 0,
    this.activeCooldownsCount = 0,
    required this.monitoringRunning,
    required this.timestamp,
  });

  factory FocusDiagnosticsReport.fromMap(
    Map<dynamic, dynamic> map,
    bool monitoringRunning,
  ) {
    return FocusDiagnosticsReport(
      manufacturer: map['manufacturer'] as String? ?? 'Unknown',
      model: map['model'] as String? ?? 'Unknown',
      sdkInt: (map['sdkInt'] as num?)?.toInt() ?? 0,
      androidVersion: map['androidVersion'] as String? ?? 'Unknown',
      usageAccessGranted: map['usageAccessGranted'] as bool? ?? false,
      usageQueryWorking: map['usageQueryWorking'] as bool? ?? false,
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? false,
      runtimePermissionGranted:
          map['runtimePermissionGranted'] as bool? ?? false,
      channelStatus: map['channelStatus'] as String? ?? 'unknown',
      batteryOptimizationIgnored:
          map['batteryOptimizationIgnored'] as bool? ?? false,
      overlayPermissionGranted:
          map['overlayPermissionGranted'] as bool? ?? false,
      enforcementServiceRunning:
          map['enforcementServiceRunning'] as bool? ?? false,
      todayBlocksCount: (map['todayBlocksCount'] as num?)?.toInt() ?? 0,
      activeCooldownsCount: (map['activeCooldowns'] as Map?)?.length ?? 0,
      monitoringRunning: monitoringRunning,
      timestamp: DateTime.now(),
    );
  }

  String toFormattedMarkdown() {
    return '''
# TimeTable Focus Mode Diagnostic Report
Generated: ${timestamp.toIso8601String()}

## Device & Platform
- Manufacturer: $manufacturer
- Model: $model
- Android SDK: $sdkInt (Android $androidVersion)

## Capabilities & Permissions
- Usage Access (AppOps): ${usageAccessGranted ? 'GRANTED' : 'NOT GRANTED'}
- Usage Events Query Test: ${usageQueryWorking ? 'SUCCESSFUL' : 'FAILED / NO EVENTS'}
- Display Over Other Apps (Overlay): ${overlayPermissionGranted ? 'GRANTED' : 'NOT GRANTED'}
- Background Enforcement Service: ${enforcementServiceRunning ? 'RUNNING (The Bouncer Active)' : 'STOPPED'}
- App Notifications: ${notificationsEnabled ? 'ENABLED' : 'DISABLED'}
- Android 13+ POST_NOTIFICATIONS: ${runtimePermissionGranted ? 'GRANTED' : 'DENIED / PENDING'}
- Notification Channel: $channelStatus
- Battery Optimization Ignored: ${batteryOptimizationIgnored ? 'YES (Unrestricted)' : 'NO (Standard/Optimized)'}
- In-App Monitor Heartbeat: ${monitoringRunning ? 'RUNNING' : 'STOPPED'}

## Enforcement & Interception Status
- Today's Forceful Interceptions / Blocks: $todayBlocksCount
- Active Cooldown Locks: $activeCooldownsCount
- Enforcement Mechanism: The Bouncer (Two-Step Kick: Home Intent + Native Full-Screen Shield)
- Data Privacy: 100% On-Device (Zero cloud transmission of app usage)
''';
  }
}

/// Aggregated state of the Focus Mode system
class FocusState {
  final bool enabled;
  final FocusSchedule schedule;
  final List<FocusAllowlistApp> allowlist;
  final List<DistractingApp> distractingApps;
  final int gracePeriodMinutes;
  final int overrideDurationMinutes;
  final bool notificationsEnabled;
  final FocusCapability capability;
  final FocusDetailedCapability detailedCapability;

  // Restriction Mode Configuration
  final bool scheduledRestrictionEnabled;
  final bool daytimeGraceEnabled;
  final int cooldownMinutes;
  final bool strictWhitelistMode;
  final bool browserLoopholeProtection;
  final bool youtubeStudyCheck;

  // Native live service & permission status
  final bool overlayPermissionGranted;
  final bool enforcementServiceRunning;
  final Map<String, int> activeCooldowns; // package -> expiry epoch ms
  final int todayBlocksCount;

  // Active runtime state
  final FocusPhase currentPhase;
  final bool isManualFocus;
  final DateTime? manualFocusStartedAt;
  final bool isOverrideActive;
  final DateTime? overrideExpiresAt;
  final DateTime? lastOverrideAt;

  // Live distracting app usage
  final Map<String, int> distractingAppDurationsSeconds;
  final String? activeForegroundPackage;
  final Map<String, DateTime> lastDistractionNotifiedAt;

  // Local stats (stored strictly on-device)
  final int todayFocusMinutes;
  final int completedSessionsToday;
  final int overridesUsedToday;

  const FocusState({
    required this.enabled,
    required this.schedule,
    required this.allowlist,
    this.distractingApps = const [],
    this.gracePeriodMinutes = 5,
    this.overrideDurationMinutes = 5,
    this.notificationsEnabled = true,
    this.capability = FocusCapability.reminderOnly,
    this.detailedCapability = const FocusDetailedCapability(),
    this.scheduledRestrictionEnabled = true,
    this.daytimeGraceEnabled = true,
    this.cooldownMinutes = 60,
    this.strictWhitelistMode = true,
    this.browserLoopholeProtection = true,
    this.youtubeStudyCheck = true,
    this.overlayPermissionGranted = false,
    this.enforcementServiceRunning = false,
    this.activeCooldowns = const {},
    this.todayBlocksCount = 0,
    this.currentPhase = FocusPhase.none,
    this.isManualFocus = false,
    this.manualFocusStartedAt,
    this.isOverrideActive = false,
    this.overrideExpiresAt,
    this.lastOverrideAt,
    this.distractingAppDurationsSeconds = const {},
    this.activeForegroundPackage,
    this.lastDistractionNotifiedAt = const {},
    this.todayFocusMinutes = 0,
    this.completedSessionsToday = 0,
    this.overridesUsedToday = 0,
  });

  factory FocusState.initial() {
    return FocusState(
      enabled: false,
      schedule: FocusSchedule.defaults(),
      allowlist: FocusAllowlistApp.defaultApps(),
      distractingApps: DistractingApp.defaultApps(),
    );
  }

  bool get isFocusActive =>
      enabled &&
      !isOverrideActive &&
      (isManualFocus || currentPhase != FocusPhase.none);

  /// Anti-Impulse Lock (30-second pause rule):
  /// Active if restriction mode is enabled AND (current phase is Full Restriction OR an app is in cooldown).
  bool get isAntiImpulseLocked =>
      enabled && (currentPhase.isFullRestriction || activeCooldowns.isNotEmpty);

  FocusState copyWith({
    bool? enabled,
    FocusSchedule? schedule,
    List<FocusAllowlistApp>? allowlist,
    List<DistractingApp>? distractingApps,
    int? gracePeriodMinutes,
    int? overrideDurationMinutes,
    bool? notificationsEnabled,
    FocusCapability? capability,
    FocusDetailedCapability? detailedCapability,
    bool? scheduledRestrictionEnabled,
    bool? daytimeGraceEnabled,
    int? cooldownMinutes,
    bool? strictWhitelistMode,
    bool? browserLoopholeProtection,
    bool? youtubeStudyCheck,
    bool? overlayPermissionGranted,
    bool? enforcementServiceRunning,
    Map<String, int>? activeCooldowns,
    int? todayBlocksCount,
    FocusPhase? currentPhase,
    bool? isManualFocus,
    DateTime? manualFocusStartedAt,
    bool? isOverrideActive,
    DateTime? overrideExpiresAt,
    DateTime? lastOverrideAt,
    Map<String, int>? distractingAppDurationsSeconds,
    String? activeForegroundPackage,
    Map<String, DateTime>? lastDistractionNotifiedAt,
    int? todayFocusMinutes,
    int? completedSessionsToday,
    int? overridesUsedToday,
  }) {
    return FocusState(
      enabled: enabled ?? this.enabled,
      schedule: schedule ?? this.schedule,
      allowlist: allowlist ?? this.allowlist,
      distractingApps: distractingApps ?? this.distractingApps,
      gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
      overrideDurationMinutes:
          overrideDurationMinutes ?? this.overrideDurationMinutes,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      capability: capability ?? this.capability,
      detailedCapability: detailedCapability ?? this.detailedCapability,
      scheduledRestrictionEnabled:
          scheduledRestrictionEnabled ?? this.scheduledRestrictionEnabled,
      daytimeGraceEnabled: daytimeGraceEnabled ?? this.daytimeGraceEnabled,
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      strictWhitelistMode: strictWhitelistMode ?? this.strictWhitelistMode,
      browserLoopholeProtection:
          browserLoopholeProtection ?? this.browserLoopholeProtection,
      youtubeStudyCheck: youtubeStudyCheck ?? this.youtubeStudyCheck,
      overlayPermissionGranted:
          overlayPermissionGranted ?? this.overlayPermissionGranted,
      enforcementServiceRunning:
          enforcementServiceRunning ?? this.enforcementServiceRunning,
      activeCooldowns: activeCooldowns ?? this.activeCooldowns,
      todayBlocksCount: todayBlocksCount ?? this.todayBlocksCount,
      currentPhase: currentPhase ?? this.currentPhase,
      isManualFocus: isManualFocus ?? this.isManualFocus,
      manualFocusStartedAt: manualFocusStartedAt ?? this.manualFocusStartedAt,
      isOverrideActive: isOverrideActive ?? this.isOverrideActive,
      overrideExpiresAt: overrideExpiresAt ?? this.overrideExpiresAt,
      lastOverrideAt: lastOverrideAt ?? this.lastOverrideAt,
      distractingAppDurationsSeconds:
          distractingAppDurationsSeconds ?? this.distractingAppDurationsSeconds,
      activeForegroundPackage:
          activeForegroundPackage ?? this.activeForegroundPackage,
      lastDistractionNotifiedAt:
          lastDistractionNotifiedAt ?? this.lastDistractionNotifiedAt,
      todayFocusMinutes: todayFocusMinutes ?? this.todayFocusMinutes,
      completedSessionsToday:
          completedSessionsToday ?? this.completedSessionsToday,
      overridesUsedToday: overridesUsedToday ?? this.overridesUsedToday,
    );
  }
}
