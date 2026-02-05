# EasyStreet Development Timeline

**Purpose**: Detailed chronological record of all development activities, code changes, and technical decisions. Each entry should provide enough context for developers to understand what was done and make retroactive changes if needed.

---

## 2026-02-04 - Sprint 1 Planning Session

**Session Type**: Planning & Code Review
**Duration**: ~1 hour
**Participants**: Claude Code (AI Assistant)
**Commits**: None (planning only, no code changes)

### Objectives
- Conduct comprehensive review of iOS and Android codebases
- Analyze project requirements and current status
- Develop first 2-week sprint plan for 2 developers

### Code Analysis Performed

#### iOS Codebase Review
**Status**: ~80% MVP Complete with Critical Blockers

**Files Analyzed**:
1. **[StreetSweepingData.swift](EasyStreet/Models/StreetSweepingData.swift)** (300 lines)
   - Contains data models: `SweepingRule` (struct), `StreetSegment` (struct)
   - `SweepingRule` properties:
     - `dayOfWeek: Int` (1-7, Sunday=1)
     - `startTime: String`, `endTime: String` (format "HH:MM")
     - `weeksOfMonth: [Int]` (which weeks of month rule applies: 1-5)
     - `applyOnHolidays: Bool` (whether sweeping occurs on holidays)
   - `StreetSegment` properties:
     - `id: String`, `streetName: String`
     - `coordinates: [[Double]]` (array of [lng, lat] pairs)
     - `rules: [SweepingRule]`
   - Methods implemented:
     - `appliesTo(date: Date) -> Bool` - checks if rule applies to given date
     - `nextSweeping(referenceDate: Date) -> (Date?, SweepingRule?)` - finds next sweep occurrence
     - `hasSweeperToday() -> Bool` - checks if sweeping today
   - `StreetSweepingDataManager` singleton:
     - Loads data from bundled JSON file (`sweeping_data_sf.json`)
     - Currently falls back to sample 2-street data (Market St, Mission St)
     - Implements `findSegment(near: CLLocationCoordinate2D)` for spatial queries

2. **[SweepingRuleEngine.swift](EasyStreet/Utils/SweepingRuleEngine.swift)** (130 lines)
   - **CRITICAL ISSUE IDENTIFIED**: Lines 13-25 contain hardcoded 2023 holidays
   ```swift
   private let holidays: [String] = [
       "2023-01-01", // New Year's Day
       "2023-01-16", // MLK Day
       // ... all dates hardcoded for 2023 only
       "2023-12-25"  // Christmas
   ]
   ```
   - Impact: Will give incorrect sweeping alerts for any year after 2023
   - Core method: `analyzeSweeperStatus(for: CLLocationCoordinate2D, completion: (SweepingStatus) -> Void)`
   - Logic flow:
     1. Find street segment near location
     2. Check if sweeping today
     3. Parse rule start time
     4. Compare with current time
     5. Return status: .safe, .today, .imminent (<1 hr), .upcoming, .noData, .unknown
   - Method: `isHoliday(_ date: Date) -> Bool` - checks against hardcoded list
   - Time parsing logic (lines 56-58): Uses string manipulation, needs refactoring

3. **[ParkedCar.swift](EasyStreet/Models/ParkedCar.swift)** (120 lines)
   - `ParkedCarManager` singleton for state management
   - Persistence via `UserDefaults`:
     - Keys: `parkedLatitude`, `parkedLongitude`, `parkedTimestamp`, `parkedStreetName`
   - Notification scheduling:
     - Uses `UNUserNotificationCenter`
     - Schedules notification 1 hour before sweeping (hardcoded)
     - Notification ID: "sweepingReminder"
   - Methods:
     - `parkCar(at:streetName:sweepingTime:)`
     - `clearParkedCar()`
     - `scheduleNotification(for:streetName:)`

4. **[MapViewController.swift](EasyStreet/Controllers/MapViewController.swift)** (667 lines)
   - MVC architecture with UIKit
   - MapKit integration:
     - Uses `MKPolylineRenderer` for street overlays
     - Color coding: Red (sweeping today), Green (no sweeping today)
     - Method `updateMapOverlays()` called on region changes (line 591)
   - Location features:
     - CoreLocation for GPS capture
     - Long-press gesture for manual pin adjustment
     - Reverse geocoding for street names
   - UI Components:
     - Search bar for address lookup
     - "I Parked Here" button
     - Status display card
     - Legend view
   - Performance concern: `rendererFor overlay` (line 533) iterates visible segments for every polyline render

