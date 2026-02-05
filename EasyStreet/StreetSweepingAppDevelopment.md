# Street Sweeping Parking Assistant - Development Plan

**Context Note:** This document outlines the development plan for the Street Sweeping Parking Assistant iOS MVP. It is derived from the requirements specified in `Reqs.mk`. This file should be updated as development progresses.

## I. Core Goal (MVP)

**Goal:** To provide iOS users in San Francisco with clear, timely, and accurate information about street sweeping schedules to help them avoid parking tickets.

**Key Functions:**
1.  Display sweeping schedules on a map.
2.  Allow users to mark where they parked.
3.  Send notifications before sweeping occurs at their parked location.

**Developer Notes:**
*   The primary objective is to prevent parking tickets for users in San Francisco.
*   Simplicity and clarity are key for the MVP.
*   Focus on the three core functions listed above.

---

## II. Target User (MVP)

**Primary Users:** iPhone users who park on San Francisco city streets.

**Developer Notes:**
*   The application should be tailored to the needs and technical familiarity of typical iPhone users.
*   Geolocation features are critical, so users are expected to have location services enabled.
*   Focus is solely on San Francisco for the MVP.

---

## III. Key Features (MVP Focus for iOS)

### 1. Street Sweeping Schedule Display & Search (MVP Core)

*   **Interactive Map Visualization (MVP):**
    *   **Technology:** Native iOS MapKit.
    *   **Data Source:** Processed San Francisco street sweeping data (from DataSF).
    *   **Display:** Street segments drawn as overlays (polylines).
    *   **Color-Coding (MVP Simplification):
        *   **Red:** Sweeping actively scheduled for *today*.
        *   **Green:** No sweeping scheduled for *today*.
        *   **Grey/Default Map Lines:** No data or not a street with a specific schedule.
    *   **Detailed Information on Tap (MVP):**
        *   Show callout/bottom sheet on tap of a street segment.
        *   Information: Street Name, Sweeping Day(s), Sweeping Times, Sweeping Weeks.
    *   **Legend (MVP):** Simple, accessible legend for Red/Green codes.
    *   **Developer Notes (Map Visualization):**
        *   MapKit is the designated framework. Ensure polylines are accurately rendered based on `the_geom` data.
        *   Color-coding logic needs to correctly interpret "today's" schedule.
        *   The tap interaction should be responsive and clearly present the detailed sweeping info.
        *   A straightforward legend is crucial for usability.

*   **Address/Location Search (MVP):**
    *   **Technology:** CoreLocation for geocoding/reverse geocoding.
    *   **Functionality:**
        *   Search bar for addresses/landmarks in SF.
        *   Map pans/zooms to searched location.
        *   Sweeping info for the searched area is displayed.
    *   **MVP Simplification:** Basic address matching. Autocomplete/POI search is V2.
    *   **Developer Notes (Address Search):**
        *   CoreLocation's geocoding capabilities will be used. Error handling for invalid addresses is important.
        *   Ensure map updates correctly upon successful search.

*   **Complex Component for Later Development (Post-MVP or Advanced MVP):**
    *   **Component Name:** Advanced Dynamic Color-Coding & Time-Based Filtering
    *   **Note:** This is explicitly out of scope for the initial MVP but documented for future reference. Requirements include more granular colors, user-configurable time windows, date/time filtering, performance optimization, and accessibility patterns.

**Developer Notes (Overall for Feature 1):**
*   This feature is central to the MVP. Data processing of SFData a prerequisite.
*   Focus on clear, accurate display of sweeping schedules for *today*.
*   Keep search functionality simple and effective for the MVP.

---

### 2. "Park My Car" Functionality (MVP Core)

*   **GPS-based Location Saving (MVP):**
    *   **Technology:** CoreLocation for current device location.
    *   **UI:** Prominent button (e.g., "I Parked Here" or car icon).
    *   **Functionality:**
        *   User taps button, app requests/uses GPS.
        *   Pin/marker dropped on map at current location.
        *   Coordinates saved locally (e.g., `UserDefaults` for MVP).
    *   **Developer Notes (GPS Location Saving):**
        *   Ensure accurate location capture. Provide clear feedback to the user during location acquisition.
        *   `UserDefaults` is suitable for a single parking spot in MVP.

