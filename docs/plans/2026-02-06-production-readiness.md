# EasyStreet Production Readiness Plan (Steps 1-5)

> **For Claude:** Read this entire document before starting. Execute tasks using `superpowers:executing-plans` skill. Each task is self-contained with exact files, code snippets, and commit messages. Build and test after every task.

**Goal:** Take the iOS app from functional MVP to App Store submission-ready by fixing data accuracy, adding legal protection, resolving critical code issues, filling test coverage gaps, and creating required App Store assets.

**Reviewed by:** 5-agent review team + 3-agent planning team + 3-agent cross-review (12 findings incorporated, see Appendix A)

---

## Project Context (Read First)

### What This App Does
EasyStreet is a street sweeping parking assistant for San Francisco. It shows an interactive map with color-coded streets (red=sweeping today, orange=tomorrow, yellow=2-3 days, green=safe), lets users mark where they parked, and sends push notifications before street sweeping begins. Data comes from SF Open Data's street sweeping schedule CSV (21,809 street segments, 36,173 sweeping rules).

### Architecture
- **Platform:** iOS 14+ / Swift 5 / UIKit / MapKit
- **Data:** SQLite bundled database (`easystreet.db`), JSON fallback
- **Project generation:** XcodeGen (`project.yml` → `.xcodeproj`)
- **Testing:** XCTest (84 tests across 7 test files, 890 lines)
- **Persistence:** UserDefaults for parked car state
- **Notifications:** UNUserNotificationCenter
- **Singletons:** HolidayCalculator, DatabaseManager, StreetRepository, StreetSweepingDataManager, SweepingRuleEngine

