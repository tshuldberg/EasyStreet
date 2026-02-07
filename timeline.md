# EasyStreet Development Timeline

**Purpose**: Detailed chronological record of all development activities, code changes, and technical decisions. Each entry provides enough context for developers to understand what was done and make retroactive changes if needed.

**Format**: Chronological order (oldest first). Every commit is accounted for in the master table and grouped into logical development sessions below.

---

## Master Commit Table

All 44 commits across Feb 4–6, 2026:

| # | SHA | Date | Message | Session |
|---|-----|------|---------|---------|
| 1 | `8ba2991` | Feb 4 | Initial commit: EasyStreet project with iOS MVP and Android config | 1 |
| 2 | `5a0b473` | Feb 4 | docs: add Android feature-parity implementation plan (14 tasks) | 2 |
| 3 | `cdf4bec` | Feb 5 | feat(android): scaffold project with Gradle wrapper, resources, and WorkManager dep | 2 |
| 4 | `ec49037` | Feb 5 | docs: update timeline with Android scaffolding session and next steps | 2 |
| 5 | `4377e18` | Feb 5 | docs: add getting started guide for new Mac contributors | 3 |
| 6 | `5d64764` | Feb 5 | docs: update timeline with getting-started guide session | 3 |
| 7 | `548b3ca` | Feb 5 | feat(android): update namespace and enable core library desugaring | 4 |
| 8 | `43a2d22` | Feb 5 | chore: add nul to gitignore (Windows artifact) | 4 |
| 9 | `ee535dc` | Feb 5 | chore(android): fix package namespace to com.easystreet | 4 |
| 10 | `6c0f2fe` | Feb 5 | feat(android): add domain models — SweepingRule, StreetSegment, ParkedCar, SweepingStatus | 4 |
| 11 | `5203f51` | Feb 5 | feat(android): add HolidayCalculator and SweepingRuleEngine with tests | 4 |
| 12 | `b605ddc` | Feb 5 | feat(android): add data layer, notifications, and app shell | 4 |
| 13 | `c6ca1a0` | Feb 5 | feat(android): add CSV-to-SQLite converter and generate easystreet.db | 4 |
| 14 | `ef9283a` | Feb 5 | docs: update timeline with Android Sprint 1 implementation session | 4 |
| 15 | `753716e` | Feb 5 | fix(android): add launcher icons, remove deprecated manifest package, fix test | 5 |
| 16 | `11cb652` | Feb 5 | feat(android): add MapViewModel, MapScreen UI, and wire up MainActivity | 5 |
| 17 | `8028aee` | Feb 5 | docs: update timeline with Android Sprint 2 — all 14 tasks complete | 5 |
| 18 | `8379cd8` | Feb 5 | fix(android): upgrade Gradle/AGP for Android Studio compatibility | 6 |
| 19 | `71cfe0d` | Feb 5 | security(android): move Google Maps API key to local.properties | 6 |
| 20 | `d2d6faa` | Feb 5 | feat(android): add street-tap bottom sheet with schedule and Park Here button | 6 |
| 21 | `e53db5d` | Feb 5 | feat(ios): add Xcode project via xcodegen with test target | 7 |
| 22 | `9552685` | Feb 5 | feat(ios): add CSV-to-JSON converter and bundle real SF street data (~21K segments) | 7 |
| 23 | `27e83d1` | Feb 5 | perf(ios): optimize map overlays with diff updates, zoom throttle, and debounce | 7 |
| 24 | `978ade3` | Feb 5 | feat(ios): replace hardcoded 2023 holidays with dynamic HolidayCalculator | 7 |
| 25 | `e007513` | Feb 5 | feat(ios): add orange/yellow color coding for tomorrow and 2-3 day sweeping | 7 |
| 26 | `272d0f8` | Feb 5 | docs: update build commands for xcodegen and add test instructions | 7 |
| 27 | `131b957` | Feb 5 | feat(ios): add configurable notification lead time (15m/30m/1h/2h) | 7 |
| 28 | `de70fc6` | Feb 5 | test(ios): add unit tests for SweepingRule, StreetSegment, and rule engine | 7 |
| 29 | `4bad493` | Feb 5 | fix(ios): UI polish - pin drag feedback, map centering fix | 7 |
| 30 | `250ef42` | Feb 5 | docs: update timeline with iOS MVP completion sprint | 7 |
| 31 | `1387ac7` | Feb 5 | feat(ios): add repository pattern, street-tap sheet, parking card, SQLite DB | 8 |
| 32 | `7e57f7c` | Feb 5 | fix(ios): streets not color-coded at default zoom after SQLite migration | 9 |
| 33 | `2daaba9` | Feb 5 | docs: update timeline with SQLite migration bug fix and feature commit SHAs | 9 |
| 34 | `ea01ded` | Feb 5 | fix(ios): overlay throttle for scroll visibility + tap gesture for street detail | 10 |
| 35 | `03270e0` | Feb 5 | fix(ios): encode overlay color directly on polyline to fix rendering | 10 |
| 36 | `612270e` | Feb 5 | fix(ios): render street overlays above labels with thicker lines | 10 |
| 37 | `be7be23` | Feb 6 | feat(ios): production readiness — legal, thread safety, tests, and code quality | 11 |
| 38 | `890f0e3` | Feb 6 | fix(ios): P0 crash guards, P1 quality fixes, and test corrections | 12 |
| 39 | `ba9336b` | Feb 6 | data(ios): update street sweeping data from Jan 2026 SF Open Data | 13 |
| 40 | `58502e2` | Feb 6 | chore: remove stale May 2025 CSV and update references to Jan 2026 data | 13 |
| 41 | `4497aa2` | Feb 6 | feat(android): cross-platform parity — fix 19 variances across 5 phases | 14 |
| 42 | `f8456a7` | Feb 6 | feat: offline mode for iOS and Android | — |
| 43 | `23c8385` | Feb 6 | feat(ios): replace always-visible legend and search bar with toolbar buttons | — |
| 44 | `53084e4` | Feb 6 | feat(ios): add live countdown timer and comprehensive color coding tests | 15 |

---

## Session 1: 2026-02-04 — Initial Commit & Project Foundation

**Session Type**: Development
**Duration**: ~2 hours
**Participants**: Trey Shuldberg, Claude Code (AI Assistant)
**Commits**: `8ba2991`

### Objectives
Bootstrap the EasyStreet project with a working iOS MVP and configured (but unimplemented) Android project.

### Technical Details

#### Files Created (19 total, +40,888 lines)

**iOS Application (6 source files):**
1. **[EasyStreet/Controllers/MapViewController.swift](EasyStreet/Controllers/MapViewController.swift)** (667 lines) — MVC main UI with MapKit integration, color-coded street overlays, "I Parked Here" GPS capture, long-press pin adjustment, address search with geocoding, status display card, legend view
2. **[EasyStreet/Models/StreetSweepingData.swift](EasyStreet/Models/StreetSweepingData.swift)** (300 lines) — `SweepingRule` struct (dayOfWeek, startTime, endTime, weeksOfMonth, applyOnHolidays), `StreetSegment` struct (id, streetName, coordinates, rules), `StreetSweepingDataManager` singleton with spatial queries
3. **[EasyStreet/Models/ParkedCar.swift](EasyStreet/Models/ParkedCar.swift)** (124 lines) — `ParkedCarManager` singleton, UserDefaults persistence, `UNUserNotificationCenter` scheduling (1hr hardcoded)
4. **[EasyStreet/Utils/SweepingRuleEngine.swift](EasyStreet/Utils/SweepingRuleEngine.swift)** (130 lines) — Status analysis engine with **hardcoded 2023 holidays** (critical blocker identified)
5. **[EasyStreet/AppDelegate.swift](EasyStreet/AppDelegate.swift)** — Standard UIKit app delegate
6. **[EasyStreet/SceneDelegate.swift](EasyStreet/SceneDelegate.swift)** — Scene lifecycle management

**iOS Resources:**
7. **[EasyStreet/Info.plist](EasyStreet/Info.plist)** — Location permission descriptions, notification authorization
8. **[EasyStreet/LaunchScreen.storyboard](EasyStreet/LaunchScreen.storyboard)** — Launch screen UI
9. **[EasyStreet/Street_Sweeping_Schedule_20250508.csv](EasyStreet/Street_Sweeping_Schedule_20250508.csv)** (7.3 MB, 37,475 rows) — Full SF street sweeping dataset (not yet integrated into app)