5. **[Street_Sweeping_Schedule_20250508.csv](EasyStreet/Street_Sweeping_Schedule_20250508.csv)** (7.3 MB, 37,475 rows)
   - **CRITICAL ISSUE**: Full dataset exists but NOT integrated into app
   - Current app uses only sample 2-street data
   - CSV Format:
     ```
     CNN,Corridor,Limits,CNNRightLeft,BlockSide,FullName,WeekDay,FromHour,ToHour,Week1,Week2,Week3,Week4,Week5,Holidays,BlockSweepID,Line
     110000,01st St,Clementina St - Folsom St,L,NorthEast,Tuesday,Tues,0,2,1,1,1,1,1,0,1613751,"LINESTRING (-122.395... 37.787...)"
     ```
   - Columns explained:
     - `CNN`: Street code
     - `FullName`: Street name
     - `WeekDay`: Day name (Mon, Tue, Wed, Thu, Fri)
     - `FromHour`, `ToHour`: Sweeping time range (24-hour format)
     - `Week1-5`: Binary flags (0/1) for which weeks of month rule applies
     - `Holidays`: 0=no sweeping on holidays, 1=sweeping occurs on holidays
     - `Line`: WKT LINESTRING geometry with coordinates

**Features Verified Working**:
- ✅ Interactive map with color-coded street overlays
- ✅ "I Parked Here" GPS location capture
- ✅ Manual pin adjustment via long-press drag
- ✅ Notification scheduling (1 hour before sweeping)
- ✅ Address search with geocoding
- ✅ UserDefaults persistence
- ✅ MapKit integration with MKPolylineRenderer

**Critical Issues Identified**:
1. 🔴 **Hardcoded 2023 holidays** (SweepingRuleEngine.swift:13-25) - production blocker
2. 🔴 **Missing real street data** - app uses only 2 sample streets, 37K+ segments not bundled
3. 🟡 **No test coverage** - zero XCTest files found
4. 🟡 **Performance concerns** - map rendering with large dataset not optimized

#### Android Codebase Review
**Status**: 0% Implementation (Greenfield)

**Files Analyzed**:
1. **[build.gradle.kts](EasyStreet_Android/app/build.gradle.kts)** (92 lines)
   - ✅ Well-configured dependencies:
     ```kotlin
     // Maps
     implementation("com.google.maps.android:maps-compose:4.3.3")
     implementation("com.google.android:play-services-maps:18.2.0")

     // Location
     implementation("com.google.android:play-services-location:21.2.0")

     // Compose UI
     implementation(platform("androidx.compose:compose-bom:2024.02.00"))
     implementation("androidx.compose.material3:material3")

     // Serialization
     implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")

     // Coroutines
     implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.0")
     ```
   - SDK configuration: `compileSdk 34`, `targetSdk 34`, `minSdk 24`
   - Jetpack Compose enabled: `buildFeatures { compose = true }`

2. **[AndroidManifest.xml](EasyStreet_Android/app/src/main/AndroidManifest.xml)** (48 lines)
   - ✅ Permissions declared:
     - `INTERNET`
     - `ACCESS_FINE_LOCATION`
     - `ACCESS_COARSE_LOCATION`
     - `ACCESS_NETWORK_STATE`
     - `POST_NOTIFICATIONS` (Android 13+)
   - Google Maps API key placeholder: `YOUR_KEY_HERE` (needs replacement)
   - Package: `com.yourdomain.easystreetandroid` (needs customization)

3. **Source Code Status**:
   - ❌ No Kotlin files exist (`app/src/main/kotlin/` - empty)
   - ❌ No data models
   - ❌ No business logic
   - ❌ No UI components
   - ❌ No tests
   - Estimated effort: 52-77 hours for iOS feature parity

**Requirements**: No actual implementation to review

#### Requirements & Documentation Review

**Files Analyzed**:
1. **[CLAUDE.md](.claude/CLAUDE.md)** - Project instructions
2. **[README.md](README.md)** - Project overview
3. **[Reqs.md](EasyStreet/Reqs.md)** - iOS requirements
4. **[StreetSweepingAppDevelopment.md](EasyStreet/StreetSweepingAppDevelopment.md)** - Development notes

**Key Requirements Identified**:
- Target users: San Francisco residents parking on city streets
- Core use case: Avoid parking tickets via sweeping notifications
- MVP features:
  - Interactive map with color-coded streets
  - "I Parked Here" GPS capture
  - Notification 1 hour before sweeping
  - Manual pin adjustment
