# iOS MVP Completion Sprint - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Take the iOS app from "code exists but can't build" to a fully testable MVP with real SF street data, dynamic holidays, enhanced UX, and comprehensive tests.

**Architecture:** MVC with UIKit. MapKit for maps, CoreLocation for GPS, UserNotifications for alerts. Data loaded from bundled JSON converted from the same SF open data CSV that Android uses. All business logic in testable utility classes (SweepingRuleEngine, HolidayCalculator). Test target uses XCTest.

**Tech Stack:** Swift 5, UIKit, MapKit, CoreLocation, UserNotifications, XCTest, xcodegen (project generation), Python 3 (one-time CSV conversion script)

---

## Current State Summary

| Component | Status | Details |
|-----------|--------|---------|
| ParkedCar.swift | OK | 165 lines, fully intact (verified Feb 5) |
| StreetSweepingData.swift | OK | 300 lines, data models + manager |
| SweepingRuleEngine.swift | BUG | Holidays hardcoded for 2023 only (lines 13-25) |
| MapViewController.swift | OK | 667 lines, all UI working |
| .xcodeproj | MISSING | No Xcode project file - app cannot be built |
| sweeping_data_sf.json | MISSING | CSV exists (7.3 MB) but no JSON bundle |
| Test coverage | ZERO | No XCTest files or test target |
| Color coding | BASIC | Only red/green; no orange/yellow |
| Notifications | BASIC | Hardcoded 1-hour advance, not configurable |
| Map performance | POOR | Removes/re-adds ALL overlays on every region change |

### iOS Source Files (6 total, 1,323 lines)

| File | Lines | Purpose |
|------|-------|---------|
| `EasyStreet/AppDelegate.swift` | 26 | App entry, notification auth |
| `EasyStreet/SceneDelegate.swift` | 45 | Window/scene setup |
| `EasyStreet/Models/StreetSweepingData.swift` | 300 | SweepingRule, StreetSegment, DataManager |
| `EasyStreet/Models/ParkedCar.swift` | 165 | ParkedCarManager, notifications |
| `EasyStreet/Controllers/MapViewController.swift` | 667 | Main UI, map, search, parking |
| `EasyStreet/Utils/SweepingRuleEngine.swift` | 130 | Status analysis, holiday check |

### Android Reference (already working)

The Android app has full feature parity with dynamic holidays, SQLite-backed data (21,785 segments), 18 passing tests, and a working UI. Key files to reference:
- `HolidayCalculator.kt` (54 lines) - port algorithm to Swift
- `SweepingRuleEngine.kt` (78 lines) - reference for status logic
- `MapViewModel.kt` (108 lines) - viewport debounce pattern (300ms)

---

## Task 1: Create Xcode Project with xcodegen

**Files:**
- Create: `EasyStreet/project.yml`
- Create: `EasyStreet/EasyStreet.xcodeproj/` (generated)
- Create: `EasyStreetTests/` (empty directory for test target)

This MUST be done first - nothing else can be built or tested without it.

**Step 1: Install xcodegen**

```bash
brew install xcodegen
```

If already installed, verify: `xcodegen --version`

**Step 2: Create project.yml**

Create `EasyStreet/project.yml`:

```yaml
name: EasyStreet
options:
  bundleIdPrefix: com.easystreet
  deploymentTarget:
    iOS: "14.0"
  createIntermediateGroups: true

targets:
  EasyStreet:
    type: application
    platform: iOS
    sources:
      - path: .
        excludes:
          - "*.md"
          - "*.csv"
          - "EasyStreet.xcodeproj"
          - "project.yml"
    resources:
      - path: LaunchScreen.storyboard
      - path: Info.plist
        buildPhase: none
    settings:
      base:
        INFOPLIST_FILE: Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.easystreet.app
        TARGETED_DEVICE_FAMILY: 1
        SWIFT_VERSION: "5.0"

  EasyStreetTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: ../EasyStreetTests
    dependencies:
      - target: EasyStreet
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.easystreet.app.tests
        SWIFT_VERSION: "5.0"
```

**Step 3: Create test target directory**

```bash
mkdir -p EasyStreetTests
```

**Step 4: Generate the Xcode project**

```bash
cd EasyStreet
xcodegen generate
```

Expected: `Created project at .../EasyStreet.xcodeproj`

**Step 5: Build to verify**

```bash
xcodebuild -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

**Step 6: Commit**

```bash
git add EasyStreet/project.yml EasyStreet/EasyStreet.xcodeproj EasyStreetTests/
git commit -m "feat(ios): add Xcode project via xcodegen with test target"
```

---

## Task 2: CSV to JSON Conversion Script

**Files:**
- Create: `tools/csv_to_json.py`
- Create: `EasyStreet/sweeping_data_sf.json` (generated output)
- Modify: `EasyStreet/project.yml` (add JSON to resources)

The Android team already has `EasyStreet_Android/tools/csv_to_sqlite.py` as reference. This script produces JSON instead of SQLite, matching the iOS `StreetSegment` Codable model.

**Step 1: Write the conversion script**

Create `tools/csv_to_json.py`:

```python
#!/usr/bin/env python3
"""
Convert SF street sweeping CSV to JSON for the iOS app bundle.

Output JSON matches the iOS StreetSegment Codable model:
  { "id": "110000-L-1613751",
    "streetName": "01st St",
    "coordinates": [[lat, lng], ...],
    "rules": [{ "dayOfWeek": 3, "startTime": "00:00", "endTime": "02:00",
                "weeksOfMonth": [1,2,3,4,5], "applyOnHolidays": false }] }
"""
import csv
import json
import os
import re
import sys

