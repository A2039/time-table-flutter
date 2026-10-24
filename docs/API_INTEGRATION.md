# API Integration Reference

This document provides a comprehensive specification of all 10 backend endpoints exposed by the Google Apps Script Web App, their request/response schemas, envelope wrapping, authentication, redirect handling, and error codes.

---

## Base URL & Transport

- **Base URL:** Configured in `AppConfig.apiBaseUrl` (or overwritten locally in `Settings`). Must end with `/exec`:
  `https://script.google.com/macros/s/<DEPLOYMENT_ID>/exec`
- **Protocol:** HTTPS / TLS only.
- **Timezone:** `Asia/Kolkata` (UTC+05:30).

---

## Authentication Strategy

The API enforces token-based authorization configured in the Google Apps Script Script Properties (`API_TOKEN` and `ADMIN_API_TOKEN`).

1. **GET Requests:**
   Token is passed as an URL-encoded query parameter:
   `?action=<ACTION>&token=<API_TOKEN>`
2. **POST Requests:**
   Token is included inside the JSON request body:
   `{ "action": "<ACTION>", "token": "<API_TOKEN>", ... }`
3. **Admin Endpoints:**
   `validateDatabase` requires `ADMIN_API_TOKEN`. It is never bundled into public releases and must be supplied on-demand.
4. **Public Endpoints:**
   `health` is public/optional authentication.

---

## Google Apps Script Redirects & Response Envelope

### Redirect Behavior (`RedirectAwareClient`)
Google Apps Script Web Apps (`ContentService`) frequently respond with HTTP 302 Found redirects:
- A GET request redirects to a temporary CDN URL on `script.googleusercontent.com`.
- A POST request redirects with HTTP 302/303 to a GET on `https://script.googleusercontent.com/macros/echo?...` which returns the JSON payload.
- `RedirectAwareClient` follows these redirects with:
  1. Strict host allowlist (`script.google.com`, `script.googleusercontent.com`, `google.com`).
  2. Bounded redirect count (max 5).
  3. Method switching from POST to GET upon receiving a 302/303 redirect.
  4. Detection of unexpected `text/html` responses (such as Google Sign-in prompts or Drive permissions errors), raising a typed `ApiException.unexpectedContentType`.

### Envelope Formats

#### Success Envelope (HTTP 200)
```json
{
  "success": true,
  "message": "Request completed successfully",
  "data": { ... },
  "meta": {
    "requestId": "server-generated-id",
    "timestamp": "2026-10-23T14:30:00.000Z"
  }
}
```

#### Error Envelope (HTTP 200 or 4xx/5xx)
```json
{
  "success": false,
  "message": "Validation failed for one or more fields.",
  "error": {
    "code": "VALIDATION_ERROR",
    "details": ["Field 'date' is required"]
  },
  "meta": {
    "requestId": "server-generated-id",
    "timestamp": "2026-10-23T14:30:05.000Z"
  }
}
```

---

## Endpoint Inventory

### 1. Health Check
- **Method:** `GET`
- **Query:** `action=health`
- **Auth:** Public / Optional
- **Response Data:**
```json
{
  "status": "ok",
  "environment": "production",
  "timeZone": "Asia/Kolkata",
  "database": {
    "connected": true,
    "expectedSheetsPresent": true,
    "message": "Connected to Google Spreadsheet successfully"
  }
}
```

### 2. Get Timetable for a Date
- **Method:** `GET`
- **Query:** `action=getTimetable&date=YYYY-MM-DD[&day_type=weekday|weekend]`
- **Auth:** User / Admin
- **Response Data:**
```json
{
  "date": "2026-10-23",
  "dayType": "weekday",
  "isDayTypeOverridden": false,
  "totalActivities": 13,
  "activities": [
    {
      "srno": 1,
      "category": "Physical",
      "time": "06:00 - 07:00",
      "duration": "60 min",
      "timePeriod": "Morning Yoga",
      "description": "प्राणायाम एवं ध्यान सत्र",
      "startTime": "06:00",
      "endTime": "07:00"
    }
  ]
}
```

### 3. Get Today's Timetable & Saved Status
- **Method:** `GET`
- **Query:** `action=getToday`
- **Auth:** User / Admin
- **Response Data:**
```json
{
  "date": "2026-10-23",
  "dayType": "weekday",
  "timetable": [ ... ],
  "status": {
    "exists": true,
    "srno": 12,
    "date": "2026-10-23",
    "dayType": "weekday",
    "statuses": {
      "1": "y",
      "2": 15,
      "3": "n",
      "4": null
    },
    "remark": "Focused day"
  }
}
```

### 4. Get Daily Status for a Date
- **Method:** `GET`
- **Query:** `action=getStatus&date=YYYY-MM-DD`
- **Auth:** User / Admin
- **Response Data:**
```json
{
  "exists": false,
  "date": "2026-10-23",
  "dayType": "weekday",
  "statuses": {},
  "remark": ""
}
```
*Note: `exists: false` is not an error; it indicates no record has been created yet.*

### 5. Save Daily Status
- **Method:** `POST`
- **Query:** `action=saveStatus`
- **Auth:** User / Admin
- **JSON Body:**
```json
{
  "date": "2026-10-23",
  "statuses": {
    "1": "y",
    "2": "n",
    "3": 10,
    "4": null
  },
  "remark": "Completed tasks on time",
  "replaceAll": false,
  "token": "..."
}
```
*Status values: `"y"` (on time), `"n"` (not completed), positive integer (late minutes), `null` (unrecorded).*

