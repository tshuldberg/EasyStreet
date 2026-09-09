# EasyStreet Data Models & Architecture Diagrams

Generated: 2026-02-09

## Entity-Relationship Diagram

This diagram covers the core data entities across both iOS (Swift/UIKit) and Android (Kotlin/Compose) platforms, plus the shared SQLite database schema.

```mermaid
erDiagram
    STREET-SEGMENT {
        string id PK
        int cnn UK
        string street_name
        text coordinates
        real lat_min
        real lat_max
        real lng_min
        real lng_max
    }

    SWEEPING-RULE {
        int id PK
        string segment_id FK
        int day_of_week
        string start_time
        string end_time
        text weeks_of_month
        bool apply_on_holidays
    }

    METADATA {
        string key PK
        string value
    }

    PARKED-CAR {
        float latitude
        float longitude
        string street_name
        timestamp parked_time
    }

    SWEEPING-STATUS {
        enum type
        datetime time
        string street_name
    }

    BOUNDING-BOX {
        real lat_min
        real lat_max
        real lng_min
        real lng_max
    }

    LAT-LNG-POINT {
        double latitude
        double longitude
    }

    HOLIDAY {
        date observed_date
        string name
        enum type
    }

    STREET-SEARCH-RESULT {
        string street_name
        double center_lat
        double center_lng
        int segment_count
    }

    NOTIFICATION {
        string id PK
        datetime trigger_time
        string street_name
        int lead_minutes
    }

    MAP-COLOR-STATUS {
        enum color
    }

    STREET-SEGMENT ||--o{ SWEEPING-RULE : "has rules"
    STREET-SEGMENT ||--|| BOUNDING-BOX : "bounded by"
    STREET-SEGMENT ||--|{ LAT-LNG-POINT : "defined by coordinates"
    STREET-SEGMENT ||--|| MAP-COLOR-STATUS : "displays as"
    PARKED-CAR }o--|| STREET-SEGMENT : "parked on"
    SWEEPING-RULE ||--|| SWEEPING-STATUS : "evaluates to"
    SWEEPING-RULE }o--o{ HOLIDAY : "skipped on (unless apply_on_holidays)"
    PARKED-CAR ||--o{ NOTIFICATION : "triggers"
    STREET-SEGMENT ||--o{ STREET-SEARCH-RESULT : "aggregates into"
```

## System Architecture Flowchart

Shows the layered architecture across both iOS and Android platforms, sharing the same SQLite database format.

```mermaid
flowchart LR
    subgraph DATA["Shared Data Layer"]
        CSV["Street Sweeping CSV\n(37,856 segments)"]
        CONVERTER["JSON/CSV-to-SQLite\nConverter Scripts"]
        SQLITE[("easystreet.db\nSQLite Database")]
        CSV --> CONVERTER --> SQLITE
    end

    subgraph IOS["iOS Platform (Swift/UIKit)"]
        DB_MGR["DatabaseManager\n(SQLite3 C API)"]
        STREET_REPO_IOS["StreetRepository\n(SQLite + JSON fallback)"]
        PARKING_REPO_IOS["ParkingRepository\n(UserDefaults)"]
        RULE_ENGINE_IOS["SweepingRuleEngine"]
        HOLIDAY_IOS["HolidayCalculator\n(11 SF holidays)"]
        MAP_VC["MapViewController\n(MapKit)"]
        NOTIF_IOS["ParkedCarManager\n(UNNotifications)"]
    end

    subgraph ANDROID["Android Platform (Kotlin/Compose)"]
        STREET_DB["StreetDatabase\n(SQLiteDatabase)"]
        STREET_DAO["StreetDao\n(raw queries + cache)"]
        STREET_REPO_AND["StreetRepository\n(coroutines)"]
        PARKING_REPO_AND["ParkingRepository\n(SharedPreferences)"]
        RULE_ENGINE_AND["SweepingRuleEngine"]
        HOLIDAY_AND["HolidayCalculator\n(11 SF holidays)"]
        MAP_VM["MapViewModel\n(StateFlow)"]
        MAP_SCREEN["MapScreen\n(Google Maps Compose)"]
        NOTIF_AND["NotificationScheduler\n(WorkManager)"]
    end

    SQLITE --> DB_MGR
    DB_MGR --> STREET_REPO_IOS
    STREET_REPO_IOS --> MAP_VC
    PARKING_REPO_IOS --> MAP_VC
    RULE_ENGINE_IOS --> MAP_VC
    HOLIDAY_IOS --> RULE_ENGINE_IOS
    NOTIF_IOS --> MAP_VC

    SQLITE --> STREET_DB
    STREET_DB --> STREET_DAO
    STREET_DAO --> STREET_REPO_AND
    STREET_REPO_AND --> MAP_VM
    PARKING_REPO_AND --> MAP_VM
    RULE_ENGINE_AND --> MAP_VM
    HOLIDAY_AND --> RULE_ENGINE_AND
    MAP_VM --> MAP_SCREEN
    NOTIF_AND --> MAP_VM
```

