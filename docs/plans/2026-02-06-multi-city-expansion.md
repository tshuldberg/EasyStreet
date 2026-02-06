# EasyStreet Multi-City Expansion Plan

**Date:** 2026-02-06
**Document Type:** Product Architecture & Strategy
**Author:** Product Architecture Session (AI-assisted)
**Status:** Draft for Review

---

## Table of Contents

1. [Target City Analysis](#1-target-city-analysis)
2. [Technical Architecture for Multi-City](#2-technical-architecture-for-multi-city)
3. [Data Pipeline Architecture](#3-data-pipeline-architecture)
4. [Phased Rollout Plan](#4-phased-rollout-plan)
5. [Monetization Considerations](#5-monetization-considerations)
6. [Risk Assessment](#6-risk-assessment)

---

## 1. Target City Analysis

### Overview: Market Sizing

The US street sweeping parking ticket market is substantial. Across the top 16 major US cities, parking ticket revenue exceeds $1.4 billion annually, with street sweeping/cleaning violations representing a significant fraction (typically 20-30% of all parking citations). EasyStreet's total addressable market is estimated at **$300M-$500M annually** in ticket revenue that residents are trying to avoid.

### Tier 1 Cities (Highest Priority)

#### 1.1 Los Angeles, CA

| Attribute | Detail |
|-----------|--------|
| **Market Size** | ~480,000 street sweeping tickets/year (extrapolated from 241,881 in H1 2024). $35M+ annual ticket revenue at $73/ticket. |
| **Data Source** | [LA Open Data Portal](https://data.lacity.org/City-Infrastructure-Service-Requests/Posted-Street-Sweeping-Routes/krk7-ayq2) - "Posted Street Sweeping Routes" |
| **Data Format** | CSV, JSON, XML via Socrata API. Dataset contains route numbers, boundaries, and posted times. |
| **Data Freshness** | Updated as routes change. Socrata SODA API available for programmatic access. |
| **Key Difference from SF** | Routes are identified by **route numbers** with boundaries rather than CNN (Centerline Network Number). Posted routes only (biweekly sweeping: 1st/3rd or 2nd/4th weeks). Geometry may be in a separate GeoJSON/shapefile on the [LA GeoHub](https://geohub.lacity.org/maps/39dfa7b7b87c4027a650828007debb5a). |
| **Holiday Differences** | California state holidays largely overlap with SF. LA observes the same federal + CA state holidays. Cesar Chavez Day (March 31) is observed. LADOT publishes [holiday parking regulation exemptions](https://ladotparking.org/parking-enforcement/holiday-parking-regulation-exemptions/). |
| **Unique Challenges** | Sprawling geography (469 sq mi vs SF's 47 sq mi) means 10x the data volume. Multiple council districts with slightly different enforcement patterns. LA County cities (Santa Monica, West Hollywood, Beverly Hills) have their own separate sweeping programs. |

#### 1.2 New York City, NY

| Attribute | Detail |
|-----------|--------|
| **Market Size** | ~1.9 million alternate side parking (ASP) tickets in FY2023 first 11 months. Estimated $85M-$120M annual revenue at $45-$65/ticket. The single largest market in the US. |
| **Data Source** | [NYC Open Data - Parking Regulation Locations and Signs](https://data.cityofnewyork.us/Transportation/Parking-Regulation-Locations-and-Signs/xswq-wnv9) + [Alternate Side Parking Signs Locations](https://data.cityofnewyork.us/Transportation/Alternate-Side-Parking-signs-locations-NYCDOT/2x64-6f34) |
| **Data Format** | Shapefile, CSV, JSON via Socrata API. [OpenCurb](http://www.opencurb.nyc/) provides GeoJSON API with curb-segment-level regulation data (free for public consumers, no API key required). [NYCDOTSigns.net](https://nycdotsigns.net/) provides sign-level lookup. |
| **Data Freshness** | Sign location data updated daily. ASP suspension calendar published annually as ICS download. |
| **Key Difference from SF** | NYC uses **Alternate Side Parking (ASP)** rather than traditional street sweeping schedules. Rules are encoded on physical signs, not as sweeping routes. Each curb segment can have multiple overlapping regulations (metered, no parking, ASP, no standing). The data model is **sign-based** not **route-based**. |
| **Holiday Differences** | **Critically different from all other cities.** NYC suspends ASP on ~33 holidays/year including religious observances: Lunar New Year, Purim, Eid Al-Fitr, Eid Al-Adha, Passover (multiple days), Shavuoth, Diwali, Losar (Tibetan New Year), Asian Lunar New Year, Solemnity of the Ascension, Tisha B'Av, Holy Thursday, Good Friday, Ash Wednesday, and more. The current `HolidayCalculator.swift` handles only 11 US/SF holidays and would need a complete overhaul for NYC. |
| **Unique Challenges** | ASP is fundamentally different from street sweeping. Signs say things like "NO PARKING 8:30AM-10AM MON & THURS" which means you must move your car during that window. The data model needs to handle overlapping, sign-based rules rather than sweeping schedules. 5 boroughs with different enforcement patterns. Snow emergency suspensions are ad-hoc. |

#### 1.3 Chicago, IL

| Attribute | Detail |
|-----------|--------|
| **Market Size** | Chicago sweeps ~1,000+ miles of streets April-November. Estimated 200,000+ street sweeping tickets/year. |
| **Data Source** | [Chicago Data Portal - Street Sweeping Schedule 2025](https://data.cityofchicago.org/Sanitation/Street-Sweeping-Schedule-2025/a2xx-z2ja) + [Street Sweeping Zones 2025](https://data.cityofchicago.org/Sanitation/Street-Sweeping-Zones-2025/utb4-q645) (with map view) |
| **Data Format** | CSV, JSON, GeoJSON via Socrata API. Schedule organized by **Ward** and **Ward section number** with specific dates. Zone geometries available as polygons. |
| **Data Freshness** | Published annually (new dataset each year). Socrata API with dataset IDs like `a2xx-z2ja`. |
| **Key Difference from SF** | Chicago uses **specific calendar dates** rather than recurring weekly patterns (e.g., "April 7" and "April 21" rather than "1st and 3rd Mondays"). Schedule is organized by **ward sections** (political boundaries) not street segments. One side swept on first date, other side on second date. **Seasonal only** (April 1 to ~November 15). |
| **Holiday Differences** | Illinois state holidays: Lincoln's Birthday (Feb 12), Casimir Pulaski Day (1st Monday in March), Election Day. These generally don't impact sweeping since it's seasonal April-November. |
| **Unique Challenges** | Annual schedule publication means data must be re-ingested each spring. Ward-based zones require polygon-to-street-segment mapping. The city also provides a [Sweep Tracker](https://www.chicago.gov/sweepertracker) for real-time truck positions. Third-party [We The Sweeple](https://www.wethesweeple.com/) already serves this market as a free alert system. |

### Tier 2 Cities (High Priority)

#### 1.4 Boston, MA

| Attribute | Detail |
|-----------|--------|
| **Market Size** | Sweeps 400+ curb miles. $40 daytime / $90 overnight violations. Estimated 100,000+ tickets/year. |
| **Data Source** | [Analyze Boston - Street Sweeping Schedules](https://data.boston.gov/dataset/street-sweeping-schedules) (legacy dataset). City also has [street sweeping lookup tool](https://www.cityofboston.gov/publicworks/sweeping/). |
| **Data Format** | CSV download. Legacy dataset. |
| **Data Freshness** | Described as "legacy dataset" - may not be actively maintained. Lookup tool appears more current. |
| **Key Difference from SF** | **Seasonal** (April 1 - November 30, except North End, South End, Beacon Hill which differ). Night sweeping program runs year-round on major roads. |
| **Holiday Differences** | Massachusetts unique holidays: Patriots' Day (3rd Monday in April), Evacuation Day (March 17, Suffolk County only - which includes Boston). |
| **Unique Challenges** | Legacy dataset format may require scraping the lookup tool for current data. Towing is common (not just ticketing). Different neighborhoods have different seasonal windows. |

#### 1.5 Washington, DC

| Attribute | Detail |
|-----------|--------|
| **Market Size** | $45/ticket. Active March 1 - October 31 in residential areas. Year-round for major roadways. |
| **Data Source** | [DC DPW - Scheduled Street Sweeping](https://dpw.dc.gov/service/street-sweeping-scheduled). Map-based lookup available. |
| **Data Format** | Web-based lookup tool. GIS data may be available through DC's open data portal. |
| **Data Freshness** | Published annually for the season. |
| **Key Difference from SF** | **Seasonal** (March-October residential, year-round major roads). 2-hour windows (9:30-11:30 AM or 12:30-2:30 PM). Warning tickets issued early in season before enforcement begins. |
| **Holiday Differences** | DC-specific holidays: Emancipation Day (April 16), Inauguration Day (every 4 years). Federal holidays strongly observed since much of the workforce is federal. |
| **Unique Challenges** | Data availability is less structured than SF/LA/Chicago. May require building relationships with DPW for data access. |

#### 1.6 Philadelphia, PA

| Attribute | Detail |
|-----------|--------|
| **Market Size** | $31/ticket (lower fine). Program covers 14 high-litter neighborhoods. Expanding coverage yearly. |
| **Data Source** | [City of Philadelphia - Cleaning Schedule](https://www.phila.gov/programs/mechanical-street-cleaning/cleaning-schedule/). SweepPHL real-time tracker. |
| **Data Format** | Web-based schedules and real-time map. Limited structured data download. |
| **Data Freshness** | Seasonal (April - October). Updated annually. |
| **Key Difference from SF** | **Limited coverage** - only 14 neighborhoods, not citywide. Mon-Thu only, 9 AM - 3 PM. Program is **expanding** which means data changes annually. |
| **Holiday Differences** | Pennsylvania has no unique state holidays beyond federal. |
| **Unique Challenges** | Not citywide - partial coverage complicates UX (need to show "no data" for uncovered areas). Lower fine ($31) means less urgency for users, potentially lower willingness to pay. Program is growing, which means frequent boundary changes. |

#### 1.7 Denver, CO

| Attribute | Detail |
|-----------|--------|
| **Market Size** | ~137,000 tickets in 2024. $50/ticket. ~$6.9M annual revenue. |
| **Data Source** | [Denver Open Data - Street Sweep Schedule](https://www.opendata-geospatialdenver.hub.arcgis.com/maps/geospatialDenver::street-sweep-schedule/explore). Also [city scheduling tool](https://denvergov.org/Online-Services-Hub/Street-Sweeping-Schedules) with email/text alerts. |
| **Data Format** | ArcGIS Hub - GeoJSON, Shapefile, CSV, KML available. |
| **Data Freshness** | Published for each sweeping season. ArcGIS Feature Service available. |
| **Key Difference from SF** | **Seasonal** (April - November). ArcGIS-hosted data rather than Socrata. Denver already provides its own alert system. |
| **Holiday Differences** | Colorado has no unique state holidays beyond federal. |
| **Unique Challenges** | Denver already provides its own scheduling and alert tool, reducing the value proposition. ArcGIS data format requires different ingestion pipeline than Socrata-based cities. |

### Tier 3 Cities (Future Expansion)

#### 1.8 San Diego, CA

| Attribute | Detail |
|-----------|--------|
| **Market Size** | ~90% of blocks have NO posted parking restrictions for sweeping. Only ~9% of blocks enforce parking restrictions during sweeping. Lower ticket volume than SF/LA. |
| **Data Source** | [San Diego Open Data - Street Sweeping Schedule](https://data.sandiego.gov/datasets/street-sweeping-schedule/) |
| **Data Format** | CSV, GeoJSON available. Well-documented open data portal. |
| **Key Difference from SF** | Most blocks don't enforce parking during sweeping. Residential blocks swept ~1x/month, commercial ~1x/week. |
| **Unique Challenges** | Low enforcement rate reduces urgency and willingness to pay. Same CA holidays as SF/LA. |

#### 1.9 Minneapolis, MN

| Attribute | Detail |
|-----------|--------|
| **Market Size** | Sweeps 1,100+ miles twice yearly (spring/fall only). 7 AM - 4:30 PM enforcement windows. |
| **Data Source** | [Minneapolis Street Sweep Map](https://www.minneapolismn.gov/getting-around/parking-driving/street-sweep/street-sweep-map/) - interactive map with sign-up for alerts. |
| **Data Format** | Interactive map; structured download availability unclear. |
| **Key Difference from SF** | **Only twice yearly** (spring and fall), not recurring weekly. Temporary no-parking signs posted before sweeping. |
| **Unique Challenges** | Twice-yearly sweeping is fundamentally different from recurring schedules - more like event-based notifications than an ongoing monitoring tool. |

#### 1.10 Pittsburgh, PA

| Attribute | Detail |
|-----------|--------|
| **Market Size** | Growing enforcement - Pittsburgh is deploying **AI cameras on sweeping trucks** to automate ticket issuance via mail. This will dramatically increase ticket volume. |
| **Data Source** | [City of Pittsburgh website](https://pittsburghpa.gov) and Parking Authority. |
| **Data Format** | Limited structured open data. |
| **Key Difference from SF** | Automated camera enforcement (tickets mailed based on license plate capture). Business districts swept at night. Residential 8 AM - 2:30 PM. |
| **Unique Challenges** | AI-camera enforcement is new and means ticket rates will surge, increasing demand for the app. However, limited open data availability. |

### City Comparison Matrix

| City | Tickets/Year | Fine | Data Quality | Data Format | Seasonal? | Holiday Complexity | Priority |
|------|-------------|------|-------------|-------------|-----------|-------------------|----------|
| **Los Angeles** | ~480K | $73 | High | CSV/JSON/Socrata | Year-round | Low (CA holidays) | **P1** |
| **New York City** | ~1.9M | $45-65 | High | Shapefile/GeoJSON/Socrata | Year-round | **Very High** (33+ holidays) | **P1** |
| **Chicago** | ~200K+ | ~$60 | High | CSV/JSON/Socrata + GeoJSON zones | Apr-Nov | Low | **P1** |
| **Boston** | ~100K+ | $40-90 | Medium | CSV (legacy) | Apr-Nov | Medium (Patriots' Day) | **P2** |
| **Washington DC** | ~80K+ | $45 | Medium | Web/GIS | Mar-Oct | Medium (Emancipation Day) | **P2** |
| **Philadelphia** | ~50K+ | $31 | Low | Web only | Apr-Oct | Low | **P2** |
| **Denver** | ~137K | $50 | High | ArcGIS/GeoJSON | Apr-Nov | Low | **P2** |
| **San Diego** | Low | Varies | High | CSV/GeoJSON | Year-round | Low (CA holidays) | **P3** |
| **Minneapolis** | Varies | Varies | Medium | Web/Map | 2x/year | Low | **P3** |
| **Pittsburgh** | Growing | Varies | Low | Limited | Apr-Nov | Low | **P3** |

---

## 2. Technical Architecture for Multi-City

### 2.1 Current Architecture Assessment

Based on analysis of the current codebase:

**Current State (Single-City, SF-Only):**

| Component | File | Current Approach | Limitation |
|-----------|------|-----------------|------------|
| Data Access | `StreetRepository.swift` | Singleton with hardcoded SQLite DB name (`easystreet.db`) | No city identifier; assumes single city |
| Database | `DatabaseManager.swift` | Opens bundled read-only DB from `Bundle.main` | Can only ship one database in the binary |
| Models | `StreetSweepingData.swift` | `StreetSegment` has no city field; `SweepingRule` has no city context | No way to distinguish segments from different cities |
| Business Logic | `SweepingRuleEngine.swift` | Singleton calling `StreetRepository.shared` | No city-aware routing |
| Holidays | `HolidayCalculator.swift` | Hardcoded 11 SF/US holidays | Cannot handle NYC's 33+ holidays or state-specific holidays |
| Data Pipeline | `csv_to_sqlite.py` / `csv_to_json.py` | Hardcoded for SF CSV column names (`CNN`, `Corridor`, `WeekDay`, etc.) | Column names differ across cities |

### 2.2 Data Model Changes

#### New Schema: `street_segments` table

```sql
CREATE TABLE street_segments (
    id TEXT PRIMARY KEY,            -- Globally unique: "{city_code}:{local_id}"
    city_code TEXT NOT NULL,         -- e.g., "sf", "la", "nyc", "chi"
    street_name TEXT NOT NULL,
    neighborhood TEXT,               -- Optional: ward, district, borough
    block_side TEXT,                  -- Left/Right/Both
    lat_min REAL NOT NULL,
    lat_max REAL NOT NULL,
    lng_min REAL NOT NULL,
    lng_max REAL NOT NULL,
    coordinates TEXT NOT NULL,        -- JSON array of [lat, lng] pairs
    metadata TEXT                     -- JSON blob for city-specific fields
);

CREATE INDEX idx_segments_city ON street_segments(city_code);
CREATE INDEX idx_segments_bounds ON street_segments(city_code, lat_min, lat_max, lng_min, lng_max);
```

#### New Schema: `sweeping_rules` table

```sql
CREATE TABLE sweeping_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    segment_id TEXT NOT NULL REFERENCES street_segments(id),
    rule_type TEXT NOT NULL DEFAULT 'recurring',  -- 'recurring', 'dated', 'sign_based'
    day_of_week INTEGER,              -- 1=Sun..7=Sat (for recurring rules)
    start_time TEXT NOT NULL,          -- "HH:MM"
    end_time TEXT NOT NULL,            -- "HH:MM"
    weeks_of_month TEXT,              -- JSON array, e.g., [1,3] or [] for every week
    specific_dates TEXT,              -- JSON array of "YYYY-MM-DD" (for Chicago-style dated rules)
    apply_on_holidays INTEGER NOT NULL DEFAULT 0,
    sign_text TEXT,                    -- Original sign text (for NYC sign-based rules)
    metadata TEXT                      -- JSON blob for city-specific fields
);
```

#### New Schema: `cities` table

```sql
CREATE TABLE cities (
    code TEXT PRIMARY KEY,             -- "sf", "la", "nyc", "chi", etc.
    name TEXT NOT NULL,                -- "San Francisco", "Los Angeles", etc.
    state TEXT NOT NULL,               -- "CA", "NY", "IL", etc.
    center_lat REAL NOT NULL,
    center_lng REAL NOT NULL,
    default_zoom REAL NOT NULL,
    sweeping_type TEXT NOT NULL,        -- "recurring", "seasonal_recurring", "dated", "sign_based"
    season_start TEXT,                 -- "MM-DD" or NULL for year-round
    season_end TEXT,                   -- "MM-DD" or NULL for year-round
    data_version TEXT NOT NULL,        -- Semver: "1.0.3"
    data_updated_at TEXT NOT NULL,     -- ISO 8601 timestamp
    holiday_set TEXT NOT NULL,         -- "us_federal", "ca_state", "nyc_asp", "il_state", etc.
    timezone TEXT NOT NULL,            -- "America/Los_Angeles", "America/New_York", etc.
    ticket_fine_amount REAL,           -- For display: "$73"
    enforcement_note TEXT,             -- "Biweekly posted routes only"
    segment_count INTEGER NOT NULL DEFAULT 0
);
```

#### New Schema: `holidays` table

```sql
CREATE TABLE holidays (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    holiday_set TEXT NOT NULL,          -- FK to cities.holiday_set
    name TEXT NOT NULL,
    date TEXT NOT NULL,                 -- "YYYY-MM-DD" (for fixed or pre-computed floating)
    year INTEGER NOT NULL,
    suspends_sweeping INTEGER NOT NULL DEFAULT 1,
    suspends_meters INTEGER NOT NULL DEFAULT 0,
    notes TEXT
);

CREATE INDEX idx_holidays_set_year ON holidays(holiday_set, year);
```

### 2.3 Swift Model Changes

```swift
// New: City model
struct City: Codable, Identifiable {
    let code: String          // "sf", "la", "nyc"
    let name: String          // "San Francisco"
    let state: String         // "CA"
    let centerLatitude: Double
    let centerLongitude: Double
    let defaultZoom: Double
    let sweepingType: SweepingType
    let seasonStart: String?  // "04-01" or nil
    let seasonEnd: String?    // "11-15" or nil
    let dataVersion: String
    let dataUpdatedAt: String
    let holidaySet: String
    let timezone: String
    let ticketFineAmount: Double?
    let enforcementNote: String?
    let segmentCount: Int

    var id: String { code }

    enum SweepingType: String, Codable {
        case recurring              // SF, LA, Boston (weekly pattern)
        case seasonalRecurring      // Denver, DC (weekly but only in season)
        case dated                  // Chicago (specific calendar dates)
        case signBased              // NYC (ASP sign rules)
    }
}

// Modified: StreetSegment gains city context
struct StreetSegment: Codable, Identifiable {
    let id: String              // "{city_code}:{local_id}"
    let cityCode: String        // "sf"
    let streetName: String
    let neighborhood: String?
    let coordinates: [[Double]]
    let rules: [SweepingRule]
}

// Modified: SweepingRule supports multiple rule types
struct SweepingRule: Codable {
    let ruleType: RuleType
    let dayOfWeek: Int?         // For recurring rules
    let startTime: String
    let endTime: String
    let weeksOfMonth: [Int]?    // For recurring rules
    let specificDates: [String]? // For dated rules (Chicago)
    let applyOnHolidays: Bool
    let signText: String?       // For sign-based rules (NYC)

    enum RuleType: String, Codable {
        case recurring
        case dated
        case signBased
    }
}
```

### 2.4 Repository Layer Refactoring

The current `StreetRepository` (singleton, single-DB) needs to become city-aware:

```
Current:
  StreetRepository.shared (singleton)
    -> DatabaseManager.shared (single bundled DB)

Proposed:
  CityManager.shared
    -> manages list of available/downloaded cities
    -> handles city selection, GPS auto-detection

  StreetRepository (one per active city, NOT singleton)
    -> CityDatabaseManager (manages per-city DB files in app Documents dir)

  HolidayService
    -> loads holiday_set per city
    -> replaces single HolidayCalculator
```

**Key Changes to `StreetRepository.swift`:**
- Remove singleton pattern; instantiate per city
- Accept `cityCode` parameter in initializer
- Open city-specific database file from Documents directory (not Bundle)
- All queries include `city_code` filter

**Key Changes to `DatabaseManager.swift`:**
- Remove singleton pattern
- Accept database file path in `open()` (not hardcoded `easystreet.db`)
- Support read-write mode for downloaded databases (not just read-only from bundle)
- Add migration support for schema upgrades

**Key Changes to `HolidayCalculator.swift`:**
- Replace with `HolidayService` that loads holidays from the `holidays` table
- Support multiple holiday sets simultaneously (user might have cars parked in different cities)
- NYC holiday set needs ~33 entries including religious observances with floating dates (Eid, Lunar New Year, Passover, etc.)

### 2.5 Backend Server Requirements

The current app bundles all data in the binary. Multi-city requires a server.

```
┌─────────────────────────────────────────────┐
│                 Backend Server               │
├─────────────────────────────────────────────┤
│                                             │
│  ┌───────────────┐    ┌──────────────────┐  │
│  │ Data Ingestion │    │  City Registry   │  │
│  │   Pipeline     │    │     API          │  │
│  │               │    │                  │  │
│  │ SF CSV ──┐    │    │ GET /cities      │  │
│  │ LA CSV ──┤    │    │ GET /cities/{id} │  │
│  │ CHI API ─┤ ──►│    │ GET /cities/{id} │  │
│  │ NYC GeoJ─┤    │    │     /version     │  │
│  │ BOS CSV ─┘    │    └──────────────────┘  │
│  └───────────────┘                          │
│         │              ┌──────────────────┐  │
│         ▼              │  Data Download   │  │
│  ┌───────────────┐    │     API          │  │
│  │  Normalizer   │    │                  │  │
│  │  (per-city    │───►│ GET /data/{city} │  │
│  │   adapter)    │    │     .sqlite.gz   │  │
│  └───────────────┘    │                  │  │
│         │              │ GET /data/{city} │  │
│         ▼              │     /holidays    │  │
│  ┌───────────────┐    │                  │  │
│  │  SQLite DB    │    │ GET /data/{city} │  │
│  │  Generator    │    │     /delta       │  │
│  └───────────────┘    └──────────────────┘  │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │          Push Notification Service     │  │
│  │  - Data update alerts                 │  │
│  │  - Holiday suspension alerts          │  │
│  │  - Emergency suspension alerts (NYC)  │  │
│  └───────────────────────────────────────┘  │
│                                             │
└─────────────────────────────────────────────┘
```

**Minimum Server Stack:**
- **API:** Lightweight REST API (FastAPI/Python or Vapor/Swift)
- **Storage:** S3 or equivalent for pre-built SQLite DB files
- **Scheduler:** Cron jobs for periodic data ingestion (daily for NYC signs, annually for Chicago, as-needed for others)
- **Push:** APNS + FCM for data update notifications
- **Cost Estimate:** ~$50-200/month at early scale (S3 + small compute instance)

### 2.6 App UI Changes

#### City Selection Flow

```
First Launch:
  1. App detects GPS location
  2. If location matches a supported city -> auto-select, confirm with user
  3. If no match -> show city picker list
  4. Download city data package (~2-15 MB compressed)
  5. Store in Documents directory

Subsequent Launches:
  1. Load last-used city
  2. Check for data updates in background
  3. Allow switching cities via Settings or menu
```

#### UI Changes Required

| Screen | Change |
|--------|--------|
| **Map View** | Add city name in nav bar. Add city switcher button. Center on selected city. |
| **Settings** | New "Manage Cities" section: list downloaded cities, download new cities, delete city data, check for updates. |
| **Onboarding** | New city selection step during onboarding. |
| **Notifications** | Include city name in notification text. |
| **Street Detail** | Show city-specific info (fine amount, enforcement hours, seasonal status). |

### 2.7 Download-on-Demand Strategy

**Decision: Download-on-demand, NOT bundled.**

Rationale:
- SF database alone is ~7-15 MB. 10 cities would be 70-150 MB in the binary.
- App Store reviewers flag binaries > 200 MB.
- Most users need only 1-2 cities.
- Allows updating city data without app updates.

**Implementation:**

| Component | Approach |
|-----------|----------|
| **Bundle** | Ship with NO city data. Include only the city registry (list of available cities with metadata). |
| **First Download** | After city selection, download `{city_code}.sqlite.gz` (~2-8 MB compressed). Decompress to Documents directory. |
| **Updates** | App checks `data_version` against server on launch. If newer version available, download in background. Show badge on Settings. |
| **Delta Updates** | For large datasets (LA, NYC), support incremental updates: only download changed segments. Reduces update size to ~100-500 KB. |
| **Offline** | Once downloaded, all data works offline. No server dependency for core functionality. |
| **Storage** | Each city: 5-20 MB uncompressed SQLite. Total for 10 cities: ~100-200 MB. Show per-city storage usage in Settings. |

### 2.8 Holiday System Overhaul

The current `HolidayCalculator.swift` computes 11 SF holidays algorithmically. This approach does not scale because:

1. NYC has 33+ holidays including religious observances with dates that depend on lunar calendars (Eid, Lunar New Year, Passover).
2. Each city/state has unique holidays (Patriots' Day in MA, Pulaski Day in IL, Cesar Chavez Day in CA).
3. NYC publishes ad-hoc emergency suspensions (snow, construction) that cannot be pre-computed.

**New Approach: Server-Published Holiday Database**

```
holidays.json (per city, per year):
[
  {
    "date": "2026-01-01",
    "name": "New Year's Day",
    "suspendsSweeping": true,
    "suspendsMeters": true
  },
  {
    "date": "2026-03-20",
    "name": "Eid al-Fitr (1st Day)",
    "suspendsSweeping": true,
    "suspendsMeters": false
  },
  ...
]
```

- Holidays are pre-computed on the server for each city/year.
- Included in the city data package download.
- Can be updated independently of street data (important for NYC emergency suspensions).
- App falls back to algorithmic US federal holidays if holiday data is unavailable.

---

## 3. Data Pipeline Architecture

### 3.1 Overview

Each city publishes data in different formats, with different column names, different schemas, and on different platforms. The pipeline must normalize all of these into the EasyStreet unified schema.

```
┌─────────────────────────────────────────────────────┐
│                  Data Pipeline                       │
│                                                     │
│  ┌──────────┐   ┌──────────┐   ┌────────────────┐  │
│  │ Ingestor │   │Normalizer│   │  DB Generator  │  │
│  │ (per     │──►│ (common  │──►│  (per city)    │  │
│  │  city)   │   │  schema) │   │                │  │
│  └──────────┘   └──────────┘   └────────────────┘  │
│       │              │              │               │
│       ▼              ▼              ▼               │
│  City-specific   Validated      city.sqlite.gz     │
│  raw data        segments +      uploaded to       │
│                  rules           S3/CDN             │
└─────────────────────────────────────────────────────┘
```

### 3.2 Per-City Ingestor Adapters

Each city gets a Python adapter that understands its specific data format:

```python
# Base class
class CityIngestor(ABC):
    @abstractmethod
    def fetch_raw_data(self) -> RawData:
        """Download or read raw data from city source."""
        pass

    @abstractmethod
    def parse_segments(self, raw: RawData) -> list[NormalizedSegment]:
        """Parse city-specific format into normalized segments."""
        pass

    @abstractmethod
    def parse_rules(self, raw: RawData, segment_id: str) -> list[NormalizedRule]:
        """Parse city-specific rules into normalized rules."""
        pass

# Per-city implementations
class SFIngestor(CityIngestor):
    """San Francisco: CSV with CNN, Corridor, WeekDay, FromHour, ToHour, Week1-5, Holidays, Line (WKT)"""
    # Already implemented in csv_to_sqlite.py and csv_to_json.py

class LAIngestor(CityIngestor):
    """Los Angeles: CSV/JSON from Socrata with route numbers, boundaries, times.
    Geometry from LA GeoHub shapefile/GeoJSON."""

class NYCIngestor(CityIngestor):
    """NYC: Shapefile/GeoJSON from OpenCurb or NYC Open Data.
    Sign-based rules parsed from sign_description field.
    ASP suspension calendar from ICS file."""

class ChicagoIngestor(CityIngestor):
    """Chicago: Socrata CSV with Ward, Section, specific dates.
    Zone polygons from separate GeoJSON dataset.
    Must convert zone polygons to street segments."""

class BostonIngestor(CityIngestor):
    """Boston: CSV from Analyze Boston.
    May require supplemental scraping of lookup tool."""

class DenverIngestor(CityIngestor):
    """Denver: ArcGIS Feature Service with GeoJSON geometry.
    Different API than Socrata-based cities."""

class DCIngestor(CityIngestor):
    """Washington DC: Web scraping + GIS data.
    Less structured than other cities."""
```

### 3.3 Data Format Mapping

| City | Raw Format | Geometry Format | Schedule Format | Adapter Complexity |
|------|-----------|----------------|-----------------|-------------------|
| **SF** | CSV (Socrata) | WKT LINESTRING in CSV | Weekly pattern (WeekDay, FromHour, ToHour, Week1-5) | Low (already done) |
| **LA** | CSV/JSON (Socrata) | Separate GeoJSON/Shapefile | Route-based biweekly (1st/3rd or 2nd/4th) | Medium |
| **NYC** | Shapefile/GeoJSON | Embedded in shapefile | Sign text parsing ("NO PARKING 8:30-10AM M&TH") | **High** (NLP for sign text) |
| **Chicago** | CSV (Socrata) | Separate zone polygons | Specific calendar dates per ward section | Medium |
| **Boston** | CSV | Embedded or separate | Weekly pattern | Medium |
| **Denver** | GeoJSON (ArcGIS) | Embedded in GeoJSON | Weekly pattern | Low-Medium |
| **DC** | Web/GIS | GIS data | Weekly 2-hour windows | Medium |
| **San Diego** | CSV/GeoJSON | Embedded in GeoJSON | Monthly pattern | Low |

### 3.4 Normalization Layer

All ingestors produce the same output format:

```python
@dataclass
class NormalizedSegment:
    local_id: str               # City's own ID
    city_code: str              # "sf", "la", etc.
    street_name: str
    neighborhood: str | None
    coordinates: list[list[float]]  # [[lat, lng], ...]
    lat_min: float
    lat_max: float
    lng_min: float
    lng_max: float

@dataclass
class NormalizedRule:
    segment_id: str             # Will be prefixed with city_code
    rule_type: str              # "recurring", "dated", "sign_based"
    day_of_week: int | None     # 1=Sun..7=Sat
    start_time: str             # "HH:MM"
    end_time: str               # "HH:MM"
    weeks_of_month: list[int] | None
    specific_dates: list[str] | None
    apply_on_holidays: bool
    sign_text: str | None
```

### 3.5 Update Frequency Strategy

| City | Source Update Frequency | Our Ingestion Frequency | Trigger |
|------|------------------------|------------------------|---------|
| **SF** | As-needed (infrequent) | Monthly | Cron check + manual |
| **LA** | As routes change | Monthly | Socrata API change detection |
| **NYC** | Signs updated daily | Weekly (signs), Daily (suspensions) | Automated |
| **Chicago** | Annually (new dataset) | Annually in March (before April start) | Manual + calendar trigger |
| **Boston** | Seasonally | Quarterly | Manual + calendar trigger |
| **Denver** | Seasonally | Annually in March | Calendar trigger |
| **DC** | Seasonally | Annually in February | Calendar trigger |

### 3.6 Data Validation & Quality Assurance

Every ingestion run must validate:

1. **Geometry Validation**
   - All coordinates within expected city bounding box
   - No degenerate segments (< 2 points)
   - No duplicate segment IDs

2. **Rule Validation**
   - Start time < end time
   - Day of week in range [1, 7]
   - Weeks of month in range [1, 5]
   - Specific dates are valid dates

3. **Coverage Validation**
   - Total segment count within expected range (flag if > 20% change from previous run)
   - Geographic coverage check (sample known streets should be present)
   - Rule distribution check (most segments should have at least one rule)

4. **Regression Testing**
   - Maintain a set of "golden" test addresses per city
   - After each ingestion, verify expected sweeping schedules for test addresses
   - Alert on any regression

---

## 4. Phased Rollout Plan

### Phase 1: California Expansion (Months 1-3)

**Cities:** Los Angeles + San Diego
**Why these first:**
- Same state = same holidays (minimal `HolidayCalculator` changes)
- Same data format philosophy (SF and LA both use Socrata + CSV)
- LA is the #1 target market by ticket volume in any single US city for street sweeping
- San Diego provides a "quick win" with excellent open data quality
- No seasonal complexity (year-round sweeping in all three CA cities)
- Allows testing multi-city architecture without needing to solve the hardest problems (NYC ASP, Chicago dated schedules)

**Technical Work:**
1. Refactor `StreetRepository` and `DatabaseManager` for multi-DB support
2. Build city selection UI and download-on-demand infrastructure
3. Build minimal backend (S3 + API for city registry and data downloads)
4. Create LA and SD ingestor adapters (extending existing SF pipeline)
5. Expand `HolidayCalculator` with Cesar Chavez Day for CA cities
6. Build Android parity for all above

**Milestone:** App supports 3 California cities with on-demand download.

### Phase 2: Major Market Expansion (Months 4-8)

**Cities:** Chicago + NYC + Boston + Denver
**Why these next:**
- Chicago and NYC represent the two largest remaining markets
- Each introduces a new schedule type that must be supported (dated rules for Chicago, sign-based rules for NYC)
- Boston and Denver are incremental after the Chicago seasonal pattern is solved
- By this phase, the architecture is proven and we're adding adapters, not rebuilding

**Technical Work:**
1. Implement `dated` rule type for Chicago's ward-section-date model
2. Implement `sign_based` rule type for NYC's ASP signs
3. Build NYC holiday system with 33+ observances including lunar/religious calendar dates
4. Add seasonal awareness to the UI (show "season starts April 1" messaging)
5. Build ArcGIS ingestor for Denver's data format
6. Implement delta update system for large datasets (LA, NYC)
7. Add push notifications for NYC emergency ASP suspensions
8. Build Boston ingestor (may require scraping if legacy CSV is insufficient)

**Milestone:** App supports 7 cities across 3 schedule types.

### Phase 3: National Coverage (Months 9-18)

**Cities:** Washington DC, Philadelphia, Pittsburgh, Minneapolis, + community-requested cities
**Strategy:** By Phase 3, the architecture supports all schedule types. Expansion becomes primarily a data ingestion problem, not an engineering problem.

**Technical Work:**
1. Build remaining city ingestors
2. Community data contribution system (users can submit corrections)
3. Partnership outreach to cities for data access agreements
4. Automated data quality monitoring and alerting
5. Consider white-label / API offering for other parking apps

**Milestone:** 10+ cities. National brand recognition. Platform for rapid expansion.

### Timeline Summary

```
Month 1-2:  Architecture refactoring (multi-DB, city model, download-on-demand)
Month 2-3:  LA + San Diego launch (Phase 1 complete)
Month 4-5:  Chicago launch (dated rules)
Month 5-7:  NYC launch (sign-based rules, complex holidays)
Month 7-8:  Boston + Denver launch (Phase 2 complete)
Month 9-12: DC + Philadelphia + Pittsburgh
Month 12-18: National expansion, community contributions, partnerships
```

---

## 5. Monetization Considerations

### 5.1 How Multi-City Changes the Business Model

**Single-City (Current):** Limited revenue potential. SF has ~$37M in street sweeping ticket revenue, but the addressable market for an app is a fraction of that (users willing to pay for an app to avoid a $75 ticket).

**Multi-City:** The aggregate market expands dramatically:
- LA + NYC + Chicago + SF alone represent ~2.8M+ tickets/year and ~$250M+ in fines
- Even capturing 1% of users at $2-5/month = $500K-$1.5M ARR
- Network effects: word-of-mouth in dense urban communities

### 5.2 Revenue Model Options

| Model | Description | Pros | Cons |
|-------|-------------|------|------|
| **Freemium** | Free for 1 city, $2.99/month for multi-city or premium features | Low barrier to entry; upsell path | Must deliver enough free value to hook users |
| **City Pack IAP** | $0.99-2.99 one-time per city | Simple; users pay for what they need | Lower recurring revenue |
| **Subscription** | $2.99-4.99/month for all cities + premium | Predictable recurring revenue | Harder to justify monthly cost |
| **Ad-Supported Free** | Free with ads; remove ads for $1.99/month | Largest user base | Ad revenue is low; UX trade-off |

**Recommended:** **Freemium + Subscription Hybrid**
- **Free tier:** One city, basic sweeping schedule display, 1-hour-before notifications
- **Premium ($2.99/month or $19.99/year):**
  - Unlimited cities
  - Customizable notification timing (2h, 4h, night-before, morning-of)
  - Widget support (iOS home screen, Android widget)
  - Calendar integration (auto-add sweeping to calendar)
  - "Where Can I Park?" safe zone finder
  - Emergency suspension push alerts (NYC)
  - Family sharing (track multiple cars)

### 5.3 Partnership Opportunities

| Partner Type | Opportunity | Revenue Potential |
|--------------|------------|-------------------|
| **Cities** | White-label version for city websites ("powered by EasyStreet"). Cities want to reduce resident complaints about tickets. | Contract revenue: $10K-50K/city/year |
| **Insurance** | Auto insurers could offer EasyStreet Premium as a perk (fewer tickets = better risk profile). | B2B licensing: $1-3 per subscriber/month |
| **Parking Apps** | SpotHero, ParkWhiz, ParkMobile could integrate EasyStreet data for their street parking users. | API licensing: per-query pricing |
| **Navigation Apps** | Waze, Google Maps, Apple Maps -- parking data integration. | Acquisition target or data licensing deal |
| **Real Estate** | Street sweeping data as a neighborhood "parking difficulty" signal for apartment listings. | Data licensing |

---

## 6. Risk Assessment

### 6.1 Data Risks

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| **City changes data format without notice** | High | Medium | Version-check ingestion; alert on schema changes; maintain format adapters per city |
| **City discontinues open data portal** | High | Low | Cache all raw data; maintain relationships with city data teams; scraping fallback |
| **Data quality degrades** | Medium | Medium | Automated validation pipeline; golden-test regression suite; user-reported corrections |
| **Stale data causes incorrect advice** | **Critical** | Medium | Display "last updated" prominently; warn if data is > 30 days old; periodic freshness checks |
| **NYC emergency suspensions missed** | High | Medium | Real-time push integration with NYC 311 API; manual monitoring fallback |

### 6.2 Legal & Licensing Risks

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| **Municipal data terms of use restrict commercial use** | Medium | Low | Most US city open data is explicitly public domain or CC0. Review each city's ToS before launch. |
| **Liability if user gets ticket due to stale/wrong data** | High | Medium | Clear disclaimer: "Not a substitute for checking posted signs." Terms of service limit liability. |
| **Competitor patents on parking data aggregation** | Low | Low | Prior art is extensive (SpotAngels since 2015, numerous city apps). FTO analysis recommended before raising funding. |

### 6.3 Competitive Risks

| Competitor | Threat Level | Their Advantage | Our Advantage |
|------------|-------------|-----------------|---------------|
| **SpotAngels** | **High** | Already multi-city (100+ cities), 4.7-star rating, free, VC-funded | SpotAngels is broad (meters, garages, street cleaning); EasyStreet can be deeper on sweeping/ASP |
| **Xtreet** | Medium | Multi-city, covers SF, Boston, Chicago, Phoenix | Smaller user base; less polished |
| **We The Sweeple** | Low | Chicago-specific; free; email alerts | Single-city only; no app |
| **FreeParkNYC** | Low | NYC-specific; ASP focus | Single-city only |
| **ParkMobile** | Medium | 20M+ users, 500+ cities | Focused on paid parking, not sweeping |
| **City-built tools** | Low | Official source; free | Poor UX; limited features; no push notifications |

**Competitive Strategy:** Position EasyStreet as the **specialist** in street sweeping/ASP avoidance. SpotAngels is a generalist parking app (garages, meters, sweeping, gas prices). EasyStreet should be the **best** at the sweeping use case -- better notifications, better real-time updates, better UI for understanding rules, and features SpotAngels doesn't have (family car tracking, calendar integration, safe-zone finder).

### 6.4 Technical Scalability Risks

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| **Database size grows beyond device storage** | Medium | Low | Per-city databases; users download only cities they need; ~10-20 MB per city is manageable |
| **Server costs scale unexpectedly** | Medium | Low | Pre-built SQLite files on S3/CDN are cheap to serve; no per-query server compute for most operations |
| **Data pipeline becomes maintenance burden** | High | High | Each city adapter requires ongoing maintenance. Budget 1-2 engineering days/quarter per city for data pipeline maintenance. |
| **Platform differences between iOS and Android grow** | Medium | Medium | Share data pipeline and backend entirely. Keep platform-specific code to UI layer only. Consider shared Kotlin Multiplatform for business logic long-term. |

### 6.5 Key Risk: NYC is Hard

NYC deserves special attention as a risk factor. It is simultaneously the largest market and the most technically challenging:

1. **Sign parsing:** Rules are encoded in sign text ("NO PARKING 8:30AM-10AM MON & THURS") which requires NLP or robust regex parsing.
2. **Overlapping regulations:** A single curb segment can have ASP rules, metered parking, no-standing zones, and commercial loading zones -- all overlapping.
3. **33+ holidays:** Including religious observances tied to lunar calendars that shift year to year.
4. **Emergency suspensions:** Snow emergencies, construction, events -- all announced ad-hoc via NYC 311.
5. **5 boroughs:** Different enforcement patterns; Manhattan below 96th St has higher fines ($65) than the rest of the city ($45).

**Recommendation:** Allocate 2-3x the engineering effort for NYC compared to other cities. Consider launching NYC as a "beta" with limited borough coverage (Manhattan first) and expanding.

---

## Appendix A: Data Source URLs

| City | Primary Data URL | Format |
|------|-----------------|--------|
| San Francisco | https://data.sfgov.org/City-Infrastructure/Street-Sweeping-Schedule/yhqp-riqs | Socrata CSV |
| Los Angeles | https://data.lacity.org/City-Infrastructure-Service-Requests/Posted-Street-Sweeping-Routes/krk7-ayq2 | Socrata CSV/JSON |
| New York City | https://data.cityofnewyork.us/Transportation/Parking-Regulation-Locations-and-Signs/xswq-wnv9 | Socrata Shapefile |
| New York City (OpenCurb) | http://www.opencurb.nyc/ | GeoJSON API |
| New York City (Signs) | https://data.cityofnewyork.us/Transportation/Alternate-Side-Parking-signs-locations-NYCDOT/2x64-6f34 | Socrata |
| Chicago (Schedule) | https://data.cityofchicago.org/Sanitation/Street-Sweeping-Schedule-2025/a2xx-z2ja | Socrata CSV |
| Chicago (Zones) | https://data.cityofchicago.org/Sanitation/Street-Sweeping-Zones-2025/utb4-q645 | Socrata GeoJSON |
| Boston | https://data.boston.gov/dataset/street-sweeping-schedules | CSV |
| Denver | https://www.opendata-geospatialdenver.hub.arcgis.com/maps/geospatialDenver::street-sweep-schedule/explore | ArcGIS GeoJSON |
| Washington DC | https://dpw.dc.gov/service/street-sweeping-scheduled | Web |
| Philadelphia | https://www.phila.gov/programs/mechanical-street-cleaning/cleaning-schedule/ | Web |
| San Diego | https://data.sandiego.gov/datasets/street-sweeping-schedule/ | CSV/GeoJSON |

## Appendix B: Holiday Sets by City

| Holiday Set | Cities | # of Holidays/Year | Notable Entries |
|------------|--------|-------------------|-----------------|
| `us_federal` | Base for all | 11 | New Year's, MLK, Presidents', Memorial, Juneteenth, July 4th, Labor, Columbus/Indigenous Peoples', Veterans, Thanksgiving, Christmas |
| `ca_state` | SF, LA, SD | 12 | + Cesar Chavez Day (Mar 31) |
| `nyc_asp` | NYC | 33+ | + Lunar New Year, Purim, Eid Al-Fitr, Eid Al-Adha, Passover (multiple days), Shavuoth, Diwali, Losar, Holy Thursday, Good Friday, Ash Wednesday, Feast of Assumption, Tisha B'Av, Lincoln's Birthday, Three Kings' Day, Solemnity of Ascension |
| `il_state` | Chicago | 13 | + Lincoln's Birthday (Feb 12), Casimir Pulaski Day (1st Mon Mar), Election Day |
| `ma_state` | Boston | 13 | + Patriots' Day (3rd Mon Apr), Evacuation Day (Mar 17, Suffolk County) |
| `dc_local` | Washington DC | 13 | + Emancipation Day (Apr 16), Inauguration Day (every 4 years Jan 20) |
| `co_state` | Denver | 11 | Same as federal |
| `pa_state` | Philadelphia, Pittsburgh | 11 | Same as federal |

## Appendix C: Estimated Database Sizes

| City | Est. Street Segments | Est. Rules | Est. SQLite Size (uncompressed) | Est. Compressed |
|------|---------------------|------------|--------------------------------|-----------------|
| San Francisco | ~25,000 | ~40,000 | ~8 MB | ~3 MB |
| Los Angeles | ~50,000-100,000 | ~100,000-200,000 | ~20-40 MB | ~6-12 MB |
| New York City | ~100,000-200,000 | ~200,000-400,000 | ~40-80 MB | ~12-25 MB |
| Chicago | ~30,000 | ~60,000 | ~10 MB | ~3 MB |
| Boston | ~10,000 | ~20,000 | ~5 MB | ~2 MB |
| Denver | ~15,000 | ~25,000 | ~6 MB | ~2 MB |
| Washington DC | ~10,000 | ~20,000 | ~5 MB | ~2 MB |
| San Diego | ~20,000 | ~30,000 | ~8 MB | ~3 MB |
| Philadelphia | ~5,000 | ~10,000 | ~3 MB | ~1 MB |
| **Total (all cities)** | **~265,000-410,000** | **~505,000-805,000** | **~105-175 MB** | **~34-53 MB** |

---

## Appendix D: Referenced Codebase Files

Current architecture files that will need modification:

| File | Path | Key Change Needed |
|------|------|-------------------|
| StreetRepository | `EasyStreet/Data/StreetRepository.swift` | Remove singleton; add city parameter; query with city_code filter |
| DatabaseManager | `EasyStreet/Data/DatabaseManager.swift` | Remove singleton; support Documents dir path; read-write mode |
| StreetSweepingData | `EasyStreet/Models/StreetSweepingData.swift` | Add cityCode to StreetSegment; add RuleType enum; add City model |
| SweepingRuleEngine | `EasyStreet/Utils/SweepingRuleEngine.swift` | Accept city parameter; route to correct holiday set |
| HolidayCalculator | `EasyStreet/Utils/HolidayCalculator.swift` | Replace with HolidayService loading from DB; support 33+ NYC holidays |
| csv_to_sqlite.py | `EasyStreet_Android/tools/csv_to_sqlite.py` | Refactor into base class + per-city adapters; add city_code column |
| csv_to_json.py | `tools/csv_to_json.py` | Refactor into adapter pattern; add city_code field |

---

*This document should be reviewed by the development team and updated as research continues. Data source availability and formats should be verified with fresh API calls before beginning Phase 1 implementation.*
