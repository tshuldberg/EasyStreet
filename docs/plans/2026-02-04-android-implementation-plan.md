# Android Feature-Parity Port — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Port the complete iOS EasyStreet MVP to Android with full 37K-row dataset via bundled SQLite and dynamic holiday calculation.

**Architecture:** MVVM with Jetpack Compose. Single-activity app. SQLite for street data (viewport-filtered queries), SharedPreferences for parked car state, WorkManager for notifications. Pure Kotlin domain layer with no Android dependencies for testability.

**Tech Stack:** Kotlin 1.9, Jetpack Compose, Google Maps SDK + maps-compose, SQLite, WorkManager, kotlinx.serialization, java.time

**Design Doc:** [2026-02-04-android-feature-parity-design.md](2026-02-04-android-feature-parity-design.md)

---

## CSV Format Reference

The source file `EasyStreet/Street_Sweeping_Schedule_20250508.csv` has these columns:

| Column | Example | Notes |
|--------|---------|-------|
| CNN | 110000 | Street segment ID (shared across rows for same segment) |
| Corridor | 01st St | Street name |
| Limits | Clementina St - Folsom St | Cross streets |
| CNNRightLeft | L or R | Side of street |
| BlockSide | NorthEast | Side label |
| FullName | Tuesday | Full day name |
| WeekDay | Tues | Abbreviated day |
| FromHour | 0 | Start hour (integer, 0-23) |
| ToHour | 2 | End hour (integer, 0-23) |
| Week1-Week5 | 1 or 0 | Whether sweeping occurs in that week of the month |
| Holidays | 0 | 0 = no sweeping on holidays, 1 = sweeps on holidays |
| BlockSweepID | 1613751 | Unique sweep block ID |
| Line | "LINESTRING (...)" | WKT geometry with lon/lat pairs |

**Key observations:**
- Multiple rows can share the same CNN (same physical street segment, different sweep days/sides)
- `BlockSweepID` is unique per sweep schedule, but CNN+CNNRightLeft groups form a logical segment
- FromHour/ToHour are integers (not "HH:mm" strings) — convert to "HH:00" format
- WKT LINESTRING has coordinates as `longitude latitude` (note: lon first, lat second)
- Week1-Week5 flags: if all are 1, sweeping is every week. Otherwise, specific weeks only.

---

## Task 1: Android Project Scaffolding

**Files:**
- Modify: `EasyStreet_Android/app/build.gradle.kts`
- Create: `EasyStreet_Android/build.gradle.kts` (project-level)
- Create: `EasyStreet_Android/settings.gradle.kts`
- Create: `EasyStreet_Android/gradle.properties`
- Create: `EasyStreet_Android/gradlew` (Gradle wrapper)
- Create: `EasyStreet_Android/gradle/wrapper/gradle-wrapper.properties`
- Create: `EasyStreet_Android/gradle/wrapper/gradle-wrapper.jar`
- Create: `EasyStreet_Android/app/src/main/res/values/strings.xml`
- Create: `EasyStreet_Android/app/src/main/res/values/themes.xml`
- Create: `EasyStreet_Android/app/src/main/res/xml/data_extraction_rules.xml`
- Create: `EasyStreet_Android/app/src/main/res/xml/backup_rules.xml`

**Step 1: Generate Gradle wrapper**

Run from the `EasyStreet_Android` directory. If `gradle` CLI is not installed, download the wrapper files manually or use Android Studio to generate them.

```bash
cd EasyStreet_Android
gradle wrapper --gradle-version 8.4
```

If `gradle` is not available, create the wrapper files manually:

`gradle/wrapper/gradle-wrapper.properties`:
```properties
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.4-bin.zip
networkTimeout=10000
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
```

**Step 2: Create project-level build.gradle.kts**

```kotlin
// EasyStreet_Android/build.gradle.kts
plugins {
    id("com.android.application") version "8.2.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false
    id("org.jetbrains.kotlin.plugin.serialization") version "1.9.22" apply false
}
```

**Step 3: Create settings.gradle.kts**

```kotlin
// EasyStreet_Android/settings.gradle.kts
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "EasyStreetAndroid"
include(":app")
```

**Step 4: Create gradle.properties**

```properties
# EasyStreet_Android/gradle.properties
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
```

**Step 5: Update app/build.gradle.kts**

Add WorkManager dependency and fix the secrets plugin application. Update the existing file:

Add to dependencies block:
```kotlin
// WorkManager
implementation("androidx.work:work-runtime-ktx:2.9.0")
```