### 6. Update One Activity
- **Method:** `POST`
- **Query:** `action=updateActivity`
- **Auth:** User / Admin
- **JSON Body:**
```json
{
  "date": "2026-10-23",
  "activityNo": 3,
  "status": 15,
  "token": "..."
}
```

### 7. Update Daily Remark
- **Method:** `POST`
- **Query:** `action=updateRemark`
- **Auth:** User / Admin
- **JSON Body:**
```json
{
  "date": "2026-10-23",
  "remark": "Reflections for the day.",
  "token": "..."
}
```

### 8. Get History
- **Method:** `GET`
- **Query:** `action=getHistory&from=YYYY-MM-DD&to=YYYY-MM-DD&page=1&pageSize=20[&dayType=weekday|weekend]`
- **Auth:** User / Admin
- **Response Data:**
```json
{
  "records": [
    {
      "date": "2026-10-22",
      "dayType": "weekday",
      "statuses": { "1": "y", "2": "n" },
      "remark": "Productive",
      "completedOnTime": 1,
      "completedLate": 0,
      "notCompleted": 1,
      "notRecorded": 0,
      "completionPercentage": 50.0
    }
  ],
  "pagination": {
    "totalRecords": 18,
    "totalPages": 1,
    "currentPage": 1,
    "pageSize": 20,
    "hasNext": false,
    "hasPrev": false
  },
  "filter": {
    "from": "2026-10-01",
    "to": "2026-10-23",
    "dayType": null
  }
}
```

### 9. Get Dashboard
- **Method:** `GET`
- **Query:** `action=getDashboard&date=YYYY-MM-DD`
- **Auth:** User / Admin
- **Response Data:**
```json
{
  "date": "2026-10-23",
  "dayType": "weekday",
  "hasSavedStatus": true,
  "metrics": {
    "totalActivities": 13,
    "completedOnTime": 9,
    "completedLate": 2,
    "notCompleted": 1,
    "notRecorded": 1,
    "totalCompleted": 11,
    "totalRecorded": 12,
    "totalLateMinutes": 25,
    "completionPercentage": 84.6,
    "recordedPercentage": 92.3
  },
  "remark": "Good momentum",
  "activities": [ ... ]
}
```

### 10. Database Validation (Admin Only)
- **Method:** `GET`
- **Query:** `action=validateDatabase`
- **Auth:** Admin Only (`ADMIN_API_TOKEN`)
- **Response Data:**
```json
{
  "overallStatus": "PASSED",
  "summary": {
    "totalErrors": 0,
    "totalWarnings": 0
  },
  "checks": {
    "sheetStructure": {
      "name": "sheetStructure",
      "status": "PASSED",
      "errors": [],
      "warnings": []
    }
  }
}
```

---

## Mapped Error Codes

| Code | Meaning | User Feedback |
|---|---|---|
| `UNAUTHORIZED` | Token missing or invalid | "Authentication required. Please check your token in Settings." |
| `FORBIDDEN` | Insufficient role | "Access denied. Insufficient permissions." |
| `VALIDATION_ERROR` | Validation failure | Displays input error details. |
| `INVALID_DATE` | Date is not YYYY-MM-DD | "Invalid date format specified." |
| `INVALID_ACTIVITY` | Slot out of range | "Invalid activity slot." |
| `INVALID_STATUS` | Unsupported status value | "Must be 'y', 'n', or positive integer minutes." |
| `LOCK_TIMEOUT` | Spreadsheet concurrency lock | Safe manual retry offered to user. |
| `SERVER_MISCONFIGURED` | Script Properties missing | "Backend configuration error." |
| `INTERNAL_ERROR` | Unhandled backend exception | Generic safe failure with requestId. |
| `UNEXPECTED_CONTENT_TYPE` | Received HTML instead of JSON | "Google sign-in prompt or deployment permissions issue." |

---

## Client-Side Loading & Skeleton State Mapping

During network transport and Apps Script execution, the Flutter frontend avoids blank screens and small spinners by presenting high-fidelity skeleton placeholders mirroring each endpoint's response layout:

| Endpoint | Action | Client Presentation State | Loading Placeholder Widget | Error & Empty Fallback |
|---|---|---|---|---|
| `getToday` | `GET` | Home / Today Screen | `HomeSkeleton` | `AppErrorView` with retry; `EmptyState` if schedule empty |
| `getTimetable` | `GET` | Date Timetable Screen | `TimetableSkeleton` | `AppErrorView` with retry; `EmptyState` for unscheduled dates |
| `getStatus` | `GET` | Included in Today / Timetable | Handled inline within page skeletons | Defaults to `exists: false` gracefully |
| `updateActivity` | `POST` | Status Editor Dialog | Button indicator (`isSaving`); dialog remains open | Error banner in dialog; preserves entered values |
| `updateRemark` | `POST` | Remark Bottom Sheet | Button indicator (`isSaving`); sheet remains open | Error snackbar; preserves entered reflection text |
| `saveStatus` | `POST` | Batch Status Save | Button loading indicator | Error banner; retains form state |
| `getDashboard` | `GET` | Analytics Dashboard Screen | `DashboardSkeleton` | `AppErrorView` with retry; `EmptyState` if no activity recorded |
| `getHistory` | `GET` | Historical Records Screen | `HistorySkeleton` (initial) / `PaginationLoadingFooter` (pagination) | `AppErrorView` with retry; `EmptyState` if no matching records |
| `health` | `GET` | Settings Connectivity Section | `HealthStatusSkeleton` | Diagnostic error row with exception details |
| `validateDatabase` | `GET` | Admin Integrity Audit Screen | `AdminAuditSkeleton` | Detailed error view with admin retry action |

