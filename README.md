# Time Table & Daily Activity Tracker (Flutter)

A modern, fast, responsive production Flutter application for tracking and managing date-based timetables and daily activity execution. Built with **Material 3**, **Riverpod**, and direct integration with the **Google Apps Script Web App API** and database.

---

## ✨ Features

- **Today's Overview & Status (`getToday`):**
  - Instant combined fetch of today's schedule activities and saved execution statuses in a single roundtrip.
  - Interactive status badges: **Completed On Time** (`"y"`), **Completed Late** (with minute duration), **Not Completed** (`"n"`), and **Unrecorded** (`null`).
  - Animated completion progress ring and breakdown stats.
  - Daily reflection card with live editing.
- **Modern Skeleton Loading UI (Zero Blank Screens):**
  - Production-grade shimmer placeholders matching actual page layouts and content structures on every data-driven screen (`Today/Home`, `Timetable`, `Dashboard`, `History`, `Settings`, `Admin`).
  - Native Flutter implementation with zero external packages: synchronized `ShimmerScope`, `SlidingGradientTransform`, and theme-aware color adaptation.
  - Full accessibility support for reduced motion (`disableAnimations`) with static placeholder fallbacks and concise screen-reader semantics.
- **Date-based Timetable Browsing (`getTimetable`, `getStatus`):**
  - Seamless day-by-day navigation with quick "Jump to Today" and calendar popup date picker.
  - Distinguishes **Weekday** vs **Weekend** timetables (`dayType`).
  - Supports Hindi and multilingual Unicode activity descriptions and titles.
- **Granular Activity & Remark Updates (`updateActivity`, `updateRemark`, `saveStatus`):**
  - Update individual activity slots without risking overwriting other activities or the daily remark.
  - Dedicated accessible status editor dialog with late-minute sliders and quick presets (5m, 10m, 15m, 30m, 45m, 60m).
  - Daily remark bottom sheet with unsaved changes detection.
- **Real Analytics & Visualization Dashboard (`getDashboard`):**
  - Driven strictly by real backend API data (no mock charts).
  - Donut / Pie chart powered by `fl_chart` visualizing On-Time vs Late vs Missed vs Unrecorded breakdowns.
  - KPI metric cards: Completion Rate %, Recorded Rate %, Total Late Minutes, and Completed Count.
  - Detailed activity breakdown list.
- **Paginated History & Filtering (`getHistory`):**
  - Historical activity logs with date range filtering (Past 7 Days, Past 30 Days, Custom range).
  - Schedule type filter: All Days, Weekdays, Weekends.
  - Server-side pagination controls (Previous/Next) with total count indicators.
  - Tap any historical record to open that date in the Timetable view.
- **Backend & Database Reachability Diagnostics (`health`):**
  - Live reachability check in Settings displaying database connectivity, expected sheet presence, and backend timezone.
- **Admin Database Integrity Audit (`validateDatabase`):**
  - Isolated behind explicit admin authorization.
  - Deep read-only verification of spreadsheet structure, headers, formulas, and schema.