Remove the `apply false` from the secrets plugin or remove it entirely (we'll handle API key via gradle.properties instead).

Remove the `navigation-compose` dependency (design says no navigation library needed).

**Step 6: Create resource files**

`app/src/main/res/values/strings.xml`:
```xml
<resources>
    <string name="app_name">EasyStreet</string>
</resources>
```

`app/src/main/res/values/themes.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.EasyStreetAndroid" parent="android:Theme.Material.Light.NoActionBar" />
</resources>
```

`app/src/main/res/xml/data_extraction_rules.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
    <cloud-backup>
        <include domain="sharedpref" path="." />
    </cloud-backup>
</data-extraction-rules>
```

`app/src/main/res/xml/backup_rules.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<full-backup-content>
    <include domain="sharedpref" path="." />
</full-backup-content>
```

**Step 7: Verify build compiles**

```bash
cd EasyStreet_Android
./gradlew assembleDebug
```

Expected: BUILD SUCCESSFUL (may have warnings about missing source files, that's OK at this stage)

**Step 8: Commit**

```bash
git add EasyStreet_Android/
git commit -m "feat(android): scaffold project with Gradle wrapper, resources, and WorkManager dep"
```

---

## Task 2: CSV → SQLite Converter Script

**Files:**
- Create: `EasyStreet_Android/tools/csv_to_sqlite.py`
- Create: `EasyStreet_Android/app/src/main/assets/easystreet.db` (generated output)

We use a Python script instead of a Kotlin script because Python has built-in CSV and SQLite support with no build dependencies. This is a one-time offline tool.

**Step 1: Write the converter script**

```python
#!/usr/bin/env python3
"""
Convert Street_Sweeping_Schedule CSV to SQLite database for EasyStreet Android.

Usage:
    python csv_to_sqlite.py <input_csv> <output_db>

Example:
    python csv_to_sqlite.py ../../EasyStreet/Street_Sweeping_Schedule_20250508.csv ../app/src/main/assets/easystreet.db
"""
import csv
import json
import re
import sqlite3
import sys
from collections import defaultdict


def parse_wkt_linestring(wkt: str) -> list[list[float]]:
    """Parse WKT LINESTRING into list of [lat, lng] pairs.

    WKT format: LINESTRING (lon1 lat1, lon2 lat2, ...)
    Output format: [[lat1, lng1], [lat2, lng2], ...]
    """
    match = re.search(r'LINESTRING\s*\((.+)\)', wkt)
    if not match:
        return []

    coords = []
    for point in match.group(1).split(','):
        parts = point.strip().split()
        if len(parts) == 2:
            lon, lat = float(parts[0]), float(parts[1])
            coords.append([lat, lon])  # Swap to lat, lng
    return coords


def day_name_to_number(day_name: str) -> int:
    """Convert day name to number (1=Monday, 7=Sunday) matching java.time.DayOfWeek."""
    mapping = {
        'mon': 1, 'monday': 1,
        'tue': 2, 'tues': 2, 'tuesday': 2,
        'wed': 3, 'wednesday': 3,
        'thu': 4, 'thurs': 4, 'thursday': 4,
        'fri': 5, 'friday': 5,
        'sat': 6, 'saturday': 6,
        'sun': 7, 'sunday': 7,
    }
    return mapping.get(day_name.lower().strip(), 0)


def weeks_to_week_of_month(w1, w2, w3, w4, w5) -> int:
    """Convert Week1-Week5 flags to a single week_of_month value.

    Returns 0 if all weeks (every week), otherwise returns the specific week number.
    If multiple non-contiguous weeks, we create separate rules for each.
    This function returns a list of week numbers to handle multi-week rules.
    """
    flags = [int(w1), int(w2), int(w3), int(w4), int(w5)]
    if all(f == 1 for f in flags):
        return [0]  # Every week

    weeks = []
    for i, flag in enumerate(flags):
        if flag == 1:
            weeks.append(i + 1)
    return weeks if weeks else [0]


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)

    input_csv = sys.argv[1]
    output_db = sys.argv[2]

    # Create database
    conn = sqlite3.connect(output_db)
    cursor = conn.cursor()

    cursor.executescript('''
        DROP TABLE IF EXISTS sweeping_rules;
        DROP TABLE IF EXISTS street_segments;

        CREATE TABLE street_segments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cnn INTEGER NOT NULL,
            street_name TEXT NOT NULL,
            limits_desc TEXT,
            block_side TEXT,
            latitude_min REAL NOT NULL,
            latitude_max REAL NOT NULL,
            longitude_min REAL NOT NULL,
            longitude_max REAL NOT NULL,
            coordinates TEXT NOT NULL
        );

        CREATE TABLE sweeping_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            segment_id INTEGER NOT NULL REFERENCES street_segments(id),
            day_of_week INTEGER NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            week_of_month INTEGER NOT NULL DEFAULT 0,
            holidays_observed INTEGER NOT NULL DEFAULT 0
        );

        CREATE INDEX idx_segments_bounds ON street_segments(
            latitude_min, latitude_max, longitude_min, longitude_max
        );

        CREATE INDEX idx_rules_segment ON sweeping_rules(segment_id);
    ''')

    # Group rows by CNN + CNNRightLeft to form unique segments
    # Each unique combination of CNN + side + geometry = one segment
    segments = {}  # key: (CNN, CNNRightLeft, Line) -> {info, rules}

    with open(input_csv, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            cnn = row['CNN'].strip()
            side = row['CNNRightLeft'].strip()
            line = row['Line'].strip()
            key = (cnn, side, line)

            if key not in segments:
                coords = parse_wkt_linestring(line)
                if not coords:
                    continue

                lats = [c[0] for c in coords]
                lngs = [c[1] for c in coords]

                segments[key] = {
                    'cnn': int(cnn),
                    'street_name': row['Corridor'].strip(),
                    'limits': row['Limits'].strip(),
                    'block_side': row['BlockSide'].strip(),
                    'coords': coords,
                    'lat_min': min(lats),
                    'lat_max': max(lats),
                    'lng_min': min(lngs),
                    'lng_max': max(lngs),
                    'rules': [],
                }

            # Parse rule from this row
            day_num = day_name_to_number(row['WeekDay'].strip())
            if day_num == 0:
                continue

            from_hour = int(row['FromHour'].strip())
            to_hour = int(row['ToHour'].strip())
            start_time = f"{from_hour:02d}:00"
            end_time = f"{to_hour:02d}:00"

            week_numbers = weeks_to_week_of_month(
                row['Week1'], row['Week2'], row['Week3'], row['Week4'], row['Week5']
            )

            holidays = int(row['Holidays'].strip())

            for week in week_numbers:
                segments[key]['rules'].append({
                    'day_of_week': day_num,
                    'start_time': start_time,
                    'end_time': end_time,
                    'week_of_month': week,
                    'holidays_observed': holidays,
                })

    # Insert into database
    segment_count = 0
    rule_count = 0

    for key, seg in segments.items():
        cursor.execute(
            '''INSERT INTO street_segments
               (cnn, street_name, limits_desc, block_side,
                latitude_min, latitude_max, longitude_min, longitude_max, coordinates)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
            (
                seg['cnn'], seg['street_name'], seg['limits'], seg['block_side'],
                seg['lat_min'], seg['lat_max'], seg['lng_min'], seg['lng_max'],
                json.dumps(seg['coords']),
            )
        )
        segment_id = cursor.lastrowid
        segment_count += 1

        for rule in seg['rules']:
            cursor.execute(
                '''INSERT INTO sweeping_rules
                   (segment_id, day_of_week, start_time, end_time, week_of_month, holidays_observed)
                   VALUES (?, ?, ?, ?, ?, ?)''',
                (
                    segment_id,
                    rule['day_of_week'],
                    rule['start_time'],
                    rule['end_time'],
                    rule['week_of_month'],
                    rule['holidays_observed'],
                )
            )
            rule_count += 1

    conn.commit()

    # Print stats
    print(f"Created {output_db}")
    print(f"  Segments: {segment_count}")
    print(f"  Rules: {rule_count}")

    # Verify
    cursor.execute("SELECT COUNT(*) FROM street_segments")
    print(f"  Verify segments: {cursor.fetchone()[0]}")
    cursor.execute("SELECT COUNT(*) FROM sweeping_rules")
    print(f"  Verify rules: {cursor.fetchone()[0]}")

    conn.close()


if __name__ == '__main__':
    main()
```

**Step 2: Run the converter**

```bash
cd EasyStreet_Android/tools
python csv_to_sqlite.py ../../EasyStreet/Street_Sweeping_Schedule_20250508.csv ../app/src/main/assets/easystreet.db
```

Expected output:
```
Created ../app/src/main/assets/easystreet.db
  Segments: ~20000-37000
  Rules: ~37000-75000
  Verify segments: (same as above)
  Verify rules: (same as above)
```

**Step 3: Verify the database**

```bash
python -c "
import sqlite3
conn = sqlite3.connect('../app/src/main/assets/easystreet.db')
c = conn.cursor()
c.execute('SELECT * FROM street_segments LIMIT 2')
for row in c.fetchall(): print(row)
c.execute('SELECT * FROM sweeping_rules LIMIT 2')
for row in c.fetchall(): print(row)
conn.close()
"
```

Expected: Rows printed with valid data, coordinates as JSON arrays of [lat, lng] pairs.

**Step 4: Commit**

```bash
git add EasyStreet_Android/tools/ EasyStreet_Android/app/src/main/assets/easystreet.db
git commit -m "feat(android): add CSV-to-SQLite converter and generate easystreet.db"
```

---

## Task 3: Domain Models (Pure Kotlin)

**Files:**
- Create: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/model/SweepingStatus.kt`
- Create: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/model/SweepingRule.kt`
- Create: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/model/StreetSegment.kt`
- Create: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/model/ParkedCar.kt`
- Test: `EasyStreet_Android/app/src/test/kotlin/com/easystreet/domain/model/SweepingRuleTest.kt`

**Step 1: Write the test for SweepingRule.appliesTo**

```kotlin
// app/src/test/kotlin/com/easystreet/domain/model/SweepingRuleTest.kt
package com.easystreet.domain.model

import org.junit.Assert.*
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalTime

class SweepingRuleTest {

    @Test
    fun `appliesTo returns true for matching day and every week`() {
        val rule = SweepingRule(
            dayOfWeek = DayOfWeek.MONDAY,
            startTime = LocalTime.of(9, 0),
            endTime = LocalTime.of(11, 0),
            weekOfMonth = 0, // every week
            holidaysObserved = false,
        )
        // 2026-02-09 is a Monday
        assertTrue(rule.appliesTo(LocalDate.of(2026, 2, 9)))
    }

    @Test
    fun `appliesTo returns false for non-matching day`() {
        val rule = SweepingRule(
            dayOfWeek = DayOfWeek.MONDAY,
            startTime = LocalTime.of(9, 0),
            endTime = LocalTime.of(11, 0),
            weekOfMonth = 0,
            holidaysObserved = false,
        )
        // 2026-02-10 is a Tuesday
        assertFalse(rule.appliesTo(LocalDate.of(2026, 2, 10)))
    }

    @Test
    fun `appliesTo respects specific week of month`() {
        val rule = SweepingRule(
            dayOfWeek = DayOfWeek.MONDAY,
            startTime = LocalTime.of(9, 0),
            endTime = LocalTime.of(11, 0),
            weekOfMonth = 1, // 1st week only
            holidaysObserved = false,
        )
        // 2026-02-02 is Monday, 1st week — should apply
        assertTrue(rule.appliesTo(LocalDate.of(2026, 2, 2)))
        // 2026-02-09 is Monday, 2nd week — should NOT apply
        assertFalse(rule.appliesTo(LocalDate.of(2026, 2, 9)))
    }
}
```

**Step 2: Run test to verify it fails**

```bash
cd EasyStreet_Android
./gradlew test --tests "com.easystreet.domain.model.SweepingRuleTest" -q
```

Expected: FAIL — class not found.

**Step 3: Write the domain models**

`SweepingStatus.kt`:
```kotlin
package com.easystreet.domain.model

import java.time.LocalDateTime

sealed class SweepingStatus {
    data object Safe : SweepingStatus()
    data class Today(val time: LocalDateTime, val streetName: String) : SweepingStatus()
    data class Imminent(val time: LocalDateTime, val streetName: String) : SweepingStatus()
    data class Upcoming(val time: LocalDateTime, val streetName: String) : SweepingStatus()
    data object NoData : SweepingStatus()
    data object Unknown : SweepingStatus()
}
```

`SweepingRule.kt`:
```kotlin
package com.easystreet.domain.model

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalTime
import java.time.temporal.WeekFields
import java.util.Locale

data class SweepingRule(
    val dayOfWeek: DayOfWeek,
    val startTime: LocalTime,
    val endTime: LocalTime,
    val weekOfMonth: Int, // 0 = every week, 1-5 = specific week
    val holidaysObserved: Boolean,
) {
    /**
     * Check if this rule applies on the given date.
     * Does NOT check holidays — that's the engine's responsibility.
     */
    fun appliesTo(date: LocalDate, isHoliday: Boolean = false): Boolean {
        if (date.dayOfWeek != dayOfWeek) return false

        if (weekOfMonth != 0) {
            val weekFields = WeekFields.of(Locale.US)
            val week = date.get(weekFields.weekOfMonth())
            if (week != weekOfMonth) return false
        }

        if (!holidaysObserved && isHoliday) return false

        return true
    }
}
```

`StreetSegment.kt`:
```kotlin
package com.easystreet.domain.model

data class LatLngPoint(val latitude: Double, val longitude: Double)

data class BoundingBox(
    val latMin: Double,
    val latMax: Double,
    val lngMin: Double,
    val lngMax: Double,
)

data class StreetSegment(
    val id: Long,
    val cnn: Int,
    val streetName: String,
    val coordinates: List<LatLngPoint>,
    val bounds: BoundingBox,
    val rules: List<SweepingRule>,
)
```

`ParkedCar.kt`:
```kotlin
package com.easystreet.domain.model

import java.time.Instant

data class ParkedCar(
    val latitude: Double,
    val longitude: Double,
    val streetName: String,
    val timestamp: Instant,
)
```

**Step 4: Run test to verify it passes**

```bash
cd EasyStreet_Android
./gradlew test --tests "com.easystreet.domain.model.SweepingRuleTest" -q
```

Expected: 3 tests PASS.

**Step 5: Commit**

```bash
git add EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/model/
git add EasyStreet_Android/app/src/test/kotlin/com/easystreet/domain/model/
git commit -m "feat(android): add domain models — SweepingRule, StreetSegment, ParkedCar, SweepingStatus"
```

---

## Task 4: HolidayCalculator

**Files:**
- Create: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/engine/HolidayCalculator.kt`
- Test: `EasyStreet_Android/app/src/test/kotlin/com/easystreet/domain/engine/HolidayCalculatorTest.kt`

**Step 1: Write the failing test**

```kotlin
// app/src/test/kotlin/com/easystreet/domain/engine/HolidayCalculatorTest.kt
package com.easystreet.domain.engine

import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDate
import java.time.Month

class HolidayCalculatorTest {

    @Test
    fun `new years day is a holiday`() {
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2026, 1, 1)))
    }

    @Test
    fun `july 4th is a holiday`() {
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2026, 7, 4)))
    }

    @Test
    fun `christmas is a holiday`() {
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2026, 12, 25)))
    }

    @Test
    fun `mlk day is third monday of january`() {
        // 2026: Jan 19 is third Monday
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2026, 1, 19)))
        assertFalse(HolidayCalculator.isHoliday(LocalDate.of(2026, 1, 12)))
    }

    @Test
    fun `thanksgiving is fourth thursday of november`() {
        // 2026: Nov 26 is fourth Thursday
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2026, 11, 26)))
    }

    @Test
    fun `regular day is not a holiday`() {
        assertFalse(HolidayCalculator.isHoliday(LocalDate.of(2026, 3, 15)))
    }

    @Test
    fun `works for different years`() {
        // 2025 Thanksgiving: Nov 27
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2025, 11, 27)))
        // 2027 Thanksgiving: Nov 25
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2027, 11, 25)))
    }

    @Test
    fun `labor day is first monday of september`() {
        // 2026: Sep 7 is first Monday
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2026, 9, 7)))
    }
}
```

**Step 2: Run test to verify it fails**

```bash
cd EasyStreet_Android
./gradlew test --tests "com.easystreet.domain.engine.HolidayCalculatorTest" -q
```

Expected: FAIL — class not found.

**Step 3: Write the implementation**

```kotlin
// app/src/main/kotlin/com/easystreet/domain/engine/HolidayCalculator.kt
package com.easystreet.domain.engine

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.Month
import java.time.temporal.TemporalAdjusters

