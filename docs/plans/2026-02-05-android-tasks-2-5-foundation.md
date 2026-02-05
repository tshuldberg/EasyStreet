# Android Tasks 2-5: Foundation Layer Implementation

**Date:** 2026-02-05
**Scope:** Android domain foundation — CSV→SQLite converter, domain models, HolidayCalculator, SweepingRuleEngine
**All domain code is pure Kotlin (no Android deps), fully unit-tested.**

---

## Step 0: Build Config Prerequisites

### 0A. Update package namespace
**File:** `EasyStreet_Android/app/build.gradle.kts` (lines 8, 12)
- Change `namespace` from `"com.yourdomain.easystreetandroid"` → `"com.easystreet.android"`
- Change `applicationId` from `"com.yourdomain.easystreetandroid"` → `"com.easystreet.android"`

**File:** `EasyStreet_Android/app/src/main/AndroidManifest.xml` (line 4)
- Change `package` from `"com.yourdomain.easystreetandroid"` → `"com.easystreet.android"`

### 0B. Enable core library desugaring
Domain models use `java.time` APIs (`LocalDate`, `LocalTime`, `DayOfWeek`, `Instant`, `TemporalAdjusters`). These require desugaring for `minSdk = 24`.

**File:** `EasyStreet_Android/app/build.gradle.kts`
- Add `isCoreLibraryDesugaringEnabled = true` to `compileOptions` block
- Add dependency: `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")`

---

## Step 1 — Task 3: Domain Models (Pure Kotlin)

**Why first:** Foundation for Tasks 4 and 5. No dependencies on other tasks.

### Files to create:

| File | Path |
|------|------|
| SweepingStatus.kt | `app/src/main/kotlin/com/easystreet/domain/model/SweepingStatus.kt` |
| SweepingRule.kt | `app/src/main/kotlin/com/easystreet/domain/model/SweepingRule.kt` |
| StreetSegment.kt | `app/src/main/kotlin/com/easystreet/domain/model/StreetSegment.kt` |
| ParkedCar.kt | `app/src/main/kotlin/com/easystreet/domain/model/ParkedCar.kt` |
| SweepingRuleTest.kt | `app/src/test/kotlin/com/easystreet/domain/model/SweepingRuleTest.kt` |

### Key specs:

**SweepingStatus** — sealed class:
- `Safe`, `NoData`, `Unknown` (data objects)
- `Today(time: LocalDateTime, streetName: String)`, `Imminent(...)`, `Upcoming(...)` (data classes)

**SweepingRule** — data class:
- Properties: `dayOfWeek: DayOfWeek`, `startTime: LocalTime`, `endTime: LocalTime`, `weekOfMonth: Int` (0=every week, 1-5=specific), `holidaysObserved: Boolean`
- Method: `appliesTo(date: LocalDate, isHoliday: Boolean = false): Boolean`
- Week calc uses `WeekFields.of(Locale.US)` for US-standard week-of-month

**StreetSegment** — data class with `LatLngPoint` and `BoundingBox` helper types:
- `id: Long`, `cnn: Int`, `streetName: String`, `coordinates: List<LatLngPoint>`, `bounds: BoundingBox`, `rules: List<SweepingRule>`

**ParkedCar** — data class: `latitude`, `longitude`, `streetName`, `timestamp: Instant`

### Tests (3):
1. `appliesTo` returns true for matching day + every week
2. `appliesTo` returns false for non-matching day
3. `appliesTo` respects specific week of month

### Verify:
```bash
cd EasyStreet_Android && .\gradlew.bat test --tests "com.easystreet.domain.model.SweepingRuleTest"
```

---

## Step 2 — Task 4: HolidayCalculator (Pure Kotlin)

### Files to create:

| File | Path |
|------|------|
| HolidayCalculator.kt | `app/src/main/kotlin/com/easystreet/domain/engine/HolidayCalculator.kt` |
| HolidayCalculatorTest.kt | `app/src/test/kotlin/com/easystreet/domain/engine/HolidayCalculatorTest.kt` |

### Key specs:
- Kotlin `object` singleton
- Methods: `isHoliday(date: LocalDate): Boolean`, `getHolidays(year: Int): Set<LocalDate>`
- **Fixed holidays:** Jan 1, Jun 19, Jul 4, Nov 11, Dec 25
- **Floating holidays:** MLK Day (3rd Mon Jan), Presidents' Day (3rd Mon Feb), Memorial Day (last Mon May), Labor Day (1st Mon Sep), Indigenous Peoples' Day (2nd Mon Oct), Thanksgiving (4th Thu Nov)
- Uses `TemporalAdjusters.firstInMonth()` / `lastInMonth()` for floating holidays
- No observed-date shifting (SF sweeping uses actual calendar dates)

### Tests (8):
1. New Year's Day 2026 is holiday
2. July 4th 2026 is holiday
3. Christmas 2026 is holiday
4. MLK Day 2026 = Jan 19 (3rd Mon); Jan 12 is NOT
5. Thanksgiving 2026 = Nov 26 (4th Thu)
6. Regular day (Mar 15) is NOT a holiday
7. Cross-year: Thanksgiving 2025 = Nov 27, 2027 = Nov 25
8. Labor Day 2026 = Sep 7 (1st Mon)

### Verify:
```bash
cd EasyStreet_Android && .\gradlew.bat test --tests "com.easystreet.domain.engine.HolidayCalculatorTest"
```

---