### Build & Test Commands
```bash
# Regenerate Xcode project after adding/removing Swift files (REQUIRED)
cd EasyStreet && xcodegen generate

# Build
xcodebuild -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator build

# Test
xcodebuild test -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Source File Inventory (as of 2026-02-06)

| File | Lines | Key Role |
|------|-------|----------|
| `EasyStreet/Controllers/MapViewController.swift` | 842 | Main UI: map, overlays, parking, search. 5 tasks modify this file (strict ordering required) |
| `EasyStreet/Models/StreetSweepingData.swift` | 416 | SweepingRule, StreetSegment structs, polyline computed property, mapColorStatus, spatial grid index |
| `EasyStreet/Data/StreetRepository.swift` | 257 | SQLite data loading, spatial queries, JSON parsing helpers (private) |
| `EasyStreet/Data/DatabaseManager.swift` | 186 | SQLite wrapper: open/close/query. No thread safety yet. Column accessors |
| `EasyStreet/Models/ParkedCar.swift` | 178 | ParkedCarManager: park/clear/update, UserDefaults persistence, notification scheduling |
| `EasyStreet/Utils/SweepingRuleEngine.swift` | 111 | analyzeSweeperStatus() - core user-facing method, SweepingStatus enum. ZERO test coverage |
| `EasyStreet/Utils/HolidayCalculator.swift` | 90 | 11 SF holidays, isHoliday check, year-based caching. Has Juneteenth (wrong), missing Day-after-Thanksgiving |
| `EasyStreet/Info.plist` | 60 | Has unused NSLocationAlwaysUsageDescription (App Store rejection risk) |
| `EasyStreet/project.yml` | 47 | XcodeGen config: iOS 14.0, libsqlite3.tbd, resources list |
| `EasyStreet/SceneDelegate.swift` | 45 | Calls viewWillAppear(true) directly (anti-pattern) |
| `EasyStreet/AppDelegate.swift` | 26 | Premature notification permission request on launch |
| `.gitignore` | 40 | Missing xcuserdata/, *.db-shm, *.db-wal |

### Data Pipeline Files

| File | Lines | Role |
|------|-------|------|
| `tools/csv_to_json.py` | 105 | CSV → JSON. `hour_to_time()` at lines 41-47 has fractional hours bug |
| `EasyStreet/tools/convert_json_to_sqlite.py` | 172 | JSON → SQLite. No metadata table yet |
| `EasyStreet_Android/tools/csv_to_sqlite.py` | 212 | CSV → SQLite (Android). Same fractional hours bug at lines 143-146 |

### Test Files

| File | Lines | Tests | Coverage Area |
|------|-------|-------|---------------|
| `EasyStreetTests/SweepingRuleEngineTests.swift` | 243 | 22 | Rule application, nextSweeping, computed properties |
| `EasyStreetTests/HitTestingTests.swift` | 203 | 16 | Map hit detection, polyline finding |
| `EasyStreetTests/StreetDetailTests.swift` | 123 | 12 | Detail view, delegate callbacks |
| `EasyStreetTests/SpatialIndexTests.swift` | 104 | 6 | Holiday cache, mapColorStatus with precomputed dates |
| `EasyStreetTests/HolidayCalculatorTests.swift` | 85 | 14 | Holiday detection across years |
| `EasyStreetTests/OverlayPipelineTests.swift` | 80 | 10 | Polyline creation, color encoding |
| `EasyStreetTests/MapColorStatusTests.swift` | 57 | 4 | Color status (date-dependent, unreliable) |

### Database State
- **iOS SQLite:** `EasyStreet/easystreet.db` (8.2 MB, 21,809 segments, 36,173 rules)
- **JSON fallback:** `EasyStreet/sweeping_data_sf.json` (7.4 MB)
- **CSV source:** `EasyStreet/Street_Sweeping_Schedule_20250508.csv` (7.3 MB)
- **No metadata table** in SQLite yet (Task 3 adds it)
- **No Assets.xcassets** directory yet (Task 20 creates it)

### Known Bugs to Fix (This Plan)
1. HolidayCalculator includes Juneteenth (SFMTA enforces sweeping on it), missing Day-after-Thanksgiving
2. No observed-date logic (July 4, 2026 = Saturday, should observe Friday July 3)
3. DatabaseManager has no thread safety (concurrent SQLite access can crash)
4. Polyline computed property creates new MKPolyline on every access (21K allocations)
5. Info.plist has NSLocationAlwaysUsageDescription without usage (App Store rejection)
6. Single notification ID "sweepingReminder" overwrites previous notifications
7. `weeksDescription` crashes on out-of-range week values (0 or >5)
8. SceneDelegate calls viewWillAppear(true) directly (UIKit anti-pattern)
9. ~28 print() statements leak to release builds

---

## Execution Overview

| Phase | Tasks | Estimated Effort | Can Parallelize? |
|-------|-------|-----------------|-----------------|
| **Phase 1: Data Accuracy** | Tasks 1-4 | ~4 hours | Tasks 1, 2 independent; Task 3 needs Task 8 first (R4) |
| **Phase 2: Legal Protection** | Tasks 5-7 | ~2 hours | Task 6 independent; Task 5 after 13-F1 (R2) |
| **Phase 3: Critical Code Fixes** | Tasks 8-13 | ~6 hours | Task 8 FIRST; MVC chain: 13-F1→5→7→9-B3→11 (R2) |
| **Phase 4: Missing Tests** | Tasks 14-19 | ~6 hours | Tasks 14-18 independent; Task 16 needs Task 8 (R3) |
| **Phase 5: App Store Assets** | Tasks 20-21 | ~2 hours | Task 20 independent; Task 21 after all code |

**Total estimated: ~20 hours of implementation work**

---

## Phase 1: Data Accuracy

### Task 1: Fix HolidayCalculator -- Remove Juneteenth, Add Day-After-Thanksgiving, Add Observed-Date Logic

**Severity:** BLOCKER -- incorrect holidays = users get tickets
**Research source:** [SFMTA Holiday Enforcement Schedule](https://www.sfmta.com/getting-around/drive-park/holiday-enforcement-schedule)

**Finding:** SFMTA enforces street sweeping on Juneteenth but suspends it the Day after Thanksgiving. The current `HolidayCalculator` has this backwards.

**Files:**
- Modify: `EasyStreet/Utils/HolidayCalculator.swift`
- Modify: `EasyStreetTests/HolidayCalculatorTests.swift`

**Step 1: Remove Juneteenth from holidays list**

In `EasyStreet/Utils/HolidayCalculator.swift`, in the `holidays(for:)` method, remove the line:
```swift
result.append(makeDate(year: year, month: 6, day: 19))   // Juneteenth
```

**Step 2: Add Day-after-Thanksgiving**

After the Thanksgiving entry, add:
```swift
// Day after Thanksgiving (Friday after 4th Thursday in November)
let thanksgiving = nthWeekday(nth: 4, weekday: 5, month: 11, year: year)
if let dayAfter = Calendar.current.date(byAdding: .day, value: 1, to: thanksgiving) {
    result.append(dayAfter)
}
```

**Step 3: Add observed-date logic for fixed holidays**

When a fixed holiday falls on Saturday, SFMTA observes Friday. When it falls on Sunday, Monday is observed.

Add a new private helper:
```swift
private func observedDate(for date: Date) -> Date {
    let cal = Calendar.current
    let weekday = cal.component(.weekday, from: date)
    switch weekday {
    case 7: return cal.date(byAdding: .day, value: -1, to: date) ?? date // Sat -> Fri
    case 1: return cal.date(byAdding: .day, value: 1, to: date) ?? date  // Sun -> Mon
    default: return date
    }
}
```

Wrap the 4 fixed holiday entries with `observedDate(for:)`:
```swift
result.append(observedDate(for: makeDate(year: year, month: 1, day: 1)))    // New Year's
result.append(observedDate(for: makeDate(year: year, month: 7, day: 4)))    // Independence Day
result.append(observedDate(for: makeDate(year: year, month: 11, day: 11)))  // Veterans Day
result.append(observedDate(for: makeDate(year: year, month: 12, day: 25)))  // Christmas
```

**Step 3b: Replace ALL force unwraps with guard-let** *(Cross-review R1: merged from Task 13-F2)*

Replace all 5 force unwraps in `holidays(for:)` and helpers (`makeDate`, `nthWeekday`) with `guard let` + `Date.distantPast` fallback. Example for `makeDate`:
```swift
private func makeDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year; components.month = month; components.day = day
    guard let date = Calendar.current.date(from: components) else { return Date.distantPast }
    return date
}
```

**Step 3c: Handle cross-year holiday boundary** *(Cross-review R8)*

New Year's 2028 falls on Saturday → observed Dec 31, 2027. The `isHoliday` method must also check the *next* year's holidays for December dates:
```swift
func isHoliday(_ date: Date) -> Bool {
    let cal = Calendar.current
    let year = cal.component(.year, from: date)
    let currentYearHolidays = holidays(for: year)
    if currentYearHolidays.contains(where: { cal.isDate($0, inSameDayAs: date) }) { return true }
    // Check if next year's New Year's is observed in this year's December
    let month = cal.component(.month, from: date)
    if month == 12 {
        let nextYearHolidays = holidays(for: year + 1)
        return nextYearHolidays.contains(where: { cal.isDate($0, inSameDayAs: date) })
    }
    return false
}
```

**Step 4: Update tests**

In `EasyStreetTests/HolidayCalculatorTests.swift`:
- Remove `testJuneteenth()`
- Add `testJuneteenthIsNotHoliday()` asserting `false` for June 19
- Add `testDayAfterThanksgiving2026()` -- Nov 27, 2026
- Add `testDayAfterThanksgiving2025()` -- Nov 28, 2025
- Add `testIndependenceDayOnSaturdayObservedFriday()` -- July 4, 2026 is Saturday, observed July 3
- Add `testChristmasOnSundayObservedMonday()` -- Dec 25, 2022 is Sunday, observed Dec 26
- Add `testVeteransDayOnSaturdayObservedFriday()` -- Nov 11, 2028 is Saturday, observed Nov 10
- Add `testCrossYearBoundary2028()` -- New Year's 2028 on Saturday → observed Dec 31, 2027 *(Cross-review R8)*
- Add `testChristmas2027OnSaturdayObservedFriday()` -- Dec 25, 2027 → observed Dec 24
- **Update existing `testIndependenceDay()` test** *(Cross-review R6)*: July 4, 2026 is Saturday, so the existing test asserting July 4 as a holiday will fail. Update it to assert July 3 (the observed Friday) is a holiday AND that July 4 itself is NOT a holiday in the observed-date list

**Step 5: Build and test**
```bash
cd EasyStreet && xcodegen generate
xcodebuild test -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -20
```

**Step 6: Commit**
```
fix(ios): correct holiday list -- remove Juneteenth, add Day-after-Thanksgiving, add observed-date logic