/**
 * Dynamically calculates US federal holidays observed by SF street sweeping.
 * No hardcoded years — works for any year.
 */
object HolidayCalculator {

    fun isHoliday(date: LocalDate): Boolean {
        return getHolidays(date.year).contains(date)
    }

    fun getHolidays(year: Int): Set<LocalDate> {
        return setOf(
            // Fixed holidays
            LocalDate.of(year, Month.JANUARY, 1),    // New Year's Day
            LocalDate.of(year, Month.JUNE, 19),       // Juneteenth
            LocalDate.of(year, Month.JULY, 4),        // Independence Day
            LocalDate.of(year, Month.NOVEMBER, 11),   // Veterans Day
            LocalDate.of(year, Month.DECEMBER, 25),   // Christmas Day

            // Floating holidays
            nthDayOfWeekInMonth(year, Month.JANUARY, DayOfWeek.MONDAY, 3),   // MLK Day
            nthDayOfWeekInMonth(year, Month.FEBRUARY, DayOfWeek.MONDAY, 3),  // Presidents' Day
            nthDayOfWeekInMonth(year, Month.SEPTEMBER, DayOfWeek.MONDAY, 1), // Labor Day
            nthDayOfWeekInMonth(year, Month.OCTOBER, DayOfWeek.MONDAY, 2),   // Indigenous Peoples' Day
            nthDayOfWeekInMonth(year, Month.NOVEMBER, DayOfWeek.THURSDAY, 4), // Thanksgiving

            // Memorial Day = last Monday of May
            lastDayOfWeekInMonth(year, Month.MAY, DayOfWeek.MONDAY),
        )
    }

    private fun nthDayOfWeekInMonth(
        year: Int,
        month: Month,
        dayOfWeek: DayOfWeek,
        n: Int,
    ): LocalDate {
        val first = LocalDate.of(year, month, 1)
            .with(TemporalAdjusters.firstInMonth(dayOfWeek))
        return first.plusWeeks((n - 1).toLong())
    }

