# Architecture & Design System

This document outlines the architectural patterns, state management, data flow, cache invalidation rules, and security boundaries implemented in the Time Table & Daily Activity Tracker Flutter app.

---

## 🏛️ Architectural Principles

The application adheres to a **feature-first, layered architecture** designed for maintainability, high testability, and clear separation of concerns:

```
[Presentation Layer]
  - UI Widgets, Screens, Dialogs, BottomSheets
  - Consumes Riverpod Notifiers & FutureProviders
  - No direct HTTP or JSON parsing
         │
         ▼
[Domain & State Management Layer]
  - Riverpod Notifiers (TodayNotifier, ThemeModeNotifier, NavigationNotifier)
  - Family FutureProviders (timetableForDateProvider, dashboardProvider)
  - Reactive cache invalidation across dates
         │
         ▼
[Data Layer - Repositories]
  - TimetableRepository, StatusRepository, DashboardRepository, HistoryRepository, HealthRepository, AdminRepository
  - Maps domain requests to typed API client calls
         │
         ▼
[Core Infrastructure Layer]
  - ApiClient (Envelope parsing, error mapping, token attachment)
  - RedirectAwareClient (Apps Script 302 handling, domain allowlists, HTML detection)
  - StorageService (FlutterSecureStorage & SharedPreferences)
```

---

## 🔄 State Management & Cache Invalidation

State is managed cleanly via **Riverpod 3.x** using `Notifier` and `AsyncNotifier`.

### Invalidation & Write Consistency Rules
Whenever a user modifies activity status or daily reflection via:
- `updateActivity(...)`
- `updateRemark(...)`
- `saveStatus(...)`

The app automatically invalidates relevant dependent caches to avoid stale reads:
1. `todayProvider` updates its internal state directly from the backend response.
2. `statusForDateProvider(date)` is invalidated.
3. `dashboardProvider(date)` is invalidated so graphs immediately reflect new metrics.
4. `historyProvider` is invalidated so log entries reflect the latest completion rate.

---

## 🌐 Google Apps Script Redirect Handling

Google Apps Script Web Apps deploy behind Google's frontend proxy and ContentService:
1. **POST Request:** Sent to `https://script.google.com/macros/s/.../exec`.
2. **Redirect:** The server executes `doPost(e)` and responds with HTTP 302 Found pointing to `https://script.googleusercontent.com/macros/echo?...`.
3. **Echo Fetch:** `RedirectAwareClient` detects the 302, switches HTTP method to `GET` (per Apps Script ContentService spec), and retrieves the final JSON payload.
4. **Security Boundary:** Redirects are restricted to an allowlist (`*.google.com`, `*.googleusercontent.com`). If redirected to an unknown domain, execution is halted with `ApiException.untrustedRedirect`.
5. **Content-Type Verification:** If the response is `text/html` (e.g. Google Accounts sign-in or Drive 404), `RedirectAwareClient` raises `ApiException.unexpectedContentType` with guidance on deployment permissions ("Who has access: Anyone").

---

## 📅 Timezone & Date-Only Invariant

- Default timezone context is **Asia/Kolkata (UTC+05:30)** matching the backend configuration.
- To prevent UTC/local date shifts (where a local evening date might convert to tomorrow in UTC), all date keys are handled strictly as `YYYY-MM-DD` strings using `AppDateUtils`.
- `AppDateUtils.todayDateString()` computes Kolkata time by applying the `+05:30` offset before extracting year, month, and day.

---

## 🛡️ Security Architecture

1. **Admin Token Isolation:**
   - The database integrity audit endpoint (`validateDatabase`) requires `ADMIN_API_TOKEN`.
   - The admin token is **never** bundled into public mobile builds, never placed in preferences, and never logged.
   - The admin screen is conditionally accessible only in development mode or via intentional unlock.
2. **User Token Security:**
   - The user API token is stored using platform-native hardware encryption via `flutter_secure_storage` (Android Keystore / iOS Keychain).
