# EasyStreet App Store Launch Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prepare and submit EasyStreet iOS app for Apple App Store review.

**Architecture:** The app is already a mature MVP (2,768 LOC, 13 source files, 22+ tests). This plan covers production-hardening (logging, edge cases), asset creation (app icons, screenshots), App Store Connect configuration (metadata, privacy), and the archive/submit workflow. Tasks are ordered by dependency — code changes first, then assets, then submission.

**Tech Stack:** Swift 5 / UIKit / MapKit / SQLite / XcodeGen / Xcode 16+

---

## Phase 1: Code Production-Readiness

### Task 1: Wrap diagnostic logging in #if DEBUG

All 18+ `print()` calls in production code paths ship to App Store builds. Apple reviewers and users don't need console spam.

**Files:**
- Modify: `EasyStreet/Controllers/MapViewController.swift` (lines with `print("[EasyStreet]`)
- Modify: `EasyStreet/Data/StreetRepository.swift` (lines with `print("[EasyStreet]`)
- Modify: `EasyStreet/Data/DatabaseManager.swift` (any print statements)
- Modify: `EasyStreet/Models/ParkedCar.swift` (line ~119, notification denied log)
- Modify: `EasyStreet/Controllers/StreetDetailViewController.swift` (any print statements)

**Step 1: Find all print statements outside #if DEBUG blocks**

Run:
```bash
grep -n 'print(' EasyStreet/Controllers/MapViewController.swift EasyStreet/Data/StreetRepository.swift EasyStreet/Data/DatabaseManager.swift EasyStreet/Models/ParkedCar.swift EasyStreet/Controllers/StreetDetailViewController.swift
```

**Step 2: Wrap each print statement in #if DEBUG / #endif**

For each `print(` found outside an existing `#if DEBUG` block, wrap it:

```swift
// Before:
print("[EasyStreet] loadStreetSweepingData: starting")

// After:
#if DEBUG
print("[EasyStreet] loadStreetSweepingData: starting")
#endif
```

For consecutive print statements, wrap them in a single `#if DEBUG` block.

**Step 3: Verify the build compiles**

Run:
```bash
xcodebuild -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 4: Run tests to confirm no regressions**

Run:
```bash
xcodebuild test -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -20
```
Expected: All tests pass.

**Step 5: Commit**

```bash
git add EasyStreet/Controllers/MapViewController.swift EasyStreet/Data/StreetRepository.swift EasyStreet/Data/DatabaseManager.swift EasyStreet/Models/ParkedCar.swift EasyStreet/Controllers/StreetDetailViewController.swift
git commit -m "chore(ios): wrap diagnostic logging in #if DEBUG for release builds"
```

---

### Task 2: Improve notification permission denial UX

When a user denies notification permission, the app silently skips scheduling. Users won't understand why they're not getting parking alerts.

**Files:**
- Modify: `EasyStreet/Models/ParkedCar.swift` (~line 119)

**Step 1: Write the updated notification request handler**

In `ParkedCar.swift`, find the `requestAuthorization` completion block and replace the silent `return` with a user-visible alert:

```swift
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
    guard granted else {
        #if DEBUG
        print("Notification permission denied or error: \(String(describing: error))")
        #endif
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("NotificationPermissionDenied"),
                object: nil
            )
        }
        return
    }
    // ... existing scheduling code
}
```

Then in `MapViewController.swift`, observe this notification and show an alert:

```swift
// In viewDidLoad or setupNotifications:
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleNotificationDenied),
    name: NSNotification.Name("NotificationPermissionDenied"),
    object: nil
)

@objc private func handleNotificationDenied() {
    let alert = UIAlertController(
        title: "Notifications Disabled",
        message: "EasyStreet can't alert you before street sweeping without notification permission. Enable notifications in Settings to receive parking alerts.",
        preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    })
    alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
    present(alert, animated: true)
}
```

**Step 2: Verify build compiles**

Run:
```bash
xcodebuild -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator build 2>&1 | tail -5
```

**Step 3: Commit**

```bash
git add EasyStreet/Models/ParkedCar.swift EasyStreet/Controllers/MapViewController.swift
git commit -m "feat(ios): show alert when notification permission denied with Settings link"
```

---

### Task 3: Improve location failure handling

`locationManager(_:didFailWithError:)` currently only logs. Users with GPS issues get no feedback.

**Files:**
- Modify: `EasyStreet/Controllers/MapViewController.swift` (~line 800)

**Step 1: Add user-facing error for persistent location failures**

Replace the existing `didFailWithError` implementation:

```swift
func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    #if DEBUG
    print("[EasyStreet] Location manager error: \(error.localizedDescription)")
    #endif

    // Don't alert for transient errors or if we already have a location
    if let clError = error as? CLError, clError.code == .denied {
        // Permission was revoked — the authorization delegate handles this
        return
    }
}
```

This ensures:
- Debug builds still log the error
- Permission revocations are handled by the existing `didChangeAuthorization` delegate
- Transient GPS errors don't spam the user with alerts

**Step 2: Build and test**

Run:
```bash
xcodebuild -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator build 2>&1 | tail -5
```

**Step 3: Commit**

```bash
git add EasyStreet/Controllers/MapViewController.swift
git commit -m "fix(ios): handle location failure errors gracefully in release builds"
```

---

## Phase 2: App Assets & Configuration

### Task 4: Create App Icon asset catalog

Apple requires an app icon in specific sizes. Without this, the app is **rejected automatically**.

**Files:**
- Create: `EasyStreet/Assets.xcassets/Contents.json`
- Create: `EasyStreet/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Modify: `EasyStreet/project.yml` (add Assets.xcassets to resources)