    private fun lastDayOfWeekInMonth(
        year: Int,
        month: Month,
        dayOfWeek: DayOfWeek,
    ): LocalDate {
        return LocalDate.of(year, month, 1)
            .with(TemporalAdjusters.lastInMonth(dayOfWeek))
    }
}
```

**Step 4: Run test to verify it passes**

```bash
cd EasyStreet_Android
./gradlew test --tests "com.easystreet.domain.engine.HolidayCalculatorTest" -q
```

Expected: All tests PASS.

**Step 5: Commit**

```bash
git add EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/engine/HolidayCalculator.kt
git add EasyStreet_Android/app/src/test/kotlin/com/easystreet/domain/engine/
git commit -m "feat(android): add dynamic HolidayCalculator for any year"
```

---

## Task 5: SweepingRuleEngine

**Files:**
- Create: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/engine/SweepingRuleEngine.kt`
- Test: `EasyStreet_Android/app/src/test/kotlin/com/easystreet/domain/engine/SweepingRuleEngineTest.kt`

**Step 1: Write the failing test**

```kotlin
// app/src/test/kotlin/com/easystreet/domain/engine/SweepingRuleEngineTest.kt
package com.easystreet.domain.engine

import com.easystreet.domain.model.SweepingRule
import com.easystreet.domain.model.SweepingStatus
import org.junit.Assert.*
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDateTime
import java.time.LocalTime

class SweepingRuleEngineTest {

    private val engine = SweepingRuleEngine

    private fun mondayRule(start: Int = 9, end: Int = 11, week: Int = 0) = SweepingRule(
        dayOfWeek = DayOfWeek.MONDAY,
        startTime = LocalTime.of(start, 0),
        endTime = LocalTime.of(end, 0),
        weekOfMonth = week,
        holidaysObserved = false,
    )

    @Test
    fun `safe when no rules`() {
        val status = engine.getStatus(emptyList(), "Test St", LocalDateTime.of(2026, 2, 9, 8, 0))
        assertTrue(status is SweepingStatus.NoData)
    }

    @Test
    fun `safe when sweeping already passed today`() {
        // Monday 2026-02-09, current time 12:00, sweeping was 9-11
        val status = engine.getStatus(
            listOf(mondayRule()),
            "Market St",
            LocalDateTime.of(2026, 2, 9, 12, 0),
        )
        assertTrue(status is SweepingStatus.Safe)
    }

    @Test
    fun `today when sweeping is later today, more than 1 hour away`() {
        // Monday 2026-02-09, current time 7:00, sweeping at 9:00
        val status = engine.getStatus(
            listOf(mondayRule()),
            "Market St",
            LocalDateTime.of(2026, 2, 9, 7, 0),
        )
        assertTrue(status is SweepingStatus.Today)
    }

    @Test
    fun `imminent when sweeping is less than 1 hour away`() {
        // Monday 2026-02-09, current time 8:30, sweeping at 9:00
        val status = engine.getStatus(
            listOf(mondayRule()),
            "Market St",
            LocalDateTime.of(2026, 2, 9, 8, 30),
        )
        assertTrue(status is SweepingStatus.Imminent)
    }

    @Test
    fun `upcoming when sweeping is on a different day`() {
        // Tuesday 2026-02-10, rule is Monday
        val status = engine.getStatus(
            listOf(mondayRule()),
            "Market St",
            LocalDateTime.of(2026, 2, 10, 10, 0),
        )
        assertTrue(status is SweepingStatus.Upcoming)
    }

    @Test
    fun `getNextSweepingTime returns correct next occurrence`() {
        // Tuesday 2026-02-10, next Monday is 2026-02-16
        val next = engine.getNextSweepingTime(
            listOf(mondayRule()),
            LocalDateTime.of(2026, 2, 10, 10, 0),
        )
        assertNotNull(next)
        assertEquals(LocalDateTime.of(2026, 2, 16, 9, 0), next)
    }

    @Test
    fun `getNextSweepingTime returns today if sweeping hasnt started yet`() {
        // Monday 2026-02-09 at 7am, sweeping at 9am today
        val next = engine.getNextSweepingTime(
            listOf(mondayRule()),
            LocalDateTime.of(2026, 2, 9, 7, 0),
        )
        assertEquals(LocalDateTime.of(2026, 2, 9, 9, 0), next)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
cd EasyStreet_Android
./gradlew test --tests "com.easystreet.domain.engine.SweepingRuleEngineTest" -q
```

Expected: FAIL — class not found.

**Step 3: Write the implementation**

```kotlin
// app/src/main/kotlin/com/easystreet/domain/engine/SweepingRuleEngine.kt
package com.easystreet.domain.engine

import com.easystreet.domain.model.SweepingRule
import com.easystreet.domain.model.SweepingStatus
import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * Pure Kotlin engine for evaluating street sweeping rules.
 * No Android dependencies — fully unit-testable.
 */
object SweepingRuleEngine {

    /**
     * Determine the sweeping status for a set of rules at a given time.
     */
    fun getStatus(
        rules: List<SweepingRule>,
        streetName: String,
        at: LocalDateTime,
    ): SweepingStatus {
        if (rules.isEmpty()) return SweepingStatus.NoData

        val today = at.toLocalDate()
        val isHoliday = HolidayCalculator.isHoliday(today)

        // Check if any rule applies today
        val todayRules = rules.filter { it.appliesTo(today, isHoliday) }

        for (rule in todayRules) {
            val sweepStart = today.atTime(rule.startTime)
            val sweepEnd = today.atTime(rule.endTime)

            if (at >= sweepEnd) {
                // Sweeping already passed
                continue
            }

            if (at >= sweepStart) {
                // Currently sweeping
                return SweepingStatus.Imminent(sweepStart, streetName)
            }

            val timeUntil = Duration.between(at, sweepStart)
            return if (timeUntil.toMinutes() < 60) {
                SweepingStatus.Imminent(sweepStart, streetName)
            } else {
                SweepingStatus.Today(sweepStart, streetName)
            }
        }

        // No applicable rule today (or all already passed) — find next occurrence
        val nextTime = getNextSweepingTime(rules, at)
        return if (nextTime != null) {
            SweepingStatus.Upcoming(nextTime, streetName)
        } else {
            SweepingStatus.Safe
        }
    }

    /**
     * Find the next sweeping time from a set of rules, starting from the given time.
     * Checks today (if sweeping hasn't started yet) and up to 60 days ahead.
     */
    fun getNextSweepingTime(
        rules: List<SweepingRule>,
        after: LocalDateTime,
    ): LocalDateTime? {
        var earliest: LocalDateTime? = null

        for (rule in rules) {
            // Check today first if sweeping hasn't started
            val today = after.toLocalDate()
            val todaySweepStart = today.atTime(rule.startTime)
            if (todaySweepStart > after && rule.appliesTo(today, HolidayCalculator.isHoliday(today))) {
                if (earliest == null || todaySweepStart < earliest) {
                    earliest = todaySweepStart
                }
                continue
            }

            // Check future days
            for (dayOffset in 1L..60L) {
                val date = today.plusDays(dayOffset)
                if (rule.appliesTo(date, HolidayCalculator.isHoliday(date))) {
                    val sweepTime = date.atTime(rule.startTime)
                    if (earliest == null || sweepTime < earliest) {
                        earliest = sweepTime
                    }
                    break
                }
            }
        }

        return earliest
    }
}
```

**Step 4: Run test to verify it passes**

```bash
cd EasyStreet_Android
./gradlew test --tests "com.easystreet.domain.engine.SweepingRuleEngineTest" -q
```

Expected: All tests PASS.

**Step 5: Commit**

