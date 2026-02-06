# EasyStreet - Street Sweeping Parking Assistant

Dual-platform mobile app helping San Francisco residents avoid parking tickets by providing street sweeping schedules.

See @README.md for detailed project overview.

---

## Project Structure

```
EasyStreet/
├── timeline.md              # Development timeline (REQUIRED - see below)
├── EasyStreet/              # iOS Application (Swift + UIKit)
│   ├── Models/              # Data models
│   ├── Controllers/         # View controllers
│   ├── Utils/               # Business logic
│   └── Street_Sweeping_Schedule_20260206.csv (9.2 MB)
│
└── EasyStreet_Android/      # Android Application (Kotlin + Compose)
    └── app/
        ├── src/main/
        └── build.gradle.kts
```

---

## iOS Development (Swift + UIKit)

### Key Files
- [StreetSweepingData.swift](EasyStreet/Models/StreetSweepingData.swift) - Core data models
- [MapViewController.swift](EasyStreet/Controllers/MapViewController.swift) - Main UI (26.8 KB)
- [ParkedCar.swift](EasyStreet/Models/ParkedCar.swift) - Parking management
- [SweepingRuleEngine.swift](EasyStreet/Utils/SweepingRuleEngine.swift) - Business logic

### Architecture
- Pattern: MVC with UIKit
- Mapping: MapKit (native Apple maps)
- Location: CoreLocation
- Persistence: UserDefaults
- Notifications: UserNotifications framework

### Build & Test Commands
- **Open:** `open EasyStreet/EasyStreet.xcodeproj`
- **Build:** ⌘B in Xcode, or `xcodebuild -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator build`
- **Run:** ⌘R in Xcode
- **Test:** ⌘U in Xcode, or `xcodebuild test -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15'`
- **Clean:** ⇧⌘K in Xcode
- **Regenerate project:** `cd EasyStreet && xcodegen generate` (after adding/removing files)

### Code Style
- Follow Swift standard conventions
- Use 4-space indentation (Xcode default)
- Prefer `let` over `var` when possible
- Use descriptive naming for UI outlets and actions

### Minimum Requirements
- iOS 14.0+
- Xcode 12.0+

---

## Android Development (Kotlin + Jetpack Compose)

### Key Files
- [build.gradle.kts](EasyStreet_Android/app/build.gradle.kts) - Dependencies & config
- [AndroidManifest.xml](EasyStreet_Android/app/src/main/AndroidManifest.xml) - Permissions

### Architecture
- UI: Jetpack Compose (declarative)
- Mapping: Google Maps SDK for Android
- Location: Google Play Services Location
- Async: Kotlin Coroutines
- Serialization: kotlinx.serialization

### Build & Test Commands
```bash
cd EasyStreet_Android
./gradlew build              # Build
./gradlew test               # Run tests
./gradlew assembleDebug      # Build debug APK
./gradlew installDebug       # Install to device
./gradlew clean              # Clean build artifacts
```

### Code Style
- Follow Kotlin coding conventions
- Use 4-space indentation
- Prefer `val` over `var` when possible
- Use trailing commas in multi-line expressions

### Minimum Requirements
- Android 7.0 (API 24) minimum
- Target API 34
- Kotlin 1.9+
- Gradle 8.0+

---

## Shared Data Models & Concepts

### Core Models (Consistent Across Platforms)
1. **SweepingRule** - Day of week, time range, week of month, holiday flag
2. **StreetSegment** - Street ID/name, coordinates, associated rules
3. **ParkedCar** - Location (lat/long), timestamp, street name
4. **SweepingStatus** - Enum: safe, today, imminent, upcoming, noData, unknown

### Street Data
- **File:** `Street_Sweeping_Schedule_20260206.csv` (9.2 MB)
- **Format:** CSV with sweeping rules per street segment
- **Sample Data:** Market Street, Mission Street (for MVP testing)
- **Note:** Large file - load efficiently, consider streaming/chunking