DAY_MAP = {
    "Mon": 2, "Tue": 3, "Tues": 3, "Wed": 4,
    "Thu": 5, "Thur": 5, "Fri": 6, "Sat": 7, "Sun": 1,
    "Monday": 2, "Tuesday": 3, "Wednesday": 4,
    "Thursday": 5, "Friday": 6, "Saturday": 7, "Sunday": 1,
}

def parse_linestring(wkt):
    """Parse WKT LINESTRING into [[lat, lng], ...] array."""
    match = re.search(r'LINESTRING\s*\((.+)\)', wkt)
    if not match:
        return None
    coords = []
    for pair in match.group(1).split(','):
        parts = pair.strip().split()
        if len(parts) == 2:
            lng, lat = float(parts[0]), float(parts[1])
            coords.append([lat, lng])
    return coords if coords else None

def hour_to_time(hour_val):
    """Convert integer hour (0-23) to 'HH:MM' string."""
    try:
        h = int(float(hour_val))
        return f"{h:02d}:00"
    except (ValueError, TypeError):
        return "00:00"

def convert(csv_path, json_path):
    segments = {}

    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            cnn = row.get('CNN', '').strip()
            side = row.get('CNNRightLeft', '').strip()
            sweep_id = row.get('BlockSweepID', '').strip()
            seg_id = f"{cnn}-{side}-{sweep_id}"

            if seg_id not in segments:
                coords = parse_linestring(row.get('Line', ''))
                if not coords:
                    continue
                segments[seg_id] = {
                    "id": seg_id,
                    "streetName": row.get('Corridor', '').strip(),
                    "coordinates": coords,
                    "rules": []
                }

            weekday_str = row.get('WeekDay', '').strip()
            day_of_week = DAY_MAP.get(weekday_str)
            if day_of_week is None:
                continue

            weeks = []
            for i in range(1, 6):
                if row.get(f'Week{i}', '0').strip() == '1':
                    weeks.append(i)

            rule = {
                "dayOfWeek": day_of_week,
                "startTime": hour_to_time(row.get('FromHour', '0')),
                "endTime": hour_to_time(row.get('ToHour', '0')),
                "weeksOfMonth": weeks,
                "applyOnHolidays": row.get('Holidays', '0').strip() == '1'
            }

            if rule not in segments[seg_id]["rules"]:
                segments[seg_id]["rules"].append(rule)

    result = list(segments.values())
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(result, f, separators=(',', ':'))

    size_mb = os.path.getsize(json_path) / 1024 / 1024
    print(f"Converted {len(result)} segments to {json_path}")
    print(f"File size: {size_mb:.1f} MB")

if __name__ == '__main__':
    csv_path = sys.argv[1] if len(sys.argv) > 1 else 'EasyStreet/Street_Sweeping_Schedule_20250508.csv'
    json_path = sys.argv[2] if len(sys.argv) > 2 else 'EasyStreet/sweeping_data_sf.json'
    convert(csv_path, json_path)
```

**Step 2: Run the script**

```bash
python3 tools/csv_to_json.py
```

Expected: `Converted ~21000 segments to EasyStreet/sweeping_data_sf.json`

**Step 3: Verify output**

```bash
python3 -c "import json; d=json.load(open('EasyStreet/sweeping_data_sf.json')); print(f'{len(d)} segments'); print(json.dumps(d[0], indent=2))"
```

Verify: first segment has id, streetName, coordinates (lat ~37.7, lng ~-122.4), rules with dayOfWeek 1-7.

**Step 4: Update project.yml to bundle the JSON**

In `EasyStreet/project.yml`, update the EasyStreet target resources:

```yaml
    resources:
      - path: LaunchScreen.storyboard
      - path: sweeping_data_sf.json
      - path: Info.plist
        buildPhase: none
```

**Step 5: Regenerate Xcode project**

```bash
cd EasyStreet && xcodegen generate
```

**Step 6: Build to verify JSON is bundled**

```bash
xcodebuild -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

**Step 7: Commit**

```bash
git add tools/csv_to_json.py EasyStreet/sweeping_data_sf.json EasyStreet/project.yml
git commit -m "feat(ios): add CSV-to-JSON converter and bundle real SF street data (~21K segments)"
```

---

## Task 3: Dynamic Holiday Calculator