```bash
git add EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/engine/SweepingRuleEngine.kt
git add EasyStreet_Android/app/src/test/kotlin/com/easystreet/domain/engine/
git commit -m "feat(android): add SweepingRuleEngine with status evaluation and next-sweep calculation"
```

---

## Task 6: SQLite Database Layer

**Files:**
- Create: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/data/db/StreetDatabase.kt`
- Create: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/data/db/StreetDao.kt`

No unit test for this task — these classes use Android APIs (Context, SQLiteDatabase) which require instrumented tests. We'll verify through integration in Task 8.

**Step 1: Write StreetDatabase**

```kotlin
// app/src/main/kotlin/com/easystreet/data/db/StreetDatabase.kt
package com.easystreet.data.db

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File
import java.io.FileOutputStream

/**
 * Opens the pre-built SQLite database from assets.
 * Copies it to the app's database directory on first launch.
 */
class StreetDatabase(private val context: Context) {

    private val dbName = "easystreet.db"

    val database: SQLiteDatabase by lazy {
        copyDatabaseIfNeeded()
        SQLiteDatabase.openDatabase(
            getDatabasePath().absolutePath,
            null,
            SQLiteDatabase.OPEN_READONLY,
        )
    }

    private fun getDatabasePath(): File {
        return context.getDatabasePath(dbName)
    }

    private fun copyDatabaseIfNeeded() {
        val dbFile = getDatabasePath()
        if (dbFile.exists()) return

        dbFile.parentFile?.mkdirs()

        context.assets.open(dbName).use { input ->
            FileOutputStream(dbFile).use { output ->
                input.copyTo(output)
            }
        }
    }
}
```

**Step 2: Write StreetDao**

```kotlin
// app/src/main/kotlin/com/easystreet/data/db/StreetDao.kt
package com.easystreet.data.db

import com.easystreet.domain.model.BoundingBox
import com.easystreet.domain.model.LatLngPoint
import com.easystreet.domain.model.StreetSegment
import com.easystreet.domain.model.SweepingRule
import org.json.JSONArray
import java.time.DayOfWeek
import java.time.LocalTime

/**
 * Data access object for querying street segments and sweeping rules.
 */
class StreetDao(private val db: StreetDatabase) {

    /**
     * Query street segments whose bounding box intersects the given viewport.
     */
    fun getSegmentsInViewport(
        latMin: Double,
        latMax: Double,
        lngMin: Double,
        lngMax: Double,
    ): List<StreetSegment> {
        val segments = mutableListOf<StreetSegment>()

        val cursor = db.database.rawQuery(
            """
            SELECT id, cnn, street_name, latitude_min, latitude_max,
                   longitude_min, longitude_max, coordinates
            FROM street_segments
            WHERE latitude_max >= ? AND latitude_min <= ?
              AND longitude_max >= ? AND longitude_min <= ?
            """.trimIndent(),
            arrayOf(
                latMin.toString(),
                latMax.toString(),
                lngMin.toString(),
                lngMax.toString(),
            ),
        )

        cursor.use {
            while (it.moveToNext()) {
                val segmentId = it.getLong(0)
                val cnn = it.getInt(1)
                val streetName = it.getString(2)
                val latMinDb = it.getDouble(3)
                val latMaxDb = it.getDouble(4)
                val lngMinDb = it.getDouble(5)
                val lngMaxDb = it.getDouble(6)
                val coordsJson = it.getString(7)

                val coordinates = parseCoordinates(coordsJson)
                val rules = getRulesForSegment(segmentId)

                segments.add(
                    StreetSegment(
                        id = segmentId,
                        cnn = cnn,
                        streetName = streetName,
                        coordinates = coordinates,
                        bounds = BoundingBox(latMinDb, latMaxDb, lngMinDb, lngMaxDb),
                        rules = rules,
                    )
                )
            }
        }

        return segments
    }

    /**
     * Find the nearest segment to a given point within a small radius.
     */
    fun findNearestSegment(lat: Double, lng: Double, radiusDeg: Double = 0.001): StreetSegment? {
        val segments = getSegmentsInViewport(
            lat - radiusDeg, lat + radiusDeg,
            lng - radiusDeg, lng + radiusDeg,
        )

        return segments.minByOrNull { segment ->
            segment.coordinates.minOf { point ->
                val dlat = point.latitude - lat
                val dlng = point.longitude - lng
                dlat * dlat + dlng * dlng
            }
        }
    }

    private fun getRulesForSegment(segmentId: Long): List<SweepingRule> {
        val rules = mutableListOf<SweepingRule>()

        val cursor = db.database.rawQuery(
            "SELECT day_of_week, start_time, end_time, week_of_month, holidays_observed FROM sweeping_rules WHERE segment_id = ?",
            arrayOf(segmentId.toString()),
        )

        cursor.use {
            while (it.moveToNext()) {
                val dayInt = it.getInt(0)
                val startStr = it.getString(1)
                val endStr = it.getString(2)
                val weekOfMonth = it.getInt(3)
                val holidays = it.getInt(4)

                rules.add(
                    SweepingRule(
                        dayOfWeek = DayOfWeek.of(dayInt),
                        startTime = LocalTime.parse(startStr),
                        endTime = LocalTime.parse(endStr),
                        weekOfMonth = weekOfMonth,
                        holidaysObserved = holidays == 1,
                    )
                )
            }
        }

        return rules
    }

    private fun parseCoordinates(json: String): List<LatLngPoint> {
        val array = JSONArray(json)
        val points = mutableListOf<LatLngPoint>()
        for (i in 0 until array.length()) {
            val point = array.getJSONArray(i)
            points.add(LatLngPoint(point.getDouble(0), point.getDouble(1)))
        }
        return points
    }
}
```

**Step 3: Commit**

```bash
git add EasyStreet_Android/app/src/main/kotlin/com/easystreet/data/db/
git commit -m "feat(android): add StreetDatabase and StreetDao for SQLite viewport queries"
```

---

## Task 7: Parking Persistence & Repository Layer

**Files:**
- Create: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/data/prefs/ParkingPreferences.kt`
- Create: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/data/repository/ParkingRepository.kt`
- Create: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/data/repository/StreetRepository.kt`

**Step 1: Write ParkingPreferences**

```kotlin
// app/src/main/kotlin/com/easystreet/data/prefs/ParkingPreferences.kt
package com.easystreet.data.prefs

import android.content.Context
import android.content.SharedPreferences
import com.easystreet.domain.model.ParkedCar
import java.time.Instant

class ParkingPreferences(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("parking", Context.MODE_PRIVATE)

    fun save(car: ParkedCar) {
        prefs.edit()
            .putFloat(KEY_LAT, car.latitude.toFloat())
            .putFloat(KEY_LNG, car.longitude.toFloat())
            .putString(KEY_STREET, car.streetName)
            .putLong(KEY_TIMESTAMP, car.timestamp.toEpochMilli())
            .apply()
    }

    fun load(): ParkedCar? {
        if (!prefs.contains(KEY_LAT)) return null

        return ParkedCar(
            latitude = prefs.getFloat(KEY_LAT, 0f).toDouble(),
            longitude = prefs.getFloat(KEY_LNG, 0f).toDouble(),
            streetName = prefs.getString(KEY_STREET, "") ?: "",
            timestamp = Instant.ofEpochMilli(prefs.getLong(KEY_TIMESTAMP, 0L)),
        )
    }

    fun clear() {
        prefs.edit().clear().apply()
    }

    companion object {
        private const val KEY_LAT = "lat"
        private const val KEY_LNG = "lng"
        private const val KEY_STREET = "street"
        private const val KEY_TIMESTAMP = "timestamp"
    }
}
```

**Step 2: Write ParkingRepository**

```kotlin
// app/src/main/kotlin/com/easystreet/data/repository/ParkingRepository.kt
package com.easystreet.data.repository