- **Active Forceful Restriction & Digital Wellbeing ("The Bouncer"):**
  - **Master Enable/Disable Toggle & Anti-Impulse Protection:** Configurable master switch with individual toggles for scheduled full restriction and daytime 5-minute grace timers. If the user attempts to turn off restriction during an active Full Restriction phase or while an app is locked in cooldown, an **Anti-Impulse 30-Second Lock** enforces a 30-second live countdown and requires typing `"I have an urgent reason"`.
  - **Four Time Phases & Evaluator:**
    - **Morning Restriction Phase (`05:00 AM – 09:00 AM`):** Full Restriction (0-second grace period; immediate auto-close/block shield).
    - **Daytime Flexible Phase (`09:00 AM – 08:30 PM`):** 5-Minute Grace Timer + Cooldown Lock. Opening a distracting app starts a 5-minute countdown; at 4:00 (1 minute left), a high-priority heads-up warning and vibration fire; at 5:00, the user is forcefully kicked to the home screen and the app is locked into a 60-minute Cooldown.
    - **Night Restriction Phase (`08:30 PM – 10:15 PM`):** Full Restriction (0-second grace period).
    - **Sleeping Restriction Phase (`10:15 PM – 05:15 AM`):** Full Restriction across midnight with zero gap into Morning Restriction (`05:00 – 09:00`).
  - **Forceful Two-Step Auto-Close Action:** Step 1 immediately fires an Android Home Intent to kick the distracting app out of the foreground; Step 2 displays a full-screen native block shield (`FocusBlockActivity`) with the blocked app's name, reason, and a "Return to TimeTable / Home" button.
  - **Native Foreground Enforcement Service (`FocusEnforcementService.kt`):** Runs as a persistent Android Foreground Service (API 34+ specialUse) with an ongoing status notification. Monitors foreground apps every 1.5–2.0 seconds **only while the device screen is interactive (`PowerManager.isInteractive`)**. Registers dynamic broadcast receivers for `ACTION_SCREEN_OFF` / `ACTION_SCREEN_ON` for **zero battery drain when the screen is off**. Persists cooldowns and session state in native `SharedPreferences` so process restarts or app closures never bypass restrictions.
  - **Device Reboot Resilience (`BootReceiver.kt`):** Automatically restores `FocusEnforcementService` on device boot if Restriction Mode is enabled.
  - **Pre-Configured VIP Exception Allowlist (Always Allowed 24/7):** TimeTable, Phone dialers, SMS/Messaging, WhatsApp, Google Maps, Alarms & Clock, Study & AI tools (YouTube for study, ChatGPT, Google Gemini), and Indian UPI & Banking apps (super.money, GPay, PhonePe, Paytm, BHIM, CRED, SBI YONO, HDFC, ICICI, Axis, Kotak) are never blocked across any phase.
  - **Installed App Picker:** Searchable modal in Flutter querying installed launcher apps via `PackageManager` to easily add apps to VIP or Distracting lists.
  - **Smart Study & Browser Loophole Protections:** YouTube 30-minute study check-in prompt (*"Studying vs. Scrolling Shorts"*) and browser 5-minute loophole limit during Full Restriction hours.
  - **Interactive Focus Diagnostics:** Built-in diagnostic tool displaying manufacturer, model, SDK level, AppOps usage permission, overlay permission (`SYSTEM_ALERT_WINDOW`), foreground service status, cooldown locks, daily block count, and a **"Test Block Shield Now"** button.
  - **100% On-Device Privacy:** Zero usage events or package lists sent outside the mobile device. All data stays local with one-tap history wiping.

---

## 🏗️ Architecture & Tech Stack

```
lib/
├── app/
│   ├── app.dart              # Root MaterialApp with theme routing
│   ├── router.dart           # NavigationBar shell with 5 primary destinations
│   └── theme/
│       ├── app_colors.dart   # Brand and status color tokens
│       ├── app_typography.dart # Google Fonts (Plus Jakarta Sans)
│       └── app_theme.dart    # Material 3 Light and Dark theme configs
├── core/
│   ├── config/app_config.dart # Compile-time defines and global constants
│   ├── errors/error_mapper.dart # Human-readable error messages and retry logic
│   ├── network/
│   │   ├── api_client.dart   # Centralized HTTP client and envelope parser
│   │   ├── api_exception.dart # Typed domain exceptions
│   │   ├── api_result.dart   # Result pattern (Success / Failure)
│   │   └── redirect_aware_client.dart # Google Apps Script redirect handler
│   ├── utils/
│   │   ├── date_utils.dart   # Date-only manipulation in Asia/Kolkata
│   │   └── result_extensions.dart
│   └── widgets/              # Reusable core widgets (Loading, Error, Empty, Ring)
│       └── skeleton/         # Shimmer primitives & page-level skeleton layouts
│           ├── shimmer.dart            # Synchronized Shimmer & ShimmerScope
│           ├── skeleton_box.dart       # Rectangular / rounded placeholder
│           ├── skeleton_circle.dart    # Circular avatar / icon placeholder
│           ├── skeleton_text.dart      # Single and multi-line text placeholders
│           ├── skeleton_card.dart      # Themed surface card container
│           ├── skeleton_list_item.dart # Activity row placeholder
│           ├── page_skeletons.dart     # Home, Timetable, Dashboard, History, Health, Admin
│           └── skeleton.dart           # Barrel export
├── features/
│   ├── admin/                # Database integrity audit screen
│   ├── daily_status/         # Status editor dialog and remark bottom sheet
│   ├── dashboard/            # KPI cards and fl_chart visualizations
│   ├── focus/                # Digital Wellbeing & Focus Mode
│   │   ├── domain/           # Models, intervals, & schedule evaluator
│   │   ├── data/             # Local storage & native platform channel
│   │   ├── providers/        # Riverpod notifier & transition providers
│   │   └── presentation/     # Focus hub screen & modular wellbeing cards
│   ├── history/              # Paginated date-range history screen
│   ├── home/                 # Today's overview, stats ring, and activity list
│   ├── settings/             # Theme, Focus Mode entry, API health, & token config
│   └── timetable/            # Date calendar timetable browser
└── shared/
    ├── models/               # Strongly-typed immutable JSON models
    ├── providers/            # Riverpod providers with cache invalidation
    ├── services/             # SharedPreferences & FlutterSecureStorage
    └── widgets/              # Status badges, DayType chips, Metric cards, AppHeaderLogo
```