**Files:**
- Create: `EasyStreet/Utils/HolidayCalculator.swift`
- Create: `EasyStreetTests/HolidayCalculatorTests.swift`
- Modify: `EasyStreet/Utils/SweepingRuleEngine.swift` (lines 9-25, 100-108)

Port from Android's working `HolidayCalculator.kt` (54 lines). Same 11 holidays, same algorithm, Swift syntax.

**Step 1: Write failing tests first**

Create `EasyStreetTests/HolidayCalculatorTests.swift`:

```swift
import XCTest
@testable import EasyStreet

class HolidayCalculatorTests: XCTestCase {

    let calculator = HolidayCalculator()

    // MARK: - Fixed Holidays

    func testNewYearsDay() {
        XCTAssertTrue(calculator.isHoliday(date(2026, 1, 1)))
        XCTAssertTrue(calculator.isHoliday(date(2027, 1, 1)))
    }

    func testJuneteenth() {
        XCTAssertTrue(calculator.isHoliday(date(2026, 6, 19)))
    }

    func testIndependenceDay() {
        XCTAssertTrue(calculator.isHoliday(date(2026, 7, 4)))
    }

    func testVeteransDay() {
        XCTAssertTrue(calculator.isHoliday(date(2026, 11, 11)))
    }

    func testChristmas() {
        XCTAssertTrue(calculator.isHoliday(date(2026, 12, 25)))
    }

    // MARK: - Floating Holidays

    func testMLKDay2026() {
        // 3rd Monday of January 2026 = Jan 19
        XCTAssertTrue(calculator.isHoliday(date(2026, 1, 19)))
        XCTAssertFalse(calculator.isHoliday(date(2026, 1, 12)))
    }

    func testPresidentsDay2026() {
        // 3rd Monday of February 2026 = Feb 16
        XCTAssertTrue(calculator.isHoliday(date(2026, 2, 16)))
    }

    func testMemorialDay2026() {
        // Last Monday of May 2026 = May 25
        XCTAssertTrue(calculator.isHoliday(date(2026, 5, 25)))
    }

    func testLaborDay2026() {
        // 1st Monday of September 2026 = Sep 7
        XCTAssertTrue(calculator.isHoliday(date(2026, 9, 7)))
    }

    func testIndigenousPeoplesDay2026() {
        // 2nd Monday of October 2026 = Oct 12
        XCTAssertTrue(calculator.isHoliday(date(2026, 10, 12)))
    }

    func testThanksgiving2026() {
        // 4th Thursday of November 2026 = Nov 26
        XCTAssertTrue(calculator.isHoliday(date(2026, 11, 26)))
        XCTAssertFalse(calculator.isHoliday(date(2026, 11, 19)))
    }

    func testThanksgiving2025() {
        // 4th Thursday of November 2025 = Nov 27
        XCTAssertTrue(calculator.isHoliday(date(2025, 11, 27)))
    }

    // MARK: - Non-Holidays

    func testRegularDayIsNotHoliday() {
        XCTAssertFalse(calculator.isHoliday(date(2026, 3, 15)))
        XCTAssertFalse(calculator.isHoliday(date(2026, 8, 20)))
    }

    func testGetHolidaysReturns11() {
        let holidays = calculator.holidays(for: 2026)
        XCTAssertEqual(holidays.count, 11)
    }

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
}
```

**Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | grep -E "(Test|FAIL|error)"
```

Expected: FAIL (HolidayCalculator not found)

**Step 3: Implement HolidayCalculator**

Create `EasyStreet/Utils/HolidayCalculator.swift`:

```swift
import Foundation

/// Calculates SF public holidays dynamically for any year.
/// Replaces the hardcoded 2023 holiday list in SweepingRuleEngine.
/// Ported from Android's HolidayCalculator.kt.
class HolidayCalculator {

    /// Returns all 11 SF public holidays for the given year.
    func holidays(for year: Int) -> [Date] {
        let cal = Calendar.current
        var result: [Date] = []

        // Fixed holidays
        result.append(makeDate(year: year, month: 1, day: 1))    // New Year's Day
        result.append(makeDate(year: year, month: 6, day: 19))   // Juneteenth
        result.append(makeDate(year: year, month: 7, day: 4))    // Independence Day
        result.append(makeDate(year: year, month: 11, day: 11))  // Veterans Day
        result.append(makeDate(year: year, month: 12, day: 25))  // Christmas

        // Floating holidays
        result.append(nthWeekday(nth: 3, weekday: 2, month: 1, year: year))  // MLK Day (3rd Mon Jan)
        result.append(nthWeekday(nth: 3, weekday: 2, month: 2, year: year))  // Presidents' Day (3rd Mon Feb)
        result.append(lastWeekday(2, month: 5, year: year))                   // Memorial Day (last Mon May)
        result.append(nthWeekday(nth: 1, weekday: 2, month: 9, year: year))  // Labor Day (1st Mon Sep)
        result.append(nthWeekday(nth: 2, weekday: 2, month: 10, year: year)) // Indigenous Peoples' Day (2nd Mon Oct)
        result.append(nthWeekday(nth: 4, weekday: 5, month: 11, year: year)) // Thanksgiving (4th Thu Nov)

        return result
    }