import com.easystreet.data.prefs.ParkingPreferences
import com.easystreet.domain.model.ParkedCar
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.Instant

class ParkingRepository(private val prefs: ParkingPreferences) {

    private val _parkedCar = MutableStateFlow(prefs.load())
    val parkedCar: StateFlow<ParkedCar?> = _parkedCar.asStateFlow()

    fun parkCar(latitude: Double, longitude: Double, streetName: String) {
        val car = ParkedCar(latitude, longitude, streetName, Instant.now())
        prefs.save(car)
        _parkedCar.value = car
    }

    fun updateLocation(latitude: Double, longitude: Double, streetName: String) {
        val current = _parkedCar.value ?: return
        val updated = current.copy(latitude = latitude, longitude = longitude, streetName = streetName)
        prefs.save(updated)
        _parkedCar.value = updated
    }

    fun clearParking() {
        prefs.clear()
        _parkedCar.value = null
    }
}
```

**Step 3: Write StreetRepository**

```kotlin
// app/src/main/kotlin/com/easystreet/data/repository/StreetRepository.kt
package com.easystreet.data.repository

import com.easystreet.data.db.StreetDao
import com.easystreet.domain.model.StreetSegment
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class StreetRepository(private val dao: StreetDao) {

    suspend fun getSegmentsInViewport(
        latMin: Double,
        latMax: Double,
        lngMin: Double,
        lngMax: Double,
    ): List<StreetSegment> = withContext(Dispatchers.IO) {
        dao.getSegmentsInViewport(latMin, latMax, lngMin, lngMax)
    }

    suspend fun findNearestSegment(lat: Double, lng: Double): StreetSegment? =
        withContext(Dispatchers.IO) {
            dao.findNearestSegment(lat, lng)
        }
}
```

**Step 4: Commit**

```bash
git add EasyStreet_Android/app/src/main/kotlin/com/easystreet/data/
git commit -m "feat(android): add ParkingPreferences, ParkingRepository, and StreetRepository"
```

---

## Task 8: Notification System

**Files:**
- Create: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/notification/NotificationScheduler.kt`
- Create: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/notification/SweepingNotificationWorker.kt`

**Step 1: Write NotificationScheduler**

```kotlin
// app/src/main/kotlin/com/easystreet/notification/NotificationScheduler.kt
package com.easystreet.notification

import android.content.Context
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import java.time.Duration
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.concurrent.TimeUnit

object NotificationScheduler {

    private const val WORK_NAME = "sweeping_alert"

    fun schedule(context: Context, sweepingTime: LocalDateTime, streetName: String) {
        val now = LocalDateTime.now()
        val notifyTime = sweepingTime.minusHours(1)

        if (notifyTime.isBefore(now)) return

        val delay = Duration.between(now, notifyTime)

        val workRequest = OneTimeWorkRequestBuilder<SweepingNotificationWorker>()
            .setInitialDelay(delay.toMillis(), TimeUnit.MILLISECONDS)
            .addTag("sweeping_notification")
            .setInputData(
                workDataOf(
                    SweepingNotificationWorker.KEY_STREET_NAME to streetName,
                    SweepingNotificationWorker.KEY_SWEEP_TIME to sweepingTime.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli(),
                )
            )
            .build()

        WorkManager.getInstance(context)
            .enqueueUniqueWork(WORK_NAME, ExistingWorkPolicy.REPLACE, workRequest)
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
    }
}
```

**Step 2: Write SweepingNotificationWorker**

```kotlin
// app/src/main/kotlin/com/easystreet/notification/SweepingNotificationWorker.kt
package com.easystreet.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

class SweepingNotificationWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    override fun doWork(): Result {
        val streetName = inputData.getString(KEY_STREET_NAME) ?: "your street"
        val sweepTimeMillis = inputData.getLong(KEY_SWEEP_TIME, 0L)

        val timeStr = if (sweepTimeMillis > 0) {
            val sweepTime = LocalDateTime.ofInstant(
                Instant.ofEpochMilli(sweepTimeMillis),
                ZoneId.systemDefault(),
            )
            sweepTime.format(DateTimeFormatter.ofPattern("h:mm a"))
        } else {
            "soon"
        }

        ensureNotificationChannel()

        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Street Sweeping Alert")
            .setContentText("Street sweeping at $timeStr on $streetName. Move your car!")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        val manager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager
        manager.notify(NOTIFICATION_ID, notification)

        return Result.success()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Sweeping Alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Alerts for upcoming street sweeping"
            }
            val manager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    companion object {
        const val KEY_STREET_NAME = "street_name"
        const val KEY_SWEEP_TIME = "sweep_time"
        private const val CHANNEL_ID = "sweeping_alerts"
        private const val NOTIFICATION_ID = 1001
    }
}
```

**Step 3: Commit**

```bash
git add EasyStreet_Android/app/src/main/kotlin/com/easystreet/notification/
git commit -m "feat(android): add NotificationScheduler and SweepingNotificationWorker"
```

---

## Task 9: Application Class & MainActivity Shell

**Files:**
- Create: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/EasyStreetApp.kt`
- Create: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/MainActivity.kt`

**Step 1: Write EasyStreetApp**

```kotlin
// app/src/main/kotlin/com/easystreet/EasyStreetApp.kt
package com.easystreet

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class EasyStreetApp : Application() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "sweeping_alerts",
                "Sweeping Alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Alerts for upcoming street sweeping near your parked car"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
```

**Step 2: Write MainActivity shell**

```kotlin
// app/src/main/kotlin/com/easystreet/MainActivity.kt
package com.easystreet

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    Text("EasyStreet - Map coming next")
                }
            }
        }
    }
}
```

**Step 3: Verify build**

```bash
cd EasyStreet_Android
./gradlew assembleDebug
```

Expected: BUILD SUCCESSFUL.

**Step 4: Commit**

```bash
git add EasyStreet_Android/app/src/main/kotlin/com/easystreet/EasyStreetApp.kt
git add EasyStreet_Android/app/src/main/kotlin/com/easystreet/MainActivity.kt
git commit -m "feat(android): add EasyStreetApp and MainActivity shell"
```

---

## Task 10: MapViewModel

**Files:**
- Create: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/ui/MapViewModel.kt`

**Step 1: Write MapViewModel**