- Post-MVP features:
  - Advanced color coding (orange=tomorrow, yellow=this week)
  - Customizable notification times
  - "Where Can I Park?" safe zone suggestions
  - Dynamic holiday updates
- Critical data:
  - 37,000+ street segments
  - WKT LINESTRING geometries
  - Complex rules: day/time/week/holiday combinations

### Deliverables Created

#### Sprint 1 Plan Document
**File**: `c:\Users\tshul\.claude\plans\scalable-knitting-pixel.md`

**Sprint Goal**: Fix critical iOS production blockers (hardcoded 2023 holidays, missing real street data) and establish Android foundation with core data models and business logic.

**Developer Assignments**:
- **Developer A**: Data & iOS Critical Path (4 stories, 24 hours)
- **Developer B**: Android Foundation (5 stories, 35 hours)

**Stories Created**:

1. **Story 1: Parse CSV to JSON Data Format** (Dev A, 8 hours, CRITICAL)
   - Objective: Convert 37,475-line CSV to JSON matching iOS data models
   - Technical approach:
     - Parse WKT LINESTRING → coordinate arrays `[[lng, lat], ...]`
     - Map day abbreviations (Mon, Tue) → numeric dayOfWeek (1-7)
     - Convert Week1-5 binary flags → weeksOfMonth array
     - Parse time strings → "HH:MM" format
     - Generate IDs: `CNN + BlockSide + BlockSweepID`
   - Output: `sweeping_data_sf.json` (~5-8 MB)
   - Blocks: Story 3, Story 7

2. **Story 2: Dynamic Holiday Management System** (Dev A, 6 hours, CRITICAL)
   - Objective: Replace hardcoded 2023 holidays with algorithmic calculation
   - Files to create:
     - `EasyStreet/Utils/HolidayCalculator.swift`
     - `EasyStreetTests/HolidayCalculatorTests.swift`
   - Files to modify:
     - `EasyStreet/Utils/SweepingRuleEngine.swift` (lines 13-25)
   - Holidays to implement:
     - Fixed: New Year's (1/1), Juneteenth (6/19), July 4th, Veterans Day (11/11), Christmas (12/25)
     - Floating: MLK Day (3rd Mon Jan), Presidents' Day (3rd Mon Feb), Memorial Day (last Mon May), Labor Day (1st Mon Sep), Indigenous Peoples' Day (2nd Mon Oct), Thanksgiving (4th Thu Nov)
   - Test cases: 15+ tests for years 2025-2030
   - Validation: Thanksgiving 2025=Nov 27, 2026=Nov 26

3. **Story 3: Integrate Real Street Data into iOS** (Dev A, 5 hours, CRITICAL)
   - Objective: Bundle and load full 37K+ dataset
   - Technical approach:
     - Add JSON to Xcode bundle (Resources group)
     - Update StreetSweepingDataManager.dataFileName
     - Implement viewport-based filtering
     - Background thread loading (<3 seconds target)
   - Performance targets:
     - Load time: <3 seconds
     - Memory usage: <150 MB
     - Smooth map rendering (60 FPS)
   - Testing: Park on 10 different SF streets, verify rules
   - Depends on: Story 1

4. **Story 4: Unit Tests for SweepingRuleEngine** (Dev A, 5 hours, HIGH)
   - Objective: Add comprehensive test coverage for business logic
   - Files to create:
     - `EasyStreetTests/SweepingRuleEngineTests.swift`
   - Test coverage targets:
     - `appliesTo(date:)` - day matching, week filtering, holiday exclusion
     - `nextSweeping()` - same week, next month, multiple rules
     - `hasSweeperToday()` - various dates
     - `analyzeSweeperStatus()` - all 6 status types
   - Target: 20+ test cases, 100% coverage on analyzeSweeperStatus()

5. **Story 5: Android Data Models (Kotlin)** (Dev B, 6 hours, CRITICAL)
   - Objective: Create Kotlin data classes matching iOS models
   - Files to create:
     - `app/src/main/kotlin/com/yourdomain/easystreetandroid/data/models/SweepingRule.kt`
     - `app/src/main/kotlin/com/yourdomain/easystreetandroid/data/models/StreetSegment.kt`
     - `app/src/main/kotlin/com/yourdomain/easystreetandroid/data/models/SweepingStatus.kt`
     - `app/src/test/kotlin/com/yourdomain/easystreetandroid/data/models/SweepingRuleTest.kt`
   - Data classes to implement:
     - `SweepingRule`: dayOfWeek, startTime, endTime, weeksOfMonth, applyOnHolidays
     - `StreetSegment`: id, streetName, coordinates, rules
     - `SweepingStatus` (sealed class): NoData, Safe, Today, Imminent, Upcoming, Unknown
   - Methods to port from iOS:
     - `SweepingRule.appliesTo(date: LocalDate): Boolean`
     - `StreetSegment.nextSweeping(): Pair<LocalDate?, SweepingRule?>`
     - `StreetSegment.hasSweeperToday(): Boolean`
   - Annotations: `@Serializable` for JSON parsing
   - Test target: 15+ unit tests
   - Blocks: All other Android stories