    /// Check if a given date is an SF public holiday.
    func isHoliday(_ date: Date) -> Bool {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        return holidays(for: year).contains { cal.isDate($0, inSameDayAs: date) }
    }

    // MARK: - Private

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        return Calendar.current.date(from: c)!
    }

    /// Returns the nth occurrence of a weekday in a given month/year.
    /// weekday uses Calendar convention: 1=Sunday, 2=Monday, ..., 7=Saturday
    private func nthWeekday(nth: Int, weekday: Int, month: Int, year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.weekday = weekday
        components.weekdayOrdinal = nth
        return Calendar.current.date(from: components)!
    }

    /// Returns the last occurrence of a weekday in a given month/year.
    private func lastWeekday(_ weekday: Int, month: Int, year: Int) -> Date {
        let cal = Calendar.current
        // Get last day of month using month+1, day=0 trick
        var components = DateComponents()
        components.year = year
        components.month = month + 1
        components.day = 0
        let lastDay = cal.date(from: components)!

        let lastDayWeekday = cal.component(.weekday, from: lastDay)
        var diff = lastDayWeekday - weekday
        if diff < 0 { diff += 7 }
        return cal.date(byAdding: .day, value: -diff, to: lastDay)!
    }
}
```

**Step 4: Regenerate project (new files added)**

```bash
cd EasyStreet && xcodegen generate
```

**Step 5: Run tests to verify they pass**

```bash
xcodebuild test -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | grep -E "(Test|PASS|FAIL)"
```

Expected: All 14 tests PASS.

**Step 6: Update SweepingRuleEngine to use HolidayCalculator**

In `EasyStreet/Utils/SweepingRuleEngine.swift`:

**Delete** lines 9-25 (the hardcoded holidays array and comments). **Replace** the `isHoliday(_:)` method (lines 100-108) with:

```swift
    private let holidayCalculator = HolidayCalculator()

    func isHoliday(_ date: Date) -> Bool {
        return holidayCalculator.isHoliday(date)
    }
```

The full file after changes should look like:

```swift
import Foundation
import CoreLocation

/// Core logic engine for determining street sweeping rules for a location
class SweepingRuleEngine {
    static let shared = SweepingRuleEngine()

    private let holidayCalculator = HolidayCalculator()

    private init() {}

    /// Find the street segment for a given location and analyze its sweeping rules
    func analyzeSweeperStatus(for location: CLLocationCoordinate2D, completion: @escaping (SweepingStatus) -> Void) {
        // ... existing method body unchanged (lines 35-98) ...
    }

    /// Check if a given date is a holiday in San Francisco
    func isHoliday(_ date: Date) -> Bool {
        return holidayCalculator.isHoliday(date)
    }
}

// SweepingStatus enum unchanged
```

**Step 7: Run tests again to confirm nothing broke**

```bash
xcodebuild test -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | grep -E "(Test|PASS|FAIL)"
```

**Step 8: Commit**

```bash
git add EasyStreet/Utils/HolidayCalculator.swift EasyStreetTests/HolidayCalculatorTests.swift EasyStreet/Utils/SweepingRuleEngine.swift
git commit -m "feat(ios): replace hardcoded 2023 holidays with dynamic HolidayCalculator"
```

---

## Task 4: SweepingRuleEngine & Data Model Tests

**Files:**
- Create: `EasyStreetTests/SweepingRuleEngineTests.swift`

**Step 1: Write tests**

Create `EasyStreetTests/SweepingRuleEngineTests.swift`:

```swift
import XCTest
@testable import EasyStreet

class SweepingRuleEngineTests: XCTestCase {

    // MARK: - SweepingRule.appliesTo Tests