SFMTA enforces street sweeping on Juneteenth but suspends it the day after
Thanksgiving. Fixed holidays falling on weekends now use the observed date
(Saturday -> Friday, Sunday -> Monday) per SFMTA convention.
```

---

### Task 2: Fix Fractional Hours Bug in CSV Conversion Scripts

**Severity:** HIGH -- proactive fix for future data updates
**Note:** Current CSV data has no fractional hours (confirmed), but the bug should be fixed defensively.

**Files:**
- Modify: `tools/csv_to_json.py` (lines 41-47, `hour_to_time`)
- Modify: `EasyStreet_Android/tools/csv_to_sqlite.py` (lines 143-146)

**Step 1: Fix iOS conversion script**

In `tools/csv_to_json.py`, replace `hour_to_time`:
```python
def hour_to_time(hour_val):
    """Convert hour value (possibly fractional, e.g. 7.5) to 'HH:MM' string."""
    try:
        fval = float(hour_val)
        h = int(fval)
        m = int(round((fval - h) * 60))
        return f"{h:02d}:{m:02d}"
    except (ValueError, TypeError):
        return "00:00"
```

**Step 2: Fix Android conversion script**

In `EasyStreet_Android/tools/csv_to_sqlite.py`, replace the inline time conversion (lines 143-146):
```python
from_hour_val = float(row['FromHour'].strip())
to_hour_val = float(row['ToHour'].strip())
from_h, from_m = int(from_hour_val), int(round((from_hour_val - int(from_hour_val)) * 60))
to_h, to_m = int(to_hour_val), int(round((to_hour_val - int(to_hour_val)) * 60))
start_time = f"{from_h:02d}:{from_m:02d}"
end_time = f"{to_h:02d}:{to_m:02d}"
```

**Step 3: Verify scripts run correctly**
```bash
python3 tools/csv_to_json.py
```

**Step 4: Commit**
```
fix(tools): handle fractional hours in CSV conversion (e.g. 7.5 -> 07:30)
```

---

### Task 3: Add Data Version Metadata to SQLite Database

**Severity:** MEDIUM -- needed for data freshness tracking

**Files:**
- Modify: `EasyStreet/tools/convert_json_to_sqlite.py` (add metadata table)
- Modify: `EasyStreet/Data/DatabaseManager.swift` (add metadata query helper)
- Modify: `EasyStreet/Data/StreetRepository.swift` (expose metadata)

**Step 1: Add metadata table to conversion script**

In `EasyStreet/tools/convert_json_to_sqlite.py`, add to schema:
```sql
CREATE TABLE IF NOT EXISTS metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
```

After data insertion, insert metadata rows:
```python
import datetime
conn.execute("INSERT INTO metadata (key, value) VALUES (?, ?)",
             ("csv_source", "Street_Sweeping_Schedule_20250508.csv"))
conn.execute("INSERT INTO metadata (key, value) VALUES (?, ?)",
             ("build_date", datetime.datetime.utcnow().isoformat() + "Z"))
conn.execute("INSERT INTO metadata (key, value) VALUES (?, ?)",
             ("segment_count", str(segment_count)))
conn.execute("INSERT INTO metadata (key, value) VALUES (?, ?)",
             ("schema_version", "2"))
conn.commit()
```

**Step 2: Add metadata query to DatabaseManager**

In `DatabaseManager.swift`, add after the column accessor methods. **Important** *(Cross-review R4)*: The `db != nil` check has a data race if called off the main thread. Wrap the entire method in `dbQueue.sync` (added in Task 8):
```swift
func metadataValue(for key: String) -> String? {
    return dbQueue.sync {
        guard db != nil else { return nil }
        var result: String?
        try? query("SELECT value FROM metadata WHERE key = ?", parameters: [key]) { stmt in
            result = DatabaseManager.string(from: stmt, column: 0)
        }
        return result
    }
}
```
**Dependency note:** Task 8 (thread safety) MUST be completed before Task 3 so that `dbQueue` exists.

**Step 3: Expose metadata in StreetRepository**

Add properties to `StreetRepository`:
```swift
private(set) var dataSourceInfo: String?
private(set) var dataBuildDate: String?
```

In `loadData()`, after SQLite opens successfully:
```swift
dataSourceInfo = DatabaseManager.shared.metadataValue(for: "csv_source")
dataBuildDate = DatabaseManager.shared.metadataValue(for: "build_date")
```

**Step 4: Rebuild the database**
```bash
python3 EasyStreet/tools/convert_json_to_sqlite.py EasyStreet/sweeping_data_sf.json EasyStreet/easystreet.db
sqlite3 EasyStreet/easystreet.db "SELECT * FROM metadata;"
```

**Step 5: Build and test**
```bash
cd EasyStreet && xcodegen generate
xcodebuild test -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -20
```

**Step 6: Commit**
```
feat(data): add metadata table to SQLite with source CSV, build date, schema version
```

---

### Task 4: Re-download Latest CSV and Rebuild Data Pipeline

**Severity:** HIGH -- close the gap between May 2025 CSV and launch date
**Note:** If DataSF is down, skip this -- May 2025 data is still usable.

**Step 1: Download latest CSV**
```bash
curl -L "https://data.sfgov.org/api/views/yhqp-riqs/rows.csv?accessType=DOWNLOAD" \
    -o EasyStreet/Street_Sweeping_Schedule_latest.csv
```

**Step 2: Compare headers with existing CSV**
```bash
diff <(head -1 EasyStreet/Street_Sweeping_Schedule_20250508.csv) \
     <(head -1 EasyStreet/Street_Sweeping_Schedule_latest.csv)
