"""
Entity-level dedup for zomato_cleaned.csv
------------------------------------------
Problem: same restaurant+location appears once per listing category
(listed_type: Delivery, Dine-out, etc.), inflating all count-based metrics.
Row-level dedup (df.duplicated()) shows 0 because rows differ in listed_type.

This script:
  1. Quantifies the entity-level duplication
  2. Checks whether votes/rate are consistent within each restaurant group
  3. Exports restaurants_unique.csv  (one row per name+location)
  4. Keeps zomato_cleaned.csv untouched (listing-level data is still valid
     for category-based analysis)

Run from the project root.
"""

import pandas as pd

INPUT_CSV = "zomato_cleaned.csv"
OUTPUT_CSV = "restaurants_unique.csv"
ENTITY_KEYS = ["name", "location"]

# How to pick the surviving row per restaurant:
#   "max_votes" -> keep the listing snapshot with the highest votes
#                  (usually matches SQL outputs that used MAX / a single row)
#   "mean"      -> average numeric columns across listings
STRATEGY = "max_votes"

df = pd.read_csv(INPUT_CSV)
print(f"Loaded {len(df):,} rows from {INPUT_CSV}\n")

# ---------------------------------------------------------------
# 1. Quantify entity-level duplication
# ---------------------------------------------------------------
entity_dupes = df.duplicated(subset=ENTITY_KEYS).sum()
n_unique = len(df.drop_duplicates(subset=ENTITY_KEYS))
print("=" * 55)
print("Scale of duplication")
print("=" * 55)
print(f"Total rows                  : {len(df):,}")
print(f"Unique restaurants (name+loc): {n_unique:,}")
print(f"Entity-level duplicate rows : {entity_dupes:,}")
print(f"Avg listings per restaurant : {len(df) / n_unique:.2f}\n")

# distribution of listings per restaurant
listing_counts = df.groupby(ENTITY_KEYS).size()
print("Listings-per-restaurant distribution:")
print(listing_counts.value_counts().sort_index().to_string(), "\n")

# example: show one heavily-duplicated restaurant
example_key = listing_counts.idxmax()
example = df[(df["name"] == example_key[0]) & (df["location"] == example_key[1])]
cols_to_show = [c for c in ["name", "location", "listed_type", "votes", "rate"]
                if c in df.columns]
print(f"Example - most duplicated restaurant ({listing_counts.max()} rows):")
print(example[cols_to_show].to_string(index=False), "\n")

# ---------------------------------------------------------------
# 2. Consistency check: do votes/rate differ across a restaurant's rows?
# ---------------------------------------------------------------
print("=" * 55)
print("Within-restaurant consistency")
print("=" * 55)
for col in ["votes", "rate"]:
    if col in df.columns:
        spread = df.groupby(ENTITY_KEYS)[col].agg(lambda s: s.max() - s.min())
        inconsistent = (spread > 0).sum()
        print(f"{col:<6}: {inconsistent:,} restaurants have varying values "
              f"across listings (max spread: {spread.max():,.2f})")
print("(Small spreads are snapshot noise from different scrape moments.)\n")

# ---------------------------------------------------------------
# 3. Build the unique-restaurants table
# ---------------------------------------------------------------
print("=" * 55)
print(f"Dedup using strategy: {STRATEGY}")
print("=" * 55)

if STRATEGY == "max_votes":
    # keep the row with the highest votes per restaurant
    unique_df = (
        df.sort_values("votes", ascending=False)
          .drop_duplicates(subset=ENTITY_KEYS, keep="first")
          .drop(columns=[c for c in ["listed_type"] if c in df.columns])
          .sort_values(ENTITY_KEYS)
          .reset_index(drop=True)
    )
elif STRATEGY == "mean":
    numeric_cols = df.select_dtypes("number").columns.tolist()
    other_cols = [c for c in df.columns
                  if c not in numeric_cols + ENTITY_KEYS + ["listed_type"]]
    agg = {c: "mean" for c in numeric_cols} | {c: "first" for c in other_cols}
    unique_df = df.groupby(ENTITY_KEYS, as_index=False).agg(agg)
else:
    raise ValueError(f"Unknown STRATEGY: {STRATEGY}")

unique_df.to_csv(OUTPUT_CSV, index=False)
print(f"Wrote {len(unique_df):,} rows -> {OUTPUT_CSV}\n")

# ---------------------------------------------------------------
# 4. Validation against known values
# ---------------------------------------------------------------
print("=" * 55)
print("Spot-check (compare against q1_credible_restaurants.csv)")
print("=" * 55)
for check_name in ["Byg Brewski Brewing Company", "Toit", "Truffles"]:
    row = unique_df[unique_df["name"] == check_name]
    if not row.empty:
        print(row[cols_to_show[:2] + ["votes", "rate"]].to_string(index=False))
print("\nIf these match your Q1 SQL output, the dedup strategy is correct.")
print("If votes look slightly off, flip STRATEGY to 'mean' and compare.")