```kotlin
// app/src/main/kotlin/com/easystreet/ui/MapViewModel.kt
package com.easystreet.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.easystreet.data.db.StreetDao
import com.easystreet.data.db.StreetDatabase
import com.easystreet.data.prefs.ParkingPreferences
import com.easystreet.data.repository.ParkingRepository
import com.easystreet.data.repository.StreetRepository
import com.easystreet.domain.engine.SweepingRuleEngine
import com.easystreet.domain.model.ParkedCar
import com.easystreet.domain.model.StreetSegment
import com.easystreet.domain.model.SweepingStatus
import com.easystreet.notification.NotificationScheduler
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDateTime

class MapViewModel(application: Application) : AndroidViewModel(application) {

    private val streetDb = StreetDatabase(application)
    private val streetDao = StreetDao(streetDb)
    private val streetRepo = StreetRepository(streetDao)

    private val parkingPrefs = ParkingPreferences(application)
    val parkingRepo = ParkingRepository(parkingPrefs)

    private val _visibleSegments = MutableStateFlow<List<StreetSegment>>(emptyList())
    val visibleSegments: StateFlow<List<StreetSegment>> = _visibleSegments.asStateFlow()

    private val _sweepingStatus = MutableStateFlow<SweepingStatus>(SweepingStatus.NoData)
    val sweepingStatus: StateFlow<SweepingStatus> = _sweepingStatus.asStateFlow()

    private var viewportJob: Job? = null

    /**
     * Called when the map camera moves. Debounces by 300ms.
     */
    fun onViewportChanged(latMin: Double, latMax: Double, lngMin: Double, lngMax: Double) {
        viewportJob?.cancel()
        viewportJob = viewModelScope.launch {
            delay(300)
            val segments = streetRepo.getSegmentsInViewport(latMin, latMax, lngMin, lngMax)
            _visibleSegments.value = segments
        }
    }

    /**
     * Park the car at the given location.
     */
    fun parkCar(lat: Double, lng: Double) {
        viewModelScope.launch {
            val segment = streetRepo.findNearestSegment(lat, lng)
            val streetName = segment?.streetName ?: "Unknown Street"

            parkingRepo.parkCar(lat, lng, streetName)

            if (segment != null) {
                evaluateAndSchedule(segment, streetName)
            } else {
                _sweepingStatus.value = SweepingStatus.NoData
            }
        }
    }

    /**
     * Update parked car location after pin drag.
     */
    fun updateParkingLocation(lat: Double, lng: Double) {
        viewModelScope.launch {
            val segment = streetRepo.findNearestSegment(lat, lng)
            val streetName = segment?.streetName ?: "Unknown Street"

            parkingRepo.updateLocation(lat, lng, streetName)

            if (segment != null) {
                evaluateAndSchedule(segment, streetName)
            } else {
                _sweepingStatus.value = SweepingStatus.NoData
                NotificationScheduler.cancel(getApplication())
            }
        }
    }

    /**
     * Clear parking state.
     */
    fun clearParking() {
        parkingRepo.clearParking()
        _sweepingStatus.value = SweepingStatus.NoData
        NotificationScheduler.cancel(getApplication())
    }

    private fun evaluateAndSchedule(segment: StreetSegment, streetName: String) {
        val now = LocalDateTime.now()
        val status = SweepingRuleEngine.getStatus(segment.rules, streetName, now)
        _sweepingStatus.value = status

        val nextTime = SweepingRuleEngine.getNextSweepingTime(segment.rules, now)
        if (nextTime != null) {
            NotificationScheduler.schedule(getApplication(), nextTime, streetName)
        }
    }
}
```

**Step 2: Commit**

```bash
git add EasyStreet_Android/app/src/main/kotlin/com/easystreet/ui/MapViewModel.kt
git commit -m "feat(android): add MapViewModel with viewport queries, parking, and notification scheduling"
```

---

## Task 11: MapScreen Compose UI

**Files:**
- Create: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/ui/MapScreen.kt`
- Modify: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/MainActivity.kt`

This is the largest task. It builds the full map UI with overlays, parking marker, and search.

**Step 1: Write MapScreen**

```kotlin
// app/src/main/kotlin/com/easystreet/ui/MapScreen.kt
package com.easystreet.ui

import android.Manifest
import android.content.pm.PackageManager
import android.location.Geocoder
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import com.easystreet.domain.engine.SweepingRuleEngine
import com.easystreet.domain.model.SweepingStatus
import com.google.android.gms.location.LocationServices
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.*
import kotlinx.coroutines.launch
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MapScreen(viewModel: MapViewModel = viewModel()) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // SF default location
    val sfCenter = LatLng(37.7749, -122.4194)
    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(sfCenter, 15f)
    }

    val visibleSegments by viewModel.visibleSegments.collectAsState()
    val parkedCar by viewModel.parkingRepo.parkedCar.collectAsState()
    val sweepingStatus by viewModel.sweepingStatus.collectAsState()

    var searchQuery by remember { mutableStateOf("") }
    var showSearch by remember { mutableStateOf(false) }

    // Location permission
    val hasLocationPermission = remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        )
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        hasLocationPermission.value = permissions[Manifest.permission.ACCESS_FINE_LOCATION] == true
    }

    LaunchedEffect(Unit) {
        if (!hasLocationPermission.value) {
            permissionLauncher.launch(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                )
            )
        }
    }

    // Move to user location on first permission grant
    LaunchedEffect(hasLocationPermission.value) {
        if (hasLocationPermission.value) {
            val fusedClient = LocationServices.getFusedLocationProviderClient(context)
            try {
                fusedClient.lastLocation.addOnSuccessListener { location ->
                    if (location != null) {
                        scope.launch {
                            cameraPositionState.animate(
                                CameraUpdateFactory.newLatLngZoom(
                                    LatLng(location.latitude, location.longitude),
                                    16f,
                                )
                            )
                        }
                    }
                }
            } catch (_: SecurityException) {
                // Permission was revoked between check and use
            }
        }
    }

    // Viewport change listener
    val isMoving = cameraPositionState.isMoving
    LaunchedEffect(isMoving) {
        if (!isMoving) {
            val bounds = cameraPositionState.projection?.visibleRegion?.latLngBounds ?: return@LaunchedEffect
            viewModel.onViewportChanged(
                bounds.southwest.latitude,
                bounds.northeast.latitude,
                bounds.southwest.longitude,
                bounds.northeast.longitude,
            )
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        GoogleMap(
            modifier = Modifier.fillMaxSize(),
            cameraPositionState = cameraPositionState,
            properties = MapProperties(
                isMyLocationEnabled = hasLocationPermission.value,
            ),
            uiSettings = MapUiSettings(
                myLocationButtonEnabled = hasLocationPermission.value,
                zoomControlsEnabled = false,
            ),
        ) {
            // Street overlays
            val now = LocalDateTime.now()
            visibleSegments.forEach { segment ->
                val status = SweepingRuleEngine.getStatus(segment.rules, segment.streetName, now)
                val color = when (status) {
                    is SweepingStatus.Imminent -> Color.Red
                    is SweepingStatus.Today -> Color.Red
                    is SweepingStatus.Upcoming -> Color.Green
                    is SweepingStatus.Safe -> Color.Green
                    is SweepingStatus.NoData -> Color.Gray
                    is SweepingStatus.Unknown -> Color.Gray
                }

                Polyline(
                    points = segment.coordinates.map { LatLng(it.latitude, it.longitude) },
                    color = color,
                    width = 8f,
                )
            }

            // Parked car marker
            parkedCar?.let { car ->
                Marker(
                    state = MarkerState(position = LatLng(car.latitude, car.longitude)),
                    title = car.streetName,
                    snippet = "Your car",
                    icon = BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_AZURE),
                    draggable = true,
                    onInfoWindowClick = {},
                )
            }
        }

        // Search bar
        if (showSearch) {
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
                    .align(Alignment.TopCenter),
                placeholder = { Text("Search address...") },
                singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedContainerColor = MaterialTheme.colorScheme.surface,
                    unfocusedContainerColor = MaterialTheme.colorScheme.surface,
                ),
                trailingIcon = {
                    TextButton(onClick = {
                        scope.launch {
                            val geocoder = Geocoder(context, Locale.getDefault())
                            @Suppress("DEPRECATION")
                            val results = geocoder.getFromLocationName(searchQuery, 1)
                            results?.firstOrNull()?.let { address ->
                                cameraPositionState.animate(
                                    CameraUpdateFactory.newLatLngZoom(
                                        LatLng(address.latitude, address.longitude),
                                        17f,
                                    )
                                )
                            }
                            showSearch = false
                            searchQuery = ""
                        }
                    }) {
                        Text("Go")
                    }
                },
            )
        } else {
            IconButton(
                onClick = { showSearch = true },
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(16.dp),
            ) {
                Text("\uD83D\uDD0D", style = MaterialTheme.typography.headlineSmall)
            }
        }

        // Bottom: Park button or parking info sheet
        Column(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (parkedCar != null) {
                // Parking info card
                ParkingInfoCard(
                    streetName = parkedCar!!.streetName,
                    status = sweepingStatus,
                    onClearParking = { viewModel.clearParking() },
                )
            } else {
                // "I Parked Here" button
                Button(
                    onClick = {
                        val center = cameraPositionState.position.target
                        viewModel.parkCar(center.latitude, center.longitude)
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.primary,
                    ),
                ) {
                    Text("I Parked Here")
                }
            }
        }
    }
}

@Composable
fun ParkingInfoCard(
    streetName: String,
    status: SweepingStatus,
    onClearParking: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
        ) {
            Text(
                text = streetName,
                style = MaterialTheme.typography.titleMedium,
            )

            Spacer(modifier = Modifier.height(8.dp))

            val (statusText, statusColor) = when (status) {
                is SweepingStatus.Safe -> "Safe to park" to Color(0xFF4CAF50)
                is SweepingStatus.Today -> {
                    val timeStr = status.time.format(DateTimeFormatter.ofPattern("h:mm a"))
                    "Sweeping today at $timeStr" to Color(0xFFFF9800)
                }
                is SweepingStatus.Imminent -> {
                    val timeStr = status.time.format(DateTimeFormatter.ofPattern("h:mm a"))
                    "Sweeping imminent at $timeStr!" to Color.Red
                }
                is SweepingStatus.Upcoming -> {
                    val timeStr = status.time.format(DateTimeFormatter.ofPattern("EEE, MMM d 'at' h:mm a"))
                    "Next sweeping: $timeStr" to Color(0xFF4CAF50)
                }
                is SweepingStatus.NoData -> "No sweeping data available" to Color.Gray
                is SweepingStatus.Unknown -> "Status unknown" to Color.Gray
            }

            Text(
                text = statusText,
                color = statusColor,
                style = MaterialTheme.typography.bodyLarge,
            )

            Spacer(modifier = Modifier.height(12.dp))

            OutlinedButton(
                onClick = onClearParking,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Clear Parking")
            }
        }
    }
}
```