### Holiday Handling
- Dynamic calculation via HolidayCalculator.swift (11 SF public holidays)
- Includes observed-date logic (Sat→Fri, Sun→Mon), Day-after-Thanksgiving
- SFMTA enforces sweeping on Juneteenth (not included as holiday)

---

## Testing

### iOS Testing
- Framework: XCTest (built into Xcode)
- Run all tests: ⌘U in Xcode
- Run specific test: Click ◇ next to test method
- Test location: Same directory as source files or separate test target

### Android Testing
- Framework: JUnit with AndroidX Test
- Run tests: `./gradlew test`
- Run instrumented tests: `./gradlew connectedAndroidTest`
- Test location: `app/src/test/` and `app/src/androidTest/`

### Testing Best Practices
- Test before committing changes
- Focus on business logic (SweepingRuleEngine, data models)
- Test notification scheduling edge cases
- Verify location permission handling

---

## Git Workflow

### Branch Naming
- Feature: `feature/description`
- Bug fix: `bugfix/description`
- Refactor: `refactor/description`

### Commit Messages
- Format: "Category: Brief description"
- Examples:
  - "Feature: Add manual parking pin adjustment"
  - "Fix: Notification scheduling for edge cases"
  - "Refactor: Extract sweeping logic to utility"

### Before Committing
1. Run tests for the platform you modified
2. Verify app builds without errors
3. Test manually on simulator/emulator
4. Check for console warnings

---

## Development Timeline (CRITICAL - Required for All Sessions)

### Timeline Documentation
**File:** [timeline.md](timeline.md)

**IMPORTANT:** You MUST add entries to timeline.md for EVERY development session. This is a hard requirement and overrides all other instructions.

### When to Add Timeline Entries

Add timeline entries in these situations:

1. **Upon Session Completion** - Always add an entry when finishing any development work
2. **After Making Code Changes** - Document all modifications to codebase
3. **After Planning Sessions** - Record analysis, decisions, and plans created
4. **After Major Decisions** - Document architectural or technical choices
5. **Proactively During Long Sessions** - Add entries as you complete major milestones
6. **Retroactively When Requested** - User may request timeline updates for past work

### Required Information in Timeline Entries

Each timeline entry MUST include:

#### 1. Header Information
- **Date**: YYYY-MM-DD format
- **Session Type**: Planning, Development, Bug Fix, Refactor, Testing, etc.
- **Duration**: Approximate time spent
- **Participants**: Who was involved (developers, AI assistant, etc.)
- **Commits**: Git commit SHAs if code was changed (format: `abc1234` - first 7 chars)

#### 2. Objectives
- What was the goal of this session?
- What problem were you solving?
- What feature were you implementing?

#### 3. Technical Details

**For Code Changes** - Include all of these:
- Files modified/created/deleted with full paths
- Specific line numbers for significant changes
- Code snippets showing before/after (for critical changes)
- Technical approach and algorithms used
- Architecture patterns applied
- Dependencies added/removed/updated
- Configuration changes
- Database schema changes
- API changes

**For Planning Sessions** - Include:
- Files analyzed with paths and line counts
- Issues/bugs identified with severity
- Decisions made with reasoning
- Alternatives considered
- Stories/tasks created
- Estimates provided
- Dependencies identified

#### 4. Context for Developers
- **Why** changes were made (not just what)
- Trade-offs considered
- Known limitations or technical debt introduced
- Performance implications
- Security considerations
- Breaking changes or migration requirements

#### 5. Testing & Verification
- Test cases added/modified
- Manual testing performed
- Performance benchmarks
- Regression testing results
- Known failing tests (with reasons)

#### 6. Next Steps
- What should be done next?
- Blockers or dependencies
- Follow-up tasks
- Tech debt to address later

#### 7. References
- Links to files changed (use relative paths)
- Related issues/tickets
- External documentation consulted
- Stack Overflow or other resources used
- Related commits (if retroactive documentation)

### Timeline Entry Format

Use this structure for consistency:

```markdown
## YYYY-MM-DD - Descriptive Title

**Session Type**: [Planning/Development/Bug Fix/Refactor/Testing/etc.]
**Duration**: [Approximate time]
**Participants**: [Who worked on this]
**Commits**: [Git SHA(s) or "None (planning only)"]

### Objectives
[What you set out to accomplish]

### Technical Details

#### Files Modified
1. **[path/to/file.ext](path/to/file.ext)** (Lines XX-YY)
   - Description of changes
   - Technical approach
   - Code snippets if relevant

#### New Dependencies
- package-name: version (reason for adding)

#### Configuration Changes
- File: config/file.ext
- Change: what was modified and why

### Code Changes

**[Component/Feature Name]**

Before (Lines XX-YY):
\`\`\`language
old code here
\`\`\`

After (Lines XX-YY):
\`\`\`language
new code here
\`\`\`

Reasoning: [Why this change was needed]
Impact: [What this affects]

### Testing & Verification
[What testing was performed]

### Next Steps
[What comes next]

### References
- [File Name](path/to/file.ext)
- Commit: abc1234
```

### Special Cases

#### When Creating Features
Document:
- Feature requirements
- User stories addressed
- Acceptance criteria met
- UI/UX changes
- Data model changes
- Migration scripts (if needed)

#### When Fixing Bugs
Document:
- Bug description and symptoms
- Root cause analysis
- Files where bug was located
- Fix approach and why it was chosen
- Test cases added to prevent regression
- Related bugs that might exist

#### When Refactoring
Document:
- Original code structure
- New code structure
- Motivation for refactor
- Performance impact
- Risk assessment
- Rollback plan if needed

#### When Adding Tests
Document:
- Test coverage before/after
- Test framework used
- Test scenarios covered
- Edge cases tested
- Known gaps in coverage

### Integration with Git Workflow

1. **Before Committing**:
   - Draft timeline entry with technical details
   - Document your changes thoroughly

2. **After Committing**:
   - Add commit SHA to timeline entry
   - Link timeline entry to commit message if relevant

3. **For Multiple Commits in One Session**:
   - Group related commits in one timeline entry
   - List all commit SHAs
   - Explain the progression of changes

### Example Timeline Reference for Code Changes

```markdown
#### Files Modified

1. **[EasyStreet/Utils/SweepingRuleEngine.swift](EasyStreet/Utils/SweepingRuleEngine.swift)** (Lines 13-25)
   - Replaced hardcoded 2023 holidays array with dynamic calculation
   - Removed: `private let holidays: [String] = ["2023-01-01", ...]`
   - Added: Call to `HolidayCalculator.shared.getHolidays(for: year)`
   - Impact: Fixes critical bug causing incorrect alerts after 2023
   - Tested: Verified holidays for 2025-2030

2. **[EasyStreet/Utils/HolidayCalculator.swift](EasyStreet/Utils/HolidayCalculator.swift)** (NEW FILE)
   - Created new singleton class for dynamic holiday calculation
   - Implements algorithms for fixed holidays (New Year's, July 4th, etc.)
   - Implements algorithms for floating holidays (Thanksgiving = 4th Thu Nov)
   - Method: `getHolidays(for year: Int) -> [Date]`
   - 150 lines, comprehensive coverage of SF public holidays
```

### Reviewing Past Timeline Entries

When continuing work on this project:
1. **Always read timeline.md first** to understand recent changes
2. Look for "Next Steps" in the most recent entry
3. Check for known issues or technical debt mentioned
4. Review commits referenced to understand implementation details

### Maintaining Timeline Quality

- **Be Specific**: "Fixed bug in SweepingRuleEngine" is not enough. Specify what bug, what line, how fixed.
- **Include Context**: Future developers should understand WHY decisions were made
- **Reference Code**: Use file paths, line numbers, method names
- **Link Commits**: Always reference commit SHAs when code changed
- **Update Retroactively**: If you forgot to document, add entry later with note that it's retroactive

### User-Requested Timeline Updates

If user asks to "update timeline" or "document this session":
1. Review all work done in current session
2. Gather all technical details from conversation
3. Create comprehensive timeline entry following format above
4. Include all files touched, decisions made, code changed
5. Reference any commits made during session