```
If headers differ, STOP and investigate schema changes.

**Step 3: Run the full pipeline**
```bash
DATE=$(date +%Y%m%d)
mv EasyStreet/Street_Sweeping_Schedule_latest.csv EasyStreet/Street_Sweeping_Schedule_${DATE}.csv
python3 tools/csv_to_json.py EasyStreet/Street_Sweeping_Schedule_${DATE}.csv EasyStreet/sweeping_data_sf.json
python3 EasyStreet/tools/convert_json_to_sqlite.py EasyStreet/sweeping_data_sf.json EasyStreet/easystreet.db
```

**Step 4: Verify**
```bash
sqlite3 EasyStreet/easystreet.db "SELECT COUNT(*) FROM street_segments; SELECT COUNT(*) FROM sweeping_rules; SELECT * FROM metadata;"
```

**Step 5: Build, test, commit**
```
data(ios): rebuild street sweeping data from latest SF Open Data CSV
```

---

## Phase 2: Legal Protection

### Task 5: Add In-App Disclaimer (First Launch + Info Button)

**Severity:** HIGH -- legal protection against liability

**Files:**
- Create: `EasyStreet/Utils/DisclaimerManager.swift`
- Modify: `EasyStreet/Controllers/MapViewController.swift`

**Step 1: Create DisclaimerManager**

Create `EasyStreet/Utils/DisclaimerManager.swift`:
```swift
import Foundation

struct DisclaimerManager {
    private static let hasSeenDisclaimerKey = "hasSeenDisclaimer_v1"

    static var hasSeenDisclaimer: Bool {
        UserDefaults.standard.bool(forKey: hasSeenDisclaimerKey)
    }

    static func markDisclaimerSeen() {
        UserDefaults.standard.set(true, forKey: hasSeenDisclaimerKey)
    }

    static let disclaimerTitle = "Important Notice"

    static let disclaimerBody = """
    EasyStreet provides street sweeping schedule information based on data \
    from the City of San Francisco's open data portal. This information is \
    provided for convenience only and may not reflect the most current schedules.

    Always check posted street signs for the official sweeping schedule at \
    your parking location. EasyStreet is not responsible for parking tickets \
    or towing resulting from reliance on information displayed in this app.
    """

    static let attributionText = "Data: City of San Francisco (data.sfgov.org)"
}
```

**Step 2: Show disclaimer on first launch and add info button**

In `MapViewController.swift`, at the end of `viewDidLoad()`:
```swift
if !DisclaimerManager.hasSeenDisclaimer {
    showDisclaimer(isFirstLaunch: true)
}
```

Add nav bar info button:
```swift
navigationItem.leftBarButtonItem = UIBarButtonItem(
    image: UIImage(systemName: "info.circle"),
    style: .plain, target: self, action: #selector(infoTapped)
)
```

Add handler methods:
```swift
@objc private func infoTapped() {
    showDisclaimer(isFirstLaunch: false)
}

private func showDisclaimer(isFirstLaunch: Bool) {
    let alert = UIAlertController(
        title: DisclaimerManager.disclaimerTitle,
        message: DisclaimerManager.disclaimerBody,
        preferredStyle: .alert
    )
    if isFirstLaunch {
        alert.addAction(UIAlertAction(title: "I Understand", style: .default) { _ in
            DisclaimerManager.markDisclaimerSeen()
        })
    } else {
        alert.addAction(UIAlertAction(title: "OK", style: .default))
    }
    present(alert, animated: true)
}
```

**Step 3: Regenerate Xcode project** *(Cross-review R10: new Swift file requires xcodegen)*
```bash
cd EasyStreet && xcodegen generate
```

**Step 4: Build, commit**
```
feat(ios): add first-launch disclaimer and info button for legal protection
```

---

### Task 6: Create Privacy Policy

**Severity:** BLOCKER -- Apple rejects apps without a privacy policy URL

**Files:**
- Create: `docs/privacy-policy.md`

Create `docs/privacy-policy.md` covering:
- Location data collected (when-in-use only, stored locally)
- Notification preferences stored locally
- No analytics, no tracking, no server communication
- No personal identifiers collected
- Data sourced from SF Open Data (PDDL license)
- Contact information

This file will be hosted via GitHub Pages. The URL goes into App Store Connect metadata.

**Commit:**
```
docs: add privacy policy for App Store submission
```

---

### Task 7: Add Attribution Label to Map View

**Severity:** LOW -- good practice under PDDL, not legally required

**Files:**
- Modify: `EasyStreet/Controllers/MapViewController.swift`

Add a small `UILabel` at the bottom of the map view with `DisclaimerManager.attributionText` in 9pt secondary color.

**Commit:**
```
feat(ios): add SF Open Data attribution label on map view
```

---

## Phase 3: Critical Code Fixes

### Task 8: Thread Safety in DatabaseManager

**Severity:** HIGH -- potential crash from concurrent SQLite access

**Files:**
- Modify: `EasyStreet/Data/DatabaseManager.swift`

Add a private serial dispatch queue and wrap `open()`, `close()`, and `query()` in `dbQueue.sync { }`:

```swift
private let dbQueue = DispatchQueue(label: "com.easystreet.databasemanager", qos: .userInitiated)
```

Wrap all three public methods in `dbQueue.sync` blocks to serialize all SQLite operations.

**Commit:**
```
fix(ios): add serial dispatch queue to DatabaseManager for thread safety
```

---

### Task 9: Memory and Performance Optimization

**Severity:** HIGH -- affects 21K segment rendering

**Files:**
- Modify: `EasyStreet/Models/StreetSweepingData.swift` (polyline caching)
- Modify: `EasyStreet/Data/StreetRepository.swift` (coordinate parse caching)
- Modify: `EasyStreet/Controllers/MapViewController.swift` (colorCache optimization)

**B1: Cache MKPolyline on StreetSegment** *(Cross-review R11: must be thread-safe)*

Replace the computed `polyline` property with a thread-safe static cache using `NSLock`:
```swift
private static var polylineCache: [String: MKPolyline] = [:]
private static let polylineCacheLock = NSLock()