6. **Story 6: Android Business Logic - SweepingRuleEngine** (Dev B, 8 hours, CRITICAL)
   - Objective: Port iOS sweeping analysis logic to Kotlin
   - Files to create:
     - `app/src/main/kotlin/com/yourdomain/easystreetandroid/business/SweepingRuleEngine.kt`
     - `app/src/test/kotlin/com/yourdomain/easystreetandroid/business/SweepingRuleEngineTest.kt`
   - Technical approach:
     - Singleton class pattern
     - Port HolidayCalculator from Story 2
     - Use `java.time` APIs (LocalDate, DayOfWeek)
     - Haversine distance for segment finding
     - Kotlin coroutines for async operations
   - Core method: `analyzeSweeperStatus(location: LatLng, callback: (SweepingStatus) -> Unit)`
   - Test with: Market St coordinates (37.7932, -122.3964)
   - Target: 20+ unit tests, logic identical to iOS
   - Depends on: Story 5

7. **Story 7: Android Data Manager & JSON Loading** (Dev B, 7 hours, HIGH)
   - Objective: Create data loading and spatial query layer
   - Files to create:
     - `app/src/main/kotlin/com/yourdomain/easystreetandroid/data/StreetSweepingDataManager.kt`
     - `app/src/test/kotlin/com/yourdomain/easystreetandroid/data/StreetSweepingDataManagerTest.kt`
   - Technical approach:
     - Singleton pattern
     - Load from `assets/sweeping_data_sf.json`
     - Parse with kotlinx.serialization
     - Background loading: Coroutines with Dispatchers.IO
     - Haversine distance calculation
   - Methods to implement:
     - `segmentsInBounds(bounds: LatLngBounds): List<StreetSegment>`
     - `findSegmentNear(location: LatLng, maxDistance: Double = 50.0): StreetSegment?`
   - Performance targets:
     - Load time: <5 seconds
     - Memory: <200 MB
     - Accuracy: Within 50m for segment matching
   - Sample data fallback: Market + Mission for debugging
   - Depends on: Story 1, Story 5

8. **Story 8: Android Parked Car Model & Persistence** (Dev B, 6 hours, HIGH)
   - Objective: State management with SharedPreferences persistence
   - Files to create:
     - `app/src/main/kotlin/com/yourdomain/easystreetandroid/data/ParkedCarManager.kt`
     - `app/src/main/kotlin/com/yourdomain/easystreetandroid/notifications/NotificationScheduler.kt`
     - `app/src/test/kotlin/com/yourdomain/easystreetandroid/data/ParkedCarManagerTest.kt`
   - Technical approach:
     - Singleton pattern
     - SharedPreferences for persistence (keys: latitude, longitude, timestamp, streetName)
     - Kotlin StateFlow for reactive state changes
     - WorkManager for notification scheduling
     - POST_NOTIFICATIONS permission handling (Android 13+)
   - Properties:
     - `isCarParked: Boolean`
     - `parkedLocation: LatLng?`
     - `parkedTime: LocalDateTime?`
     - `parkedStreetName: String?`
   - Notification timing: 1 hour before sweeping (MVP)
   - Test: Park → close app → reopen → verify location restored
   - Depends on: Story 5

9. **Story 9: Android Basic UI Scaffold (Jetpack Compose)** (Dev B, 8 hours, MEDIUM - Stretch Goal)
   - Objective: Demonstrate Android foundation with minimal working UI
   - Files to create:
     - `app/src/main/kotlin/com/yourdomain/easystreetandroid/ui/MainActivity.kt`
     - `app/src/main/kotlin/com/yourdomain/easystreetandroid/ui/screens/MapScreen.kt`
     - `app/src/main/kotlin/com/yourdomain/easystreetandroid/ui/viewmodels/MapViewModel.kt`
     - `app/src/main/kotlin/com/yourdomain/easystreetandroid/ui/viewmodels/ParkingViewModel.kt`
   - UI Components:
     - `MapScreen`: Google Maps Compose, centered on SF (37.7749, -122.4194)
     - `ParkButton`: Floating action button "I Parked Here"
     - `StatusCard`: Color-coded sweeping status display
   - Features:
     - Location permission request flow
     - Blue dot for current location
     - Red pin for parked location
     - Mock sweeping data (sample 2-street)
   - Testing: Manual on Android emulator API 34
   - Depends on: Story 5, 6, 7