**Step 2: Update MainActivity to use MapScreen**

Replace the content of `MainActivity.kt`:

```kotlin
// app/src/main/kotlin/com/easystreet/MainActivity.kt
package com.easystreet

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import com.easystreet.ui.MapScreen

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                MapScreen()
            }
        }
    }
}
```

**Step 3: Verify build**

```bash
cd EasyStreet_Android
./gradlew assembleDebug
```

Expected: BUILD SUCCESSFUL.

**Step 4: Commit**

```bash
git add EasyStreet_Android/app/src/main/kotlin/com/easystreet/ui/MapScreen.kt
git add EasyStreet_Android/app/src/main/kotlin/com/easystreet/MainActivity.kt
git commit -m "feat(android): add MapScreen with Google Maps, street overlays, parking, and search"
```

---

## Task 12: Handle Marker Drag for Pin Adjustment

**Files:**
- Modify: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/ui/MapScreen.kt`

The `Marker` composable in maps-compose supports `onMarkerDragEnd`. We need to wire the drag event to `viewModel.updateParkingLocation`.

**Step 1: Update the Marker in MapScreen.kt**

Find the `Marker` composable for the parked car and update it:

```kotlin
// Replace the existing Marker block inside GoogleMap with:
parkedCar?.let { car ->
    val markerState = rememberMarkerState(position = LatLng(car.latitude, car.longitude))

    LaunchedEffect(car.latitude, car.longitude) {
        markerState.position = LatLng(car.latitude, car.longitude)
    }

    MarkerInfoWindow(
        state = markerState,
        title = car.streetName,
        snippet = "Drag to adjust",
        icon = BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_AZURE),
        draggable = true,
        onMarkerDragEnd = { marker ->
            viewModel.updateParkingLocation(
                marker.position.latitude,
                marker.position.longitude,
            )
        },
    )
}
```

Note: `MarkerInfoWindow` is used instead of `Marker` because it better supports drag callbacks in maps-compose.

**Step 2: Verify build**

```bash
cd EasyStreet_Android
./gradlew assembleDebug
```

Expected: BUILD SUCCESSFUL.

**Step 3: Commit**

```bash
git add EasyStreet_Android/app/src/main/kotlin/com/easystreet/ui/MapScreen.kt
git commit -m "feat(android): add draggable marker for manual parking pin adjustment"
```

---

## Task 13: Notification Permission (API 33+)

**Files:**
- Modify: `EasyStreet_Android/app/src/main/kotlin/com/easystreet/ui/MapScreen.kt`

On Android 13+, the `POST_NOTIFICATIONS` permission must be requested at runtime. We should request it when the user first taps "I Parked Here".

**Step 1: Add notification permission request**

In `MapScreen.kt`, add a notification permission launcher alongside the location permission:

```kotlin
// Add near the other permission launcher:
val notificationPermissionLauncher = rememberLauncherForActivityResult(
    ActivityResultContracts.RequestPermission()
) { _ ->
    // Permission result doesn't block parking — notification just won't fire if denied
}
```

Then update the "I Parked Here" button's onClick:

```kotlin
onClick = {
    // Request notification permission on API 33+ before parking
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
        if (ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }
    val center = cameraPositionState.position.target
    viewModel.parkCar(center.latitude, center.longitude)
},
```

**Step 2: Verify build**

```bash
cd EasyStreet_Android
./gradlew assembleDebug
```

Expected: BUILD SUCCESSFUL.

**Step 3: Commit**

```bash
git add EasyStreet_Android/app/src/main/kotlin/com/easystreet/ui/MapScreen.kt
git commit -m "feat(android): request POST_NOTIFICATIONS permission on API 33+"
```

---

## Task 14: Final Integration & Build Verification

**Files:**
- Modify: `EasyStreet_Android/app/src/main/AndroidManifest.xml` (if namespace needs updating)
- No new files

**Step 1: Update AndroidManifest package to match source**

The manifest currently uses `com.yourdomain.easystreetandroid` but our source uses `com.easystreet`. Update `build.gradle.kts`:

Change `namespace` and `applicationId`:
```kotlin
namespace = "com.easystreet"
// ...
applicationId = "com.easystreet"
```

Update `AndroidManifest.xml` to remove the `package` attribute (namespace in build.gradle.kts handles it in modern AGP):
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
```

**Step 2: Run all tests**

```bash
cd EasyStreet_Android
./gradlew test -q
```

Expected: All tests PASS (SweepingRuleTest, HolidayCalculatorTest, SweepingRuleEngineTest).

**Step 3: Run full debug build**

```bash
cd EasyStreet_Android
./gradlew assembleDebug
```

Expected: BUILD SUCCESSFUL.

**Step 4: Commit**

```bash
git add EasyStreet_Android/
git commit -m "feat(android): finalize package namespace and verify full build"
```

---

## Task Summary

| Task | Description | Tests | Depends On |
|------|-------------|-------|------------|
| 1 | Project scaffolding (Gradle, resources) | Build check | — |
| 2 | CSV → SQLite converter + generate DB | Manual verify | — |
| 3 | Domain models (SweepingRule, StreetSegment, etc.) | 3 unit tests | — |
| 4 | HolidayCalculator | 8 unit tests | — |
| 5 | SweepingRuleEngine | 7 unit tests | 3, 4 |
| 6 | SQLite database layer (StreetDatabase, StreetDao) | Via integration | 3 |
| 7 | Parking persistence & repositories | — | 3 |
| 8 | Notification system (WorkManager) | — | — |
| 9 | Application class & MainActivity shell | Build check | 1 |
| 10 | MapViewModel | — | 5, 6, 7, 8 |
| 11 | MapScreen Compose UI | Build check | 10 |
| 12 | Marker drag for pin adjustment | Build check | 11 |
| 13 | Notification permission (API 33+) | Build check | 11 |
| 14 | Final integration & build verification | All tests + build | All |

**Parallel-safe tasks** (can be done independently):
- Tasks 1, 2, 3, 4 are all independent
- Tasks 6, 7, 8 depend only on Task 3

**Critical path:** 1 → 9 → 10 → 11 → 12 → 13 → 14