var polyline: MKPolyline {
    StreetSegment.polylineCacheLock.lock()
    defer { StreetSegment.polylineCacheLock.unlock() }
    if let cached = StreetSegment.polylineCache[id] { return cached }
    let points = coordinates.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
    let pl = MKPolyline(coordinates: points, count: points.count)
    StreetSegment.polylineCache[id] = pl
    return pl
}

/// Clear polyline cache (used by tests for isolation)
static func clearPolylineCache() {
    polylineCacheLock.lock()
    defer { polylineCacheLock.unlock() }
    polylineCache.removeAll()
}
```

**WARNING** *(Cross-review R12)*: Existing `OverlayPipelineTests` use a shared segment ID "test" which will collide with the static cache. Add `StreetSegment.clearPolylineCache()` to `setUp()` in `OverlayPipelineTests.swift`.

**B2: Cache parsed coordinates in StreetRepository**

Add `private var coordinateCache: [String: [[Double]]] = [:]` and check it before calling `parseCoordinatesJSON()`.

**B3: Day-based colorCache invalidation**

Replace `colorCache.removeAll()` on every map move with day-based invalidation:
```swift
private var colorCacheDay: Int = -1

// In updateMapOverlays():
let currentDay = cal.ordinality(of: .day, in: .year, for: today) ?? 0
if currentDay != colorCacheDay {
    colorCache.removeAll(keepingCapacity: true)
    colorCacheDay = currentDay
}
for segment in visibleSegments where colorCache[segment.id] == nil {
    colorCache[segment.id] = segment.mapColorStatus(today: today, upcomingDates: upcomingDates)
}
```

**Commit:**
```
perf(ios): cache polylines, parsed coordinates, and color status to reduce allocation churn
```

---

### Task 10: Info.plist Cleanup

**Severity:** HIGH -- `NSLocationAlwaysUsageDescription` without usage risks rejection

**Files:**
- Modify: `EasyStreet/Info.plist`

**Changes:**
1. **Remove** `NSLocationAlwaysAndWhenInUseUsageDescription` and `NSLocationAlwaysUsageDescription` (app only uses When-In-Use)
2. **Remove** `NSUserNotificationsUsageDescription` (not a valid iOS key)
3. **Change** `UIRequiredDeviceCapabilities` from `armv7` to `arm64`

**Verify:** `plutil -lint EasyStreet/Info.plist`

**Commit:**
```
fix(ios): clean Info.plist -- remove unused location/notification keys, update capabilities to arm64
```

---

### Task 11: Debug Logging Cleanup

**Severity:** MEDIUM -- console spam in release builds

**Files:**
- Modify: `EasyStreet/Controllers/MapViewController.swift` (~9 print calls)
- Modify: `EasyStreet/Data/StreetRepository.swift` (~8 print calls)
- Modify: `EasyStreet/Data/DatabaseManager.swift` (~3 print calls)
- Modify: `EasyStreet/Models/ParkedCar.swift` (~3 print calls)
- Modify: `EasyStreet/Models/StreetSweepingData.swift` (~3 print calls)

Wrap all `print()` calls outside existing `#if DEBUG` blocks with `#if DEBUG ... #endif`. For consecutive prints, use a single block.

**Commit:**
```
chore(ios): wrap ~28 debug print statements in #if DEBUG for release builds
```

---

### Task 12: Notification Fixes

**Severity:** MEDIUM -- premature permission request + single notification ID

**Files:**
- Modify: `EasyStreet/AppDelegate.swift`
- Modify: `EasyStreet/Models/ParkedCar.swift`

**E1: Remove premature notification request from AppDelegate**

Remove the `UNUserNotificationCenter.current().requestAuthorization` call from `AppDelegate.swift` (and the `import UserNotifications`). Permission is already requested contextually in `ParkedCarManager.scheduleNotification()`.

**E2: Fix notification ID collision**

Replace the single `"sweepingReminder"` identifier with unique IDs per sweeping event:
```swift
private struct NotificationIDs {
    static let sweepingReminderPrefix = "sweepingReminder_"
}
private var scheduledNotificationIDs: [String] = []
```

Generate unique IDs using timestamp: `"\(prefix)\(Int(sweepingTime.timeIntervalSince1970))"`. Track scheduled IDs for proper cancellation in `clearParkedCar()`.

**E3: Deduplicate before scheduling** *(Cross-review R5)*

Before scheduling a new notification, remove any pending notifications with the same sweeping time to prevent duplicates when the user re-parks or the app re-evaluates:
```swift
// In scheduleNotification(), before adding new request:
let existingIDs = scheduledNotificationIDs.filter { $0.hasPrefix(NotificationIDs.sweepingReminderPrefix) }
UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: existingIDs)
scheduledNotificationIDs.removeAll()
```

**Commit:**
```
fix(ios): remove premature notification request, use unique notification IDs per sweeping event
```

---

### Task 13: Code Quality Fixes

**Severity:** MEDIUM -- anti-patterns and crash risks

**Files:**
- Modify: `EasyStreet/SceneDelegate.swift`
- Modify: `EasyStreet/Controllers/MapViewController.swift`
- Modify: `EasyStreet/Utils/HolidayCalculator.swift`
- Modify: `EasyStreet/Utils/SweepingRuleEngine.swift`
- Modify: `.gitignore`

**F1: Fix SceneDelegate calling viewWillAppear directly**

Extract refresh logic into a public `refreshMapDisplay()` method on MapViewController. Call that from SceneDelegate instead of `viewWillAppear(true)`.

**F2: ~~Replace force unwraps in HolidayCalculator~~ MERGED INTO TASK 1** *(Cross-review R1)*

HolidayCalculator force unwraps are now fixed as part of Task 1 Step 3b. Only the `SweepingRuleEngine.swift` force unwrap remains here -- fix the force unwrap at line ~47-50 with a guard that returns `.unknown`.

**F2b: Guard `weeksDescription` against out-of-range values** *(Cross-review R9)*