*   **Manual Pin Adjustment (MVP):**
    *   Allow users to drag the pin to fine-tune parked location.
    *   **Developer Notes (Pin Adjustment):**
        *   The drag interaction should be smooth and intuitive.
        *   Updated coordinates must be saved correctly.

*   **Parking Details Display (MVP):**
    *   Once parking location is set, app determines relevant street segment.
    *   **Developer Notes (Details Display):**
        *   This display should be very clear and prominent after parking.

*   **Complex Component (Core to MVP but has intricate logic):**
    *   **Component Name:** Parked Spot Sweeping Rule Engine
    *   **Requirements:**
        *   Input: Parked coordinates, current date/time.
        *   Process:
            1.  Spatial query on local sweeping data to find the street segment for parked coordinates.
            2.  Retrieve sweeping rules for that segment (Day, From/ToHour, Week1-5OfMonth, Holidays).
            3.  Logic to determine if sweeping is scheduled for *today* (check day, week, holiday).
            4.  Calculate and display the next sweeping time.
            5.  Display "Sweeping Today: [Time Range]" or "Next Sweeping: [Date] at [Time Range]".
        *   Output: Clear textual description of sweeping rules and next occurrence.
    *   **Developer Notes (Rule Engine):**
        *   This is a critical logic component. Accuracy is paramount.
        *   Thoroughly test logic for date/time calculations, week of month, and holiday considerations.
        *   The spatial query needs to be efficient enough for a good user experience, even if iterating through pre-filtered segments in MVP.

*   **Data Storage (MVP):**
    *   Parked latitude, longitude, timestamp of parking.
    *   Stored locally (`UserDefaults` for MVP).
    *   **Developer Notes (Data Storage):**
        *   Ensure data is persisted correctly and cleared when the user clears their parked car.

**Developer Notes (Overall for Feature 2):**
*   User trust depends on the accuracy of this feature. The Rule Engine is the heart of it.
*   The flow from tapping "I Parked Here" to seeing sweeping details for that spot should be seamless.

---

### 3. Notifications and Alerts (MVP Core)

*   **Imminent Sweeping Alert (MVP):**
    *   **Technology:** `UserNotifications` framework for local notifications.
    *   **Trigger:** Car parked AND "Parked Spot Sweeping Rule Engine" determines an imminent sweep.
    *   **Functionality:**
        *   Schedule local notification (e.g., 1 hour before sweeping - MVP hardcodes this).
        *   Notification content: "Street sweeping soon at [Street Name]! Move your car by [Sweeping Start Time]."
    *   **Developer Notes (Imminent Alert):**
        *   Notification delivery must be reliable.
        *   The 1-hour lead time is fixed for MVP but should be easily configurable later.
        *   Ensure notification content is clear and actionable.

*   **"Clear Parked Car" (MVP):**
    *   Button/action for user to indicate car has been moved.
    *   Clears saved parked location and cancels scheduled notifications.
    *   **Developer Notes ("Clear Parked Car"):**
        *   This action must reliably cancel notifications to prevent false alarms.
        *   UI should provide clear confirmation that the parked car info has been cleared.

*   **Complex Component for Later Development (Post-MVP):**
    *   **Component Name:** Advanced Notification Scheduler & Background Processing
    *   **Note:** This is explicitly out of scope for MVP. Future requirements include robust background task handling, configurable lead times, smart reminders, time zone/clock change handling, and re-scheduling on data updates.

**Developer Notes (Overall for Feature 3):**
*   Notifications are a key value proposition for preventing tickets.
*   MVP focuses on local notifications triggered by the app logic.
*   Reliability of clearing parked car status and associated notifications is crucial.

---

### "Where Can I Park?" Advisor (DEFERRED - Post-MVP)
*   **Reasoning:** High complexity (UI, real-time multi-segment querying, routing logic). Best to stabilize core MVP features first.
*   **Future Requirements:** User destination input, nearby segment querying, time-based filtering for safe zones, visual highlighting, performance.
*   **Developer Notes:** This feature is explicitly deferred. No development effort for MVP.

---

