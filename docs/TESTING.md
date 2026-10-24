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
│   ├── app_config_test.dart             # Configuration parser & branding validation
│   ├── envelope_parsing_test.dart       # JSON envelope validation (success, error, meta, codes)
│   ├── model_parsing_test.dart          # Domain models (Unicode/Hindi, status values, metrics, health)
│   ├── date_utils_test.dart             # Asia/Kolkata date calculations, weekend checks, date math
│   ├── redirect_and_redaction_test.dart # Apps Script 302 redirect following, allowlist, secret redaction
│   └── repositories_test.dart           # All 5 feature repositories with MockClient
├── widget/
│   └── skeleton_test.dart               # 19 tests: Shimmer primitives, reduced motion, themes, page skeletons, screen states
└── widget_test.dart                     # UI widgets (HomeScreen, StatusBadge, ProgressRing, Dialogs)
```

**Total Automated Tests:** 57 tests across 8 test suites (100% passing).

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
4. **Security & Redaction:**
   - URL query parameter redaction (`token=***REDACTED***`).
   - Allowlist enforcement blocking external domains.
   - HTML response detection preventing crashes on Google Sign-in pages.
5. **Widget Interactions:**
   - Rendering timetable activity cards and status badges.
   - Selecting late minutes via slider and chips in `StatusEditorDialog`.
   - Triggering error views and retry callbacks.

---

## 📋 Manual Live API Smoke-Test Checklist

When validating against a real deployed Google Apps Script Web App:

1. **Health Verification:**
   - Navigate to **Settings** -> tap **Check Connection** on API Health Check.
   - Verify Overall Status is `OK`, Google Sheets Database is `Connected`, and Timezone is `Asia/Kolkata`.
2. **Today's Timetable Load:**
   - Open **Today** tab.
   - Confirm activities are listed in chronological order with correct categories, titles, and times.
3. **Status Update (On-Time):**
   - Tap on an unrecorded activity card -> choose **Completed On Time** -> tap **Save Status**.
   - Verify status badge turns green (`On Time`) and progress ring updates.
4. **Status Update (Late Minutes):**
   - Tap on another activity -> choose **Completed Late** -> select `15 m` -> tap **Save Status**.
   - Verify status badge displays `+15 min` and Dashboard shows 15 total late minutes.
5. **Daily Reflection / Remark:**
   - Tap the Reflection Card -> enter a test remark -> tap **Save Reflection**.
   - Pull down to refresh -> verify remark persists.
6. **Date Navigation:**
   - Open **Timetable** tab -> tap Next Day / Previous Day.
   - Verify weekday vs weekend activities switch appropriately.
7. **Analytics Dashboard:**
   - Open **Dashboard** tab.
   - Verify Donut chart renders proportional slices for On Time, Late, Not Done, and Unrecorded.
   - Confirm Completion Rate percentage matches `(completed on time + completed late) / total activities * 100`.
8. **History Query:**
   - Open **History** tab -> filter by **Past 7 Days**.
   - Confirm paginated records appear with accurate completion stats.