    func testRuleAppliesToCorrectDay() {
        // Feb 2, 2026 is a Monday (weekday 2)
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: false)
        let monday = makeDate(2026, 2, 2)
        XCTAssertTrue(rule.appliesTo(date: monday))
    }

    func testRuleDoesNotApplyToWrongDay() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: false)
        let tuesday = makeDate(2026, 2, 3)
        XCTAssertFalse(rule.appliesTo(date: tuesday))
    }

    func testRuleRespectsWeekOfMonth() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [1, 3], applyOnHolidays: false)
        let firstMonday = makeDate(2026, 2, 2)   // Week 1
        let secondMonday = makeDate(2026, 2, 9)  // Week 2
        let thirdMonday = makeDate(2026, 2, 16)  // Week 3
        XCTAssertTrue(rule.appliesTo(date: firstMonday))
        XCTAssertFalse(rule.appliesTo(date: secondMonday))
        XCTAssertTrue(rule.appliesTo(date: thirdMonday))
    }

    func testRuleSuspendedOnHoliday() {
        // Christmas 2025 = Thursday (weekday 5)
        let rule = SweepingRule(dayOfWeek: 5, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: false)
        let christmas = makeDate(2025, 12, 25)
        XCTAssertFalse(rule.appliesTo(date: christmas))
    }

    func testRuleAppliesOnHolidayWhenFlagged() {
        let rule = SweepingRule(dayOfWeek: 5, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true)
        let christmas = makeDate(2025, 12, 25)
        XCTAssertTrue(rule.appliesTo(date: christmas))
    }

    // MARK: - StreetSegment.hasSweeperToday Tests

    func testHasSweeperTodayWhenRuleApplies() {
        let today = Date()
        let weekday = Calendar.current.component(.weekday, from: today)
        let rule = SweepingRule(dayOfWeek: weekday, startTime: "23:00", endTime: "23:59",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = StreetSegment(id: "test", streetName: "Test St",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        XCTAssertTrue(segment.hasSweeperToday())
    }

    func testHasSweeperTodayWhenNoRule() {
        let today = Date()
        let weekday = Calendar.current.component(.weekday, from: today)
        let otherDay = (weekday % 7) + 1
        let rule = SweepingRule(dayOfWeek: otherDay, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: false)
        let segment = StreetSegment(id: "test", streetName: "Test St",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        XCTAssertFalse(segment.hasSweeperToday())
    }

    // MARK: - StreetSegment.nextSweeping Tests

    func testNextSweepingFindsUpcomingDate() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: false)
        let segment = StreetSegment(id: "test", streetName: "Test St",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        let (nextDate, nextRule) = segment.nextSweeping()
        XCTAssertNotNil(nextDate)
        XCTAssertNotNil(nextRule)
        if let d = nextDate {
            XCTAssertEqual(Calendar.current.component(.weekday, from: d), 2)
        }
    }

    // MARK: - Helpers

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        return Calendar.current.date(from: c)!
    }
}
```

**Step 2: Regenerate project and run tests**

```bash
cd EasyStreet && xcodegen generate
xcodebuild test -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | grep -E "(Test|PASS|FAIL)"
```

Expected: All tests PASS (14 holiday + 8 engine = 22 total).

**Step 3: Commit**

```bash
git add EasyStreetTests/SweepingRuleEngineTests.swift
git commit -m "test(ios): add unit tests for SweepingRule, StreetSegment, and rule engine"
```

---

## Task 5: Map Performance Optimization

**Files:**
- Modify: `EasyStreet/Controllers/MapViewController.swift` (lines 69-74, 287-292, 588-592)

Critical for handling 21K+ segments. Without this, the app will freeze when real data is loaded. Android's MapViewModel already does viewport-debounced queries (300ms).

**Step 1: Add tracking properties**

In `MapViewController.swift`, after line 74 (`private var isAdjustingPin = false`), add:

```swift
    private var displayedSegmentIDs: Set<String> = []
    private var overlayUpdateTimer: Timer?
```

**Step 2: Replace updateMapOverlays with differential updates**

Replace lines 287-292 (`updateMapOverlays` method) with:

```swift
    private func updateMapOverlays() {
        let span = mapView.region.span

        // Don't render overlays when zoomed out too far (prevents 21K+ overlays)
        guard span.latitudeDelta < 0.05 else {
            let polylines = mapView.overlays.filter { $0 is MKPolyline }
            if !polylines.isEmpty {
                mapView.removeOverlays(polylines)
            }
            displayedSegmentIDs.removeAll()
            return
        }

        let visibleRect = mapView.visibleMapRect
        let visibleSegments = StreetSweepingDataManager.shared.segments(in: visibleRect)
        let visibleIDs = Set(visibleSegments.map { $0.id })

        // Remove overlays no longer visible
        let toRemove = displayedSegmentIDs.subtracting(visibleIDs)
        if !toRemove.isEmpty {
            let overlaysToRemove = mapView.overlays.filter { overlay in
                if let polyline = overlay as? MKPolyline, let title = polyline.title {
                    return toRemove.contains(title)
                }
                return false
            }
            mapView.removeOverlays(overlaysToRemove)
        }

        // Add new overlays
        let toAdd = visibleIDs.subtracting(displayedSegmentIDs)
        if !toAdd.isEmpty {
            let newSegments = visibleSegments.filter { toAdd.contains($0.id) }
            for segment in newSegments {
                let polyline = segment.polyline
                polyline.title = segment.id
                mapView.addOverlay(polyline)
            }
        }

        displayedSegmentIDs = visibleIDs
    }
```

**Step 3: Debounce region changes**

Replace lines 588-592 (`regionDidChangeAnimated`) with:

```swift
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        overlayUpdateTimer?.invalidate()
        overlayUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.updateMapOverlays()
        }
    }
```

**Step 4: Build and test**

```bash
xcodebuild -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

**Step 5: Commit**

```bash
git add EasyStreet/Controllers/MapViewController.swift
git commit -m "perf(ios): optimize map overlays with diff updates, zoom throttle, and debounce"
```

---

## Task 6: Enhanced Color Coding (Orange/Yellow)

