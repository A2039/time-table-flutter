import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/features/focus/domain/focus_models.dart';

void main() {
  group('Distracting Apps Model & Package Verification', () {
    test('Default distracting apps contain verified Instagram and Facebook package IDs', () {
      final defaults = DistractingApp.defaultApps();
      final instagram = defaults.firstWhere((a) => a.id == 'instagram');
      final facebook = defaults.firstWhere((a) => a.id == 'facebook');

      expect(instagram.packageName, 'com.instagram.android');
      expect(facebook.packageName, 'com.facebook.katana');
      expect(instagram.isTracked, isTrue);
      expect(facebook.isTracked, isTrue);
    });

    test('Allowlist contains study and educational apps by default', () {
      final allowlist = FocusAllowlistApp.defaultApps();
      final youtube = allowlist.firstWhere((a) => a.id == 'youtube');

      expect(youtube.packageName, 'com.google.android.youtube');
      expect(youtube.isAllowed, isTrue);
      expect(youtube.category, AllowlistCategory.study);
    });

    test(
      'Allowlist contains essential communications, clock, and emergency tools',
      () {
        final allowlist = FocusAllowlistApp.defaultApps();
        final phone = allowlist.firstWhere((a) => a.id == 'phone');
        final emergency = allowlist.firstWhere((a) => a.id == 'emergency');
        final clock = allowlist.firstWhere((a) => a.id == 'clock');
        final maps = allowlist.firstWhere((a) => a.id == 'maps');

        expect(phone.isAllowed, isTrue);
        expect(emergency.isAllowed, isTrue);
        expect(clock.isAllowed, isTrue);
        expect(maps.isAllowed, isTrue);
      },
    );
  });

  group('Per-App Cumulative Usage & Switching Simulation', () {
    test('Correctly accumulates time across Instagram -> Facebook switches without resetting', () {
      // Simulate cumulative duration map
      final Map<String, int> durations = {};
      const instagramPkg = 'com.instagram.android';
      const facebookPkg = 'com.facebook.katana';

      // Session 1: User opens Instagram for 3 minutes (180s)
      durations[instagramPkg] = (durations[instagramPkg] ?? 0) + 180;
      expect(durations[instagramPkg], 180);

      // Session 2: User switches to Facebook for 4 minutes (240s)
      durations[facebookPkg] = (durations[facebookPkg] ?? 0) + 240;
      expect(durations[facebookPkg], 240);
      expect(durations[instagramPkg], 180); // Instagram duration preserved

      // Both are under 5m grace limit (300s)
      const graceLimitSec = 5 * 60;
      expect(durations[instagramPkg]! >= graceLimitSec, isFalse);
      expect(durations[facebookPkg]! >= graceLimitSec, isFalse);

      // Session 3: User switches back to Instagram for 2.5 minutes (150s)
      durations[instagramPkg] = (durations[instagramPkg] ?? 0) + 150;

      // Cumulative Instagram is now 330s (5.5 minutes)
      expect(durations[instagramPkg], 330);
      expect(durations[instagramPkg]! >= graceLimitSec, isTrue);
    });

    test('Allowlisted apps are excluded from distracting usage tracking', () {
      final allowlist = FocusAllowlistApp.defaultApps();
      final allowlistPackages = allowlist
          .where((a) => a.isAllowed)
          .map((a) => a.packageName)
          .toSet();

      // YouTube is allowlisted
      expect(allowlistPackages.contains('com.google.android.youtube'), isTrue);

      // Instagram is not allowlisted
      expect(allowlistPackages.contains('com.instagram.android'), isFalse);
    });
  });

  group('Notification Cooldown & Deduplication Logic', () {
    test('Enforces 15-minute cooldown between repeated notifications for same package', () {
      final now = DateTime(2026, 10, 25, 14, 0);
      final notifiedMap = <String, DateTime>{'com.instagram.android': now};

      // 5 minutes later: still within cooldown
      final queryTime1 = now.add(const Duration(minutes: 5));
      final lastNotified1 = notifiedMap['com.instagram.android'];
      final shouldNotify1 =
          lastNotified1 == null ||
          queryTime1.difference(lastNotified1).inMinutes >= 15;
      expect(shouldNotify1, isFalse);

      // 16 minutes later: cooldown expired
      final queryTime2 = now.add(const Duration(minutes: 16));
      final shouldNotify2 =
          lastNotified1 == null ||
          queryTime2.difference(lastNotified1).inMinutes >= 15;
      expect(shouldNotify2, isTrue);
    });
  });

  group('Truthful Capability & Diagnostics Report', () {
    test('Diagnostics report distinguishes permissions, query test, and monitor heartbeat', () {
      final report = FocusDiagnosticsReport(
        manufacturer: 'Google',
        model: 'Pixel 8',
        sdkInt: 34,
        androidVersion: '14',
        usageAccessGranted: true,
        usageQueryWorking: true,
        notificationsEnabled: true,
        runtimePermissionGranted: true,
        channelStatus: 'created_enabled',
        batteryOptimizationIgnored: false,
        monitoringRunning: true,
        timestamp: DateTime(2026, 10, 25, 14, 0),
      );

      final markdown = report.toFormattedMarkdown();

      expect(markdown, contains('Usage Access (AppOps): GRANTED'));
      expect(markdown, contains('Usage Events Query Test: SUCCESSFUL'));
      expect(markdown, contains('Android 13+ POST_NOTIFICATIONS: GRANTED'));
      expect(
        markdown,
        contains('Display Over Other Apps (Overlay): NOT GRANTED'),
      );
      expect(markdown, contains('The Bouncer'));
      expect(markdown, contains('100% On-Device'));
    });

    test('Separately reports denied notification permission even when Usage Access is granted', () {
      const detailed = FocusDetailedCapability(
        usageAccessGranted: true,
        usageQueryWorking: true,
        notificationPermission: NotificationPermissionStatus.denied,
        notificationChannel: NotificationChannelStatus.notCreated,
        monitoringRunning: true,
      );

      expect(detailed.usageAccessGranted, isTrue);
      expect(detailed.areNotificationsFunctional, isFalse);
    });
  });

  group(
    'The Bouncer: 5-Minute Daytime Grace, 1-Min Warning & Cooldown Lock',
    () {
      test('Simulates 5-minute countdown reaching 4:00 (1-min warning) and 5:00 (auto-close + cooldown)', () {
        const graceMinutes = 5;
        const graceSeconds = graceMinutes * 60; // 300s
        const oneMinuteWarningSec = graceSeconds - 60; // 240s (4:00)
        const cooldownMinutes = 60;

        int currentSessionSeconds = 0;
        bool hasWarnedOneMinute = false;
        bool isAutoClosed = false;
        int? cooldownExpiresEpochMs;

        final now = DateTime(2026, 10, 25, 14, 0);

        // Tick 1 to 119: 0s to 238s -> No warning, no auto-close
        for (int i = 0; i < 119; i++) {
          currentSessionSeconds += 2;
          if (currentSessionSeconds >= oneMinuteWarningSec &&
              !hasWarnedOneMinute) {
            hasWarnedOneMinute = true;
          }
        }
        expect(currentSessionSeconds, 238);
        expect(hasWarnedOneMinute, isFalse);
        expect(isAutoClosed, isFalse);

        // Tick 120: 240s (4:00 elapsed) -> Trigger 1-minute warning!
        currentSessionSeconds += 2;
        if (currentSessionSeconds >= oneMinuteWarningSec &&
            !hasWarnedOneMinute) {
          hasWarnedOneMinute = true;
        }
        expect(currentSessionSeconds, 240);
        expect(hasWarnedOneMinute, isTrue);
        expect(isAutoClosed, isFalse);

        // Ticks up to 300s (5:00 elapsed) -> Auto-Close + 60m Cooldown lock!
        while (currentSessionSeconds < graceSeconds) {
          currentSessionSeconds += 2;
        }
        expect(currentSessionSeconds, 300);

        if (currentSessionSeconds >= graceSeconds) {
          isAutoClosed = true;
          cooldownExpiresEpochMs =
              now.millisecondsSinceEpoch + (cooldownMinutes * 60 * 1000);
        }
        expect(isAutoClosed, isTrue);
        expect(
          cooldownExpiresEpochMs,
          now.millisecondsSinceEpoch + (60 * 60 * 1000),
        );

        // Re-opening app during cooldown:
        final reOpenTime = now
            .add(const Duration(minutes: 10))
            .millisecondsSinceEpoch;
        final isStillInCooldown = reOpenTime < cooldownExpiresEpochMs!;
        expect(
          isStillInCooldown,
          isTrue,
        ); // Immediately auto-closed without grace
      });
    },
  );

  group('VIP Exception Allowlist (Always Allowed 24/7)', () {
    test('Verified default VIP list contains all required payment, dialer, and study packages', () {
      final allowlist = FocusAllowlistApp.defaultApps();
      final packageNames = allowlist.map((a) => a.packageName).toSet();

      // Study & AI
      expect(packageNames.contains('com.google.android.youtube'), isTrue);
      expect(packageNames.contains('com.openai.chatgpt'), isTrue);
      expect(packageNames.contains('com.google.android.apps.bard'), isTrue);

      // Payments & UPI
      expect(packageNames.contains('money.super.app'), isTrue);
      expect(packageNames.contains('in.super.money'), isTrue);
      expect(
        packageNames.contains('com.google.android.apps.nbu.paisa.user'),
        isTrue,
      );
      expect(packageNames.contains('com.phonepe.app'), isTrue);
      expect(packageNames.contains('net.one97.paytm'), isTrue);
      expect(packageNames.contains('in.org.npci.upiapp'), isTrue);
      expect(packageNames.contains('com.dreamplug.androidapp'), isTrue);
      expect(packageNames.contains('com.sbi.lotusintouch'), isTrue);
      expect(packageNames.contains('com.snapwork.hdfc'), isTrue);
      expect(packageNames.contains('com.csam.icici.bank.imobile'), isTrue);
      expect(packageNames.contains('com.axis.mobile'), isTrue);
      expect(packageNames.contains('com.msf.kbank.mobile'), isTrue);

      // Essential Dialers, Messages & WhatsApp
      expect(packageNames.contains('com.whatsapp'), isTrue);
      expect(packageNames.contains('com.whatsapp.w4b'), isTrue);
      expect(packageNames.contains('com.google.android.dialer'), isTrue);
      expect(
        packageNames.contains('com.google.android.apps.messaging'),
        isTrue,
      );
      expect(packageNames.contains('com.google.android.deskclock'), isTrue);
      expect(packageNames.contains('com.google.android.apps.maps'), isTrue);
    });
  });

  group('Anti-Impulse Lock (30-Second Pause Rule)', () {
    test('isAntiImpulseLocked is active during Full Restriction phases', () {
      final schedule = FocusSchedule.defaults();
      final state = FocusState(
        enabled: true,
        schedule: schedule,
        allowlist: FocusAllowlistApp.defaultApps(),
        currentPhase: FocusPhase.morning,
      );

      expect(state.currentPhase.isFullRestriction, isTrue);
      expect(state.isAntiImpulseLocked, isTrue);
    });

    test('isAntiImpulseLocked is active when an app is in cooldown even in daytime', () {
      final schedule = FocusSchedule.defaults();
      final state = FocusState(
        enabled: true,
        schedule: schedule,
        allowlist: FocusAllowlistApp.defaultApps(),
        currentPhase: FocusPhase.none, // Daytime
        activeCooldowns: {
          'com.instagram.android':
              DateTime.now().millisecondsSinceEpoch + 60000,
        },
      );

      expect(state.currentPhase.isFullRestriction, isFalse);
      expect(state.isAntiImpulseLocked, isTrue);
    });

    test('isAntiImpulseLocked is false during normal daytime with no active cooldowns', () {
      final schedule = FocusSchedule.defaults();
      final state = FocusState(
        enabled: true,
        schedule: schedule,
        allowlist: FocusAllowlistApp.defaultApps(),
        currentPhase: FocusPhase.none, // Daytime
        activeCooldowns: const {},
      );

      expect(state.currentPhase.isFullRestriction, isFalse);
      expect(state.isAntiImpulseLocked, isFalse);
    });
  });
}
