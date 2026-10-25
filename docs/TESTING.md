# Testing & Quality Assurance Guide

This document describes the automated test suite, coverage areas, and manual smoke test procedures for the Time Table & Daily Activity Tracker application.

---

## 🧪 Automated Test Suite

The test suite covers unit and widget testing with 100% mocked network environments to ensure predictable, deterministic test execution without hitting live backend servers during CI.

### Running Automated Tests
```bash
flutter test
```

### Test Suite Structure

```
test/
├── unit/
│   ├── app_config_test.dart                 # Configuration parser & branding validation
│   ├── envelope_parsing_test.dart           # JSON envelope validation (success, error, meta, codes)
│   ├── model_parsing_test.dart              # Domain models (Unicode/Hindi, status values, metrics, health)
│   ├── date_utils_test.dart                 # Asia/Kolkata date calculations, weekend checks, date math
│   ├── redirect_and_redaction_test.dart     # Apps Script 302 redirect following, allowlist, secret redaction
│   ├── repositories_test.dart               # All 5 feature repositories with MockClient
│   ├── focus_schedule_evaluator_test.dart   # 14 tests: 4 time phases, Full Restriction mode, cross-midnight, 05:00-05:15 overlap, transitions
│   ├── focus_storage_test.dart              # 6 tests: SharedPreferences persistence, defaults, edits, rollover, privacy
│   └── focus_usage_detection_test.dart      # 13 tests: 5-minute countdown with 4:00 warning & 5:00 auto-close + 60m cooldown, re-opening during cooldown, complete VIP package verification (UPI/dialers/study), Anti-Impulse 30s lock rule, Instagram/Facebook tracking
├── widget/
│   ├── focus_mode_test.dart                 # 15 tests: Settings card, Focus hub, 7 cards, Anti-Impulse 30s confirmation modal, Installed App Picker, VIP allowlist, distracting apps, diagnostics modal, privacy
│   └── skeleton_test.dart                   # 19 tests: Shimmer primitives, reduced motion, themes, page skeletons, screen states
└── widget_test.dart                         # UI widgets (HomeScreen, StatusBadge, ProgressRing, Dialogs)
```

**Total Automated Tests:** 109 tests across 12 test suites (100% passing).

### Key Automated Assertions
1. **Envelope Validation:**
   - Success envelope with payload and `requestId`.
   - Error envelope with typed code (`VALIDATION_ERROR`, `LOCK_TIMEOUT`, `UNAUTHORIZED`).
2. **Status Values:**
   - `"y"` (on time)
   - `"n"` (not completed)
   - Positive integer minutes (e.g. 5, 15 min late)
   - `null` (unrecorded / reset slot)
3. **Skeleton Loading UI & Accessibility (`test/widget/skeleton_test.dart`):**
   - `SkeletonBox`, `SkeletonCircle`, `SkeletonText`, `SkeletonCard`, and `SkeletonListItem` render with exact dimensions.
   - `Shimmer` horizontal sliding wave operates smoothly across all children.
   - `disableAnimations: true` (reduced motion) halts animation and displays static placeholders without errors.
   - Light and Dark theme brightness transitions adapt skeleton base and highlight colors.
   - Screen-reader semantics announce a single concise `"Loading content"` message.
   - Full-page skeletons (`HomeSkeleton`, `TimetableSkeleton`, `DashboardSkeleton`, `HistorySkeleton`, `HealthStatusSkeleton`, `AdminAuditSkeleton`, and `PaginationLoadingFooter`) render matching page structures.
   - Screen state lifecycle: Initial loading displays skeleton; arriving data cleanly replaces skeleton; errors display `AppErrorView` with retry.