In `StreetSweepingData.swift`, `weeksDescription` uses `ordinals[$0 - 1]` which crashes if `$0 == 0` or `$0 > 5`. Add a bounds check:
```swift
var weeksDescription: String {
    let ordinals = ["1st", "2nd", "3rd", "4th", "5th"]
    return weeksOfMonth.compactMap { week in
        guard week >= 1, week <= ordinals.count else { return nil }
        return ordinals[week - 1]
    }.joined(separator: ", ") + " week" + (weeksOfMonth.count > 1 ? "s" : "")
}
```

**F3: Update .gitignore**

Add:
```
EasyStreet/EasyStreet.xcodeproj/xcuserdata/
xcuserdata/
*.db-shm
*.db-wal
*.db-journal
```

Run `git rm --cached` on any already-tracked files matching these patterns.

**Commit:**
```
fix(ios): fix SceneDelegate lifecycle anti-pattern, remove force unwraps, update gitignore
```

---

## Phase 4: Missing Tests

### Task 14: SweepingRuleEngine Status Tests

**Severity:** CRITICAL -- the core user-facing method has ZERO tests

**Files:**
- Create: `EasyStreetTests/SweepingRuleEngineStatusTests.swift`
- Modify: `EasyStreet/Utils/SweepingRuleEngine.swift` (extract testable method)

**Refactoring:** Extract the body of `analyzeSweeperStatus` into a new `internal` method:
```swift
func determineStatus(for segment: StreetSegment?, at now: Date) -> SweepingStatus
```

**Test methods (10 tests):**

| Test | Scenario | Expected |
|------|----------|----------|
| `testNoSegmentReturnsNoData` | nil segment | `.noData` |
| `testSweepingAlreadyPassedReturnsSafe` | Today's sweep at 06:00, now is 14:00 | `.safe` |
| `testSweepingMoreThanOneHourAwayReturnsToday` | Sweep at 18:00, now 14:00 | `.today` |
| `testSweepingLessThanOneHourAwayReturnsImminent` | Sweep at 14:30, now 14:00 | `.imminent` |
| `testSweepingExactlyOneHourAwayReturnsToday` | Sweep at 15:00, now 14:00 | `.today` |
| `testSweepingJustUnderOneHourReturnsImminent` | Sweep at 14:59, now 14:00 | `.imminent` |
| `testMalformedStartTimeReturnsUnknown` | startTime: "bad" | `.unknown` |
| `testNoSweeperTodayWithUpcomingReturnsUpcoming` | Rule for different day | `.upcoming` |
| `testNoSweeperTodayNoUpcomingReturnsSafe` | Empty rules | `.safe` |
| `testNoMatchingRuleReturnsSafe` | Defensive branch | `.safe` |

**Pre-step: Regenerate Xcode project** *(Cross-review R10)*
```bash
cd EasyStreet && xcodegen generate
```

**Commit:**
```
test(ios): add 10 tests for SweepingRuleEngine status determination
```

---

### Task 15: ParkedCarManager Tests

**Severity:** HIGH -- persistence and notification scheduling untested

**Files:**
- Create: `EasyStreetTests/ParkedCarManagerTests.swift`
- Modify: `EasyStreet/Models/ParkedCar.swift` (add injectable init)

**Refactoring:** Add `init(defaults: UserDefaults)` to ParkedCarManager for test isolation.

**Test methods (14 tests):**

| Test | Scenario |
|------|----------|
| `testIsCarParkedFalseInitially` | Fresh defaults |
| `testParkCarSetsIsCarParkedTrue` | After parking |
| `testParkCarSavesCoordinates` | Lat/lng round-trip |
| `testParkCarSavesStreetName` | Street name persistence |
| `testParkCarSavesTimestamp` | Time recorded |
| `testParkCarWithoutStreetName` | nil street name |
| `testClearParkedCarRemovesAll` | Full cleanup |
| `testUpdateParkedLocationChanges` | Pin moved |
| `testUpdateParkedLocationNoop` | No car parked |
| `testNotificationLeadMinutesDefault` | 60 minutes |
| `testNotificationLeadMinutesPersists` | Custom value |
| `testParkCarPostsNotification` | NSNotification posted |
| `testClearParkedCarPostsNotification` | NSNotification posted |
| `testUpdateLocationPostsNotification` | NSNotification posted |

Uses `UserDefaults(suiteName: "ParkedCarManagerTests")` for isolation with cleanup in `setUp`/`tearDown`.

**Pre-step: Regenerate Xcode project** *(Cross-review R10)*
```bash
cd EasyStreet && xcodegen generate
```

**Commit:**
```
test(ios): add 14 tests for ParkedCarManager persistence and notifications
```

---

### Task 16: DatabaseManager Tests

**Severity:** HIGH -- entire SQLite layer untested

**Files:**
- Create: `EasyStreetTests/DatabaseManagerTests.swift`
- Modify: `EasyStreet/Data/DatabaseManager.swift` (add `open(at:)` and `internal init`)

**Refactoring:** Add `func open(at path: String) throws` for test databases. Make `init()` internal.

**IMPORTANT** *(Cross-review R3)*: The `open(at:)` method must use `SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE` flags (not readonly), and all operations must go through `dbQueue.sync` (from Task 8). In-memory databases (`:memory:`) also need these flags.

**Test methods (15 tests):**

| Test | Scenario |
|------|----------|
| `testOpenInMemorySucceeds` | `:memory:` database |
| `testQueryOnClosedDatabaseThrows` | No open() called |
| `testOpenTwiceDoesNotThrow` | Idempotent open |
| `testCloseAndReopenWorks` | Lifecycle |
| `testSimpleSelectQuery` | CREATE + INSERT + SELECT |
| `testParameterBindingString` | WHERE name = ? |
| `testParameterBindingInt` | WHERE id = ? |
| `testParameterBindingDouble` | WHERE val = ? |
| `testUnsupportedParameterTypeThrows` | Bool parameter |
| `testInvalidSQLThrows` | Syntax error |
| `testColumnAccessorString` | string(from:column:) |
| `testColumnAccessorInt` | int(from:column:) |
| `testColumnAccessorDouble` | double(from:column:) |
| `testNullColumnReturnsEmpty` | NULL text -> "" |
| `testMultipleRowsIterated` | 5 rows, 5 callbacks |

Uses in-memory SQLite (`:memory:`) for all tests.