**Files:**
- Modify: `EasyStreet/Models/StreetSweepingData.swift` (add `MapColorStatus` enum and method to `StreetSegment`)
- Modify: `EasyStreet/Controllers/MapViewController.swift` (lines 526-551 renderer, lines 196-219 legend)
- Modify: `EasyStreetTests/SweepingRuleEngineTests.swift` (add color status tests)

Android only has red/green/gray. This makes iOS better by adding orange (tomorrow) and yellow (2-3 days).

**Step 1: Add MapColorStatus to StreetSegment**

In `EasyStreet/Models/StreetSweepingData.swift`, after line 132 (end of `hasSweeperToday()` method), add:

```swift
    /// Color status for map display
    enum MapColorStatus {
        case red       // Sweeping today
        case orange    // Sweeping tomorrow
        case yellow    // Sweeping within 2-3 days
        case green     // No sweeping soon
    }

    func mapColorStatus() -> MapColorStatus {
        if hasSweeperToday() { return .red }

        let cal = Calendar.current
        let today = Date()
        for dayOffset in 1...3 {
            guard let futureDate = cal.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            if rules.contains(where: { $0.appliesTo(date: futureDate) }) {
                return dayOffset == 1 ? .orange : .yellow
            }
        }

        return .green
    }
```

**Step 2: Update map renderer**

In `MapViewController.swift`, replace lines 536-541 (the if/else block inside `rendererFor overlay`):

```swift
                // Color based on sweeping urgency
                switch segment.mapColorStatus() {
                case .red:
                    renderer.strokeColor = .systemRed
                case .orange:
                    renderer.strokeColor = .systemOrange
                case .yellow:
                    renderer.strokeColor = .systemYellow
                case .green:
                    renderer.strokeColor = .systemGreen
                }
```

**Step 3: Update the legend**

In `MapViewController.swift`, replace lines 213-218 (the legend item creation in `setupLegendView()`):

```swift
        let redItem = createLegendItem(color: .systemRed, text: "Today")
        let orangeItem = createLegendItem(color: .systemOrange, text: "Tomorrow")
        let yellowItem = createLegendItem(color: .systemYellow, text: "2-3 Days")
        let greenItem = createLegendItem(color: .systemGreen, text: "Safe")

        stackView.addArrangedSubview(redItem)
        stackView.addArrangedSubview(orangeItem)
        stackView.addArrangedSubview(yellowItem)
        stackView.addArrangedSubview(greenItem)
```

Also update the legend height constraint (line 157) from `80` to `120`:

```swift
            legendView.heightAnchor.constraint(equalToConstant: 120)
```

And update the legend width (line 156) from `100` to `120`:

```swift
            legendView.widthAnchor.constraint(equalToConstant: 120),
```

**Step 4: Add tests**

In `EasyStreetTests/SweepingRuleEngineTests.swift`, add:

```swift
    // MARK: - MapColorStatus Tests

    func testMapColorStatusRedWhenSweepingToday() {
        let today = Date()
        let weekday = Calendar.current.component(.weekday, from: today)
        let rule = SweepingRule(dayOfWeek: weekday, startTime: "23:00", endTime: "23:59",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        XCTAssertEqual(segment.mapColorStatus(), .red)
    }

    func testMapColorStatusGreenWhenNoSweepingSoon() {
        let future = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let weekday = Calendar.current.component(.weekday, from: future)
        let rule = SweepingRule(dayOfWeek: weekday, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        XCTAssertEqual(segment.mapColorStatus(), .green)
    }
```

Note: `MapColorStatus` must conform to `Equatable` for `XCTAssertEqual`. Add conformance:

```swift
    enum MapColorStatus: Equatable {
```

**Step 5: Regenerate project, build, and run tests**

```bash
cd EasyStreet && xcodegen generate
xcodebuild test -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | grep -E "(Test|PASS|FAIL)"
```

Expected: All tests PASS.

**Step 6: Commit**

```bash
git add EasyStreet/Models/StreetSweepingData.swift EasyStreet/Controllers/MapViewController.swift EasyStreetTests/SweepingRuleEngineTests.swift
git commit -m "feat(ios): add orange/yellow color coding for tomorrow and 2-3 day sweeping"
```

---

## Task 7: Configurable Notification Timing

**Files:**
- Modify: `EasyStreet/Models/ParkedCar.swift` (lines 16-21 UserDefaultsKeys, lines 119-120 hardcoded timing)
- Modify: `EasyStreet/Controllers/MapViewController.swift` (add settings button)

**Step 1: Add notification setting to ParkedCarManager**

In `ParkedCar.swift`, add to `UserDefaultsKeys` struct (after line 20):

```swift
        static let notificationLeadMinutes = "notificationLeadMinutes"
```

Add computed property after `parkedStreetName` (after line 53):

```swift
    /// Notification lead time in minutes (default: 60)
    var notificationLeadMinutes: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: UserDefaultsKeys.notificationLeadMinutes)
            return stored > 0 ? stored : 60
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.notificationLeadMinutes)
        }
    }
```

