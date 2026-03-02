# Auto-Detect Parking — Design Document

**Date:** 2026-02-09
**Status:** Approved
**Platform:** iOS

## Overview

When enabled, the app detects when a user stops driving and walks away from their car, then prompts via iOS notification to save the parking spot. The user taps "Yes, Save Spot" and their parked location is recorded — no need to open the app.

## Detection Pipeline

### APIs Used

- **`CMMotionActivityManager`** — classifies device activity as automotive, walking, stationary, etc. Battery-efficient (uses motion coprocessor).
- **`CLLocationManager.startMonitoringSignificantLocationChanges()`** — wakes the app on ~200m location changes. Very low battery impact compared to continuous GPS.

### State Machine

```
idle → driving → possiblePark → (3-min timer) → confirmed → notification sent → idle
                      ↓
              (driving resumes) → idle (false positive filtered)
```

**States:**

| State | Entry Condition | Behavior |
|---|---|---|
| `idle` | Default / reset | Monitoring activity, waiting for automotive |
| `driving` | CoreMotion reports `automotive` (confidence ≥ medium) | Tracking location, waiting for stop |
| `possiblePark` | Was `driving`, now `walking` or `stationary` | Captures GPS coordinate, starts 3-minute timer |
| `confirmed` | 3-minute timer expires, still not driving | Resolves street name, fires notification |

**False positive filters:**

- **3-minute confirmation timer** — red lights (30-60s), drive-throughs, and quick stops are filtered out because the user resumes driving before the timer expires
- **CoreMotion confidence threshold** — only `medium` or `high` confidence automotive activity triggers the `driving` state
- **Activity transition required** — must go from `automotive` → `walking`/`stationary`, not just a speed drop

### Location Capture

The GPS coordinate is captured at the moment the `possiblePark` state begins (where the car stopped), not where the user walks to after exiting the vehicle.

## Notification UX

### Prompt

- **Title:** "Did you just park?"
- **Body:** "It looks like you parked on [Street Name]"
- **Sound:** Default

### Actions

| Action | Identifier | Behavior |
|---|---|---|
| Yes, Save Spot | `confirmPark` | Calls `ParkingRepository.parkCar(at:streetName:)` — triggers existing sweeping status check and alert scheduling |
| No | `dismissPark` | Dismisses notification, resets state machine to `idle` |

### No Response

If the user ignores the notification, no parking is saved. The state machine resets to `idle` after 10 minutes so it can detect subsequent parking events.

### Notification Category

Register `UNNotificationCategory` with identifier `"parkingDetection"` containing the two actions above. Handle in the existing `UNUserNotificationCenterDelegate` conformance.

## Permissions

### Opt-In Model

- **Settings toggle:** "Auto-Detect Parking" (OFF by default)
- **Enabling** requests:
  - `CLLocationManager.requestAlwaysAuthorization()` — required for background location
  - `CMMotionActivityManager` access — requires `NSMotionUsageDescription` in Info.plist
- **Disabling** stops all background monitoring immediately
- Users who never enable the feature never see additional permission prompts

### Info.plist Additions

| Key | Value |
|---|---|
| `NSMotionUsageDescription` | "EasyStreet uses motion data to detect when you've parked your car so it can remind you to save your spot." |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | "EasyStreet uses your location in the background to detect when you've parked and alert you about street sweeping near your car." |
| `UIBackgroundModes` | Add `location` |

## Architecture

### New Files

| File | Purpose |
|---|---|
| `EasyStreet/Services/ParkingDetectionService.swift` | Singleton service. Manages CoreMotion + location monitoring, runs state machine, fires notifications. |
| `EasyStreet/Models/ParkingDetectionState.swift` | State enum (`idle`, `driving`, `possiblePark`, `confirmed`) and transition validation logic. |

### Modified Files

| File | Change |
|---|---|
| `MapViewController.swift` | Initialize/teardown `ParkingDetectionService` based on settings toggle. Handle `confirmPark` notification action by calling `parkingRepo.parkCar()`. |
| `ParkedCar.swift` | Register `"parkingDetection"` notification category with Yes/No actions during notification setup. |
| `Info.plist` | Add `NSMotionUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `UIBackgroundModes: location`. |
| Settings UI | Add "Auto-Detect Parking" toggle backed by `UserDefaults`. On enable: request permissions + start service. On disable: stop service. |

### Design Patterns

- **Singleton** (`ParkingDetectionService.shared`) — consistent with `ParkedCarManager.shared`, `SweepingRuleEngine.shared`, `StreetRepository.shared`
- **State machine in separate model** — testable in isolation without CoreMotion/location dependencies
- **Feeds into existing parking flow** — `parkCar(at:streetName:)` triggers all existing sweeping status checks, map annotation updates, and notification scheduling

### Integration Point

```
ParkingDetectionService (new)
    ↓ confirms parking
ParkingRepository.parkCar(at:streetName:)  (existing)
    ↓
ParkedCarManager saves to UserDefaults (existing)
    ↓
NotificationCenter.post(.parkedCarStatusDidChange) (existing)
    ↓
MapViewController updates annotation + card (existing)
```

## Battery Considerations

- **Significant location changes** (~200m threshold) use cell tower/WiFi triangulation, not GPS — very low battery impact
- **CoreMotion activity updates** run on the M-series motion coprocessor, not the main CPU — negligible battery impact
- **No continuous GPS polling** — GPS is only used momentarily to capture the precise parking coordinate when the `possiblePark` state begins
- **Feature is off by default** — users who don't enable it have zero additional battery drain

## Testing Strategy

- Unit test the state machine transitions in isolation (mock activity/location inputs)
- Test false positive filtering: simulate red light (stop < 3 min), drive-through, passenger drop-off
- Test notification action handling: confirm and dismiss paths
- Test permission flow: enable toggle → permission prompt → monitoring starts
- Test disable flow: toggle off → monitoring stops immediately

## Edge Cases

- **User parks but phone is in bag (no walking detected):** `stationary` activity also triggers `possiblePark`, so this is handled
- **User is a passenger:** Will get prompted but can tap "No" — acceptable for an opt-in feature
- **App terminated by system:** `startMonitoringSignificantLocationChanges()` survives app termination — iOS relaunches the app in the background on location change
- **Multiple park events in one trip:** State machine resets to `idle` after each confirmed event or 10-minute timeout
- **Already parked via manual button:** If `isCarParked` is already true, suppress the auto-detect notification to avoid confusion
