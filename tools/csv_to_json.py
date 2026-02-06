#!/usr/bin/env python3
"""
Convert SF street sweeping CSV to JSON for the iOS app bundle.

Output JSON matches the iOS StreetSegment Codable model:
  { "id": "110000-L-1613751",
    "streetName": "01st St",
    "coordinates": [[lat, lng], ...],
    "rules": [{ "dayOfWeek": 3, "startTime": "00:00", "endTime": "02:00",
                "weeksOfMonth": [1,2,3,4,5], "applyOnHolidays": false }] }
"""
import csv
import json
import os
import re
import sys

# iOS dayOfWeek convention: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
DAY_MAP = {
    "Mon": 2, "Tue": 3, "Tues": 3, "Wed": 4,
    "Thu": 5, "Thur": 5, "Fri": 6, "Sat": 7, "Sun": 1,
    "Monday": 2, "Tuesday": 3, "Wednesday": 4,
    "Thursday": 5, "Friday": 6, "Saturday": 7, "Sunday": 1,
}


def parse_linestring(wkt):
    """Parse WKT LINESTRING into [[lat, lng], ...] array."""
    match = re.search(r'LINESTRING\s*\((.+)\)', wkt)
    if not match:
        return None
    coords = []
    for pair in match.group(1).split(','):
        parts = pair.strip().split()
        if len(parts) == 2:
            lng, lat = float(parts[0]), float(parts[1])
            coords.append([lat, lng])
    return coords if coords else None


def hour_to_time(hour_val):
    """Convert integer hour (0-23) to 'HH:MM' string."""
    try:
        h = int(float(hour_val))
        return f"{h:02d}:00"
    except (ValueError, TypeError):
        return "00:00"


def convert(csv_path, json_path):
    segments = {}

    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            cnn = row.get('CNN', '').strip()
            side = row.get('CNNRightLeft', '').strip()
            sweep_id = row.get('BlockSweepID', '').strip()
            seg_id = f"{cnn}-{side}-{sweep_id}"

            if seg_id not in segments:
                coords = parse_linestring(row.get('Line', ''))
                if not coords:
                    continue
                segments[seg_id] = {
                    "id": seg_id,
                    "streetName": row.get('Corridor', '').strip(),
                    "coordinates": coords,
                    "rules": []
                }

            weekday_str = row.get('WeekDay', '').strip()
            day_of_week = DAY_MAP.get(weekday_str)
            if day_of_week is None:
                continue

            weeks = []
            for i in range(1, 6):
                if row.get(f'Week{i}', '0').strip() == '1':
                    weeks.append(i)

            rule = {
                "dayOfWeek": day_of_week,
                "startTime": hour_to_time(row.get('FromHour', '0')),
                "endTime": hour_to_time(row.get('ToHour', '0')),
                "weeksOfMonth": weeks,
                "applyOnHolidays": row.get('Holidays', '0').strip() == '1'
            }

            if rule not in segments[seg_id]["rules"]:
                segments[seg_id]["rules"].append(rule)

    result = list(segments.values())
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(result, f, separators=(',', ':'))

    size_mb = os.path.getsize(json_path) / 1024 / 1024
    print(f"Converted {len(result)} segments to {json_path}")
    print(f"File size: {size_mb:.1f} MB")


if __name__ == '__main__':
    csv_path = sys.argv[1] if len(sys.argv) > 1 else 'EasyStreet/Street_Sweeping_Schedule_20250508.csv'
    json_path = sys.argv[2] if len(sys.argv) > 2 else 'EasyStreet/sweeping_data_sf.json'
    convert(csv_path, json_path)