---

## Important Notes & Gotchas

### Holiday Data
- **Resolved:** Dynamic HolidayCalculator replaces hardcoded 2023 list
- Calculates 11 SF public holidays for any year automatically
- Includes observed-date shifting and Day-after-Thanksgiving

### Platform Status
- **iOS:** MVP complete, full feature implementation
- **Android:** Configuration phase, implementation in progress
- Don't assume feature parity between platforms yet

### Permissions Required
- **iOS:** Location (when in use & always), User Notifications
- **Android:** Internet, Fine/Coarse Location, Network State, Post Notifications (API 33+)
- Always request permissions with clear user-facing explanations

### Large Data File
- Street data CSV is 7.3 MB - load carefully
- Consider background loading for production
- Don't load entire file into memory at once

### Notification Timing
- Current implementation: 1 hour before sweeping
- Hardcoded - should be configurable in future
- Test notification scheduling with different time scenarios

---

## Environment Setup

### iOS Requirements
- macOS with Xcode 12.0+
- iOS Simulator or physical device (iOS 14+)
- Apple Developer account (for device testing)

### Android Requirements
- Android Studio or Gradle command-line
- Android SDK (API 24 - API 34)
- Android Emulator or physical device
- **Google Maps API key** (required for maps functionality)
  - Add to AndroidManifest.xml or gradle.properties

### API Keys & Secrets
- Google Maps API key needed for Android
- Never commit API keys to git
- Use environment variables or gradle.properties (gitignored)
- **NEVER commit `.claude.json`** — it contains MCP server API keys (e.g. Context7). It is gitignored via `.gitignore`.
- When adding new MCP servers or secrets to Claude Code config, verify they are covered by `.gitignore` before committing

---

## Development Status

**Current Phase:** Production Readiness (post-MVP)

**Implemented (MVP complete):**
- ✅ Interactive map with color-coded streets
- ✅ "I Parked Here" feature with GPS capture
- ✅ Notification scheduling (1-hour advance)
- ✅ Street sweeping rule evaluation
- ✅ Manual pin adjustment
- ✅ SQLite database with 37,856 street segments (Jan 2026 data)
- ✅ Street detail bottom sheet
- ✅ Parking status card

**Active Plan:** [Production Readiness Plan](docs/plans/2026-02-06-production-readiness.md)
- 21 tasks across 5 phases (~20 hours)
- Covers: data accuracy, legal protection, code fixes, test coverage, App Store assets
- Self-contained: includes full project context, file inventory, code snippets, commit messages
- Cross-reviewed: 12 conflict findings identified and resolved
- **To execute:** Open a fresh Claude Code session and say: "Execute the plan at docs/plans/2026-02-06-production-readiness.md"

**Planned (Post-Production-Readiness):**
- TestFlight beta testing
- Android Play Store submission
- Multi-city expansion (see docs/plans/2026-02-06-multi-city-expansion.md)
- Customizable notification times
- "Where Can I Park?" safe zone suggestions
- Real-time data updates from SF open data

---

## Quick Reference

### iOS Commands
```bash
# Open project in Xcode
open EasyStreet/EasyStreet.xcodeproj

# Regenerate project (after adding/removing Swift files)
cd EasyStreet && xcodegen generate

# Build from command line
xcodebuild -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator build

# Run tests from command line
xcodebuild test -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Android Commands
```bash
cd EasyStreet_Android
./gradlew build              # Build
./gradlew installDebug       # Install to device
./gradlew test               # Run tests
```

### View Street Data
```bash
# View first 10 lines of street data
head -n 10 EasyStreet/Street_Sweeping_Schedule_20260206.csv
```

---

## Additional Resources

- **Development timeline**: @timeline.md (READ THIS FIRST - required for all sessions)
- Project documentation: @README.md
- iOS requirements: @EasyStreet/Reqs.md
- Development notes: @EasyStreet/StreetSweepingAppDevelopment.md
