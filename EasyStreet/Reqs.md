# Street Sweeping Parking Assistant - Application Design Notes (iOS MVP)

## I. Core Goal (MVP)
To provide iOS users in San Francisco with clear, timely, and accurate information about street sweeping schedules to help them avoid parking tickets by:
1.  Displaying sweeping schedules on a map.
2.  Allowing users to mark where they parked.
3.  Sending notifications before sweeping occurs at their parked location.

## II. Target User (MVP)
iPhone users who park on San Francisco city streets.

## III. Key Features (MVP Focus for iOS)

### 1. Street Sweeping Schedule Display & Search (MVP Core)

*   **Interactive Map Visualization (MVP):**
    *   **Technology:** Native iOS MapKit.
    *   **Data Source:** Processed San Francisco street sweeping data (from DataSF).
    *   **Display:** Street segments will be drawn on the map as overlays (polylines).
    *   **Color-Coding (MVP Simplification):**
        *   **Red:** Sweeping actively scheduled for *today* for that segment.
        *   **Green:** No sweeping scheduled for *today* for that segment.
        *   **Grey/Default Map Lines:** No data or not a street with a specific sweeping schedule from the dataset.
    *   **Detailed Information on Tap (MVP):**
        *   When a user taps on a drawn street segment (polyline):
            *   Display a callout or a bottom sheet.
            *   Information to show: Street Name, Sweeping Day(s) (e.g., "Tuesdays"), Sweeping Times (e.g., "9:00 AM - 11:00 AM"), Sweeping Weeks (e.g., "1st & 3rd weeks of month").
    *   **Legend (MVP):** A simple, accessible legend explaining the Red/Green color codes.
    *   **Complex Component for Later Development (Post-MVP or Advanced MVP):**
        *   **Component Name:** Advanced Dynamic Color-Coding & Time-Based Filtering
        *   **Requirements:**
            *   More granular color codes (e.g., orange for "sweeping tomorrow," yellow for "sweeping later today but not imminent").
            *   User-configurable time windows for these colors.
            *   Ability to filter the map display based on a future date/time selected by the user.
            *   Performance optimization for rendering many complex, dynamically colored segments.
            *   Accessibility considerations (patterns/icons for color blindness).

*   **Address/Location Search (MVP):**
    *   **Technology:** CoreLocation framework for geocoding (string to coordinates) and reverse geocoding.
    *   **Functionality:**
        *   A search bar where users can type an address or landmark in San Francisco.
        *   On search, the map pans and zooms to the entered location.
        *   Sweeping schedule information for the searched area is displayed on the map.
    *   **MVP Simplification:** Basic address matching. Advanced autocomplete or point-of-interest search can be V2.

### 2. "Park My Car" Functionality (MVP Core)

*   **GPS-based Location Saving (MVP):**
    *   **Technology:** CoreLocation framework for getting current device location.
    *   **UI:** A prominent button (e.g., "I Parked Here" or a car icon).
    *   **Functionality:**
        *   User taps the button.
        *   App requests and uses current GPS location.
        *   A pin/marker is dropped on the map at the user's current location.
        *   The coordinates are saved locally on the device (e.g., using `UserDefaults` for simplicity in MVP, or Core Data for more robustness).
*   **Manual Pin Adjustment (MVP):**
    *   Allow users to drag the pin to fine-tune the parked location if GPS is slightly off.
*   **Parking Details Display (MVP):**
    *   Once a parking location is set:
        *   The app determines the relevant street segment based on the parked coordinates.
        *   **Complex Component (Core to MVP but has intricate logic):**
            *   **Component Name:** Parked Spot Sweeping Rule Engine
            *   **Requirements:**
                *   Input: Parked coordinates (latitude, longitude), current date/time.
                *   Process:
                    1.  Perform a spatial query on the local street sweeping data to find the exact street segment (or nearest relevant segment within a tolerance) corresponding to the parked coordinates. This involves checking if the point is on or very near a `the_geom` linestring from the dataset.
                    2.  Retrieve the sweeping rules for that specific segment: `WeekDay`, `FromHour`, `ToHour`, `Week1OfMonth` to `Week5OfMonth`, `Holidays`.
                    3.  Implement logic to accurately determine if sweeping is scheduled for *today* based on these rules (checking day of week, week of month, and holiday status).
                    4.  Calculate and display the next sweeping time for that spot.
                    5.  If sweeping is today, display "Sweeping Today: [Time Range]".
                    6.  If sweeping is not today, display "Next Sweeping: [Date] at [Time Range]".
                *   Output: Clear textual description of the sweeping rules and next occurrence for the parked spot.
        *   This information is displayed clearly to the user (e.g., in a dedicated section of the UI).
