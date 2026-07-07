# Zomato Bangalore Restaurant Analysis

An end-to-end data analysis project examining **12,037 unique restaurants** across Bengaluru, built through a complete **Python → SQL → Excel → Tableau** pipeline. The project moves from raw data cleaning all the way to three interactive Tableau dashboards, with every business finding cross-validated across all four tools.

**Live Tableau dashboards:** [View on Tableau Public](https://public.tableau.com/app/profile/pratham.kumar5320/viz/Analyzing_Zomato_Restaurants_Bengaluru/Where_to_eat?publish=yes)

**📊 Dataset source:** [Zomato Bangalore Restaurants — Kaggle](https://www.kaggle.com/datasets/himanshupoddar/zomato-bangalore-restaurants)

---

## Table of Contents

- [Project Overview](#project-overview)
- [The Data Quality Story](#the-data-quality-story-51k--12k)
- [Tech Stack & Pipeline](#tech-stack--pipeline)
- [Repository Structure](#repository-structure)
- [Key Findings](#key-findings)
- [SQL Analysis — 12 Business Queries](#sql-analysis--12-business-queries)
- [Excel Workbook](#excel-workbook)
- [Tableau Dashboards](#tableau-dashboards)
- [Platform Snapshot](#platform-snapshot)
- [How to Reproduce](#how-to-reproduce)

---

## Project Overview

This project analyzes restaurant listings scraped from Zomato for the Bengaluru market, answering practical business questions across five dimensions: **ratings & credibility, location, cuisine, pricing & value, and service adoption** (online ordering vs. table booking).

The goal was not just to produce charts, but to build a defensible analytical narrative — one where the same numbers hold true whether you check them in a SQL query, an Excel pivot table, or a Tableau dashboard. Every headline figure in the dashboards traces back to an audited SQL query.

---

## The Data Quality Story (51K → 12K)

The most important part of this project happened mid-way through, and it's worth calling out explicitly because it changed every downstream number.

The raw Kaggle dataset contains **51,042 rows**. Early in the analysis, these were treated as 51,042 restaurants. During cross-validation, a discrepancy surfaced: the same restaurant name and location combination appeared many times over — because the raw data is at the **listing grain**, not the restaurant grain. A single restaurant could appear dozens of times, once per cuisine tag, per menu-listing context, and so on.

Treating listings as restaurants would have inflated every count, skewed every average, and produced a portfolio piece full of confidently-stated wrong numbers.

**The fix:**
- A deduplication script (`python/dedupe_restaurants.py`) collapsed the data to one row per genuine restaurant entity, producing `restaurants_unique.csv` with **12,037 unique restaurants** — roughly 39,000 duplicate listings removed.
- A **full SQL re-audit** of all 12 business queries was run against the corrected table.
- Several directional findings shifted in magnitude, but the audit confirmed **none of the core conclusions flipped** — a good sign the underlying signal was real, not an artifact of duplication.

This raw-vs-processed distinction is preserved in the repo (`data/raw/` vs `data/processed/`) as an audit trail.

---

## Tech Stack & Pipeline

| Stage | Tool | What it did |
|-------|------|-------------|
| **1. Clean & Dedup** | Python (Pandas) | Collapsed 51K listings → 12K unique restaurants; generated location coordinates |
| **2. Analyze** | SQL (PostgreSQL) | 12 business queries across 5 analytical dimensions |
| **3. Report** | Excel | 6-sheet workbook with pivots, calculated columns, conditional formatting, charts |
| **4. Visualize** | Tableau Public | 3 interactive dashboards |

The pipeline is intentionally sequential: SQL produces the audited source-of-truth outputs, Excel and Tableau both build on those same outputs, which is why the numbers reconcile across all three.

---

## Repository Structure

```
Zomato-Bangalore-Analysis/
├── data/
│   ├── raw/
│   │   ├── zomato.csv                    # Original unprocessed Kaggle export
│   │   └── zomato_cleaned.csv            # Cleaned, pre-dedup (51,042-row listing-grain)
│   └── processed/
│       ├── restaurants_unique.csv        # Deduplicated 12,037 unique restaurants
│       └── location_coords.csv           # Lat/long per location for mapping
├── python/
│   ├── Analyzing_Zomato_Restaurants.ipynb # Cleaning, EDA & deduplication notebook
│   ├── dedupe_restaurants.py             # Listing → restaurant deduplication
│   └── geocode_locations.py              # Location coordinate generation
├── sql/
│   ├── q1–q12 query files                # 12 audited business queries
│   └── outputs/
│       └── q1–q12 output CSVs            # Query result exports (feed Excel & Tableau)
├── excel/
│   └── Analyzing_Zomato_Restaurants.xlsx # 6-sheet analytical workbook
├── tableau/
│   ├── (Tableau workbook)
│   └── dashboards/                       # Dashboard screenshots
└── README.md
```

---

## Key Findings

All five findings below were re-verified against the corrected 12,037-restaurant dataset.

| # | Dimension | Finding | Evidence |
|---|-----------|---------|----------|
| 1 | **Rating** | Restaurants with 5,000+ votes are *always* rated Good or Excellent — high engagement is a near-perfect proxy for quality | 100% quality score (31 restaurants) · Q3 |
| 2 | **Location** | Koramangala 5th Block is the single most reliable area in the city for consistent quality | 85% quality score · Q4 |
| 3 | **Cuisine** | North Indian dominates supply but underperforms on quality — the most common cuisine ranks near the bottom | 66.7% of locations, quality rank #22 (gap −21) · Q7/Q8 |
| 4 | **Pricing** | Budget hidden gems out-rate the *entire* premium tier on average — price is a poor predictor of quality at the top end | 4.17 vs 3.99 avg rating · Q10 |
| 5 | **Service** | Table booking alone predicts quality better than offering both online ordering *and* table booking | 4.15 vs 4.09 avg rating · Q12 |

---

## SQL Analysis — 12 Business Queries

The analytical backbone. Each query maps to a specific business question and feeds a corresponding Excel sheet and Tableau view. All were re-run and audited against `restaurants_unique`.

**Rating & Credibility**
- **Q1 — Most credible restaurants:** Top restaurants filtered by rating ≥ 4.0 AND votes ≥ 500, ranked by a credibility score (`rating × log₁₀(votes)`) to filter out lucky low-vote outliers.
- **Q2 — Rating tier cross-tab:** Distribution of Excellent / Good / Average / Poor / Unrated across the three price categories.
- **Q3 — Does vote volume predict rating?** Buckets restaurants by vote ranges and compares average rating per bucket.

**Location**
- **Q4 — Location leaderboard:** Top 15 areas by restaurant count, with average rating, cost, and quality score.
- **Q5 — Best value locations:** Areas combining high average rating with low average cost (≥ 100 restaurants).
- **Q6 — Digital adoption by location:** Online-ordering adoption ranked across all areas.

**Cuisine**
- **Q7 — Dominant cuisine per location:** Window function (`ROW_NUMBER() OVER PARTITION BY location`) to find each area's dominant cuisine, plus a citywide dominance summary.
- **Q8 — Cuisine performance:** Popularity rank vs. quality rank for top cuisines, exposing "overrated" vs. "hidden gem" cuisines via rank gap.

**Pricing & Value**
- **Q9 — Price tier performance:** Is premium pricing justified? Average rating, votes, and quality score per tier with tier-over-tier jumps.
- **Q10 — Hidden gems:** Budget restaurants (≤ ₹400) rated ≥ 4.0, ranked by votes, plus a "gem rarity funnel" showing how few budget spots become proven gems.

**Service Adoption**
- **Q11 — Online ordering vs. dine-in only:** Side-by-side comparison of rating, cost, and votes by service type, broken down by price tier.
- **Q12 — Service segment analysis:** Both-services vs. online-only vs. table-only vs. neither — which service model correlates with the best quality.

---

## Excel Workbook

`excel/Analyzing_Zomato_Restaurants.xlsx` — a six-sheet analytical workbook built on the SQL outputs:

- **KPI_Summary** — executive dashboard with headline metrics and the top-5 findings table
- **Rating_Analysis** — Q1–Q3 with credibility scores, tier cross-tab, and vote-bucket analysis
- **Location_Analysis** — Q4–Q6 plus a combined cross-referenced location ranking (INDEX/MATCH across three query outputs)
- **Cuisine_Analysis** — Q7–Q8 with rank-gap calculations and a diverging bar chart of hidden gems vs. overrated cuisines
- **Pricing_Value** — Q9–Q10 with a gem-rarity funnel and an interactive what-if price calculator
- **Service_Adoption** — Q11–Q12 with within-tier gap analysis and a service-segment performance chart

Techniques used: pivot tables, `SUMIFS`/`AVERAGEIFS`, `INDEX-MATCH`/`VLOOKUP` cross-referencing, named ranges, data bars, color scales, text-based conditional formatting, and native Excel charts.

---

## Tableau Dashboards

Three interactive dashboards published to Tableau Public. *(Screenshots are stored in `tableau/dashboards/`.)*

### 1. Executive Overview
KPI cards and top-level distributions — the at-a-glance state of the Bengaluru market.

![Executive Overview](tableau/dashboards/executive_overview.png)

### 2. Deep Dive Analysis
Comparative analytics — cuisine performance scatter (popularity vs. quality), price tier by location heatmap, and cuisine quality by location.

![Deep Dive Analysis](tableau/dashboards/deep_dive_analysis.png)

### 3. Where to Eat (Restaurant Discovery)
A recommendation-focused dashboard: credibility leaderboard, hidden gems, and a geographic restaurant map with per-location rating and cost.

![Where to Eat](tableau/dashboards/where_to_eat.png)

> **Note on mapping:** Bengaluru's hyperlocal area names (HSR, Basavanagudi, etc.) aren't in Tableau's built-in geocoder, so a custom `location_coords.csv` was joined in to plot accurate coordinates.

---

## Platform Snapshot

Headline metrics for the Bengaluru restaurant market (post-audit, 12,037 restaurants):

| Metric | Value |
|--------|-------|
| Total unique restaurants | 12,037 |
| Platform average rating | 3.63 |
| Average cost for two | ₹490 |
| Online ordering adoption | 52.8% |
| Table booking adoption | 7.8% |
| Unrated restaurants | 23.9% |
| Unique locations | 93 |
| Unique cuisines | 87 |

---

## How to Reproduce

1. **Data:** Download the raw dataset from [Kaggle](https://www.kaggle.com/datasets/himanshupoddar/zomato-bangalore-restaurants).
2. **Dedup:** Run `python/dedupe_restaurants.py` to produce `restaurants_unique.csv`.
3. **Coordinates:** Run `python/geocode_locations.py` to generate `location_coords.csv`.
4. **SQL:** Load `restaurants_unique.csv` into PostgreSQL and run the queries in `sql/`.
5. **Excel / Tableau:** Open the workbook in `excel/`, or explore the [live dashboards](https://public.tableau.com/app/profile/pratham.kumar5320/viz/Analyzing_Zomato_Restaurants_Bengaluru/Where_to_eat?publish=yes).

---

## About

Built as a portfolio project demonstrating an end-to-end analytics workflow — from raw-data cleaning and a real data-quality catch, through SQL analysis, to business-ready Excel reporting and interactive Tableau dashboards.

**Author:** Pratham Kumar · [GitHub](https://github.com/prathamkumarr)