## IV. Data Management (MVP - San Francisco Only)

*   **Street Sweeping Dataset (Source: DataSF):**
    *   **Format:** CSV or SODA API.
    *   **Preprocessing (One-time or during app build/update):**
        *   **Complex Component (Essential Pre-computation):**
            *   **Component Name:** Sweeping Data Parser & Local Database Builder
            *   **Requirements:**
                1.  **Fetch Data:** Download latest data (e.g., CSV).
                2.  **Parse Rows:** Interpret `WeekDay`, `FromHour`, `ToHour`, `Week1OfMonth`-`Week5OfMonth` flags, `Holidays` flag, `the_geom` (WKT LineString to MapKit coordinates).
                3.  **Structure for Local Storage:** Define Swift structs/classes.
                4.  **Store Locally:** Bundled processed JSON or Plist for MVP. (Note: 37,000 rows will be sizable; efficient loading/querying is key).
                5.  **Holiday Logic:** Implement SF public holiday list. Interpret `Holidays` flag correctly (e.g., `Holidays=FALSE` means sweeping suspended on listed holidays). *Self-correction from Reqs.mk noted: `Holidays=FALSE` means suspended on holidays. `Holidays=TRUE` means happens even on holidays. This needs careful verification against SFMTA policy.* MVP assumes `Holidays=FALSE` means suspended on a predefined list.
            *   **Developer Notes (Data Parser/Builder):**
                *   This is a critical pre-computation step. The script/process for this needs to be robust.
                *   Parsing `the_geom` accurately into `CLLocationCoordinate2D` arrays is vital for map display.
                *   The holiday logic interpretation is crucial and needs to be double-checked with official SFMTA rules if possible, beyond the dataset documentation.
                *   The choice of bundled Plist/JSON needs to consider app startup time and memory footprint. Investigate efficient ways to load/query this data. Initial thought: a dictionary keyed by a geohash or similar for faster spatial proximity checks before iterating full segment list.

        *   **Data Updates:** Bundled with app for MVP. App update needed for data refresh.
        *   **Developer Notes (Data Updates):**
            *   The data update process is manual for MVP (re-process and re-bundle). Document this process clearly.

*   **User-Specific Data (MVP):**
    *   Parked car location (latitude, longitude), timestamp of parking.
    *   Stored using `UserDefaults`.
    *   **Developer Notes (User Data):**
        *   `UserDefaults` is sufficient for a single parked car. Ensure keys are well-defined and data is cleared appropriately.

**Developer Notes (Overall for Data Management):**
*   The quality and structure of the preprocessed sweeping data will significantly impact app performance and accuracy.
*   Keep user data storage simple and reliable for MVP using `UserDefaults`.

---

## V. Technical Architecture & Considerations (iOS MVP)

1.  **Platform:** Native iOS (Swift).
    *   **Developer Notes:** Ensure latest stable Swift version and Xcode.
2.  **Mapping Engine:** Apple MapKit.
    *   Use `MKPolyline` for street segments.
    *   Use `MKMapViewDelegate` for tap interactions.
    *   **Developer Notes:** Familiarize with efficient `MKPolyline` rendering and delegate methods.
3.  **Location Services:** CoreLocation framework.
    *   Request `WhenInUseUsageDescription` authorization.
    *   Getting current location, geocoding for search.
    *   **Developer Notes:** Handle various location permission states gracefully. Provide clear rationale for permission requests.
4.  **Notifications:** `UserNotifications` framework for local notifications.
    *   Requesting notification permissions.
    *   **Developer Notes:** Implement robust permission handling and ensure notifications are well-formed.
5.  **Data Storage (Sweeping Schedule):**
    *   **Initial MVP approach:** Processed SFGov data into bundled Plist/JSON (array of Swift objects).
    *   **Loading Strategy:** Load only necessary map segments for visible map rect to maintain performance.
    *   **Developer Notes (Sweeping Data Storage):**
        *   The Plist/JSON structure needs to be optimized for quick lookup and rendering.
        *   The loading strategy is crucial for performance with a large dataset. Consider spatial indexing techniques if simple filtering by visible rect is not performant enough, even with a flat file.

    *   **Complex Component for Later Development (Post-MVP Data Management):**
        *   **Component Name:** On-Device Spatial Database & Indexing
        *   **Note:** Post-MVP. Involves SQLite with Spatialite, backend update mechanism, data sync.