*   **Data Storage (MVP):**
    *   Parked latitude, longitude, and timestamp of parking.
    *   Stored locally on the device (`UserDefaults` for single parking spot, Core Data if history is considered for MVP but likely overkill).

### 3. Notifications and Alerts (MVP Core)

*   **Imminent Sweeping Alert (MVP):**
    *   **Technology:** `UserNotifications` framework for local notifications.
    *   **Trigger:** If a car is marked as parked ("Park My Car" feature used) AND the "Parked Spot Sweeping Rule Engine" determines a sweep is scheduled for that location.
    *   **Functionality:**
        *   Schedule a local notification to fire a configurable amount of time *before* sweeping begins (e.g., 1 hour before - MVP can hardcode this, V2 can make it user-configurable).
        *   Notification content: "Street sweeping soon at [Street Name]! Move your car by [Sweeping Start Time]."
    *   **Complex Component for Later Development (Post-MVP):**
        *   **Component Name:** Advanced Notification Scheduler & Background Processing
        *   **Requirements:**
            *   Robust background task handling to ensure notifications are scheduled and delivered reliably even if the app is terminated or the device restarts. This involves using Background App Refresh and potentially other iOS background modes carefully to conserve battery.
            *   User-configurable notification lead times.
            *   "Smart" reminders (e.g., a second reminder if the first is ignored and sweeping is very close).
            *   Handling edge cases like changes to the device's time zone or clock.
            *   Ensuring notifications are re-scheduled correctly if the app data is updated.

*   **"Clear Parked Car" (MVP):**
    *   A button/action for the user to indicate they have moved their car.
    *   This should clear the saved parked location and cancel any scheduled local notifications for that spot.

### "Where Can I Park?" Advisor (DEFERRED - Post-MVP)
*   **Reasoning:** This feature adds significant complexity in terms of UI, real-time data querying across many segments, and potentially route-finding logic. Best to stabilize core features first.
*   **Future Requirements if Implemented:**
    *   Ability for users to specify a destination or search area.
    *   Algorithm to query all street segments in the vicinity.
    *   Apply current time (or user-selected future time) to filter out segments with active or upcoming sweeping.
    *   Visually highlight "safe" (green) zones on the map.
    *   Performance considerations for querying and rendering potentially large areas.

## IV. Data Management (MVP - San Francisco Only)

*   **Street Sweeping Dataset (Source: DataSF):**
    *   **Format:** The provided link points to data typically downloadable as CSV or viewable via API (Socrata Open Data API - SODA).
    *   **Preprocessing (One-time or during app build/update):**
        *   **Complex Component (Essential Pre-computation):**
            *   **Component Name:** Sweeping Data Parser & Local Database Builder
            *   **Requirements:**
                1.  **Fetch Data:** Download the latest data (e.g., CSV).
                2.  **Parse Rows:** Iterate through each row.
                    *   Parse `WeekDay`.
                    *   Parse `FromHour`, `ToHour` (e.g., "0400" -> 4:00 AM, "1300" -> 1:00 PM). Convert to a consistent time representation (e.g., minutes from midnight or `DateComponents`).
                    *   Interpret `Week1OfMonth` to `Week5OfMonth` flags.
                    *   Interpret `Holidays` flag.
                    *   Parse `the_geom` (likely WKT LineString) into a MapKit-compatible format (e.g., an array of `CLLocationCoordinate2D` for a `MKPolyline`).
                3.  **Structure for Local Storage:** Define a local data structure (e.g., Swift structs/classes).
                4.  **Store Locally:**
                    *   Use SQLite with Spatialite extension if complex spatial queries are needed frequently on-device *beyond* simple point-in-polygon for the parked car.
                    *   For MVP, if `the_geom` is primarily used for drawing and the "Parked Spot" check involves iterating through pre-filtered segments (e.g., by current day of week), a simpler storage like bundling a processed JSON or Plist file within the app might suffice. The 37,000 rows with geometries will be a sizable file, so efficient loading and querying are key.
                    *   Core Data can also store this, but handling `the_geom` efficiently would need careful planning.
                5.  **Holiday Logic:**
                    *   Maintain a list of San Francisco public holidays.
                    *   The `Holidays` (TRUE/FALSE) column in the dataset indicates if sweeping is *suspended* on holidays or *occurs regardless* of holidays. This logic needs to be correctly implemented. If `Holidays` is TRUE (meaning sweeping *does* occur on holidays), then the holiday list is ignored for that rule. If `Holidays` is FALSE (meaning sweeping is *suspended* on holidays), then the rule is skipped if the sweep day falls on an observed holiday. *Self-correction: The dataset column name is `Holidays`. If `Holidays` = FALSE, it means sweeping is NOT on holidays (i.e., suspended). If `Holidays` = TRUE, it means sweeping still happens on holidays for that specific rule. This needs careful checking against SFMTA's actual holiday policy.*
                        *After checking typical SFMTA behavior: Street sweeping is generally *suspended* on major holidays. The `Holidays` field in the dataset needs to be interpreted carefully. If a rule has `Holidays` as `FALSE` or `0`, it means it's suspended on holidays. If it's `TRUE` or `1`, it means it happens even on holidays (less common for general sweeping but possible for some routes).* For MVP, we will assume if `Holidays` is `FALSE`, sweeping is suspended on a predefined list of major holidays.
        *   **Data Updates:** For MVP, the processed data will be bundled with the app. Updates will require an app update. A backend for dynamic data updates is Post-MVP.