**Pre-step: Regenerate Xcode project** *(Cross-review R10)*
```bash
cd EasyStreet && xcodegen generate
```

**Commit:**
```
test(ios): add 15 tests for DatabaseManager SQLite operations
```

---

### Task 17: StreetRepository Parsing Tests

**Severity:** MEDIUM -- coordinate/weeks JSON parsing untested

**Files:**
- Create: `EasyStreetTests/StreetRepositoryTests.swift`
- Modify: `EasyStreet/Data/StreetRepository.swift` (change `private` to `internal` on parsing methods)

**Refactoring:** Change `private func parseCoordinatesJSON` and `private func parseWeeksJSON` to `func` (internal access).

**Test methods (14 tests):**

| Test | Input | Expected |
|------|-------|----------|
| `testParseCoordinatesValid` | `"[[37.78,-122.41]]"` | 1 coordinate |
| `testParseCoordinatesEmpty` | `"[]"` | empty |
| `testParseCoordinatesEmptyString` | `""` | empty |
| `testParseCoordinatesInvalidJSON` | `"not json"` | empty |
| `testParseCoordinatesWrongType` | `"[1,2,3]"` | empty |
| `testParseCoordinatesSingle` | `"[[37.78,-122.41]]"` | 1 item |
| `testParseCoordinatesMalformedInner` | `"[[37.78]]"` | 1 item (1 element) |
| `testParseWeeksValid` | `"[1,3]"` | [1,3] |
| `testParseWeeksEmpty` | `"[]"` | empty |
| `testParseWeeksEmptyString` | `""` | empty |
| `testParseWeeksInvalidJSON` | `"bad"` | empty |
| `testParseWeeksAllFive` | `"[1,2,3,4,5]"` | [1,2,3,4,5] |
| `testParseWeeksNegative` | `"[-1,0,6]"` | [-1,0,6] (no validation) |
| `testParseWeeksStringArray` | `'["a","b"]'` | empty |

**Pre-step: Regenerate Xcode project** *(Cross-review R10)*
```bash
cd EasyStreet && xcodegen generate
```

**Commit:**
```
test(ios): add 14 tests for StreetRepository JSON parsing edge cases
```

---

### Task 18: Fix Conditional MapColorStatus Tests

**Severity:** MEDIUM -- existing tests silently pass without asserting

**Files:**
- Modify: `EasyStreetTests/MapColorStatusTests.swift`

Replace all 4 tests with deterministic versions using `mapColorStatus(today:upcomingDates:)` with fixed dates (March 2, 2026 = Monday). Add 4 new tests:

| Test | Scenario |
|------|----------|
| `testRedWhenSweepingToday` | Rule for Monday, ref=Monday |
| `testGreenWhenNoSweepingSoon` | Rule for Saturday, ref=Monday |
| `testOrangeWhenSweepingTomorrow` | Rule for Tuesday, ref=Monday |
| `testYellowWhenSweepingIn2Days` | Rule for Wednesday, ref=Monday |
| `testYellowWhenSweepingIn3Days` | Rule for Thursday, ref=Monday |
| `testRedPrecedenceOverOrange` | Rules for Mon+Tue |
| `testOrangePrecedenceOverYellow` | Rules for Tue+Wed |
| `testWeekOfMonthRestriction` | Rule for week 2, ref=week 1 -> green |

**Commit:**
```
test(ios): replace date-dependent MapColorStatus tests with deterministic fixed-date versions
```

---

### Task 19: Edge Case Tests for Data Models

**Severity:** MEDIUM -- out-of-range values could crash

**Files:**
- Modify: `EasyStreetTests/SweepingRuleEngineTests.swift`

Add 11 edge case tests:

| Test | Scenario | Risk |
|------|----------|------|
| `testWeeksOfMonthWithZero` | weeksOfMonth: [0] | Never matches |
| `testWeeksOfMonthWithFive` | weeksOfMonth: [5] | 5th week exists rarely |
| `testWeeksOfMonthWithSix` | weeksOfMonth: [6] | Never matches |
| `testDayOfWeekZero` | dayOfWeek: 0 | `dayName` crash risk |
| `testDayOfWeekEight` | dayOfWeek: 8 | `dayName` crash risk |
| `testMalformedStartTime` | startTime: "25:00" | Fallback format |
| `testEmptyTimeStrings` | startTime: "" | Fallback |
| `testNextSweepingMalformedTime` | bad startTime | Returns nil |
| `testNextSweepingNoRules` | empty rules | (nil, nil) |
| `testWeeksDescriptionWeekFive` | [5] | "5th weeks" |
| `testWeeksDescriptionWeekSix` | [6] | Crash risk - document |

**Commit:**
```
test(ios): add 11 edge case tests for out-of-range and malformed data
```

---

## Phase 5: App Store Assets

### Task 20: App Icon Asset Catalog Setup

**Severity:** BLOCKER -- Apple auto-rejects without an icon

**Files:**
- Create: `EasyStreet/Assets.xcassets/Contents.json`
- Create: `EasyStreet/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Modify: `EasyStreet/project.yml` (add Assets.xcassets to resources, add ASSETCATALOG_COMPILER_APPICON_NAME)

Create the directory structure and Contents.json files declaring all required icon sizes for iOS 14+. The actual 1024x1024 PNG icon design is a **manual creative task** -- the catalog scaffold enables it.

Required sizes: 40x40, 60x60, 58x58, 87x87, 80x80, 120x120, 180x180, 1024x1024.

**Commit:**
```
chore(ios): add AppIcon asset catalog scaffold for App Store submission
```

---

### Task 21: Screenshot Capture Process

**Severity:** HIGH -- required for App Store listing

**Required sizes:** iPhone 15 Pro Max (6.7"), iPhone 11 Pro Max (6.5"), iPhone 8 Plus (5.5")

**5 recommended screenshots:**
1. Map overview with color-coded streets and legend
2. Street detail bottom sheet with sweeping schedule
3. Car parked with status card showing "Safe"
4. Notification lead time settings action sheet
5. Search result with address pinned

**Capture workflow:**
```bash
xcrun simctl boot "iPhone 15 Pro Max"
xcrun simctl status_bar "iPhone 15 Pro Max" override --time "9:41" --batteryState charged --batteryLevel 100
xcrun simctl location "iPhone 15 Pro Max" set 37.7749,-122.4194
# Navigate to desired state, then:
xcrun simctl io "iPhone 15 Pro Max" screenshot screenshot_N.png
```

---

## Task Dependency Graph

*(Updated with cross-review findings R2, R3, R4, R7)*

```
Phase 1 (Data):
  Task 1 (Holidays + force unwraps) ──┐
  Task 2 (Fractional hrs) ────────────┤
                                      │
  Task 8 (Thread safety) ─────────────┤──> Task 3 (Metadata) ──> Task 4 (Rebuild)
                                      │         (R4: needs dbQueue from Task 8)