4. **The Bouncer & Forceful Restriction Mode Tests (`focus_schedule_evaluator_test.dart`, `focus_storage_test.dart`, `focus_usage_detection_test.dart`, `focus_mode_test.dart`):**
   - **4 Time Phases:**
     - Morning Phase (`05:00` – `09:00` -> Full Restriction `isFullRestriction = true`, 0s grace)
     - Daytime Phase (`09:00` – `20:30` -> 5-Minute Countdown + 60m Cooldown)
     - Night Phase (`20:30` – `22:15` -> Full Restriction `isFullRestriction = true`, 0s grace)
     - Sleeping Phase (`22:15` – `05:15` -> Full Restriction across midnight)
   - **The Bouncer Countdown & Interception:**
     - Simulates tick-by-tick countdown: reaches 4:00 (240s) triggering 1-minute heads-up warning notification + vibration.
     - Reaches 5:00 (300s) triggering immediate auto-close (Step 1: Home kick, Step 2: Full-screen block shield) and locks app into 60-minute Cooldown.
     - Re-opening app during cooldown immediately triggers block shield without countdown.
   - **VIP Exception Package Verification:**
     - Verifies entire pre-configured VIP list (YouTube, ChatGPT, Gemini, WhatsApp, Phone, SMS, Alarm/Clock, Maps, Super.money, GPay, PhonePe, Paytm, BHIM, CRED, SBI, HDFC, ICICI, Axis, Kotak) is immune from restriction.
   - **Anti-Impulse Lock (30-Second Pause Rule):**
     - Verifies `isAntiImpulseLocked` is true during any Full Restriction phase or while an app is in cooldown.
     - Tests `AntiImpulseDialog` widget: ensures unlock button is disabled for 30 seconds and requires typing exact phrase `"I have an urgent reason"`.
   - **Installed App Picker:**
     - Tests `InstalledAppPickerDialog` for searching and picking device applications for VIP or Distracting lists.
   - **Truthful Capability Reporting:**
     - Tests separate reporting of Usage Access (AppOps), Usage Events query capability, Display Over Other Apps (Overlay), Background Enforcement Service, and notification permissions.
5. **Security & Redaction:**
   - URL query parameter redaction (`token=***REDACTED***`).
   - Allowlist enforcement blocking external domains.
   - HTML response detection preventing crashes on Google Sign-in pages.
6. **Widget Interactions:**
   - Rendering timetable activity cards and status badges.
   - Selecting late minutes via slider and chips in `StatusEditorDialog`.
   - Triggering error views and retry callbacks.

---

## 📋 Manual Live API Smoke-Test Checklist

When validating against a real deployed Google Apps Script Web App:

1. **Health Verification:**
   - Navigate to **Settings** -> tap **Check Connection** on API Health Check.
   - Verify Overall Status is `OK`, Database is `Connected`, and Timezone is `Asia/Kolkata`.
2. **Digital Wellbeing & Focus Mode Setup:**
   - Navigate to **Settings** -> find the **Digital Wellbeing & Focus Mode** section.
   - Toggle Focus Mode **ON** -> verify active status badge and next transition indicator update.
   - Tap **Manage Schedules, Allowlist & Grace Period** to open the full Focus Mode hub.
   - Verify all 6 cards appear: Status & Capability, Daily Focus Schedule, Essential App Allowlist, Grace Period & Breaks, System Permissions Checklist, and On-Device Privacy Guarantee.
   - Verify the **05:00 – 05:15 Overlap Resolution** row displays "Sleep Focus (Default)"; tap "Morning Focus" and verify the priority updates immediately.
   - Tap **Emergency Override (Break)** -> confirm 5-minute break -> verify the yellow break countdown banner appears with remaining minutes.
   - Tap **Allowlist** switches for Phone, WhatsApp, Maps -> add a custom app package -> verify addition.
   - Tap **Clear Focus History** in Privacy card -> confirm erasure -> verify today's focused minutes reset to 0m.
3. **Today's Timetable Load:**
   - Open **Today** tab.
   - Confirm activities are listed in chronological order with correct categories, titles, and times.
4. **Status Update (On-Time):**
   - Tap on an unrecorded activity card -> choose **Completed On Time** -> tap **Save Status**.
   - Verify status badge turns green (`On Time`) and progress ring updates.
5. **Status Update (Late Minutes):**
   - Tap on another activity -> choose **Completed Late** -> select `15 m` -> tap **Save Status**.
   - Verify status badge displays `+15 min` and Dashboard shows 15 total late minutes.
6. **Daily Reflection / Remark:**
   - Tap the Reflection Card -> enter a test remark -> tap **Save Reflection**.
   - Pull down to refresh -> verify remark persists.
7. **Date Navigation:**
   - Open **Timetable** tab -> tap Next Day / Previous Day.
   - Verify weekday vs weekend activities switch appropriately.
8. **Analytics Dashboard:**
   - Open **Dashboard** tab.
   - Verify Donut chart renders proportional slices for On Time, Late, Not Done, and Unrecorded.
   - Confirm Completion Rate percentage matches `(completed on time + completed late) / total activities * 100`.
9. **History Query:**
   - Open **History** tab -> filter by **Past 7 Days**.
   - Confirm paginated records appear with accurate completion stats.
