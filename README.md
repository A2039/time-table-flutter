# Time Table & Daily Activity Tracker (Flutter)

A modern, fast, responsive production Flutter application for tracking and managing date-based timetables and daily activity execution. Built with **Material 3**, **Riverpod**, and direct integration with the **Google Apps Script Web App API** and **Google Sheets** database.

---

## ✨ Features

- **Today's Overview & Status (`getToday`):**
  - Instant combined fetch of today's schedule activities and saved execution statuses in a single roundtrip.
  - Interactive status badges: **Completed On Time** (`"y"`), **Completed Late** (with minute duration), **Not Completed** (`"n"`), and **Unrecorded** (`null`).
  - Animated completion progress ring and breakdown stats.
  - Daily reflection card with live editing.
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
  - Live reachability check in Settings displaying Google Sheets database connectivity, expected sheet presence, and backend timezone.
- **Admin Database Integrity Audit (`validateDatabase`):**
  - Isolated behind explicit admin authorization.
  - Deep read-only verification of spreadsheet structure, headers, formulas, and schema.

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
├── features/
│   ├── admin/                # Database integrity audit screen
│   ├── daily_status/         # Status editor dialog and remark bottom sheet
│   ├── dashboard/            # KPI cards and fl_chart visualizations
│   ├── history/              # Paginated date-range history screen
│   ├── home/                 # Today's overview, stats ring, and activity list
│   ├── settings/             # Theme, API health test, and secure token config
│   └── timetable/            # Date calendar timetable browser
└── shared/
    ├── models/               # Strongly-typed immutable JSON models
    ├── providers/            # Riverpod providers with cache invalidation
    ├── services/             # SharedPreferences & FlutterSecureStorage
    └── widgets/              # Status badges, DayType chips, Metric cards
```

- **Framework:** Flutter 3.47+ / Dart 3.13+
- **State Management:** `flutter_riverpod` (v3.x `Notifier` & `AsyncNotifier`)
- **Networking:** `http` with custom `RedirectAwareClient`
- **Charts:** `fl_chart`
- **Secure Storage:** `flutter_secure_storage` (Platform Keystore/Keychain)
- **Preferences:** `shared_preferences`

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
   - `SPREADSHEET_ID`: Target Google Sheets document ID
   - `API_TOKEN`: User access token
   - `ADMIN_API_TOKEN`: Administrative access token
   - `TIMEZONE`: `Asia/Kolkata`
