#!/usr/bin/env python3
"""
convert_json_to_sqlite.py

Converts sweeping_data_sf.json into an SQLite database (easystreet.db)
for use by the EasyStreet iOS app.

Usage:
    python3 convert_json_to_sqlite.py <input.json> <output.db>

The input JSON is an array of street segment objects, each with:
    - id: unique segment identifier
    - streetName: human-readable street name
    - coordinates: array of [lat, lng] pairs
    - rules: array of sweeping rule objects

The output database has three tables:
    - street_segments (id, street_name, coordinates, lat_min/max, lng_min/max)
    - sweeping_rules (id, segment_id, day_of_week, start_time, end_time,
                      weeks_of_month, apply_on_holidays)
    - metadata (key, value) -- data version tracking
"""

import json
import sqlite3
import sys
import os
import time
import datetime


SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS street_segments (
    id TEXT PRIMARY KEY,
    street_name TEXT NOT NULL,
    coordinates TEXT NOT NULL,
    lat_min REAL NOT NULL,
    lat_max REAL NOT NULL,
    lng_min REAL NOT NULL,
    lng_max REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS sweeping_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    segment_id TEXT NOT NULL REFERENCES street_segments(id),
    day_of_week INTEGER NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL,
    weeks_of_month TEXT NOT NULL,
    apply_on_holidays INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_segments_bbox
    ON street_segments(lat_min, lat_max, lng_min, lng_max);

CREATE INDEX IF NOT EXISTS idx_rules_segment
    ON sweeping_rules(segment_id);

CREATE TABLE IF NOT EXISTS metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
"""


def compute_bounding_box(coordinates):
    """Compute the lat/lng bounding box from a list of [lat, lng] pairs."""
    lats = [coord[0] for coord in coordinates]
    lngs = [coord[1] for coord in coordinates]
    return min(lats), max(lats), min(lngs), max(lngs)


def convert(input_path, output_path):
    """Read JSON input and write to an SQLite database."""
    # Validate input file exists
    if not os.path.isfile(input_path):
        print(f"Error: Input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    # Remove existing output database if present
    if os.path.exists(output_path):
        os.remove(output_path)
        print(f"Removed existing database: {output_path}")

    # Read JSON data
    print(f"Reading JSON from: {input_path}")
    start_time = time.time()

    with open(input_path, "r", encoding="utf-8") as f:
        segments = json.load(f)

    read_elapsed = time.time() - start_time
    print(f"Loaded {len(segments)} segments in {read_elapsed:.2f}s")

    # Open SQLite database and create schema
    conn = sqlite3.connect(output_path)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=OFF")
    conn.executescript(SCHEMA_SQL)

    segment_count = 0
    rule_count = 0

    # Use a single transaction for all inserts
    conn.execute("BEGIN TRANSACTION")

    for segment in segments:
        segment_id = segment["id"]
        street_name = segment["streetName"]
        coordinates = segment["coordinates"]

        # Compute bounding box from coordinates
        lat_min, lat_max, lng_min, lng_max = compute_bounding_box(coordinates)

        # Store coordinates as a JSON string
        coordinates_json = json.dumps(coordinates)

        conn.execute(
            """
            INSERT INTO street_segments (id, street_name, coordinates, lat_min, lat_max, lng_min, lng_max)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (segment_id, street_name, coordinates_json, lat_min, lat_max, lng_min, lng_max),
        )
        segment_count += 1

        # Insert each sweeping rule for this segment
        for rule in segment.get("rules", []):
            day_of_week = rule["dayOfWeek"]
            start_time_val = rule["startTime"]
            end_time_val = rule["endTime"]
            weeks_of_month_json = json.dumps(rule["weeksOfMonth"])
            apply_on_holidays = 1 if rule.get("applyOnHolidays", False) else 0

            conn.execute(
                """
                INSERT INTO sweeping_rules (segment_id, day_of_week, start_time, end_time, weeks_of_month, apply_on_holidays)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (segment_id, day_of_week, start_time_val, end_time_val, weeks_of_month_json, apply_on_holidays),
            )
            rule_count += 1

        # Print progress every 1000 segments
        if segment_count % 1000 == 0:
            print(f"  Processed {segment_count} segments ({rule_count} rules so far)...")

    conn.execute("COMMIT")

    # Insert metadata
    csv_source = os.path.basename(input_path).replace(".json", ".csv")
    conn.execute("INSERT INTO metadata (key, value) VALUES (?, ?)",
                 ("csv_source", csv_source))
    conn.execute("INSERT INTO metadata (key, value) VALUES (?, ?)",
                 ("build_date", datetime.datetime.utcnow().isoformat() + "Z"))
    conn.execute("INSERT INTO metadata (key, value) VALUES (?, ?)",
                 ("segment_count", str(segment_count)))
    conn.execute("INSERT INTO metadata (key, value) VALUES (?, ?)",
                 ("schema_version", "2"))
    conn.commit()

    # Optimize the database
    conn.execute("ANALYZE")
    conn.execute("VACUUM")
    conn.close()

    total_elapsed = time.time() - start_time
    db_size = os.path.getsize(output_path)
    db_size_mb = db_size / (1024 * 1024)

    print()
    print("=== Conversion Complete ===")
    print(f"  Segments inserted: {segment_count}")
    print(f"  Rules inserted:    {rule_count}")
    print(f"  Database size:     {db_size_mb:.2f} MB")
    print(f"  Output file:       {output_path}")
    print(f"  Total time:        {total_elapsed:.2f}s")


def main():
    if len(sys.argv) != 3:
        print("Usage: python3 convert_json_to_sqlite.py <input.json> <output.db>", file=sys.stderr)
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]
    convert(input_path, output_path)


if __name__ == "__main__":
    main()