**Step 2: Use configurable lead time in scheduleNotification**

In `ParkedCar.swift`, replace line 120:

```swift
            let notificationTime = sweepingTime.addingTimeInterval(-3600) // 1 hour earlier
```

With:

```swift
            let leadSeconds = TimeInterval(self.notificationLeadMinutes * 60)
            let notificationTime = sweepingTime.addingTimeInterval(-leadSeconds)
```

**Step 3: Add settings button to MapViewController**

In `MapViewController.swift`, at the end of `viewDidLoad()` (before the closing brace at line 105), add:

```swift
        // Settings button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
        )
```

Add the settings handler method after `handleLongPress` (after line 503):

```swift
    @objc private func settingsTapped() {
        let current = ParkedCarManager.shared.notificationLeadMinutes
        let alert = UIAlertController(
            title: "Notification Lead Time",
            message: "How far in advance should we notify you? Currently: \(current) minutes",
            preferredStyle: .actionSheet
        )
        for minutes in [15, 30, 60, 120] {
            let title = minutes < 60 ? "\(minutes) minutes" : "\(minutes / 60) hour\(minutes > 60 ? "s" : "")"
            let style: UIAlertAction.Style = minutes == current ? .destructive : .default
            alert.addAction(UIAlertAction(title: title, style: style) { _ in
                ParkedCarManager.shared.notificationLeadMinutes = minutes
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
```

**Step 4: Build**

```bash
xcodebuild -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

**Step 5: Commit**

```bash
git add EasyStreet/Models/ParkedCar.swift EasyStreet/Controllers/MapViewController.swift
git commit -m "feat(ios): add configurable notification lead time (15m/30m/1h/2h)"
```

---

## Task 8: Error Handling & Edge Cases

**Files:**
- Modify: `EasyStreet/Controllers/MapViewController.swift` (lines 632-644 location auth, lines 408-412 park button, lines 356-397 status display)

**Step 1: Improve location permission denial handling**

In `MapViewController.swift`, replace lines 637-639 (the `.denied, .restricted` case):

```swift
        case .denied, .restricted:
            let alert = UIAlertController(
                title: "Location Services Required",
                message: "EasyStreet needs your location to find nearby street sweeping schedules. Please enable location access in Settings.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
```

**Step 2: Add reverse geocoding fallback for street name**

Replace lines 508-514 (`findStreetName` method) with an async version:

```swift
    private func findStreetName(for coordinate: CLLocationCoordinate2D, completion: @escaping (String) -> Void) {
        // Try sweeping data first
        if let segment = StreetSweepingDataManager.shared.findSegment(near: coordinate) {
            completion(segment.streetName)
            return
        }
        // Fallback to reverse geocoding
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            completion(placemarks?.first?.thoroughfare ?? "Unknown Street")
        }
    }
```

**Step 3: Update callers of findStreetName**

In `parkButtonTapped()` (line 408), replace:

```swift
        let streetName = findStreetName(for: location) ?? "Unknown Street"
        ParkedCarManager.shared.parkCar(at: location, streetName: streetName)
        addParkedCarAnnotation(at: location)
        updateUIForParkedState()
        checkSweepingStatusForParkedCar()
```

With:

```swift
        findStreetName(for: location) { [weak self] streetName in
            ParkedCarManager.shared.parkCar(at: location, streetName: streetName)
            self?.addParkedCarAnnotation(at: location)
            self?.updateUIForParkedState()
            self?.checkSweepingStatusForParkedCar()
        }
```

In `handleLongPress` `.ended` case (line 494), replace:

```swift
            let streetName = findStreetName(for: finalCoordinate) ?? "Unknown Street"
            parkedAnnotation.subtitle = streetName
```

With:

```swift
            findStreetName(for: finalCoordinate) { streetName in
                parkedAnnotation.subtitle = streetName
            }
```

**Step 4: Improve no-data status message**

In `updateStatusDisplay`, replace line 359:

```swift
            statusLabel.text = "No sweeping data available for this location."
```

With:

```swift
            statusLabel.text = "No sweeping data for this location. This area may not have scheduled street sweeping, or it may be outside our coverage area. Check posted street signs."
```

**Step 5: Build and test**

```bash
xcodebuild test -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`, all tests PASS.

**Step 6: Commit**

```bash
git add EasyStreet/Controllers/MapViewController.swift
git commit -m "fix(ios): improve error handling for location, geocoding fallback, and status messages"
```

---

## Task 9: UI Polish

**Files:**
- Modify: `EasyStreet/Controllers/MapViewController.swift` (lines 466-503 pin drag, lines 647-661 location updates)

**Step 1: Add visual feedback during pin drag**

In `handleLongPress`, in the `.began` case (after line 477 `isAdjustingPin = true`), add:

```swift
                if let annotationView = mapView.view(for: parkedAnnotation) {
                    UIView.animate(withDuration: 0.2) {
                        annotationView.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                        annotationView.alpha = 0.8
                    }
                }
