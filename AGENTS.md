# AGENTS.md — EasyStreet (Native)

Instructions for agents working in `/Users/trey/Desktop/Apps/Parks/EasyStreet`.

## Overview

EasyStreet is a dual-platform street-sweeping assistant for San Francisco:
- iOS app (Swift + UIKit)
- Android app (Kotlin + Jetpack Compose)

## Instruction Sync (Critical)

- Keep `/Users/trey/Desktop/Apps/Parks/EasyStreet/AGENTS.md` and `/Users/trey/Desktop/Apps/Parks/EasyStreet/.claude/CLAUDE.md` synchronized for persistent project rules.
- Any new rule or rule change must be applied in both files in the same change.

## Core References

- Main project context: `/Users/trey/Desktop/Apps/Parks/EasyStreet/.claude/CLAUDE.md`
- Project docs: `/Users/trey/Desktop/Apps/Parks/EasyStreet/README.md`
- Session tracking: `/Users/trey/Desktop/Apps/Parks/EasyStreet/timeline.md`

## Project Structure

```text
EasyStreet/            iOS app (Swift/UIKit)
EasyStreetTests/       iOS tests
EasyStreet_Android/    Android app (Kotlin/Compose)
docs/                  plans and supporting docs
timeline.md            required development tracking
```

## Key Commands

### iOS

```bash
open EasyStreet/EasyStreet.xcodeproj
xcodebuild -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator build
xcodebuild test -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15'
cd EasyStreet && xcodegen generate
```

### Android

```bash
cd EasyStreet_Android
./gradlew build
./gradlew test
./gradlew assembleDebug
```

## Domain Rules

- Keep sweeping-rule logic and holiday handling consistent with existing model semantics (`SweepingRule`, `StreetSegment`, `ParkedCar`, `SweepingStatus`).
- Holiday behavior uses dynamic calculation with observed-date logic; avoid hardcoded static year lists.
- Street data CSV is large; prefer memory-conscious loading strategies.

## Validation Requirements

Before completion:
1. Build/test the platform(s) you modified.
2. Verify notification and permission-related flows when changes touch location/time logic.
3. Include manual verification notes for map/location UX changes.

## Collaboration Rules

- Default to one agent/session unless tasks are independent.
- If parallelizing, assign clear file ownership:
  - iOS: `EasyStreet/`
  - Android: `EasyStreet_Android/`
  - Docs/tracking: `docs/`, `timeline.md`, `README.md`
- Include full task context (paths, acceptance criteria, constraints) when delegating.

## Timeline Is Mandatory

- Update `/Users/trey/Desktop/Apps/Parks/EasyStreet/timeline.md` for every meaningful session (planning, implementation, bug-fix, refactor, testing).
- Include objectives, files changed, technical decisions, validation performed, and next steps.
- Keep entries specific and reviewable; do not replace historical entries.

## Security and Secrets

- Never commit API keys or secrets.
- Keep local secret-bearing config files gitignored.
- Do not commit `.claude.json` if it contains MCP/API credentials.

## Workspace Skill

- `/daily-report-ops` — `/Users/trey/Desktop/Apps/.claude/skills/daily-report-ops/SKILL.md`