- **Framework:** Flutter 3.47+ / Dart 3.13+
- **State Management:** `flutter_riverpod` (v3.x `Notifier` & `AsyncNotifier`)
- **Networking:** `http` with custom `RedirectAwareClient`
- **Charts:** `fl_chart`
- **Secure Storage:** `flutter_secure_storage` (Platform Keystore/Keychain)
- **Preferences:** `shared_preferences`

---

## 🧘 Digital Wellbeing & Focus Mode Guide

The application features an integrated, schedule-based **Focus Mode** that supports mindful routine adherence during study, evening wind-down, and sleep.

### 1. Default Schedule & Cross-Midnight Interval Math
The default schedule divides the 24-hour day into three focused wellbeing intervals using device-local time:

| Phase | Default Window | Description |
|---|---|---|
| **Morning Focus** | `05:00 – 09:00` | Morning routine, planning, exercise, and deep study |
| **Night Focus** | `20:30 – 22:15` | Evening reflection, wind-down, and reading |
| **Sleep Focus** | `22:15 – 05:15` | Overnight rest and screen detachment (crosses midnight) |

- **Cross-Midnight Calculation:** The interval `[22:15 – 05:15)` crosses midnight. The evaluator computes this as `minuteOfDay >= 1335 || minuteOfDay < 315`.
- **05:00 – 05:15 Overlap Resolution:** Morning Focus (`05:00 – 09:00`) and Sleep Focus (`22:15 – 05:15`) overlap by 15 minutes between `05:00` and `05:15`. By specification, the system defaults to **Sleep Focus priority** during this window. Users can customize this priority directly in the schedule manager (switching between Sleep or Morning priority).
- **Customizable Intervals:** Users can edit start and end times for each phase using native time pickers or restore default intervals with confirmation.

### 2. Essential-App Allowlist
To ensure safety and day-to-day productivity are never compromised, critical tools remain exempt:
- **Emergency & Communication:** Phone calls / dialer, SMS / system messaging, WhatsApp.
- **Time & Navigation:** Alarm / Clock, Google Maps navigation.
- **Study & AI Tools:** YouTube (educational), ChatGPT, Google Gemini.
- **Financial & Banking:** Google Pay, PhonePe, Paytm, super.money (UPI), SBI UPI / Banking.
- **Custom App Allowlisting:** Add any custom Android package name or app title on-demand.

### 3. Grace Period & Emergency Override Breaks
- **Grace Period (0, 1, 3, 5, 10 min):** When entering an un-allowlisted application during an active focus phase, a grace period (default: 5 minutes) buffers brief lookups. If distraction exceeds the grace period, respectful notification reminders invite the user back to TimeTable.
- **Emergency Override (5 or 10 min):** When unexpected urgent tasks arise, users can activate a limited emergency break. A visible countdown banner tracks remaining break time without shaming or punitive locks.

### 4. Platform Capabilities & Truth in Enforcement
A standard consumer application cannot silently kill or force-stop arbitrary third-party apps. The app reports platform capabilities truthfully:
- **Android (`Active` / `Needs permission`):**
  - Uses official `UsageStatsManager` (`android.permission.PACKAGE_USAGE_STATS`) after explicit user consent.
  - Detects foreground app package and duration on-device without background polling drain.
  - Sends notifications (`POST_NOTIFICATIONS`) inviting the user back to TimeTable.
  - **No root, no deceptive Accessibility services, and no deceptive claims of killing apps.**