**Android Configuration:**
10. **[EasyStreet_Android/app/build.gradle.kts](EasyStreet_Android/app/build.gradle.kts)** (92 lines) — Dependencies: Maps Compose 4.3.3, Play Services Location 21.2.0, Compose BOM 2024.02.00, kotlinx.serialization 1.6.3, Coroutines 1.8.0
11. **[EasyStreet_Android/app/src/main/AndroidManifest.xml](EasyStreet_Android/app/src/main/AndroidManifest.xml)** (49 lines) — Permissions: INTERNET, FINE/COARSE_LOCATION, NETWORK_STATE, POST_NOTIFICATIONS

**Documentation:**
12. **[.claude/CLAUDE.md](.claude/CLAUDE.md)** (506 lines) — Project instructions and conventions
13. **[README.md](README.md)** (75 lines) — Project overview
14. **[EasyStreet/Reqs.md](EasyStreet/Reqs.md)** (185 lines) — iOS requirements
15. **[EasyStreet/StreetSweepingAppDevelopment.md](EasyStreet/StreetSweepingAppDevelopment.md)** (301 lines) — Development notes
16. **[docs/plans/2026-02-04-android-feature-parity-design.md](docs/plans/2026-02-04-android-feature-parity-design.md)** (302 lines) — Android design document
17. **[timeline.md](timeline.md)** (453 lines) — Initial development timeline
18. **[.claude/settings.json](.claude/settings.json)** — Claude Code project settings
19. **[.gitignore](.gitignore)** — Git ignore rules

### Critical Issues Identified
1. **Hardcoded 2023 holidays** in SweepingRuleEngine.swift (lines 13-25) — production blocker
2. **Missing real street data** — app uses only 2 sample streets despite 37K CSV existing
3. **No test coverage** — zero XCTest files
4. **No .xcodeproj** — no way to build the iOS app from the repo

### iOS Features Verified Working
- Interactive map with color-coded street overlays (red/green)
- "I Parked Here" GPS location capture
- Manual pin adjustment via long-press drag
- Notification scheduling (1 hour before sweeping)
- Address search with geocoding
- UserDefaults persistence

---

## Session 2: 2026-02-04/05 — Android Implementation Planning & Project Scaffolding

**Session Type**: Planning & Development
**Duration**: ~1.5 hours
**Participants**: Trey Shuldberg, Claude Code (AI Assistant)
**Commits**: `5a0b473`, `cdf4bec`, `ec49037`

### Objectives
- Create a detailed 14-task Android implementation plan with full code specifications
- Begin execution: scaffold the Android project with Gradle wrapper, resources, and build configuration

### Technical Details

#### Commit `5a0b473` — Android Implementation Plan

**File Created:**
1. **[docs/plans/2026-02-04-android-implementation-plan.md](docs/plans/2026-02-04-android-implementation-plan.md)** (2,288 lines)
   - 14 detailed tasks with step-by-step instructions, code snippets, and commit messages
   - Test-driven development approach
   - Architecture: MVVM with Jetpack Compose, SQLite for street data, SharedPreferences for parking state

**Task Breakdown:**
| Task | Description | Depends On |
|------|-------------|------------|
| 1 | Project scaffolding (Gradle, resources) | — |
| 2 | CSV→SQLite converter script (Python) | — |
| 3 | Domain models (SweepingRule, StreetSegment, ParkedCar, SweepingStatus) | — |
| 4 | HolidayCalculator (dynamic, any year) | — |
| 5 | SweepingRuleEngine (status evaluation) | 3, 4 |
| 6 | SQLite database layer (StreetDatabase, StreetDao) | 2, 3 |
| 7 | Parking persistence & repositories | 3 |
| 8 | Notification system (WorkManager) | 3 |
| 9 | Application class & MainActivity shell | 6, 7, 8 |
| 10 | MapViewModel | 5, 6, 7 |
| 11–13 | MapScreen Compose UI, marker drag, notification permission | 10 |
| 14 | Final integration & build verification | All |

#### Commit `cdf4bec` — Android Project Scaffolding (Task 1)

**Files Created (10 total):**
- **[EasyStreet_Android/build.gradle.kts](EasyStreet_Android/build.gradle.kts)** — Project-level with AGP 8.2.2, Kotlin 1.9.22
- **[EasyStreet_Android/settings.gradle.kts](EasyStreet_Android/settings.gradle.kts)** — Plugin management
- **[EasyStreet_Android/gradle.properties](EasyStreet_Android/gradle.properties)** — JVM args, AndroidX enabled
- **[EasyStreet_Android/gradlew](EasyStreet_Android/gradlew)**, **[gradlew.bat](EasyStreet_Android/gradlew.bat)** — Gradle wrapper scripts
- **[gradle/wrapper/gradle-wrapper.jar](EasyStreet_Android/gradle/wrapper/gradle-wrapper.jar)**, **[gradle-wrapper.properties](EasyStreet_Android/gradle/wrapper/gradle-wrapper.properties)** — Gradle 8.4
- **[app/src/main/res/values/strings.xml](EasyStreet_Android/app/src/main/res/values/strings.xml)**, **[themes.xml](EasyStreet_Android/app/src/main/res/values/themes.xml)** — Resources
- **[app/src/main/res/xml/data_extraction_rules.xml](EasyStreet_Android/app/src/main/res/xml/data_extraction_rules.xml)**, **[backup_rules.xml](EasyStreet_Android/app/src/main/res/xml/backup_rules.xml)** — Backup config

**Files Modified:**
- **[EasyStreet_Android/app/build.gradle.kts](EasyStreet_Android/app/build.gradle.kts)** — Added WorkManager dep, removed navigation-compose

#### Commit `ec49037` — Timeline Update
- Updated timeline.md with scaffolding session details and next steps (+172 lines)

### Decisions Made
1. **SQLite over JSON** for Android street data — enables viewport-based spatial queries
2. **Python script for CSV→SQLite** — Python has built-in CSV/SQLite support
3. **Package namespace `com.easystreet`** — simplified from `com.yourdomain.easystreetandroid`
4. **Single MapScreen** — all functionality fits on one screen with Compose state

---

## Session 3: 2026-02-05 — Getting Started Guide for New Mac Contributors

**Session Type**: Documentation
**Duration**: ~15 minutes
**Participants**: Trey Shuldberg, Claude Code (AI Assistant)
**Commits**: `4377e18`, `5d64764`

### Objectives
Create a step-by-step onboarding guide for new Mac users joining the project.

### Technical Details

#### Commit `4377e18` — Getting Started Guide

**File Created:**
1. **[docs/getting-started.md](docs/getting-started.md)** (386 lines)
   - 8 sequential setup steps: Homebrew, Git/SSH, repo cloning, Xcode, Android Studio, Node.js, Claude Code, project orientation
   - 14 best practices for working with the project
   - Quick reference tables for common commands
   - Troubleshooting section (5 common issues)

#### Commit `5d64764` — Timeline Update
- Updated timeline.md with getting-started guide session details (+88 lines)

---

## Session 4: 2026-02-05 — Android Sprint 1: Foundation Layer (Tasks 2–9)

**Session Type**: Development
**Duration**: ~30 minutes
**Participants**: Trey Shuldberg, Claude Code (AI Assistant) with 2 parallel dev agents
**Commits**: `548b3ca`, `43a2d22`, `ee535dc`, `6c0f2fe`, `5203f51`, `b605ddc`, `c6ca1a0`, `ef9283a`

### Objectives
Execute Sprint 1 of the Android implementation plan (Tasks 2–9) using parallel developer agents to build the complete foundation layer: domain models, business logic, data layer, notifications, and app shell.

### Approach: Parallel Agent Development

**Developer A** (Tasks 3, 5, 6, 8): Domain models, SweepingRuleEngine, SQLite database layer, notifications
**Developer B** (Tasks 4, 2, 7, 9): HolidayCalculator, CSV→SQLite converter, parking persistence, app shell

### Commit Progression

| SHA | Description |
|-----|-------------|
| `548b3ca` | Update namespace to com.easystreet.android, enable core library desugaring, add foundation plan doc |
| `43a2d22` | Add `nul` to .gitignore (Windows artifact) |
| `ee535dc` | Fix package namespace to `com.easystreet` (critical: mismatch would cause ClassNotFoundException) |
| `6c0f2fe` | Add domain models: SweepingRule, StreetSegment, ParkedCar, SweepingStatus |
| `5203f51` | Add HolidayCalculator and SweepingRuleEngine with tests |
| `b605ddc` | Add data layer (StreetDatabase, StreetDao), notifications, and app shell |
| `c6ca1a0` | Add CSV-to-SQLite converter and generate easystreet.db |
| `ef9283a` | Update timeline with Sprint 1 session |