3. **Secret Redaction in Logs:**
   - All outgoing URLs and error messages pass through `RedirectAwareClient.redactSecrets`, which sanitizes `token=...`, `apiToken=...`, and `Bearer ...` tokens before logging.

---

## 💎 Skeleton Loading UI & State Transition Architecture

To provide an elite, polished user experience without layout shifts or jarring spinners, the application implements a dedicated **Skeleton Loading Design System** (`lib/core/widgets/skeleton/`).

### 1. Architectural Design & Primitives
- **Zero-Dependency Native Animation:** Built strictly with Flutter's core framework (`AnimationController`, `InheritedWidget`, `SlidingGradientTransform`, and `LinearGradient`) to guarantee 100% stability across Android, iOS, Windows Desktop, and Web without third-party package conflicts or deprecations.
- **Synchronized Wave Animation (`Shimmer` & `ShimmerScope`):**
  - A single orchestrator `Shimmer` widget drives a smooth horizontal sweeping gradient across all child placeholders simultaneously.
  - Skeletons obtain animation progress and theme-derived colors through `ShimmerScope`, repainting only their individual `BoxDecoration` layers without triggering entire-page rebuilds.
- **Reusable Building Blocks:**
  - `SkeletonBox`: Rounded rectangular placeholder block with customizable width, height, and corner radius.
  - `SkeletonCircle`: Circular placeholder for avatar icons, circular badges, and progress rings.
  - `SkeletonText`: Single-line or multi-line text line placeholders with configurable line count, heights, and natural last-line width variance.
  - `SkeletonCard`: Container styled to match the app's Card surface, border elevation, and padding.
  - `SkeletonListItem`: Composed activity/history row skeleton with leading avatar, title, subtitle, time indicator, and trailing status badge.

### 2. Page-Level Skeletons (`page_skeletons.dart`)
Every screen that loads API data has a custom skeleton layout mirroring its real content:
- **`HomeSkeleton`:** Date heading, day type chip, overview progress card (96px progress ring, 4 stat rows, linear progress bar), daily reflection card, section title, and 4 activity card skeletons.
- **`TimetableSkeleton`:** Timetable header chip, activity count, reflection card, and 5 activity row skeletons.
- **`DashboardSkeleton`:** 2x2 KPI metrics grid, donut chart card with legend placeholders, and 3 activity breakdown rows.
- **`HistorySkeleton`:** Date range summary row, 5 full history day cards (with date, day type, completion badge, progress bar, and 4 status pill indicators).
- **`HealthStatusSkeleton`:** 3 diagnostic check rows with status indicators and latency pills in Settings.
- **`AdminAuditSkeleton`:** Audit summary score card and 4 database schema check cards in Admin.
- **`PaginationLoadingFooter`:** Compact bottom shimmer indicator for pagination without tearing down loaded rows.

### 3. Theme Adaptation & Accessibility
- **Theme-Aware Color Palettes:**
  - **Light Theme:** Base color uses `theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55)` with high-contrast highlight `theme.colorScheme.surface.withValues(alpha: 0.95)`.
  - **Dark Theme:** Base color uses `theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)` with highlight `theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.75)`.
- **Reduced-Motion Fallback:** Automatically respects `MediaQuery.of(context).disableAnimations`. If reduced motion is requested by the user's OS, animation is stopped and static calm placeholders are rendered.
- **Screen Reader Semantics:** Wrapped in `Semantics(label: 'Loading content', container: true, excludeSemantics: true)` so screen readers announce a single concise loading message instead of reading dozens of individual skeleton rectangles.