*   **User-Specific Data (MVP):**
    *   Parked car location (latitude, longitude).
    *   Timestamp of parking.
    *   Stored using `UserDefaults` (simple key-value storage, suitable for a single parked car location).

## V. Technical Architecture & Considerations (iOS MVP)

1.  **Platform:** Native iOS (Swift).
2.  **Mapping Engine:** Apple MapKit.
    *   Use `MKPolyline` to draw street segments.
    *   Use `MKMapViewDelegate` methods for tap interactions on overlays.
3.  **Location Services:** CoreLocation framework.
    *   Requesting `WhenInUseUsageDescription` authorization.
    *   Getting current location.
    *   Geocoding for search.
4.  **Notifications:** `UserNotifications` framework for local notifications.
    *   Requesting notification permissions.
5.  **Data Storage (Sweeping Schedule):**
    *   **Initial MVP approach:** Process the SFGov data into a more readily usable format (e.g., array of Swift objects, possibly stored as a Plist or JSON file bundled in the app). Each object would represent a rule for a segment, including pre-parsed coordinates for its `MKPolyline`.
    *   **Loading Strategy:** Load only necessary map segments for the visible map rect to maintain performance.
    *   **Complex Component for Later Development (Post-MVP Data Management):**
        *   **Component Name:** On-Device Spatial Database & Indexing
        *   **Requirements:**
            *   Integration of SQLite with Spatialite or a similar solution for efficient on-device spatial queries (e.g., "find all segments within X meters of this point," "find segment containing this point").
            *   Mechanism for updating this local database from a backend service.
            *   Efficient data synchronization.
6.  **Offline Capability (MVP):**
    *   Once data is bundled and the user has parked, viewing the parked car's status and relevant sweeping rules should work offline.
    *   Map display of general sweeping areas (cached map tiles from MapKit, and our bundled overlays) should work offline.
    *   Address search might require an internet connection for geocoding if not using onboard geocoding.

## VI. User Interface (UI) & User Experience (UX) - iOS MVP Principles

1.  **Simplicity & iOS Native Feel:** Adhere to iOS Human Interface Guidelines.
2.  **Clear Visual Hierarchy:**
    *   Parked car location and its sweeping status should be very prominent.
    *   Easy-to-use "Park My Car" button.
3.  **Onboarding (MVP Light):**
    *   Brief explanation of permissions needed (Location, Notifications) on first request.
    *   A simple info screen explaining color codes accessible from a help button.
4.  **Permissions:** Request location and notification permissions at appropriate times with clear explanations of why they are needed.

## VII. Development Phases (Recap for MVP)

1.  **Phase 1: iOS MVP (San Francisco Only)**
    *   Data parsing script (run locally by developer) to convert DataSF CSV/GeoJSON into a bundled app resource (e.g., Plist/JSON of processed sweeping rules and geometries).
    *   MapKit display with Red/Green color-coded sweeping segments based on *today's* schedule.
    *   Tap on segment to show full details.
    *   Basic address search to pan map.
    *   "Park My Car" feature (GPS + manual adjust) saving to `UserDefaults`.
    *   "Parked Spot Sweeping Rule Engine" to determine rules for the saved spot.
    *   Local notifications via `UserNotifications` framework (e.g., 1 hour before sweeping).
    *   "Clear Parked Car" functionality.