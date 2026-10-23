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

- Default timezone context is **Asia/Kolkata (UTC+05:30)** matching the backend Google Sheets configuration.
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