Phase 2 (Legal):                      │
  Task 6 (Privacy policy)             │    (independent, no code)
                                      │
Phase 3 (Code):                       │
  Task 8  (Thread safety)             │    FIRST (required by Tasks 3, 9, 16)
  Task 10 (Info.plist)                │    (independent)
  Task 12 (Notifications)             │    (independent)
                                      │
  ┌── MapViewController.swift ordering (R2, R7): ──┐
  │ Task 13-F1 (SceneDelegate)                     │
  │   └──> Task 5 (Disclaimer + info button)       │
  │          └──> Task 7 (Attribution label)        │
  │                └──> Task 9-B3 (colorCache)      │
  │                       └──> Task 11 (Debug log)  │  ← ABSOLUTE LAST per R7
  └────────────────────────────────────────────────┘
  Task 9-B1/B2 (polyline + coord cache)   (after Task 8, independent of MVC chain)
  Task 13-F2b (weeksDescription guard)     (independent)
  Task 13-F3 (.gitignore)                 (independent)

Phase 4 (Tests):
  Task 14 (Engine status)  ──┐
  Task 15 (ParkedCar)        │   (all independent of each other)
  Task 16 (DatabaseManager)  │   (R3: needs dbQueue from Task 8)
  Task 17 (Repository)       │
  Task 18 (Color status)     │
  Task 19 (Edge cases) ──────┘──> Final test run

Phase 5 (Assets):
  Task 20 (Icon catalog)       (independent)
  Task 21 (Screenshots) ──────> (after all code changes)
```

**Critical ordering constraints:**
1. **Task 8 must complete before** Tasks 3, 9-B1, 16 (all need `dbQueue` or thread-safe patterns)
2. **MapViewController.swift** has strict sequential ordering: 13-F1 → 5 → 7 → 9-B3 → 11
3. **Task 11 (debug logging) must be absolute last** to touch each file it modifies (R7)
4. **Task 1 now includes force-unwrap fixes** (merged from Task 13-F2), so Task 13 no longer modifies HolidayCalculator.swift

**Revised parallel execution with 3 agents:**
- Agent A: Tasks 8, 3, 4, 13-F1, 5, 7, 9-B3, 11 *(owns MapViewController.swift chain + thread safety)*
- Agent B: Tasks 1, 2, 9-B1/B2, 12, 14, 15 *(owns HolidayCalculator + data + tests)*
- Agent C: Tasks 6, 10, 13-F2b/F3, 16, 17, 18, 19, 20 *(owns tests + assets + independent fixes)*
- **Screenshots (Task 21)** run after all agents complete

---

## Risk Notes

1. ~~**HolidayCalculator cross-year edge case**~~ **RESOLVED** in Task 1 Step 3c *(Cross-review R8)*

2. **Privacy policy hosting:** If the GitHub repo is private, GitHub Pages won't work. Consider Netlify, Vercel, or a simple static host.

3. **CSV download may fail:** Task 4 depends on DataSF being up. If it fails, the May 2025 data is acceptable for launch.

4. ~~**Thread safety + performance interaction**~~ **RESOLVED** -- polylineCache now uses NSLock (R11), metadataValue wraps in dbQueue.sync (R4), open(at:) uses correct flags (R3).

5. ~~**`weeksDescription` crash**~~ **RESOLVED** in Task 13-F2b *(Cross-review R9)*

6. **OverlayPipelineTests regression:** polylineCache (Task 9-B1) uses static state that persists across tests. `setUp()` must call `StreetSegment.clearPolylineCache()` *(Cross-review R12)*.

7. **Existing test breakage:** `testIndependenceDay` will fail after Task 1 because July 4, 2026 is Saturday → observed July 3. Must update the test as part of Task 1 Step 4 *(Cross-review R6)*.

---

## Appendix A: Cross-Review Findings (R1-R12)

All 12 cross-review findings have been incorporated into the plan above:

| ID | Finding | Resolution |
|----|---------|------------|
| R1 | Task 1 + Task 13-F2 both modify HolidayCalculator.swift | Merged: Task 1 now includes guard-let fixes (Step 3b) |
| R2 | 5 tasks collide on MapViewController.swift | Strict ordering defined: 13-F1 → 5 → 7 → 9-B3 → 11 |
| R3 | Task 16's `open(at:)` uses wrong SQLite flags | Updated Task 16 to use READWRITE \| CREATE + dbQueue.sync |
| R4 | Task 3's metadataValue has data race | Wrapped in dbQueue.sync, Task 8 now prerequisite for Task 3 |
| R5 | Task 12 introduces notification duplication | Added Step E3: dedup before scheduling |
| R6 | Task 1 breaks existing testIndependenceDay | Added explicit test update in Task 1 Step 4 |
| R7 | Task 11 must be absolute last per file | Enforced in dependency graph and agent assignment |
| R8 | No task fixes cross-year holiday boundary | Added Task 1 Step 3c with December boundary check |
| R9 | No task fixes weeksDescription crash | Added Task 13-F2b with bounds guard |
| R10 | Missing xcodegen in Tasks 5, 14-17 | Added xcodegen generate step to each |
| R11 | polylineCache is static and not thread-safe | Changed to NSLock-protected in Task 9-B1 |
| R12 | OverlayPipelineTests break from polyline cache | Added clearPolylineCache() + setUp() call |