## SQLite Database Schema Detail

### `street_segments` Table (iOS)

| Column | Type | Constraint |
|--------|------|------------|
| id | TEXT | PRIMARY KEY |
| street_name | TEXT | NOT NULL |
| coordinates | TEXT | NOT NULL (JSON array of [lat, lng]) |
| lat_min | REAL | NOT NULL |
| lat_max | REAL | NOT NULL |
| lng_min | REAL | NOT NULL |
| lng_max | REAL | NOT NULL |

### `street_segments` Table (Android)

| Column | Type | Constraint |
|--------|------|------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT |
| cnn | INTEGER | NOT NULL |
| street_name | TEXT | NOT NULL |
| limits_desc | TEXT | (nullable) |
| block_side | TEXT | (nullable) |
| latitude_min | REAL | NOT NULL |
| latitude_max | REAL | NOT NULL |
| longitude_min | REAL | NOT NULL |
| longitude_max | REAL | NOT NULL |
| coordinates | TEXT | NOT NULL |

### `sweeping_rules` Table (iOS)

| Column | Type | Constraint |
|--------|------|------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT |
| segment_id | TEXT | NOT NULL, FK -> street_segments(id) |
| day_of_week | INTEGER | NOT NULL |
| start_time | TEXT | NOT NULL |
| end_time | TEXT | NOT NULL |
| weeks_of_month | TEXT | NOT NULL (JSON array) |
| apply_on_holidays | INTEGER | NOT NULL DEFAULT 0 |

### `sweeping_rules` Table (Android)

| Column | Type | Constraint |
|--------|------|------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT |
| segment_id | INTEGER | NOT NULL, FK -> street_segments(id) |
| day_of_week | INTEGER | NOT NULL (1=Mon..7=Sun, java.time) |
| start_time | TEXT | NOT NULL |
| end_time | TEXT | NOT NULL |
| week_of_month | INTEGER | NOT NULL DEFAULT 0 (0=every week) |
| holidays_observed | INTEGER | NOT NULL DEFAULT 0 |

### `metadata` Table (iOS only)

| Column | Type | Constraint |
|--------|------|------------|
| key | TEXT | PRIMARY KEY |
| value | TEXT | NOT NULL |

### Indexes

- `idx_segments_bbox` / `idx_segments_bounds` on bounding box columns (spatial queries)
- `idx_rules_segment` on `segment_id` (rule lookups per segment)

## Platform Schema Differences

| Aspect | iOS | Android |
|--------|-----|---------|
| Segment ID type | TEXT (string) | INTEGER (autoincrement) |
| Extra columns | -- | cnn, limits_desc, block_side |
| Day-of-week convention | 1=Sun..7=Sat (Apple Calendar) | 1=Mon..7=Sun (java.time.DayOfWeek) |
| Weeks encoding | JSON array `[1,3]` | Single integer (0=every) |
| Holiday column name | apply_on_holidays | holidays_observed |
| Bounding box columns | lat_min/lat_max/lng_min/lng_max | latitude_min/latitude_max/longitude_min/longitude_max |
| Metadata table | Yes | No |

## In-Memory Models Summary

### Shared Concepts (Both Platforms)

| Model | iOS (Swift) | Android (Kotlin) | Fields |
|-------|-------------|-------------------|--------|
| Street Segment | `StreetSegment` struct | `StreetSegment` data class | id, streetName, coordinates, rules, bounds |
| Sweeping Rule | `SweepingRule` struct | `SweepingRule` data class | dayOfWeek, startTime, endTime, weeksOfMonth, applyOnHolidays |
| Parked Car | `ParkedCarManager` class | `ParkedCar` data class | latitude, longitude, streetName, timestamp |
| Sweeping Status | `SweepingStatus` enum | `SweepingStatus` sealed class | safe, today, imminent, upcoming, noData, unknown (+activeNow on Android) |
| Holiday Calculator | `HolidayCalculator` class | `HolidayCalculator` object | 11 SF holidays, observed-date shifting, year-based caching |

### Android-Only Models

| Model | Description |
|-------|-------------|
| `LatLngPoint` | Coordinate pair (latitude, longitude) |
| `BoundingBox` | Geographic bounding rectangle (latMin/Max, lngMin/Max) |
| `StreetSearchResult` | Aggregated search result (streetName, center coordinate, segment count) |
