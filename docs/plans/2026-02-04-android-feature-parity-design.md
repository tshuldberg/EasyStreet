# Android Feature-Parity Port — Design Document

**Date:** 2026-02-04
**Status:** Approved
**Scope:** Full feature-parity port of iOS MVP to Android with full dataset integration

---

## Goals

Port the complete iOS EasyStreet MVP to Android using Jetpack Compose, with two key improvements over the current iOS state:
1. Full 37K-row street sweeping dataset integrated from the start (via bundled SQLite)
2. Dynamic holiday calculation (no hardcoded years)

## Architecture

**Pattern:** MVVM with Jetpack Compose

```
┌─────────────────────────────────────┐
│           UI Layer (Compose)        │
│  MapScreen  │  ParkingSheet  │ etc  │
├─────────────────────────────────────┤
│          ViewModel Layer            │
│  MapViewModel  │  ParkingViewModel  │
├─────────────────────────────────────┤
│         Repository Layer            │
│  StreetRepository  │  ParkingRepo   │
├─────────────────────────────────────┤
│           Data Layer                │
│  SQLite DB  │  SharedPreferences    │
│  (streets)  │  (parked car state)   │
└─────────────────────────────────────┘
```

- **Compose UI** — Single-activity app with Compose screens. Google Maps via `maps-compose` library.
- **ViewModels** — Hold UI state, coordinate between repositories. Survive configuration changes.
- **Repositories** — Abstract data access. `StreetRepository` queries SQLite for segments by viewport bounds. `ParkingRepository` manages parked car state via SharedPreferences.
- **SweepingRuleEngine** — Pure Kotlin port of the iOS business logic. Stateless utility, easily testable.
- **NotificationScheduler** — Wraps WorkManager to schedule/cancel sweeping alerts.

**Data flow for the main use case:**
1. User parks → GPS captured → saved to SharedPreferences
2. ViewModel queries StreetRepository for nearby segments
3. SweepingRuleEngine evaluates sweeping status
4. NotificationScheduler sets up WorkManager job for 1hr before next sweep
5. Map updates with color-coded overlays for visible viewport

---

## Data Pipeline & SQLite Schema

### Build-time CSV → SQLite Conversion

A Kotlin script (or Gradle task) pre-processes `Street_Sweeping_Schedule_20250508.csv` into a SQLite database bundled in `assets/`. This runs once at build time, not on the user's device.

### Database Tables

```sql
-- Street segments with their geometry
CREATE TABLE street_segments (
    id INTEGER PRIMARY KEY,
    cnn INTEGER,
    street_name TEXT NOT NULL,
    latitude_min REAL,
    latitude_max REAL,
    longitude_min REAL,
    longitude_max REAL,
    coordinates TEXT  -- JSON array of [lat, lng] pairs from WKT LINESTRING
);

-- Sweeping rules linked to segments
CREATE TABLE sweeping_rules (
    id INTEGER PRIMARY KEY,
    segment_id INTEGER REFERENCES street_segments(id),
    day_of_week INTEGER,      -- 1=Mon, 7=Sun
    start_time TEXT,           -- "HH:mm"
    end_time TEXT,             -- "HH:mm"
    week_of_month INTEGER,    -- 1-5, 0=every week
    holidays_observed INTEGER  -- 0=sweeps on holidays, 1=skips holidays
);

CREATE INDEX idx_segments_bounds ON street_segments(
    latitude_min, latitude_max, longitude_min, longitude_max
);
```

### Viewport Query

```sql
SELECT * FROM street_segments
WHERE latitude_max >= ? AND latitude_min <= ?
  AND longitude_max >= ? AND longitude_min <= ?
```

The bounding box index makes this fast even with 37K rows. Coordinates are stored as a JSON string and parsed into polyline points at render time.

---

## Core Kotlin Models & Rule Engine

### Data Models

```kotlin
data class StreetSegment(
    val id: Long,
    val cnn: Int,
    val streetName: String,
    val coordinates: List<LatLng>,
    val bounds: LatLngBounds,
    val rules: List<SweepingRule>
)

data class SweepingRule(
    val dayOfWeek: Int,
    val startTime: LocalTime,
    val endTime: LocalTime,
    val weekOfMonth: Int,     // 0 = every week
    val holidaysObserved: Boolean
)

data class ParkedCar(
    val latitude: Double,
    val longitude: Double,
    val streetName: String,
    val timestamp: Instant
)

enum class SweepingStatus {
    SAFE, TODAY, IMMINENT, UPCOMING, NO_DATA, UNKNOWN
}
```

### SweepingRuleEngine

Pure Kotlin, no Android dependencies:
- `getStatus(rules: List<SweepingRule>, at: LocalDateTime): SweepingStatus`
- `getNextSweepingTime(rules: List<SweepingRule>, after: LocalDateTime): LocalDateTime?`
- `isHoliday(date: LocalDate): Boolean` — dynamic calculation, not hardcoded

Uses `java.time` APIs throughout (no legacy Date/Calendar).

### Holiday Calculator

- Algorithmically computes federal + SF holidays for any year
- Fixed holidays: New Year's, July 4th, Veterans Day, Christmas, etc.
- Floating holidays: MLK Day (3rd Mon Jan), Thanksgiving (4th Thu Nov), etc.
- No hardcoded year — works for 2025, 2026, and beyond

---

## UI & Map Interaction

### Single-activity Compose app with three main UI states:

**1. Map Screen (default)**
- Full-screen Google Map via `maps-compose`
- Color-coded polyline overlays for visible streets:
  - Red — Sweeping today
  - Green — Safe (no sweeping soon)
  - Gray — No data
- Camera move listener with ~300ms debounce triggers viewport re-query
- Floating "I Parked Here" button (bottom center)

**2. Parking Active State**
- Blue marker at parked location
- Draggable pin for manual adjustment (long press + drag)
- Bottom sheet showing:
  - Street name
  - Next sweeping time
  - Sweeping status (color-coded text)
  - "Clear Parking" button
- Status updates in real-time as rules are evaluated

**3. Search**
- Top search bar for address entry
- Android Geocoder API to resolve addresses
- Map animates to searched location

### User Flow
1. App opens → map centers on current location
2. User taps "I Parked Here" → GPS captured, marker placed, bottom sheet appears
3. User can drag pin to adjust → street name + status re-evaluate on drop
4. Notification scheduled via WorkManager
5. User taps "Clear Parking" → marker removed, notification cancelled

No navigation library needed — all one screen with conditional Compose state.

---

## Notifications & Background Work

### WorkManager Setup

```kotlin
val delay = nextSweepTime.minus(1, ChronoUnit.HOURS) - Instant.now()

val workRequest = OneTimeWorkRequestBuilder<SweepingNotificationWorker>()
    .setInitialDelay(delay.toMillis(), TimeUnit.MILLISECONDS)
    .addTag("sweeping_notification")
    .build()

WorkManager.getInstance(context)
    .enqueueUniqueWork("sweeping_alert", ExistingWorkPolicy.REPLACE, workRequest)
```

### SweepingNotificationWorker
- Reads parked car location from SharedPreferences
- Fires notification: "Street sweeping in ~1 hour on [Street Name]. Move your car!"
- Uses a notification channel created at app startup (required API 26+)

### Lifecycle Handling
- **User parks** → schedule work
- **User clears parking** → cancel work by unique name
- **User moves pin** → cancel + reschedule with new street's rules
- **Device reboot** → WorkManager automatically re-enqueues pending work

### Permissions
- `POST_NOTIFICATIONS` — runtime permission required on API 33+, requested when user first parks
- No foreground service needed
- No exact alarm permission needed

---

## Project Structure

```
EasyStreet_Android/app/src/main/
├── kotlin/com/easystreet/
│   ├── EasyStreetApp.kt              # Application class, notification channel setup
│   ├── MainActivity.kt               # Single activity, Compose entry point
│   │
│   ├── data/
│   │   ├── db/
│   │   │   ├── StreetDatabase.kt     # SQLiteOpenHelper, opens bundled DB from assets
│   │   │   └── StreetDao.kt          # Viewport queries, segment + rule loading
│   │   ├── prefs/
│   │   │   └── ParkingPreferences.kt # SharedPreferences wrapper for parked car
│   │   └── repository/
│   │       ├── StreetRepository.kt   # Abstracts DB access, returns domain models
│   │       └── ParkingRepository.kt  # Parked car state management
│   │
│   ├── domain/
│   │   ├── model/
│   │   │   ├── StreetSegment.kt      # Street segment data class
│   │   │   ├── SweepingRule.kt       # Sweeping rule data class
│   │   │   ├── ParkedCar.kt          # Parked car data class
│   │   │   └── SweepingStatus.kt     # Status enum
│   │   └── engine/
│   │       ├── SweepingRuleEngine.kt # Pure Kotlin business logic
│   │       └── HolidayCalculator.kt  # Dynamic holiday computation
│   │
│   ├── ui/
│   │   ├── MapScreen.kt              # Main Compose screen
│   │   ├── MapViewModel.kt           # Map state, viewport queries
│   │   ├── ParkingSheet.kt           # Bottom sheet Compose UI
│   │   ├── ParkingViewModel.kt       # Parking state management
│   │   └── SearchBar.kt              # Address search component
│   │
│   └── notification/
│       ├── NotificationScheduler.kt  # WorkManager scheduling logic
│       └── SweepingNotificationWorker.kt  # Worker that fires notification
│
├── assets/
│   └── easystreet.db                 # Pre-built SQLite database
│
└── res/
    ├── values/strings.xml
    └── drawable/                      # App icon, marker assets
```

### Build Tooling
- A standalone Kotlin script or Gradle task to convert `Street_Sweeping_Schedule_20250508.csv` → `easystreet.db`
- Run once, output committed to `assets/`

~18 Kotlin source files total. Clean separation of concerns, each file with a single responsibility.

---

## Technical Decisions Summary

| Decision | Choice | Reasoning |
|----------|--------|-----------|
| UI Framework | Jetpack Compose | Modern, declarative, already configured in project |
| Maps | Google Maps SDK + maps-compose | Standard Android mapping, good Compose integration |
| Data Storage | Pre-built SQLite in assets | Fast spatial queries, low memory, handles 37K rows |
| Persistence | SharedPreferences | Simple key-value for parked car state |
| Background Work | WorkManager | Battery-friendly, survives reboots, no special permissions |
| Business Logic | Pure Kotlin (no Android deps) | Fully unit-testable, portable |
| Holiday Handling | Dynamic calculation | Fixes iOS hardcoded-year limitation |
| Street Rendering | Viewport-only with debounce | Best performance for 37K segments |
| Architecture | MVVM | Standard Android pattern, good Compose fit |

---

## Minimum Requirements

- Android 7.0 (API 24) minimum
- Target API 34
- Kotlin 1.9+
- Gradle 8.0+
- Google Maps API key required