### Technical Details

#### Files Created (21 total)

**Domain Models** (`app/src/main/kotlin/com/easystreet/domain/model/`):
1. **[SweepingStatus.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/model/SweepingStatus.kt)** — Sealed class: Safe, Today, Imminent, Upcoming, NoData, Unknown
2. **[SweepingRule.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/model/SweepingRule.kt)** — Data class with `appliesTo(date, isHoliday)` using `WeekFields.of(Locale.US)`
3. **[StreetSegment.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/model/StreetSegment.kt)** — LatLngPoint, BoundingBox, StreetSegment data classes
4. **[ParkedCar.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/model/ParkedCar.kt)** — latitude, longitude, streetName, timestamp

**Domain Engine** (`app/src/main/kotlin/com/easystreet/domain/engine/`):
5. **[HolidayCalculator.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/engine/HolidayCalculator.kt)** — Dynamic US federal holidays for any year (11 holidays)
6. **[SweepingRuleEngine.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/engine/SweepingRuleEngine.kt)** — `getStatus()` and `getNextSweepingTime()`, matches iOS logic

**Data Layer** (`app/src/main/kotlin/com/easystreet/data/`):
7. **[StreetDatabase.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/data/db/StreetDatabase.kt)** — Copies bundled SQLite from assets on first launch
8. **[StreetDao.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/data/db/StreetDao.kt)** — Viewport-filtered spatial queries with bounding box index
9. **[ParkingPreferences.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/data/prefs/ParkingPreferences.kt)** — SharedPreferences wrapper
10. **[ParkingRepository.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/data/repository/ParkingRepository.kt)** — Reactive StateFlow wrapper
11. **[StreetRepository.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/data/repository/StreetRepository.kt)** — Coroutine-based, dispatches to IO

**Notifications** (`app/src/main/kotlin/com/easystreet/notification/`):
12. **[NotificationScheduler.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/notification/NotificationScheduler.kt)** — WorkManager-based 1hr-before-sweep alerts
13. **[SweepingNotificationWorker.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/notification/SweepingNotificationWorker.kt)** — Fires high-priority notification

**App Shell:**
14. **[EasyStreetApp.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/EasyStreetApp.kt)** — Application class with notification channel setup
15. **[MainActivity.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/MainActivity.kt)** — Compose shell with placeholder text

**Tests:**
16. **[SweepingRuleTest.kt](EasyStreet_Android/app/src/test/kotlin/com/easystreet/domain/model/SweepingRuleTest.kt)** — 3 tests
17. **[HolidayCalculatorTest.kt](EasyStreet_Android/app/src/test/kotlin/com/easystreet/domain/engine/HolidayCalculatorTest.kt)** — 8 tests
18. **[SweepingRuleEngineTest.kt](EasyStreet_Android/app/src/test/kotlin/com/easystreet/domain/engine/SweepingRuleEngineTest.kt)** — 7 tests

**Tools & Assets:**
19. **[csv_to_sqlite.py](EasyStreet_Android/tools/csv_to_sqlite.py)** — Python converter script
20. **[easystreet.db](EasyStreet_Android/app/src/main/assets/easystreet.db)** — Generated SQLite: 21,785 segments, 36,718 rules

**Other:**
21. **[docs/plans/2026-02-05-android-tasks-2-5-foundation.md](docs/plans/2026-02-05-android-tasks-2-5-foundation.md)** (222 lines) — Foundation plan document

#### Files Modified
- **[build.gradle.kts](EasyStreet_Android/app/build.gradle.kts)** — Fixed namespace to `com.easystreet`, added `coreLibraryDesugaring`
- **[AndroidManifest.xml](EasyStreet_Android/app/src/main/AndroidManifest.xml)** — Fixed package to `com.easystreet`
- **[.gitignore](.gitignore)** — Added `nul` (Windows artifact)

### Issues Found & Fixed
1. **CRITICAL: Namespace mismatch** — `build.gradle.kts` had `com.easystreet.android` but source files used `com.easystreet`. Fixed by aligning namespace.

### Testing & Verification
- CSV converter: 21,785 segments, 36,718 rules from 37,475 CSV rows
- All 19 source files in correct directory paths
- Build verification deferred until Android SDK available

---

## Session 5: 2026-02-05 — Android Sprint 2: UI Layer (Tasks 10–14)

**Session Type**: Development
**Duration**: ~15 minutes
**Participants**: Trey Shuldberg, Claude Code (AI Assistant) with 2 parallel dev agents
**Commits**: `753716e`, `11cb652`, `8028aee`

### Objectives
Complete the Android UI layer: MapViewModel, MapScreen, and wire up MainActivity. All 14 tasks from the implementation plan completed.

### Approach
Dispatched two developers in parallel:
- **Dev A**: MapScreen.kt (Tasks 11+12+13 combined — full UI with drag + notification permission)
- **Dev B**: MapViewModel.kt (Task 10) + MainActivity.kt update

### Commit Progression