6.  **Offline Capability (MVP):**
    *   Bundled data enables offline viewing of parked car status/rules.
    *   Map display (cached tiles + bundled overlays) should work offline.
    *   Address search may need internet for geocoding.
    *   **Developer Notes (Offline):**
        *   Test offline scenarios thoroughly. Ensure core functionality (viewing parked car rules) is robust offline.
        *   Clearly indicate if features like new address searches are unavailable offline.

**Developer Notes (Overall for Technical Architecture):**
*   Stick to native iOS frameworks for MVP to ensure stability and performance.
*   Performance, especially map rendering and data querying, is a key consideration with the dataset size.
*   Manage permissions carefully and provide good user explanations.

---

## VI. User Interface (UI) & User Experience (UX) - iOS MVP Principles

1.  **Simplicity & iOS Native Feel:** Adhere to iOS Human Interface Guidelines (HIG).
    *   **Developer Notes:** Prioritize ease of use. Avoid custom UI that deviates significantly from HIG unless strong justification exists.
2.  **Clear Visual Hierarchy:**
    *   Parked car location and its sweeping status should be very prominent.
    *   Easy-to-use "Park My Car" button.
    *   **Developer Notes:** Use size, color, and placement effectively to guide the user's attention to critical information and actions.
3.  **Onboarding (MVP Light):**
    *   Brief explanation of permissions needed (Location, Notifications) on first request.
    *   Simple info screen explaining color codes (accessible via help button).
    *   **Developer Notes:** Keep onboarding minimal. Contextual explanations for permission requests are preferred.
4.  **Permissions:** Request at appropriate times with clear explanations.
    *   **Developer Notes:** Follow best practices for requesting permissions: ask only when needed, and clearly state why.

**Developer Notes (Overall for UI/UX):**
*   The user experience should be focused and intuitive, directly addressing the core goal of avoiding tickets.
*   Clarity of information (sweeping times, parked status) is paramount.

---

## VII. Development Phases (Recap for MVP)

**Phase 1: iOS MVP (San Francisco Only)**

1.  **Data Parsing Script:**
    *   Develop a script (e.g., Python) to convert DataSF CSV/GeoJSON into a bundled app resource (Plist/JSON).
    *   **Tasks:** Fetch, parse rules & geometries, structure, output file.
    *   **Developer Notes:** This script is a foundational step. Ensure it's well-documented and can be re-run easily if the source data format changes or for updates.

2.  **MapKit Display:**
    *   Implement map view with Red/Green color-coded sweeping segments based on *today's* schedule.
    *   Implement tap on segment to show full details.
    *   **Developer Notes:** Focus on rendering performance and accurate color-coding based on current date.

3.  **Address Search:**
    *   Implement basic address search to pan/zoom map.
    *   **Developer Notes:** Integrate CoreLocation geocoding.

4.  **"Park My Car" Feature:**
    *   Implement GPS location saving (to `UserDefaults`) with manual pin adjustment.
    *   Implement the "Parked Spot Sweeping Rule Engine" to determine and display rules for the saved spot.
    *   **Developer Notes:** The Rule Engine logic is complex and needs rigorous testing, especially date/time calculations and holiday handling.

5.  **Local Notifications:**
    *   Implement local notifications via `UserNotifications` framework (e.g., 1 hour before sweeping).
    *   **Developer Notes:** Ensure notifications are scheduled correctly based on the Rule Engine output and parked location.

6.  **"Clear Parked Car" Functionality:**
    *   Implement functionality to clear parked location and cancel notifications.
    *   **Developer Notes:** Critical for preventing incorrect notifications.

**Developer Notes (Overall for Development Phases):**
*   These phases outline the core deliverables for the MVP.
*   Iterative testing throughout each phase is crucial.
*   Start with data processing, then map display, followed by parking functionality, and finally notifications.

---

**End of MVP Development Plan based on Reqs.mk.**
Further sections can be added for detailed task breakdowns, sprint planning, or post-MVP considerations as needed. 