### 4. Comprehensive State Transition Model
| State | Visual Behavior | User Experience |
|---|---|---|
| **Initial Load** | Full-page layout skeleton (`HomeSkeleton`, etc.) | Eliminates blank screens and jarring spinners. |
| **Background Refresh** | Existing data remains fully visible; native `RefreshIndicator` or header refresh cue spins | Prevents screen flashing while fetching fresh data. |
| **Pagination** | Existing loaded records are retained; bottom `PaginationLoadingFooter` shimmers | Seamless browsing experience without scroll resets. |
| **Saving / Updating** | Dialog/button-level loading indicator (`isSubmitting`); user inputs are preserved | Prevents duplicate submissions without reloading the entire page. |
| **Success (with Data)** | Real content replaces skeleton with zero layout shift | Smooth transition into interactive cards and charts. |
| **Success (Empty)** | Descriptive `EmptyState` with icon and guidance message | Explicitly informs user that no data exists (distinguished from loading). |
| **Failure / Error** | `AppErrorView` with human-readable error and "Try Again" retry button | Resilient error recovery with token redaction. |

---

## 🥊 Forceful Restriction & Digital Wellbeing Architecture ("The Bouncer")

To help users strictly adhere to their timetable, combat digital addiction, and prevent mindless social media scrolling, the app features an active **Forceful Restriction System ("The Bouncer")** (`lib/features/focus/` & native Android subsystem).

### 1. Four Time Phases & Schedule Mathematics
The system divides the 24-hour day into 4 distinct phases evaluated dynamically:
1. **Morning Restriction Phase (`05:00 AM – 09:00 AM`):**
   - **Mode:** Full Restriction (0-second grace period).
   - Distracting / non-allowlisted apps cannot be used at all. Opening them immediately triggers the two-step auto-close and displays the block shield.
2. **Daytime Flexible Phase (`09:00 AM – 08:30 PM`):**
   - **Mode:** 5-Minute Countdown Timer + Cooldown Lock.
   - Opening a tracked distracting app (e.g. Instagram, Facebook) begins a 5-minute countdown.
   - At **4:00 elapsed (1 minute remaining)**, a high-priority heads-up warning notification and vibration are triggered (*"1 minute left on [App]! Wrap up what you are doing."*).
   - At **5:00 elapsed (0:00 remaining)**, the app is forcefully auto-closed and locked in a **Cooldown Period** (configurable: 30, 60, or 120 minutes; default: 60 minutes).
3. **Night Restriction Phase (`08:30 PM – 10:15 PM`):**
   - **Mode:** Full Restriction (0-second grace period).
   - Immediate auto-close on any restricted app.
4. **Sleeping Restriction Phase (`10:15 PM – 05:15 AM`):**
   - **Mode:** Full Restriction across midnight (`22:15` to `05:15`).
   - Seamlessly transitions into Morning Restriction (`05:00 – 09:00`) between `05:00 AM` and `05:15 AM` with zero gap.

### 2. Forceful Auto-Close Mechanism ("The Bouncer")
Because standard Android sandboxing prohibits `killBackgroundProcesses` from terminating foreground third-party apps, TimeTable implements the industry-standard two-step enforcement mechanism:
- **Step 1 — Immediate Home Kick:**
  Fires an Android Home Intent (`Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)`), instantly pushing the distracting app out of the foreground.
- **Step 2 — Full-Screen Block Shield (`FocusBlockActivity`):**
  Launches a dedicated high-priority native activity or `TYPE_APPLICATION_OVERLAY` window over other apps displaying:
  - Blocked app name and icon pill.
  - Clear rationale (e.g. *"5-Minute Limit Reached — Cooldown active until 3:15 PM"* or *"Night Restriction Active (8:30 PM – 10:15 PM)"*).
  - Primary button: **"Return to TimeTable / Home"**.
- Re-opening a restricted app during Cooldown or Full Restriction is detected within 1.5 seconds and immediately triggers the two-step kick again.