- **iOS (`Reminder-only` / `Unsupported`):**
  - Discloses that third-party app termination requires Apple's `FamilyControls` and `ManagedSettings` entitlements.
  - In absence of Apple Screen Time entitlements, functions truthfully as a reminder and schedule tracker.
- **Desktop & Web (`Reminder-only`):**
  - Tracks schedules and displays countdowns and transition reminders inside the app.

### 5. Privacy & Data Retention
- **100% On-Device:** Zero installed packages, foreground timestamps, or usage data are ever sent outside mobile device.
- **Local Summaries Only:** Only total daily focused minutes and override counts are stored locally in `SharedPreferences`.
- **One-Tap Erasure:** The privacy card provides an immediate "Clear Focus History" option to wipe all stored statistics.
- **Permission Revocation:** The app provides direct shortcuts to Android System Settings where users can revoke Usage Access or Notifications at any time.

---

## 🔒 Security & Token Handling

> [!WARNING]
> **Mobile Client Token Security Notice**
> Mobile application binaries can be decompiled and inspected. Never embed sensitive admin tokens (`ADMIN_API_TOKEN`) or production database master secrets in a public Flutter client binary.
>
> 1. For private prototype/internal usage, user tokens can be supplied at compile time or entered via the in-app Settings screen, which stores the token locally using platform-encrypted storage (`flutter_secure_storage`).
> 2. The admin database validation audit (`validateDatabase`) is isolated behind explicit user confirmation and requires entering the admin token on-demand; it is never hardcoded.
> 3. For public multi-user production deployments, a proper authentication backend (e.g. Firebase Auth, Supabase, OAuth 2.0) issuing short-lived user-scoped tokens should be deployed in front of the spreadsheet.

---

## 🚀 Getting Started

### 1. Prerequisites
- Flutter SDK 3.47+ (`flutter --version`)
- Dart SDK 3.13+
- Android Studio / Xcode (for mobile deployments) or Chrome (for web)

### 2. Configuration
Copy `.env.example` or pass configuration flags via `--dart-define`:

```bash
# Compile with your Google Apps Script Web App Deployment URL and API token
flutter run \
  --dart-define=API_BASE_URL="https://script.google.com/macros/s/AKfycb.../exec" \
  --dart-define=API_TOKEN="your_personal_user_token" \
  --dart-define=APP_ENV=development
```

Alternatively, launch the app directly and configure the Web App URL and User API Token through the **Settings** screen.

---

## 🧪 Testing, Formatting, and Analysis

Run static analysis:
```bash
flutter analyze
```

Format code:
```bash
dart format .
```

Run test suite:
```bash
flutter test
```

Build release Android App Bundle:
```bash
flutter build appbundle --release
```

---

## ⚡ Automation Scripts (`scripts/`)

Interactive PowerShell utility scripts are available for project operations:

- **`scripts\build_project.ps1`**:
  - Interactive multi-target build orchestration (Android AAB/APK, iOS, Windows Desktop, Web).
  - Automatically runs `update_version.ps1`, cleans project, resolves dependencies, and compiles the selected target with artifact size reporting.
- **`scripts\run_project.ps1`**:
  - Interactive launcher for Android, Windows, Web, or iOS.
  - Supports device selection, target architecture (ARM64 vs Universal), and IDE log filtering (VS Code, Google Antigravity).
- **`scripts\update_version.ps1`**:
  - Automatically increments the developer build number (`+B`) on every run.
  - Interactively prompts for Feature Version updates (**[L]**arge / Major, **[M]**edium / Minor, **[S]**mall / Patch).
  - Synchronously updates `pubspec.yaml`, `lib/config/app_config.json`, and `lib/core/config/app_config.dart`.


---

## 🛠️ Google Apps Script Backend Deployment Checklist

Ensure your Google Apps Script Web App is deployed with:
1. **Execute as:** `Me (your Google account)`
2. **Who has access:** `Anyone` (authentication is handled via the `API_TOKEN` parameter in the request payload/query)
3. **Script Properties configured:**
   - `SPREADSHEET_ID`: Target document ID
   - `API_TOKEN`: User access token
   - `ADMIN_API_TOKEN`: Administrative access token
   - `TIMEZONE`: `Asia/Kolkata`
