"""
Geocode Bangalore neighborhoods from zomato_cleaned.csv
Output: location_coords.csv (location, latitude, longitude)
Uses Nominatim (OpenStreetMap) - free, but rate-limited to 1 request/sec.
~90 locations = ~2 minutes runtime.
"""

import pandas as pd
import time
from geopy.geocoders import Nominatim

INPUT_CSV = "zomato_cleaned.csv"
OUTPUT_CSV = "location_coords.csv"
LOCATION_COL = "location"  

# Bangalore bounding box for sanity-checking results
LAT_MIN, LAT_MAX = 12.7, 13.3
LON_MIN, LON_MAX = 77.3, 77.9

# Manual fixes for locations Nominatim can't resolve.
MANUAL_COORDS = {
    "ITPL Main Road, Whitefield": (12.9857, 77.7367),
    "Rammurthy Nagar": (13.0159, 77.6785),
    "Sadashiv Nagar": (13.0068, 77.5813),
}


def main():
    df = pd.read_csv(INPUT_CSV)
    locations = sorted(df[LOCATION_COL].dropna().unique())
    print(f"Found {len(locations)} unique locations to geocode\n")

    geolocator = Nominatim(user_agent="zomato_bangalore_portfolio")

    rows = []
    failed = []

    for i, loc in enumerate(locations, 1):
        # Manual override takes priority
        if loc in MANUAL_COORDS:
            lat, lon = MANUAL_COORDS[loc]
            rows.append({"location": loc, "latitude": lat, "longitude": lon})
            print(f"[{i}/{len(locations)}] {loc} -> manual override")
            continue

        query = f"{loc}, Bengaluru, Karnataka, India"
        try:
            result = geolocator.geocode(query, timeout=10)
        except Exception:
            result = None

        if (
            result
            and LAT_MIN <= result.latitude <= LAT_MAX
            and LON_MIN <= result.longitude <= LON_MAX
        ):
            rows.append(
                {
                    "location": loc,
                    "latitude": result.latitude,
                    "longitude": result.longitude,
                }
            )
            print(f"[{i}/{len(locations)}] {loc} -> OK")
        else:
            failed.append(loc)
            print(f"[{i}/{len(locations)}] {loc} -> FAILED")

        time.sleep(1)  # Nominatim rate limit: 1 req/sec

    coords = pd.DataFrame(rows)
    coords.to_csv(OUTPUT_CSV, index=False)

    print(f"\nGeocoded {len(coords)}/{len(locations)} locations -> {OUTPUT_CSV}")
    if failed:
        print(f"\nFAILED ({len(failed)}) - add these to MANUAL_COORDS and re-run:")
        for loc in failed:
            print(f'    "{loc}": (LAT, LON),')


if __name__ == "__main__":
    main()