## Step 3 — Task 5: SweepingRuleEngine (Pure Kotlin)

**Depends on:** Tasks 3 + 4 (uses SweepingRule, SweepingStatus, HolidayCalculator)

### Files to create:

| File | Path |
|------|------|
| SweepingRuleEngine.kt | `app/src/main/kotlin/com/easystreet/domain/engine/SweepingRuleEngine.kt` |
| SweepingRuleEngineTest.kt | `app/src/test/kotlin/com/easystreet/domain/engine/SweepingRuleEngineTest.kt` |

### Key specs:
- Kotlin `object` singleton
- Methods: `getStatus(rules, streetName, at: LocalDateTime): SweepingStatus`, `getNextSweepingTime(rules, after: LocalDateTime): LocalDateTime?`

**Status logic (matches iOS `SweepingRuleEngine.swift` lines 42-97):**
1. Empty rules → `NoData`
2. Check if any rule applies today (via `appliesTo` + `HolidayCalculator.isHoliday`)
3. If sweeping today:
   - Start time already passed → **`Safe`** (sweeping done for today — matches iOS line 72)
   - Less than 1 hour until start → `Imminent`
   - More than 1 hour → `Today`
4. If no sweeping today:
   - Find next sweep (up to 60 days ahead) → `Upcoming`
   - Nothing found → `Safe`

### Tests (7):
1. Empty rules → `NoData`
2. Monday 12:00, rule 9-11 → `Safe` (already passed)
3. Monday 07:00, rule 9-11 → `Today` (>1hr away)
4. Monday 08:30, rule 9-11 → `Imminent` (<1hr)
5. Tuesday, Monday rule → `Upcoming`
6. `getNextSweepingTime` returns correct next occurrence
7. `getNextSweepingTime` returns today if not started yet

### Verify:
```bash
cd EasyStreet_Android && .\gradlew.bat test --tests "com.easystreet.domain.engine.SweepingRuleEngineTest"
```

---

## Step 4 — Task 2: CSV → SQLite Converter (Python)

**Why last:** Independent of Kotlin code. Doing it last lets us focus on getting Kotlin tests passing first.

### Files to create:

| File | Path |
|------|------|
| csv_to_sqlite.py | `EasyStreet_Android/tools/csv_to_sqlite.py` |
| easystreet.db | `EasyStreet_Android/app/src/main/assets/easystreet.db` (generated) |

### Key specs:
- **Input:** `EasyStreet/Street_Sweeping_Schedule_20250508.csv` (37,475 rows)
- **Output:** SQLite database with two tables

**Schema:**
```sql
CREATE TABLE street_segments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cnn INTEGER, street_name TEXT, limits_desc TEXT, block_side TEXT,
    latitude_min REAL, latitude_max REAL, longitude_min REAL, longitude_max REAL,
    coordinates TEXT  -- JSON [[lat,lng], ...]
);
CREATE TABLE sweeping_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    segment_id INTEGER REFERENCES street_segments(id),
    day_of_week INTEGER, start_time TEXT, end_time TEXT,
    week_of_month INTEGER, holidays_observed INTEGER
);
CREATE INDEX idx_bounds ON street_segments(latitude_min, latitude_max, longitude_min, longitude_max);
CREATE INDEX idx_segment ON sweeping_rules(segment_id);
```

**Processing logic:**
- Parse WKT LINESTRING → swap lon/lat to lat/lon
- Group rows by `(CNN, CNNRightLeft, Line)` → one segment, many rules
- Day mapping: Mon=1, Tue=2, ..., Sun=7 (java.time convention)
- Time: `FromHour`/`ToHour` integers → `"HH:00"` strings
- Week flags: if all Week1-5 = 1 → `week_of_month = 0`; otherwise one rule row per active week
- Skip rows with empty/invalid geometry

### Verify:
```bash
cd EasyStreet_Android/tools
py csv_to_sqlite.py "..\..\EasyStreet\Street_Sweeping_Schedule_20250508.csv" "..\app\src\main\assets\easystreet.db"
```
Check: ~20K-25K segments, ~37K-75K rules.

---

## Final Verification

Run all 18 unit tests together:
```bash
cd EasyStreet_Android && .\gradlew.bat test
```
Expected: 18 tests pass (3 model + 8 holiday + 7 engine).

---

## Gotchas & Notes

1. **Day-of-week convention differs from iOS:** iOS uses Sun=1, Android uses Mon=1. The SQLite converter must use Android convention.
2. **`WeekFields.of(Locale.US)`** defines week 1 as the week containing the 1st of the month — matches SF street sweeping rules.
3. **Core library desugaring** is critical: `java.time` not available natively on API 24. Unit tests run on host JVM (fine), but app will crash at runtime without desugaring.
4. **`data object` requires Kotlin 1.9+** — project uses 1.9.22, so this works.
5. **Python on Windows:** Use `py` command (Python 3.11.9 available).
6. **iOS "safe after passed" behavior:** When today's sweeping already happened, iOS returns `.safe` without looking ahead (line 72 of SweepingRuleEngine.swift). Android must match this.

---

## Commits (5 total)
1. `chore(android): update package namespace and enable java.time desugaring`
2. `feat(android): add domain models — SweepingRule, StreetSegment, ParkedCar, SweepingStatus`
3. `feat(android): add dynamic HolidayCalculator for any year`
4. `feat(android): add SweepingRuleEngine with status evaluation`
5. `feat(android): add CSV-to-SQLite converter and generate easystreet.db`