**Step 1: Create the asset catalog directory structure**

```bash
mkdir -p EasyStreet/Assets.xcassets/AppIcon.appiconset
```

**Step 2: Create Assets.xcassets/Contents.json**

Write to `EasyStreet/Assets.xcassets/Contents.json`:
```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**Step 3: Create AppIcon.appiconset/Contents.json**

For Xcode 15+ / iOS 17+, Apple simplified to a single 1024x1024 icon. But since we target iOS 14+, we need the full set. Write to `EasyStreet/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images" : [
    { "idiom" : "iphone", "scale" : "2x", "size" : "20x20" },
    { "idiom" : "iphone", "scale" : "3x", "size" : "20x20" },
    { "idiom" : "iphone", "scale" : "2x", "size" : "29x29" },
    { "idiom" : "iphone", "scale" : "3x", "size" : "29x29" },
    { "idiom" : "iphone", "scale" : "2x", "size" : "40x40" },
    { "idiom" : "iphone", "scale" : "3x", "size" : "40x40" },
    { "idiom" : "iphone", "scale" : "2x", "size" : "60x60" },
    { "idiom" : "iphone", "scale" : "3x", "size" : "60x60" },
    { "idiom" : "ios-marketing", "scale" : "1x", "size" : "1024x1024" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**Step 4: Add Assets.xcassets to project.yml resources**

In `EasyStreet/project.yml`, add `Assets.xcassets` to the resources list:
```yaml
    resources:
      - LaunchScreen.storyboard
      - sweeping_data_sf.json
      - easystreet.db
      - Assets.xcassets
```

And add the ASSETCATALOG_COMPILER_APPICON_NAME setting:
```yaml
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.easystreet.app
      TARGETED_DEVICE_FAMILY: 1
      SWIFT_VERSION: "5.0"
      ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
```

**Step 5: Regenerate the Xcode project**

```bash
cd EasyStreet && xcodegen generate
```

**Step 6: Verify build**

```bash
xcodebuild -project EasyStreet/EasyStreet.xcodeproj -scheme EasyStreet -sdk iphonesimulator build 2>&1 | tail -5
```

Note: Build will warn about missing icon images until actual PNG files are added. This is expected. The actual icon design is a **manual/creative task** — the developer must create a 1024x1024 PNG (no alpha/transparency) and export it at each required size, then place the files in the appiconset directory with matching filenames referenced in Contents.json.

**Step 7: Commit the asset catalog scaffold**

```bash
git add EasyStreet/Assets.xcassets EasyStreet/project.yml
git commit -m "chore(ios): add AppIcon asset catalog scaffold for App Store submission"
```

---

### Task 5: Increment build configuration for release

**Files:**
- Modify: `EasyStreet/Info.plist`

**Step 1: Verify current version and build number**

Read `EasyStreet/Info.plist` and confirm:
- `CFBundleShortVersionString` = `1.0`
- `CFBundleVersion` = `1`

These are appropriate for a first App Store release. No changes needed unless you've already submitted a TestFlight build with version `1.0 (1)`.

**Step 2: (If needed) Increment build number**

If you've already uploaded build 1 to App Store Connect:
```xml
<key>CFBundleVersion</key>
<string>2</string>
```

**Step 3: Commit if changed**

```bash
git add EasyStreet/Info.plist
git commit -m "chore(ios): increment build number for App Store submission"
```

---

## Phase 3: App Store Connect & Metadata (Manual Steps)

> These tasks are performed in the browser at [App Store Connect](https://appstoreconnect.apple.com) and the [Apple Developer Portal](https://developer.apple.com). They cannot be automated via CLI.

### Task 6: Apple Developer Program enrollment

**Prerequisites:** Apple ID, $99/year fee, valid ID for identity verification.

**Steps:**
1. Go to https://developer.apple.com/programs/
2. Click "Enroll"
3. Sign in with Apple ID
4. Complete identity verification
5. Pay the $99/year fee
6. Wait 24-48 hours for approval

**Verification:** You can access the "Certificates, Identifiers & Profiles" section at https://developer.apple.com/account

---

### Task 7: Register App ID and create provisioning profiles

**Steps in Apple Developer Portal:**
1. Go to **Certificates, Identifiers & Profiles**
2. Under **Identifiers**, click **+** to register a new App ID
   - Platform: iOS
   - Bundle ID: **Explicit** — `com.easystreet.app`
   - Description: "EasyStreet"
   - Capabilities: Push Notifications (enable)
3. Under **Certificates**, create an **Apple Distribution** certificate if you don't have one
   - Generate a CSR from Keychain Access
   - Upload CSR, download certificate, double-click to install
4. Under **Profiles**, create an **App Store** provisioning profile
   - Select the `com.easystreet.app` App ID
   - Select your Distribution certificate
   - Name it "EasyStreet App Store"
   - Download and double-click to install

**Alternative:** In Xcode, go to **Signing & Capabilities** and enable **Automatically manage signing**. Xcode will create all of this for you if your Apple Developer account is signed in.

---

### Task 8: Create App Store Connect record

**Steps:**
1. Go to https://appstoreconnect.apple.com
2. Click **My Apps** → **+** → **New App**
3. Fill in:
   - Platform: **iOS**
   - Name: **EasyStreet**
   - Primary Language: **English (U.S.)**
   - Bundle ID: **com.easystreet.app**
   - SKU: **easystreet-ios-001**
4. Click **Create**

---

### Task 9: Fill in App Store metadata

**In the App Store Connect app record, fill in:**

#### App Information Tab
- **Name:** EasyStreet
- **Subtitle:** Street Sweeping Parking Alerts (max 30 chars)
- **Category:** Navigation (primary), Travel (secondary)
- **Content Rights:** "This app does not contain third-party content" OR declare SF Open Data as public domain

#### Pricing & Availability
- **Price:** Free
- **Availability:** United States (expand later if desired)

#### App Store Tab (Version 1.0)
- **Description** (suggested):
  > Never get a street sweeping parking ticket again. EasyStreet shows you real-time street sweeping schedules in San Francisco with color-coded maps, so you always know when to move your car.
  >
  > Features:
  > - Color-coded street map showing sweeping schedules
  > - "I Parked Here" — tap to save your parking spot
  > - Push notifications 1 hour before sweeping starts
  > - Search any address to check its schedule
  > - Tap any street to see detailed sweeping times
  >
  > EasyStreet covers all 21,000+ street segments in San Francisco using official city data.

- **Keywords:** street sweeping, parking, san francisco, ticket, parking ticket, sf parking, street cleaning, tow, move car (max 100 chars)
- **Support URL:** (your website or GitHub pages URL)
- **Privacy Policy URL:** (see Task 10)
- **What's New:** Initial release

#### Screenshots (Required)
- Minimum: **6.7" display** (iPhone 15 Pro Max) — at least 1 screenshot
- Recommended: Also **6.5"** (iPhone 11 Pro Max) and **5.5"** (iPhone 8 Plus)
- Content suggestions:
  1. Map view with color-coded streets
  2. "I Parked Here" pin on map
  3. Street detail sheet showing schedule
  4. Notification alert preview
  5. Search for an address

**How to capture:** Run in simulator at each size, use ⌘S to capture screenshots.

#### App Icon
- Upload the **1024x1024 PNG** (no alpha channel) created in Task 4

---

### Task 10: Create and host privacy policy

Apple requires a privacy policy URL since the app uses location data.

**Files:**
- Create: A hosted webpage (GitHub Pages, personal site, or similar)

**Privacy policy must cover:**
1. **What data is collected:** Device location (when parked), notification preferences
2. **How it's used:** To display nearby street sweeping schedules and send parking alerts
3. **Storage:** All data stored locally on device (no server, no cloud sync)
4. **Third parties:** No data shared with third parties
5. **Location data:** Used only while the app is active (or always, if background location is used) to determine parking location relative to sweeping schedules
6. **Contact info:** Email or website for privacy inquiries

**Hosting options (free):**
- GitHub Pages: Create a repo, add `privacy-policy.html`, enable Pages
- Use a simple static site generator

**Verification:** The URL must be publicly accessible (Apple checks it during review).

---

### Task 11: Complete App Privacy declarations in App Store Connect

**In App Store Connect → App Privacy:**

1. **Data Types collected:**
   - **Location** → Precise Location
     - Usage: App Functionality
     - Linked to User: No (data stays on device)
     - Tracking: No

2. **Data not collected (confirm):**
   - Contact Info: No
   - Health & Fitness: No
   - Financial Info: No
   - Browsing History: No
   - Search History: No (searches are local only)
   - Identifiers: No
   - Purchases: No
   - Usage Data: No (unless you add analytics later)
   - Diagnostics: No (unless you add crash reporting)

---

## Phase 4: Build, Archive & Submit

### Task 12: Archive the release build

**Prerequisites:** Tasks 1-5 complete (code changes), Task 7 complete (provisioning).

**Steps in Xcode:**

1. Open `EasyStreet/EasyStreet.xcodeproj`
2. Select **Any iOS Device (arm64)** as the build destination (NOT a simulator)
3. Ensure signing:
   - Target → Signing & Capabilities → Team: your Apple Developer account
   - Check "Automatically manage signing" is ON
   - Bundle ID: `com.easystreet.app`
4. **Product → Archive** (⌘ Shift B won't work — must use Archive)
5. Wait for the archive to complete
6. The **Organizer** window opens automatically

**Verification:** The archive appears in the Organizer with version 1.0 (1) and no signing errors.

---

### Task 13: Upload to App Store Connect

**From Xcode Organizer:**

1. Select the archive from Task 12
2. Click **Distribute App**
3. Select **App Store Connect** → **Upload**
4. Options:
   - Include bitcode: Yes (if prompted)
   - Upload symbols: Yes
   - Manage version and build number: Auto
5. Select your Distribution certificate and provisioning profile
6. Click **Upload**
7. Wait for processing (5-15 minutes)

**Verification:** In App Store Connect → TestFlight, the build appears with status "Processing" then "Ready to Submit".

---

### Task 14: Submit for App Review

**In App Store Connect:**

1. Go to your app → **App Store** tab → **Version 1.0**
2. Under **Build**, click **+** and select the uploaded build
3. Fill in:
   - **Review Notes** (optional): "EasyStreet displays street sweeping schedules for San Francisco using official city data. The app requires location access to show schedules near the user's current position and parked car."
   - **Demo account:** Not applicable (no login)
4. Scroll down and verify all required fields are green ✅
5. Click **Submit for Review**

**Common rejection reasons to pre-empt:**
- Missing privacy policy URL → Task 10
- Missing location usage description → Already in Info.plist ✅
- Insufficient app icon → Task 4
- Crash on launch → Test on real device first
- Insufficient functionality → The map + parking + notifications provide clear value ✅

**Review timeline:** Typically 24-48 hours. Check status in App Store Connect.

---

## Phase 5: Post-Launch

### Task 15: Monitor and respond

**Ongoing activities after approval:**

1. **Crash reports:** Check Xcode Organizer → Crashes weekly
2. **App Store reviews:** Respond to user feedback in App Store Connect
3. **Metrics:** Monitor downloads, retention in App Analytics
4. **Updates:** Submit new versions through the same Archive → Upload → Submit flow
5. **Certificate renewal:** Distribution certificates expire after 1 year — renew before expiration
6. **Developer Program renewal:** $99/year — renew before it lapses or the app is removed

---

## Summary: Task Dependency Graph

```
Phase 1 (Code - parallelizable):
  Task 1: Wrap logging ──┐
  Task 2: Notification UX ├──→ Build & test all ──→ Phase 4
  Task 3: Location errors ─┘

Phase 2 (Assets):
  Task 4: App icon catalog ──→ Phase 4
  Task 5: Build number ──→ Phase 4

Phase 3 (Manual - App Store Connect):
  Task 6: Developer enrollment ──→ Task 7
  Task 7: App ID & profiles ──→ Task 12
  Task 8: App Store Connect record ──→ Task 9
  Task 9: Metadata ──→ Task 14
  Task 10: Privacy policy ──→ Task 9
  Task 11: Privacy declarations ──→ Task 14

Phase 4 (Submission):
  Task 12: Archive ──→ Task 13
  Task 13: Upload ──→ Task 14
  Task 14: Submit for review

Phase 5 (Ongoing):
  Task 15: Monitor & respond
```

**Parallelism notes:**
- Tasks 1, 2, 3 can run in parallel (independent code changes)
- Tasks 6-11 can proceed in parallel with Tasks 1-5
- Task 12 requires Tasks 1-5 AND Task 7 to be complete
- Task 14 requires Tasks 9, 11, 12, 13 to be complete