**Sprint Timeline**:
- Week 1 (Days 1-5): Foundation work, critical fixes, JSON parsing
- Week 2 (Days 6-10): Integration, testing, UI scaffold
- Sync points: Day 5 (JSON validation), Day 8 (test strategy)

**Dependencies Identified**:
1. Story 1 blocks Story 3 and Story 7 (JSON data needed)
2. Story 2 informs Story 6 (holiday algorithm)
3. Story 5 blocks all other Android stories (models foundation)

**Risks Identified**:
1. CSV parsing complexity (High impact, mitigated by early prioritization)
2. Android learning curve (Medium impact, leverage iOS reference)
3. Performance with 37K segments (Medium impact, test early + viewport filtering)
4. Holiday algorithm accuracy (Low impact, comprehensive tests)

### Technical Decisions Made

1. **Data Format**: JSON chosen over CSV for app bundle
   - Reasoning: Faster parsing, native iOS/Android support, smaller size
   - Trade-off: Requires one-time conversion from CSV

2. **Holiday Management**: Algorithmic calculation vs. external API
   - Decision: Algorithmic for MVP (offline capability)
   - Post-MVP: Consider API for updates without app releases

3. **Android Architecture**: Match iOS patterns
   - Singleton managers for data and state
   - Separation: Models, Business Logic, UI
   - Kotlin idioms where appropriate (coroutines, sealed classes, StateFlow)

4. **Testing Strategy**: Unit tests for business logic priority
   - Focus: SweepingRuleEngine, HolidayCalculator, data models
   - Target: 80% coverage on core logic
   - Reasoning: Most critical for accuracy, highest ROI

5. **Sprint Scope**: Balance iOS fixes with Android foundation
   - iOS: Fix blockers, add tests (production-ready)
   - Android: Data layer + business logic (no UI pressure)
   - Reasoning: De-risk iOS release, establish Android properly

### Artifacts Created

1. **Sprint Plan**: `c:\Users\tshul\.claude\plans\scalable-knitting-pixel.md`
   - 9 user stories with detailed tasks
   - Acceptance criteria for each story
   - Testing requirements
   - Risk mitigation strategies

### Code Changes

**None** - This was a planning session. No code was modified.

### Next Steps

**For Developer A** (Start Day 1):
1. Set up Python/Node environment for CSV parsing
2. Analyze CSV structure (sample first 100 rows)
3. Design JSON schema matching iOS models
4. Begin Story 1: CSV parser implementation

**For Developer B** (Start Day 1):
1. Review iOS data models thoroughly
2. Set up Android project structure: `data/models` package
3. Begin Story 5: Implement `SweepingRule.kt`
4. Port `appliesTo()` logic from Swift to Kotlin

**Coordination**:
- Day 2: Dev A shares JSON sample for Dev B validation
- Day 4: Dev A shares HolidayCalculator for Dev B to port
- Daily standups on: data format, holiday algorithms, performance

### References

**iOS Files Reviewed**:
- [StreetSweepingData.swift](EasyStreet/Models/StreetSweepingData.swift)
- [SweepingRuleEngine.swift](EasyStreet/Utils/SweepingRuleEngine.swift)
- [ParkedCar.swift](EasyStreet/Models/ParkedCar.swift)
- [MapViewController.swift](EasyStreet/Controllers/MapViewController.swift)
- [Street_Sweeping_Schedule_20250508.csv](EasyStreet/Street_Sweeping_Schedule_20250508.csv)

**Android Files Reviewed**:
- [build.gradle.kts](EasyStreet_Android/app/build.gradle.kts)
- [AndroidManifest.xml](EasyStreet_Android/app/src/main/AndroidManifest.xml)

**Documentation Reviewed**:
- [CLAUDE.md](.claude/CLAUDE.md)
- [README.md](README.md)
- [Reqs.md](EasyStreet/Reqs.md)
- [StreetSweepingAppDevelopment.md](EasyStreet/StreetSweepingAppDevelopment.md)

**Plan Document**:
- [Sprint 1 Plan](.claude/plans/scalable-knitting-pixel.md)

---