### 3. Native Background Enforcement Service (`FocusEnforcementService.kt`)
- **Persistent Lightweight Service:** Runs as an Android Foreground Service with type `specialUse` (API 34+ compliant) and an ongoing status notification showing the active phase.
- **Interactive Screen Polling Only:** Monitors foreground apps using `UsageStatsManager.queryEvents` every **1.5 to 2.0 seconds ONLY while the screen is interactive (`PowerManager.isInteractive`)**.
- **Zero Battery Drain When Screen is Off:** Registers a dynamic `BroadcastReceiver` for `Intent.ACTION_SCREEN_OFF` and `Intent.ACTION_SCREEN_ON` (and `ACTION_USER_PRESENT`). Polling stops completely when the screen is off or device locked.
- **State Persistence:** Countdown timers, active usage sessions, and cooldown expiration timestamps are persisted in native `SharedPreferences` so process restarts or Flutter UI closure never bypass restrictions.
- **Boot Recovery (`BootReceiver.kt`):** Automatically restores `FocusEnforcementService` on device boot if Restriction Mode is enabled.

### 4. VIP Exception Allowlist (Always Allowed 24/7)
Essential study, utility, communication, and financial apps are permanently protected from restrictions and countdown timers across all phases:
- **TimeTable App itself** (`com.timetable`)
- **System & Core Phone:** Phone dialers (`com.google.android.dialer`, Samsung/OEM dialers), Contacts, SMS/Messaging, System Settings, System UI, and default Home Launchers (dynamically resolved via `PackageManager`).
- **Communication:** WhatsApp & WhatsApp Business (`com.whatsapp`, `com.whatsapp.w4b`).
- **Alarms & Clock:** Google DeskClock, Samsung Clock, OnePlus Clock, ColorOS/MIUI Clock.
- **Navigation:** Google Maps (`com.google.android.apps.maps`).
- **Study & AI Tools:** YouTube (`com.google.android.youtube`), ChatGPT (`com.openai.chatgpt`), Google Gemini (`com.google.android.apps.bard`).
- **UPI, Payments & Banking Apps:** super.money (`money.super.app`, `in.super.money`), Google Pay (`com.google.android.apps.nbu.paisa.user`), PhonePe (`com.phonepe.app`), Paytm (`net.one97.paytm`), BHIM (`in.org.npci.upiapp`), CRED (`com.dreamplug.androidapp`), SBI YONO, HDFC, ICICI, Axis, Kotak, and Indian banking apps.
- **Keyword Fallback:** Heuristic fallback for any installed package matching payment, banking, dialer, or alarm keywords.

### 5. Anti-Impulse Protection (30-Second Pause Rule)
To prevent spontaneous surrender when cravings strike:
- During normal daytime hours without active cooldowns, the user can toggle Restriction Mode or modify schedules normally.
- If the user attempts to turn **OFF** the master toggle or remove an app while a **Full Restriction Phase is active OR while an app is locked in cooldown**, an anti-impulse dialog is presented:
  - Requires a non-dismissible **30-second live countdown timer**.
  - Requires typing the exact confirmation phrase: `"I have an urgent reason"`.
  - Only when both conditions are satisfied is the unlock button activated.

### 6. Smart Study & Browser Loophole Protections
- **YouTube 30-Minute Study Check-In:**
  Because YouTube is allowed for study lectures, if YouTube remains continuously in the foreground for 30 minutes during a restriction phase, a non-destructive check-in prompt appears asking: *"30-Minute Study Check: Are you watching a study lecture or scrolling Shorts?"* with options to continue studying for another 30 minutes or close YouTube.
- **Browser Loophole Protection:**
  When enabled, web browsers (Chrome, Brave, Firefox, Edge, Samsung Browser) are placed under the 5-minute daytime grace timer during restriction hours so users cannot bypass Instagram blocks via `instagram.com`.

### 7. Diagnostics & Installed App Picker
- **Interactive Focus Diagnostics Dialog:** Reports Usage Access, Display Over Other Apps (Overlay), Background Service status, active phase, cooldown locks, and today's interception count. Includes a **"Test Block Shield Now"** button to preview the full-screen blocker.
- **Installed App Picker:** Searchable modal in the Flutter UI querying launchable apps directly from `PackageManager` to effortlessly add apps to either the VIP Exception Allowlist or Distracting Apps list.