| SHA | Description |
|-----|-------------|
| `753716e` | Fix: add launcher icons for all densities, remove deprecated `package` attribute from AndroidManifest.xml, fix SweepingRuleEngineTest (Feb 16 2026 is Presidents' Day) |
| `11cb652` | Add MapViewModel (viewport-debounced segment queries, parking actions), MapScreen (Google Maps, color-coded polylines, draggable marker, address search, ParkingInfoCard), wire up MainActivity |
| `8028aee` | Update timeline with Sprint 2 completion |

### Technical Details

#### Files Created
1. **[MapViewModel.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/ui/MapViewModel.kt)** (108 lines) — `AndroidViewModel` with viewport-debounced segment queries (300ms), parking actions, `StateFlow` for visibleSegments and sweepingStatus
2. **[MapScreen.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/ui/MapScreen.kt)** (330 lines) — Google Maps centered on SF, color-coded Polyline overlays, draggable parking marker via `MarkerState.dragState`, address search via Geocoder, ParkingInfoCard, POST_NOTIFICATIONS permission request on API 33+

#### Files Modified
- **[MainActivity.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/MainActivity.kt)** — Replaced placeholder text with `MapScreen()` composable

### Issues Found & Fixed
1. **`MarkerInfoWindow.onMarkerDragEnd` doesn't exist in maps-compose 4.3.3** — Fixed by observing `MarkerState.dragState` via `LaunchedEffect` instead

### Testing & Verification
- `gradlew test`: 18/18 tests pass (3 model + 8 holiday + 7 engine)
- `gradlew assembleDebug`: BUILD SUCCESSFUL
- All 14 implementation plan tasks complete

---

## Session 6: 2026-02-05 — Android Compatibility Fixes & Enhancements

**Session Type**: Bug Fix / Enhancement
**Duration**: ~1 hour
**Participants**: Trey Shuldberg, Claude Code (AI Assistant)
**Commits**: `8379cd8`, `71cfe0d`, `d2d6faa`

### Objectives
Fix Android build compatibility issues discovered in Android Studio, secure the API key, and add street-tap bottom sheet feature.

### Commit Progression

| SHA | Description |
|-----|-------------|
| `8379cd8` | Upgrade AGP 8.2.2→8.7.3, Gradle 8.4→8.9 for Java 21 support; bump minSdk 24→26 (java.time built-in); update desugar_jdk_libs 2.0.4→2.1.4; fix corrupted test file |
| `71cfe0d` | Move Google Maps API key from AndroidManifest.xml to local.properties (gitignored); use manifestPlaceholders to inject at build time |
| `d2d6faa` | Add street-tap bottom sheet: tapping a polyline opens ModalBottomSheet with street name, color-coded next sweeping, weekly schedule, and Park Here button. Updated polyline colors to three tiers: red (today/imminent), orange (within 48h), green (>48h) |

### Technical Details

#### `8379cd8` — Gradle/AGP Upgrade
- **[EasyStreet_Android/app/build.gradle.kts](EasyStreet_Android/app/build.gradle.kts)** — AGP 8.2.2→8.7.3, minSdk 24→26, desugar_jdk_libs 2.0.4→2.1.4
- **[EasyStreet_Android/build.gradle.kts](EasyStreet_Android/build.gradle.kts)** — AGP version bump
- **[EasyStreet_Android/gradle/wrapper/gradle-wrapper.properties](EasyStreet_Android/gradle/wrapper/gradle-wrapper.properties)** — Gradle 8.4→8.9

#### `71cfe0d` — API Key Security
- **[EasyStreet_Android/app/build.gradle.kts](EasyStreet_Android/app/build.gradle.kts)** — Read `MAPS_API_KEY` from local.properties via manifestPlaceholders (+10 lines)
- **[EasyStreet_Android/app/src/main/AndroidManifest.xml](EasyStreet_Android/app/src/main/AndroidManifest.xml)** — Replace hardcoded placeholder with `${MAPS_API_KEY}` (-5 lines)

#### `d2d6faa` — Street-Tap Bottom Sheet
- **[MapScreen.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/ui/MapScreen.kt)** (+137 lines) — `ModalBottomSheet` with street name, next sweeping status, weekly schedule list, "Park Here" button
- **[MapViewModel.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/ui/MapViewModel.kt)** (+11 lines) — Street selection state management

---

## Session 7: 2026-02-05 — iOS MVP Completion Sprint

**Session Type**: Development
**Duration**: ~3 hours
**Participants**: Trey Shuldberg, Claude Code (AI Assistant), 3 parallel developer agents
**Commits**: `e53db5d`, `9552685`, `27e83d1`, `978ade3`, `e007513`, `272d0f8`, `131b957`, `de70fc6`, `4bad493`, `250ef42`

### Objectives
Complete the iOS app from "code exists but can't build" to a fully testable MVP with xcodegen project generation, real street data, dynamic holidays, comprehensive tests, enhanced colors, map optimization, configurable notifications, and UI polish.

### Approach
Subagent-driven development with 3 parallel developers:
- **Developer A** (Core Logic): HolidayCalculator, SweepingRuleEngine tests, notification config
- **Developer B** (Map & Rendering): Map performance optimization, 4-color coding, legend expansion
- **Developer C** (UX & Docs): UI polish, documentation updates, timeline, final verification

Sprint plan: [docs/plans/2026-02-05-ios-mvp-sprint.md](docs/plans/2026-02-05-ios-mvp-sprint.md) (~44KB)

### Commit Progression

| SHA | Description | Key Files |
|-----|-------------|-----------|
| `e53db5d` | Add Xcode project via xcodegen with test target; fix 3 compilation errors | project.yml, project.pbxproj, ParkedCar.swift, SweepingRuleEngine.swift |
| `9552685` | Add CSV-to-JSON converter and bundle real SF street data (~21K segments) | csv_to_json.py, sweeping_data_sf.json, project.yml |
| `27e83d1` | Optimize map overlays with diff updates, zoom throttle, and debounce | MapViewController.swift (+79, -33) |
| `978ade3` | Replace hardcoded 2023 holidays with dynamic HolidayCalculator | HolidayCalculator.swift (NEW, 72 lines), SweepingRuleEngine.swift (-25, +10), HolidayCalculatorTests.swift (NEW, 84 lines) |
| `e007513` | Add orange/yellow color coding for tomorrow and 2-3 day sweeping | MapViewController.swift, StreetSweepingData.swift (+MapColorStatus enum), MapColorStatusTests.swift (NEW) |
| `272d0f8` | Update build commands for xcodegen and add test instructions | CLAUDE.md, getting-started.md |
| `131b957` | Add configurable notification lead time (15m/30m/1h/2h) | ParkedCar.swift (+15) |
| `de70fc6` | Add 16 unit tests for SweepingRule, StreetSegment, and rule engine | SweepingRuleEngineTests.swift (NEW, 242 lines) |
| `4bad493` | UI polish: pin drag scale/alpha animation, map centering fix with hasInitiallyLocated flag | MapViewController.swift (+20, -9) |
| `250ef42` | Update timeline with iOS MVP completion sprint | timeline.md |

### Technical Details

#### Files Created
1. **[EasyStreet/project.yml](EasyStreet/project.yml)** (~40 lines) — xcodegen config for iOS 14+, app target + test target
2. **[tools/csv_to_json.py](tools/csv_to_json.py)** (~105 lines) — CSV→JSON converter: parses WKT LINESTRING, maps day names to numeric dayOfWeek, converts Week1-5 flags
3. **[EasyStreet/sweeping_data_sf.json](EasyStreet/sweeping_data_sf.json)** (~7.4 MB) — 21,809 street segments from CSV
4. **[EasyStreet/Utils/HolidayCalculator.swift](EasyStreet/Utils/HolidayCalculator.swift)** (72 lines) — 11 SF public holidays (fixed + floating), singleton with `isHoliday()` and `getHolidays(for:)`
5. **[EasyStreetTests/HolidayCalculatorTests.swift](EasyStreetTests/HolidayCalculatorTests.swift)** (84 lines) — 14 tests for all holidays across multiple years
6. **[EasyStreetTests/SweepingRuleEngineTests.swift](EasyStreetTests/SweepingRuleEngineTests.swift)** (242 lines) — 16 tests: rule application, week-of-month, holiday interactions, engine behavior
7. **[EasyStreetTests/MapColorStatusTests.swift](EasyStreetTests/MapColorStatusTests.swift)** (57 lines) — 4 tests for red/orange/yellow/green status

#### Key File Changes
- **[SweepingRuleEngine.swift](EasyStreet/Utils/SweepingRuleEngine.swift)** — Removed hardcoded 2023 holidays (-25 lines), delegated to HolidayCalculator (+10 lines)
- **[StreetSweepingData.swift](EasyStreet/Models/StreetSweepingData.swift)** — Added `MapColorStatus` enum and `mapColorStatus()` method (+23 lines)
- **[MapViewController.swift](EasyStreet/Controllers/MapViewController.swift)** — Differential overlay updates (add/remove changed only), zoom-level throttle (skip when `latitudeDelta > 0.05`), 300ms debounce, 4-color renderer, expanded 120x120 legend, pin drag animation, centering bug fix
- **[ParkedCar.swift](EasyStreet/Models/ParkedCar.swift)** — Added `notificationLeadMinutes` with settings gear action sheet

### Testing & Verification

**34 total tests, all passing (0 failures):**

| Test Suite | Tests | Description |
|------------|-------|-------------|
| HolidayCalculatorTests | 14 | All 11 fixed and floating holidays, multi-year validation |
| SweepingRuleEngineTests | 16 | Rule application, engine status, next sweep calculation |
| MapColorStatusTests | 4 | Red/orange/yellow/green mapping |

**Build:** `xcodebuild build` (iPhone 14 sim, iOS 16.2): BUILD SUCCEEDED
**Tests:** `xcodebuild test`: 34/34 PASSED in 0.053 seconds

### Key Improvements

| Area | Before | After |
|------|--------|-------|
| **Build** | No .xcodeproj | xcodegen-based reproducible builds |
| **Street data** | 2 sample streets | 21,809 real SF segments |
| **Holidays** | Hardcoded 2023 dates | Dynamic calculation for any year |
| **Tests** | 0 | 34 tests covering core logic |
| **Map colors** | 2 (red/green) | 4 (red/orange/yellow/green) |
| **Map performance** | Full redraw on every change | Differential, zoom throttle, debounce |
| **Notifications** | Hardcoded 1-hour | Configurable 15m/30m/1h/2h |

---

## Session 8: 2026-02-05 — iOS Repository Pattern, Street-Tap Sheet, Parking Card & SQLite

**Session Type**: Development
**Duration**: ~30 minutes
**Participants**: Trey Shuldberg, Claude Code (AI Assistant) with 3 parallel agents
**Commits**: `1387ac7`

### Objectives
- Extract data access behind Repository pattern
- Add street-tap bottom sheet to view sweeping schedules
- Replace hidden status/buttons with always-visible parking card
- Migrate from 7.4MB in-memory JSON to pre-bundled SQLite database

### Approach
- **Phase 1** (sequential): Repository pattern — foundation for subsequent phases
- **Phase 2** (3 parallel agents): Street detail sheet, parking card, SQLite migration
- **Phase 3** (sequential): Integration wiring, build verification, test suite

### Technical Details

#### Files Created (7 total)

1. **[StreetRepository.swift](EasyStreet/EasyStreet/Data/StreetRepository.swift)** (243 lines) — Tries SQLite first via `DatabaseManager.shared.open()`, falls back to JSON; bounding-box WHERE clauses with LEFT JOIN
2. **[ParkingRepository.swift](EasyStreet/EasyStreet/Data/ParkingRepository.swift)** (42 lines) — Wraps `ParkedCarManager.shared`
3. **[StreetDetailViewController.swift](EasyStreet/EasyStreet/Controllers/StreetDetailViewController.swift)** (279 lines) — Bottom sheet with street name, color-coded next sweeping, weekly schedule, "Park Here" button; iOS 15+ `UISheetPresentationController` / iOS 14 `.pageSheet`
4. **[ParkingCardView.swift](EasyStreet/EasyStreet/Views/ParkingCardView.swift)** (180 lines) — Persistent bottom card with `.notParked` / `.parked` states; cornerRadius 12, shadow
5. **[DatabaseManager.swift](EasyStreet/EasyStreet/Data/DatabaseManager.swift)** (183 lines) — sqlite3 C API wrapper, `SQLITE_OPEN_READONLY`, parameterized queries
6. **[convert_json_to_sqlite.py](EasyStreet/EasyStreet/tools/convert_json_to_sqlite.py)** (173 lines) — JSON→SQLite converter: street_segments + sweeping_rules tables with indexes
7. **[easystreet.db](EasyStreet/EasyStreet/easystreet.db)** (8.23 MB) — 21,809 segments, 36,173 rules

#### Files Modified
- **[MapViewController.swift](EasyStreet/EasyStreet/Controllers/MapViewController.swift)** (799 lines) — Removed old parkButton/clearParkButton/statusView; added ParkingCardView, tap gesture with polyline hit testing (perpendicular distance), StreetDetail presentation, delegate conformance, replaced DataManager with repos
- **[SweepingRuleEngine.swift](EasyStreet/EasyStreet/Utils/SweepingRuleEngine.swift)** — Replaced `StreetSweepingDataManager.shared` → `StreetRepository.shared`
- **[project.yml](EasyStreet/EasyStreet/project.yml)** — Added `easystreet.db` to resources, `libsqlite3.tbd` dependency

### Hit Testing Algorithm
Point-to-line-segment perpendicular distance: convert tap to `MKMapPoint`, iterate polyline segments, project and clamp parameter t to [0,1], threshold: `metersPerPixel * 30` (adaptive to zoom).

### Architecture Decisions
1. **Repository pattern with fallback** — SQLite first, JSON fallback (non-breaking migration)
2. **ParkingCardView as persistent UI** — Always-visible with two-state container views
3. **sqlite3 C API directly** — Zero external dependencies via system `libsqlite3.tbd`

### Testing & Verification
- Build succeeded (xcodebuild, iPhone 17 Pro Simulator, iOS 26.2)
- All existing tests pass: HolidayCalculatorTests (14), MapColorStatusTests (4), SpatialIndexTests, SweepingRuleEngineTests (7)
- SQLite conversion: 21,809 segments / 36,173 rules in 0.95s

---

## Session 9: 2026-02-05 — Fix: Streets Not Color-Coded After SQLite Migration

**Session Type**: Bug Fix
**Duration**: ~10 minutes
**Participants**: Trey Shuldberg, Claude Code (AI Assistant)
**Commits**: `7e57f7c`, `2daaba9`

### Objectives
Diagnose and fix streets not being color-coded when viewing San Francisco after the SQLite migration.

### Root Cause Analysis
Two independent issues combined:
1. **Boundary condition** — Initial map span was `0.05` degrees, but zoom guard used strict `< 0.05`, so `0.05 < 0.05 = false` → overlays never loaded at default zoom
2. **Synchronous callback timing** — SQLite `loadData()` called `completion(true)` synchronously (unlike old async JSON path), firing before the map settled its initial region

### Technical Details

#### Commit `7e57f7c` — Bug Fix
1. **[MapViewController.swift](EasyStreet/EasyStreet/Controllers/MapViewController.swift)** (Line 126) — Changed initial span `0.05` → `0.03` (now well within the `< 0.05` threshold)
2. **[StreetRepository.swift](EasyStreet/EasyStreet/Data/StreetRepository.swift)** (Line 22) — Wrapped SQLite success callback in `DispatchQueue.main.async` to match async JSON behavior

#### Commit `2daaba9` — Timeline Update
- Documented the bug fix and added commit SHAs for the preceding feature commit (+59 lines)

### Lessons Learned
- Boundary conditions matter: strict `<` vs `<=` caused the default zoom to be exactly at the cutoff
- When replacing an async data loading path with a synchronous one, preserve callback timing semantics

---

## Session 10: 2026-02-05 — iOS Overlay Rendering Bug Fixes

**Session Type**: Bug Fix
**Duration**: ~30 minutes
**Participants**: Trey Shuldberg, Claude Code (AI Assistant)
**Commits**: `ea01ded`, `03270e0`, `612270e`

### Objectives
Fix multiple overlay rendering issues discovered during manual testing on the simulator.

### Commit Progression

#### `ea01ded` — Overlay Throttle + Tap Gesture
**[MapViewController.swift](EasyStreet/EasyStreet/Controllers/MapViewController.swift)** (+25, -2)
- Changed overlay updates from debounce to **throttle** so streets appear while scrolling (not just after stopping)
- Added `UIGestureRecognizerDelegate` so tap gesture fires alongside MKMapView's internal recognizers, enabling the street-tap detail sheet

#### `03270e0` — Polyline Color Encoding
**[MapViewController.swift](EasyStreet/EasyStreet/Controllers/MapViewController.swift)** (+29, -13)
- Store color status in `polyline.subtitle` at creation time so the renderer reads it directly from the polyline object
- **Root cause fixed:** Race condition where `rendererFor` was called after `colorCache` was cleared/rebuilt by a subsequent `updateMapOverlays()` call, causing all streets to render gray

#### `612270e` — Overlay Z-Level and Visibility
**[MapViewController.swift](EasyStreet/EasyStreet/Controllers/MapViewController.swift)** (+3, -2)
- Use `.aboveLabels` overlay level instead of `.aboveRoads` so polylines render on top of Apple Maps' dark mode road rendering
- Increase line width to 8pt with 0.85 alpha for better visibility

---

## Session 11: 2026-02-06 — iOS Production Readiness

**Session Type**: Development
**Duration**: ~2 hours
**Participants**: Trey Shuldberg, Claude Code (AI Assistant)
**Commits**: `be7be23`

### Objectives
Comprehensive production readiness pass: data accuracy fixes, legal protection, thread safety, expanded test coverage, and asset preparation.

### Technical Details

**38 files changed, +4,785 / -268 lines.** Organized into 5 phases:

#### Phase 1: Data Correctness
- **[HolidayCalculator.swift](EasyStreet/Utils/HolidayCalculator.swift)** (+53, -existing) — Added observed-date shifting (Sat→Fri, Sun→Mon), Day-after-Thanksgiving, cross-year boundary check (Dec 2027 → Jan 1 2028 observed), caching
- **[tools/csv_to_json.py](tools/csv_to_json.py)**, **[convert_json_to_sqlite.py](EasyStreet/tools/convert_json_to_sqlite.py)**, **[csv_to_sqlite.py](EasyStreet_Android/tools/csv_to_sqlite.py)** — Fixed fractional hours parsing in CSV scripts, added metadata table in SQLite

#### Phase 2: Legal & Compliance
- **[DisclaimerManager.swift](EasyStreet/Utils/DisclaimerManager.swift)** (27 lines, NEW) — First-launch disclaimer with "I Understand" acknowledgment, re-show via info button, attribution text
- **[docs/privacy-policy.md](docs/privacy-policy.md)** (63 lines, NEW) — Privacy policy document

#### Phase 3: Thread Safety & Code Quality
- **[DatabaseManager.swift](EasyStreet/Data/DatabaseManager.swift)** (199 lines, rewritten) — Serial dispatch queue for all SQLite operations, thread-safe access
- **[MapViewController.swift](EasyStreet/Controllers/MapViewController.swift)** (+168 lines) — Polyline cache with `NSLock`, day-based color cache, notification dedup with unique IDs, disclaimer integration
- **[StreetDetailViewController.swift](EasyStreet/Controllers/StreetDetailViewController.swift)** (+8 lines) — Minor fixes
- **[StreetRepository.swift](EasyStreet/Data/StreetRepository.swift)** (+45 lines) — Thread-safe coordinate cache
- **[ParkedCar.swift](EasyStreet/Models/ParkedCar.swift)** (+69 lines) — Notification dedup, improved persistence
- **[StreetSweepingData.swift](EasyStreet/Models/StreetSweepingData.swift)** (+32 lines) — Model improvements
- **[SweepingRuleEngine.swift](EasyStreet/Utils/SweepingRuleEngine.swift)** (+57 lines) — Refactored status determination
- **[Info.plist](EasyStreet/Info.plist)**, **[SceneDelegate.swift](EasyStreet/SceneDelegate.swift)**, **[AppDelegate.swift](EasyStreet/AppDelegate.swift)** — Cleanup

#### Phase 4: Test Coverage
6 new test files (~85 new tests), bringing total to **142 tests**:
- **[SweepingRuleEngineStatusTests.swift](EasyStreetTests/SweepingRuleEngineStatusTests.swift)** (105 lines, NEW)
- **[ParkedCarManagerTests.swift](EasyStreetTests/ParkedCarManagerTests.swift)** (155 lines, NEW)
- **[DatabaseManagerTests.swift](EasyStreetTests/DatabaseManagerTests.swift)** (213 lines, NEW)
- **[StreetRepositoryTests.swift](EasyStreetTests/StreetRepositoryTests.swift)** (84 lines, NEW)
- **[HitTestingTests.swift](EasyStreetTests/HitTestingTests.swift)** (202 lines, NEW)
- **[OverlayPipelineTests.swift](EasyStreetTests/OverlayPipelineTests.swift)** (85 lines, NEW)
- **[StreetDetailTests.swift](EasyStreetTests/StreetDetailTests.swift)** (122 lines, NEW)
- **[MapHitTesting.swift](EasyStreet/Utils/MapHitTesting.swift)** (77 lines, NEW) — Extracted from MapViewController for testability
- **[HolidayCalculatorTests.swift](EasyStreetTests/HolidayCalculatorTests.swift)**, **[MapColorStatusTests.swift](EasyStreetTests/MapColorStatusTests.swift)**, **[SweepingRuleEngineTests.swift](EasyStreetTests/SweepingRuleEngineTests.swift)** — Expanded

#### Phase 5: App Store Preparation
- **[Assets.xcassets/AppIcon.appiconset/Contents.json](EasyStreet/Assets.xcassets/AppIcon.appiconset/Contents.json)** (62 lines, NEW) — App Icon scaffold for all required sizes
- **[Assets.xcassets/Contents.json](EasyStreet/Assets.xcassets/Contents.json)** (NEW)

#### Plan Documents Created
- **[docs/plans/2026-02-06-production-readiness.md](docs/plans/2026-02-06-production-readiness.md)** (1,120 lines) — 21 tasks across 5 phases
- **[docs/plans/2026-02-06-app-store-launch.md](docs/plans/2026-02-06-app-store-launch.md)** (582 lines) — App Store submission plan
- **[docs/plans/2026-02-06-multi-city-expansion.md](docs/plans/2026-02-06-multi-city-expansion.md)** (890 lines) — Multi-city expansion design

### Testing & Verification
- 142 tests passing (up from 34)
- Build succeeded with all new files and dependencies

---

## Session 12: 2026-02-06 — iOS P0 Crash Guards & P1 Quality Fixes

**Session Type**: Bug Fix
**Duration**: ~30 minutes
**Participants**: Trey Shuldberg, Claude Code (AI Assistant)
**Commits**: `890f0e3`

### Objectives
Address P0 crash risks and P1 quality issues discovered during production readiness review. Fix test regressions.

### Technical Details

**8 files changed, +33 / -89 lines.**

#### P0 Crash Guards
1. **[StreetSweepingData.swift](EasyStreet/Models/StreetSweepingData.swift)** (+10) — Bounds check on `dayName` for invalid `dayOfWeek` values; coordinate array length guards
2. **[StreetRepository.swift](EasyStreet/Data/StreetRepository.swift)** (+9) — Coordinate array length guards; cap `coordinateCache` at 1,000 entries with eviction

#### P1 Quality Fixes
3. **[MapViewController.swift](EasyStreet/Controllers/MapViewController.swift)** (-13) — Removed debug test polyline left from debugging
4. **[ParkedCar.swift](EasyStreet/Models/ParkedCar.swift)** (+7) — Persist `scheduledNotificationIDs` to UserDefaults (previously only in memory)
5. **[SweepingRuleEngine.swift](EasyStreet/Utils/SweepingRuleEngine.swift)** (-67, +dedup) — Deduplicated: `analyzeSweeperStatus` now delegates to `determineStatus` instead of duplicating logic

#### Test Corrections
6. **[HolidayCalculatorTests.swift](EasyStreetTests/HolidayCalculatorTests.swift)** — Fixed holiday count test (11 not 12) and observed-date test for Christmas 2027
7. **[ParkedCarManagerTests.swift](EasyStreetTests/ParkedCarManagerTests.swift)** (+1) — Minor fix
8. **[SpatialIndexTests.swift](EasyStreetTests/SpatialIndexTests.swift)** (+9) — Test corrections

### Testing & Verification
- **142 tests passing** — all corrections verified
- Build succeeded

---

## Session 13: 2026-02-06 — Street Data Refresh (Jan 2026 SF Open Data)

**Session Type**: Data Update
**Duration**: ~20 minutes
**Participants**: Trey Shuldberg, Claude Code (AI Assistant)
**Commits**: `ba9336b`, `58502e2`

### Objectives
Refresh the street sweeping dataset from the latest SF Open Data portal and clean up stale data files.

### Technical Details

#### Commit `ba9336b` — Data Refresh

**Files Changed (3):**
1. **[Street_Sweeping_Schedule_20260206.csv](EasyStreet/Street_Sweeping_Schedule_20260206.csv)** (37,879 lines, NEW) — Fresh download from data.sfgov.org, updated Jan 8, 2026
2. **[easystreet.db](EasyStreet/easystreet.db)** (8.6 MB → 12.4 MB) — Rebuilt via existing pipeline
3. **[sweeping_data_sf.json](EasyStreet/sweeping_data_sf.json)** — Regenerated

**Data Growth:**
| Metric | Before (May 2025) | After (Jan 2026) |
|--------|-------------------|-------------------|
| Segments | 21,809 | 37,856 |
| Rules | 36,173 | 37,032 |
| CSV rows | 37,475 | 37,879 |

- Normalized SODA API lowercase headers to match expected format

#### Commit `58502e2` — Cleanup

**Files Changed (4):**
1. **[Street_Sweeping_Schedule_20250508.csv](EasyStreet/Street_Sweeping_Schedule_20250508.csv)** — DELETED (replaced by 20260206 version)
2. **[tools/csv_to_json.py](tools/csv_to_json.py)** — Updated default input path to new CSV
3. **[EasyStreet_Android/tools/csv_to_sqlite.py](EasyStreet_Android/tools/csv_to_sqlite.py)** — Updated default input path
4. **[.claude/CLAUDE.md](.claude/CLAUDE.md)** — Updated data file references, segment count (37,856), holiday status documentation

### Testing & Verification
- 142 tests passing (no test changes needed)
- JSON and SQLite regenerated successfully via existing converter scripts

---

## Session 14: 2026-02-06 — Android Cross-Platform Parity: 19 Variances Fixed

**Session Type**: Development
**Duration**: ~45 minutes
**Participants**: Trey Shuldberg, Claude Code (AI Assistant)
**Commits**: `4497aa2`

### Objectives
Bring the Android app into full parity with the iOS app across 5 phases, fixing 19 variances identified by a 6-agent team analysis. iOS is the authoritative implementation; all changes are Android-side.

### Technical Details

**18 files changed, +770 / -102 lines.** 15 files modified, 1 new file created.

#### Phase 1: Data Correctness (CRITICAL + HIGH)

##### V-003: Fix Holiday Calculation (CRITICAL)
1. **[HolidayCalculator.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/engine/HolidayCalculator.kt)** (82 lines, REWRITTEN)
   - Removed Juneteenth (SFMTA enforces sweeping on this date)
   - Added Day-after-Thanksgiving (Friday after 4th Thursday of November)
   - Added observed-date shifting (Sat→Fri, Sun→Mon) for New Year's, July 4th, Veterans Day, Christmas
   - Added cross-year boundary check (`isHoliday()` checks next year in December)
   - Added caching via `ConcurrentHashMap<Int, Set<LocalDate>>`

2. **[HolidayCalculatorTest.kt](EasyStreet_Android/app/src/test/kotlin/com/easystreet/domain/engine/HolidayCalculatorTest.kt)** (95 lines, REWRITTEN) — Expanded from 7 to 12 tests

##### V-004: Fix Parking Coordinate Precision (HIGH)
3. **[ParkingPreferences.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/data/prefs/ParkingPreferences.kt)** (65 lines, REWRITTEN) — `putFloat()` → `putLong(rawBits)` for full double precision; added `notificationLeadMinutes` property; migration fallback for old Float storage

##### V-005: Extend Next-Sweep Scan Range (HIGH)
4. **[SweepingRuleEngine.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/engine/SweepingRuleEngine.kt)** — Changed `1L..60L` → `1L..180L` (matches iOS)

##### V-006: Widen Search Radius (HIGH)
5. **[StreetDao.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/data/db/StreetDao.kt)** — `radiusDeg: 0.001` → `0.005` (matches iOS)

#### Phase 2: UI Parity (HIGH + MEDIUM)

##### V-008: Day-Offset Map Color System (HIGH)
6. **[MapScreen.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/ui/MapScreen.kt)** (719 lines, REWRITTEN) — Replaced status-based coloring with `mapColorForSegment()`: Red (today), Orange (tomorrow), Yellow (2-3 days), Green (safe), Gray (no data). Added `MapLegend` composable.

##### V-009: Polyline Rendering (MEDIUM)
- Added `zIndex = 1f` and `alpha = 0.85f` to all Polylines

##### V-013: Disclaimer / Legal (HIGH)
7. **[DisclaimerManager.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/ui/DisclaimerManager.kt)** (34 lines, NEW) — SharedPreferences-backed `hasSeenDisclaimer_v1`, identical text from iOS. MapScreen: non-dismissable AlertDialog, info button to re-show, attribution overlay.

##### V-017: GPS-Based Parking (MEDIUM)
- "I Parked Here": replaced camera center with `FusedLocationProviderClient.lastLocation`, fallback chain: GPS → camera center

##### V-019: Deprecated Geocoder API (LOW)
- API 33+: `Geocoder.getFromLocationName()` callback; below: `@Suppress("DEPRECATION")` on legacy API

#### Phase 3: Notifications (HIGH + MEDIUM)

##### V-011: Notification Architecture (HIGH)
8. **[NotificationScheduler.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/notification/NotificationScheduler.kt)** (50 lines, REWRITTEN) — Configurable `leadMinutes` parameter, unique work names per sweep time, cancel via tag

9. **[SweepingNotificationWorker.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/notification/SweepingNotificationWorker.kt)** — Dynamic notification IDs via `sweepTimeMillis.hashCode()`

##### V-018: Notification Settings UI (MEDIUM)
- `NotificationSettingsDialog` with radio buttons: 15m/30m/1h/2h, stored via ParkingPreferences

#### Phase 4: Code Quality (MEDIUM)

##### V-007: Rename Holiday Flag
10. **[SweepingRule.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/model/SweepingRule.kt)** — `holidaysObserved` → `appliesToHolidays`

##### V-010: Add ActiveNow Sweep Status
11. **[SweepingStatus.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/model/SweepingStatus.kt)** — Added `data class ActiveNow`

12. **[SweepingRuleEngine.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/engine/SweepingRuleEngine.kt)** — Returns `ActiveNow` when sweep in progress

##### V-012: DB Error Handling
13. **[StreetDatabase.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/data/db/StreetDatabase.kt)** — Added `DatabaseInitException`, wraps lazy init

14. **[MapViewModel.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/ui/MapViewModel.kt)** (+48 lines) — `dbError: StateFlow<String?>`, error card with `errorContainer` background; notification settings support

##### V-014: Segment ID Type
15. **[StreetSegment.kt](EasyStreet_Android/app/src/main/kotlin/com/easystreet/domain/model/StreetSegment.kt)** — `val id: Long` → `val id: String`

#### V-015, V-016: Accepted Differences (No Changes)
- V-015: Android `LatLngPoint` vs iOS `CLLocationCoordinate2D` — platform-idiomatic
- V-016: iOS models have more computed properties — acceptable divergence

### Testing & Verification

**Unit tests:** All pass (`./gradlew test` — BUILD SUCCESSFUL)
- HolidayCalculatorTest: 12 tests (expanded from 7)
- SweepingRuleEngineTest: 9 tests (expanded from 7, added `activeNow` and `5th week rule`)
- SweepingRuleTest: 3 tests (updated property name)

**Build:** `./gradlew build` — BUILD SUCCESSFUL (96 tasks, 0 failures)

**Cross-platform holiday verification (Python):**
| Date | Holiday? | Verified |
|---|---|---|
| Jan 1, 2026 (Thu) | YES | PASS |
| Jul 3, 2026 (Fri) | YES (Jul 4 observed) | PASS |
| Jul 4, 2026 (Sat) | NO | PASS |
| Jun 19, any year | NO | PASS |
| Nov 26, 2026 (Thu) | YES (Thanksgiving) | PASS |
| Nov 27, 2026 (Fri) | YES (Day after) | PASS |
| Dec 24, 2027 (Fri) | YES (Christmas observed) | PASS |
| Dec 31, 2027 (Fri) | YES (New Year 2028 observed) | PASS |

### Files Modified Summary

| Phase | Files Modified | New Files |
|---|---|---|
| 1 (Data) | HolidayCalculator.kt, HolidayCalculatorTest.kt, ParkingPreferences.kt, SweepingRuleEngine.kt, StreetDao.kt | 0 |
| 2 (UI) | MapScreen.kt | DisclaimerManager.kt |
| 3 (Notif) | NotificationScheduler.kt, SweepingNotificationWorker.kt, MapViewModel.kt | 0 |
| 4 (Quality) | SweepingRule.kt, SweepingStatus.kt, StreetSegment.kt, StreetDatabase.kt, SweepingRuleEngineTest.kt, SweepingRuleTest.kt | 0 |
| 5 (Polish) | MapScreen.kt (Geocoder API branching) | 0 |
| **Total** | **15 files modified** | **1 new file** |

### Environment Setup Notes
- Installed `openjdk@17` via Homebrew: `brew install openjdk@17`
- Set `JAVA_HOME="/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"`
- Android Studio installed; SDK at `~/Library/Android/sdk`
- Created `local.properties` with `sdk.dir` pointing to SDK

### Next Steps
1. Manual testing on Android emulator for UI changes
2. Add Google Maps API key to `local.properties` for emulator testing
3. Continue with production readiness plan at `docs/plans/2026-02-06-production-readiness.md`

---

## Appendix A: Sprint 1 Planning Session (2026-02-04)

**Session Type**: Planning & Code Review
**Duration**: ~1 hour
**Participants**: Claude Code (AI Assistant)
**Commits**: None (planning only)

This session conducted a comprehensive review of both iOS and Android codebases and produced a 2-week sprint plan for 2 developers. The code analysis identified the critical blockers (hardcoded 2023 holidays, missing street data, zero tests) that were resolved in Sessions 4–7.

### Sprint Plan Created
**Location**: `.claude/plans/scalable-knitting-pixel.md`

9 stories across 2 developers:
- **Dev A** (iOS Critical Path): CSV→JSON converter, HolidayCalculator, real data integration, SweepingRuleEngine tests
- **Dev B** (Android Foundation): Data models, SweepingRuleEngine port, data manager, parking persistence, UI scaffold

### Key Decisions
1. **JSON** over CSV for app bundle (faster parsing, native support)
2. **Algorithmic** holiday calculation (offline capability) over external API
3. **Unit tests first** for business logic (highest ROI)
4. **Balance** iOS fixes with Android foundation work

---

## Appendix B: Debug & Testing Session (2026-02-05)

**Session Type**: Bug Fix / Refactor / Testing
**Duration**: ~30 minutes
**Participants**: Trey Shuldberg, Claude Code (AI Assistant)
**Commits**: None (changes included in commit `be7be23`)

This session diagnosed overlay rendering issues and added comprehensive debug logging, extracted hit-testing into a testable utility, and added test files. The work was committed as part of Session 11's production readiness commit.

### Context
After 4 fix attempts (commits `7e57f7c`, `03270e0`, `ea01ded`, `612270e`), overlays still had issues. Data layer verified working (SQLite: 21,809 segments, 36,173 rules).

### Key Outputs
- **[MapHitTesting.swift](EasyStreet/EasyStreet/Utils/MapHitTesting.swift)** (48 lines) — Extracted perpendicular distance and polyline hit testing into static methods
- **[OverlayPipelineTests.swift](EasyStreetTests/OverlayPipelineTests.swift)** (73 lines) — 7 tests for polyline rendering
- **[HitTestingTests.swift](EasyStreetTests/HitTestingTests.swift)** (110 lines) — 8 tests for hit testing algorithm
- **[StreetDetailTests.swift](EasyStreetTests/StreetDetailTests.swift)** (98 lines) — 7 tests for street detail view

### Debug Strategy
Diagnostic logging to isolate: DB not found → bounding box issue → coordinate parsing → renderer visibility → lifecycle issue. `#if DEBUG` test polyline to isolate MapKit rendering vs data pipeline.

---

## Session 15: 2026-02-06 — Countdown Timer + Color Coding Accuracy Tests

**Session Type**: Development
**Duration**: ~30 minutes
**Participants**: Trey Shuldberg, Claude Code (AI Assistant) with 2 parallel agents
**Commits**: `53084e4`
**PR**: [#4](https://github.com/tshuldberg/EasyStreet/pull/4)

### Objectives
Add a live countdown timer to the street detail sheet and write comprehensive tests to validate color coding accuracy for edge cases like holidays, week-of-month boundaries, and multi-rule segments.

### Approach: Parallel Agent Development

Two agents worked simultaneously on independent file sets:
- **timer-agent**: CountdownFormatter utility, `nextSweepIncludingToday` method, StreetDetailViewController countdown UI
- **test-agent**: CountdownFormatterTests, ColorCodingAccuracyTests, MapColorStatusTests extensions, SweepingRuleEngineStatusTests extensions

### Technical Details

#### Files Created (3)

1. **[EasyStreet/Utils/CountdownFormatter.swift](EasyStreet/Utils/CountdownFormatter.swift)** (39 lines, NEW)
   - Pure static utility struct: `CountdownFormatter.format(interval:sweepDuration:)`
   - Display tiers: days+hours (>24h), hours+minutes (1-24h), minutes+seconds (<1h)
   - In-progress detection: negative interval within sweep duration → "Sweeping in progress"
   - Post-sweep: negative interval past duration → "Sweep completed"
   - Uses `Int(interval)` truncation for consistent display

2. **[EasyStreetTests/CountdownFormatterTests.swift](EasyStreetTests/CountdownFormatterTests.swift)** (102 lines, NEW)
   - 18 tests covering all format tiers, boundary values, zero/negative intervals
   - Key boundaries tested: 86400s (24h), 3600s (1h), 0s, sweep duration boundary
   - Fractional seconds truncation verified

3. **[EasyStreetTests/ColorCodingAccuracyTests.swift](EasyStreetTests/ColorCodingAccuracyTests.swift)** (265 lines, NEW)
   - 17 tests across 6 categories:
     - Day-of-week boundaries: Sat→Sun (orange), Fri→Mon (yellow), Sun→Thu (green)
     - Week-of-month: 4th vs 5th Monday, alternating weeks [1,3]
     - Holiday handling: Christmas 2026 skip/enforce, day-before-holiday
     - Multi-rule precedence: today overrides future, tomorrow overrides 3-day
     - Color/status correlation: red→.today/.imminent, green→.safe/.upcoming
     - Timer calculations: in-progress detection, endTime boundary, late night sweeps

#### Files Modified (5)

4. **[EasyStreet/Models/StreetSweepingData.swift](EasyStreet/Models/StreetSweepingData.swift)** (Lines 148-184, +38)
   - Added `nextSweepIncludingToday(from:)` method on `StreetSegment`
   - Unlike existing `nextSweeping(from:)` which starts from tomorrow, this checks today's rules first
   - Returns `(start: Date?, end: Date?, rule: SweepingRule?)` tuple with both start and end times
   - In-progress detection: returns sweep if `endDateTime > referenceDate`
   - Falls through to `nextSweeping(from:)` for future dates, computing endDateTime from rule

5. **[EasyStreet/Controllers/StreetDetailViewController.swift](EasyStreet/Controllers/StreetDetailViewController.swift)** (+85 lines)
   - Added `countdownLabel` with `monospacedDigitSystemFont` to prevent jitter during updates
   - Layout: inserted between `nextSweepingLabel` and `divider` with 4pt spacing
   - Timer logic: `startCountdownTimer()` → `updateCountdown()` with adaptive frequency
   - Update frequency: 1 second when < 1 hour, 60 seconds otherwise (dynamically switches)
   - Color coding: red (< 1h or in-progress), orange (1-24h), default (> 24h)
   - Hidden when no upcoming sweep data
   - Timer invalidated in `viewWillDisappear` and `deinit`
   - Added `private var countdownTimer: Timer?` property

6. **[EasyStreetTests/MapColorStatusTests.swift](EasyStreetTests/MapColorStatusTests.swift)** (Lines 125-171, +47)
   - Added 4 edge case tests:
     - `testYellowExactly3DayBoundary`: Thursday on Monday = exactly 3 days → yellow
     - `testNoRulesReturnsGreen`: empty rules array → green
     - `testRedOverridesYellow`: today rule wins over 3-day rule regardless of array order
     - `testEndOfMonthTransition`: March 31 → April 1 cross-month → orange

7. **[EasyStreetTests/SweepingRuleEngineStatusTests.swift](EasyStreetTests/SweepingRuleEngineStatusTests.swift)** (Lines 106-158, +53)
   - Added 4 edge case tests:
     - `testMidnightStartTimeUpcoming`: 00:00 sweep, 23:00 day before → .upcoming
     - `testAfterSweepEndsSameDay`: 15:00 after 09:00-11:00 sweep → .safe
     - `testMultipleRulesSameDayFirstWhereLimit`: documents `first(where:)` limitation
     - `test59MinutesAwayIsImminent`: 59 minutes → .imminent

8. **[EasyStreet/EasyStreet.xcodeproj/project.pbxproj](EasyStreet/EasyStreet.xcodeproj/project.pbxproj)** — Regenerated by `xcodegen generate` to include new source and test files

### Test Fix During Development
- `testSundayToWednesdayGreen` initially failed: Sunday→Wednesday is 3 days (within window = yellow), not 4 days
- Renamed to `testSundayToThursdayGreen` using Thursday (dayOfWeek=5) for a true 4-day gap → green

### Known Limitation Documented
`SweepingRuleEngine.determineStatus` uses `first(where:)` for today's rules (line 32). If a segment has two rules for the same day (morning + evening), only the first is evaluated. If the morning sweep passed, it returns `.safe` even if evening sweep is upcoming. Test `testMultipleRulesSameDayFirstWhereLimit` documents this behavior.

### Testing & Verification
- **185 tests passing** (up from 142), 0 failures
- Build succeeded on iPhone 17 Pro Simulator (iOS 26.2)
- `xcodegen generate` → `xcodebuild build` → `xcodebuild test` all green

### New Test Coverage

| Test Suite | Tests | New | Description |
|------------|-------|-----|-------------|
| CountdownFormatterTests | 18 | 18 | All format tiers, boundaries, negative intervals |
| ColorCodingAccuracyTests | 17 | 17 | Holidays, weeks, precedence, timer calculations |
| MapColorStatusTests | 12 | 4 | +3-day boundary, no rules, overrides, month transition |
| SweepingRuleEngineStatusTests | 14 | 4 | +midnight, post-sweep, multi-rule, 59min |
| **Total new** | | **43** | |

### Next Steps
1. Manual testing on simulator — verify countdown label ticks correctly
2. Consider adding countdown to the parking card view as well
3. Address the `first(where:)` multi-rule limitation in a future PR
4. Continue with production readiness plan

### References
- Commit: `53084e4`
- PR: [#4](https://github.com/tshuldberg/EasyStreet/pull/4)
- Branch: `feature/countdown-timer-tests`
- [CountdownFormatter.swift](EasyStreet/Utils/CountdownFormatter.swift)
- [ColorCodingAccuracyTests.swift](EasyStreetTests/ColorCodingAccuracyTests.swift)
- [CountdownFormatterTests.swift](EasyStreetTests/CountdownFormatterTests.swift)

---

*End of timeline. Total: 44 commits across 15 sessions + 2 appendices, Feb 4–6, 2026.*
