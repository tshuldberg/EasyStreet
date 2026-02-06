#!/usr/bin/env python3
"""
Convert Street_Sweeping_Schedule CSV to SQLite database for EasyStreet Android.

Usage:
    python csv_to_sqlite.py <input_csv> <output_db>

Example:
    python csv_to_sqlite.py ../../EasyStreet/Street_Sweeping_Schedule_20260206.csv ../app/src/main/assets/easystreet.db
"""
import csv
import json
import re
import sqlite3
import sys
from collections import defaultdict


def parse_wkt_linestring(wkt: str) -> list[list[float]]:
    """Parse WKT LINESTRING into list of [lat, lng] pairs."""
    match = re.search(r'LINESTRING\s*\((.+)\)', wkt)
    if not match:
        return []

    coords = []
    for point in match.group(1).split(','):
        parts = point.strip().split()
        if len(parts) == 2:
            lon, lat = float(parts[0]), float(parts[1])
            coords.append([lat, lon])
    return coords


def day_name_to_number(day_name: str) -> int:
    """Convert day name to number (1=Monday, 7=Sunday) matching java.time.DayOfWeek."""
    mapping = {
        'mon': 1, 'monday': 1,
        'tue': 2, 'tues': 2, 'tuesday': 2,
        'wed': 3, 'wednesday': 3,
        'thu': 4, 'thurs': 4, 'thursday': 4,
        'fri': 5, 'friday': 5,
        'sat': 6, 'saturday': 6,
        'sun': 7, 'sunday': 7,
    }
    return mapping.get(day_name.lower().strip(), 0)


def weeks_to_week_of_month(w1, w2, w3, w4, w5) -> list:
    """Convert Week1-Week5 flags to list of week numbers.
    Returns [0] if all weeks (every week), otherwise list of specific week numbers.
    """
    flags = [int(w1), int(w2), int(w3), int(w4), int(w5)]
    if all(f == 1 for f in flags):
        return [0]

    weeks = []
    for i, flag in enumerate(flags):
        if flag == 1:
            weeks.append(i + 1)
    return weeks if weeks else [0]


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)

    input_csv = sys.argv[1]
    output_db = sys.argv[2]

    conn = sqlite3.connect(output_db)
    cursor = conn.cursor()

    cursor.executescript('''
        DROP TABLE IF EXISTS sweeping_rules;
        DROP TABLE IF EXISTS street_segments;

        CREATE TABLE street_segments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cnn INTEGER NOT NULL,
            street_name TEXT NOT NULL,
            limits_desc TEXT,
            block_side TEXT,
            latitude_min REAL NOT NULL,
            latitude_max REAL NOT NULL,
            longitude_min REAL NOT NULL,
            longitude_max REAL NOT NULL,
            coordinates TEXT NOT NULL
        );

        CREATE TABLE sweeping_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            segment_id INTEGER NOT NULL REFERENCES street_segments(id),
            day_of_week INTEGER NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            week_of_month INTEGER NOT NULL DEFAULT 0,
            holidays_observed INTEGER NOT NULL DEFAULT 0
        );

        CREATE INDEX idx_segments_bounds ON street_segments(
            latitude_min, latitude_max, longitude_min, longitude_max
        );

        CREATE INDEX idx_rules_segment ON sweeping_rules(segment_id);
    ''')

    segments = {}

    with open(input_csv, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            cnn = row['CNN'].strip()
            side = row['CNNRightLeft'].strip()
            line = row['Line'].strip()
            key = (cnn, side, line)

            if key not in segments:
                coords = parse_wkt_linestring(line)
                if not coords:
                    continue

                lats = [c[0] for c in coords]
                lngs = [c[1] for c in coords]

                segments[key] = {
                    'cnn': int(cnn),
                    'street_name': row['Corridor'].strip(),
                    'limits': row['Limits'].strip(),
                    'block_side': row['BlockSide'].strip(),
                    'coords': coords,
                    'lat_min': min(lats),
                    'lat_max': max(lats),
                    'lng_min': min(lngs),
                    'lng_max': max(lngs),
                    'rules': [],
                }

            day_num = day_name_to_number(row['WeekDay'].strip())
            if day_num == 0:
                continue

            from_hour_val = float(row['FromHour'].strip())
            to_hour_val = float(row['ToHour'].strip())
            from_h, from_m = int(from_hour_val), int(round((from_hour_val - int(from_hour_val)) * 60))
            to_h, to_m = int(to_hour_val), int(round((to_hour_val - int(to_hour_val)) * 60))
            start_time = f"{from_h:02d}:{from_m:02d}"
            end_time = f"{to_h:02d}:{to_m:02d}"

            week_numbers = weeks_to_week_of_month(
                row['Week1'], row['Week2'], row['Week3'], row['Week4'], row['Week5']
            )

            holidays = int(row['Holidays'].strip())

            for week in week_numbers:
                segments[key]['rules'].append({
                    'day_of_week': day_num,
                    'start_time': start_time,
                    'end_time': end_time,
                    'week_of_month': week,
                    'holidays_observed': holidays,
                })

    segment_count = 0
    rule_count = 0

    for key, seg in segments.items():
        cursor.execute(
            '''INSERT INTO street_segments
               (cnn, street_name, limits_desc, block_side,
                latitude_min, latitude_max, longitude_min, longitude_max, coordinates)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
            (
                seg['cnn'], seg['street_name'], seg['limits'], seg['block_side'],
                seg['lat_min'], seg['lat_max'], seg['lng_min'], seg['lng_max'],
                json.dumps(seg['coords']),
            )
        )
        segment_id = cursor.lastrowid
        segment_count += 1

        for rule in seg['rules']:
            cursor.execute(
                '''INSERT INTO sweeping_rules
                   (segment_id, day_of_week, start_time, end_time, week_of_month, holidays_observed)
                   VALUES (?, ?, ?, ?, ?, ?)''',
                (
                    segment_id,
                    rule['day_of_week'],
                    rule['start_time'],
                    rule['end_time'],
                    rule['week_of_month'],
                    rule['holidays_observed'],
                )
            )
            rule_count += 1

    conn.commit()

    print(f"Created {output_db}")
    print(f"  Segments: {segment_count}")
    print(f"  Rules: {rule_count}")

    cursor.execute("SELECT COUNT(*) FROM street_segments")
    print(f"  Verify segments: {cursor.fetchone()[0]}")
    cursor.execute("SELECT COUNT(*) FROM sweeping_rules")
    print(f"  Verify rules: {cursor.fetchone()[0]}")

    conn.close()


if __name__ == '__main__':
    main()