```

In the `.ended` case (before `isAdjustingPin = false` at line 502), add:

```swift
            if let annotationView = mapView.view(for: parkedAnnotation) {
                UIView.animate(withDuration: 0.2) {
                    annotationView.transform = .identity
                    annotationView.alpha = 1.0
                }
            }
```

**Step 2: Fix the map centering bug**

Line 654 has `if !mapView.isUserInteractionEnabled {` which is always `true` (user interaction is enabled by default), so the auto-centering code never runs.

Add a property after `isAdjustingPin` (line 74):

```swift
    private var hasInitiallyLocated = false
```

Replace lines 647-661 (`didUpdateLocations`) with:

```swift
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last?.coordinate else { return }
        currentLocation = location

        // Only center map on first location fix
        if !hasInitiallyLocated {
            hasInitiallyLocated = true
            let region = MKCoordinateRegion(center: location,
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            mapView.setRegion(region, animated: true)
        }

        locationManager.stopUpdatingLocation()
    }
```

**Step 3: Build**

```bash
xcodebuild -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add EasyStreet/Controllers/MapViewController.swift
git commit -m "fix(ios): UI polish - pin drag feedback, map centering fix"
```

---

## Task 10: Documentation Updates

**Files:**
- Modify: `.claude/CLAUDE.md` (update build commands)
- Modify: `docs/getting-started.md` (update iOS section)

**Step 1: Update CLAUDE.md build commands**

In `.claude/CLAUDE.md`, update the iOS Build & Test Commands section to reflect the new xcodegen-based workflow:

```markdown
### Build & Test Commands
- **Open:** `open EasyStreet/EasyStreet.xcodeproj`
- **Build:** ⌘B in Xcode, or `xcodebuild -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator build`
- **Run:** ⌘R in Xcode
- **Test:** ⌘U in Xcode, or `xcodebuild test -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15'`
- **Clean:** ⇧⌘K in Xcode
- **Regenerate project:** `cd EasyStreet && xcodegen generate` (after adding/removing files)
```

**Step 2: Update getting-started.md iOS section**

Add instructions for opening the project and regenerating it:

```markdown
### Open the iOS project

```bash
open EasyStreet/EasyStreet.xcodeproj
```

In Xcode:
1. Select a simulator (e.g., iPhone 15) from the device dropdown
2. Press **Cmd + B** to build
3. Press **Cmd + R** to run
4. Press **Cmd + U** to run tests

If you need to regenerate the Xcode project (e.g., after adding new Swift files):

```bash
brew install xcodegen  # one-time
cd EasyStreet
xcodegen generate
```
```

**Step 3: Commit**

```bash
git add .claude/CLAUDE.md docs/getting-started.md
git commit -m "docs: update build commands for xcodegen and add test instructions"
```

---

## Task 11: Timeline Update & Final Verification

**Files:**
- Modify: `timeline.md`

**Step 1: Full build + test verification**

```bash
cd EasyStreet && xcodegen generate
xcodebuild -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -5
xcodebuild test -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | grep -E "(Test|PASS|FAIL|Executed)"
```

Expected:
- `** BUILD SUCCEEDED **`
- All ~24 tests PASS (14 holiday + 8 engine + 2 color)

**Step 2: Write timeline entry**

Add comprehensive timeline entry documenting all changes made in this sprint. Include:
- All files created/modified with line numbers
- All commit SHAs
- Test results summary
- Decisions made and rationale
- Updated "Next Steps" section

**Step 3: Commit**

```bash
git add timeline.md
git commit -m "docs: update timeline with iOS MVP completion sprint"
```

---

## Execution Order & Dependencies

```
Task 1 (Xcode project) ──────┐
                              ├──> Task 3 (HolidayCalculator) ──> Task 4 (tests)
Task 2 (CSV → JSON)    ──────┤
                              ├──> Task 5 (map performance)
                              ├──> Task 6 (color coding)
                              ├──> Task 7 (notifications)
                              ├──> Task 8 (error handling)
                              └──> Task 9 (UI polish)
                                        │
                                        v
                              Task 10 (docs) ──> Task 11 (timeline + verify)
```

- **Tasks 1 & 2** are independent and can run in parallel. They unblock everything else.
- **Task 3** depends on Tasks 1 & 2 (needs project to build + tests to reference).
- **Task 4** depends on Task 3 (tests reference HolidayCalculator).
- **Tasks 5-9** can run in any order after Tasks 1-2 are complete.
- **Tasks 10-11** are always last.

## Risk Notes

1. **xcodegen** may need project.yml tweaks based on Xcode version (tested with Xcode 14+)
2. **CSV parsing** may have edge cases in coordinate format - verify first 10 segments visually
3. **JSON file size** could be 5-10 MB - minified with `separators=(',', ':')` to reduce size
4. **37K overlays** even with viewport filtering could be heavy - the zoom throttle in Task 5 is critical
5. **HolidayCalculator `lastWeekday`** uses month+1/day=0 trick - verify for December edge case
6. **`findStreetName` change** from sync to async in Task 8 requires updating all callers
