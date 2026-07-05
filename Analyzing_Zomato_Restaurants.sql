-- ============================================================
-- ZOMATO BANGALORE RESTAURANTS — DATASET SUMMARY
--
-- DATASET SCOPE NOTE
-- ============================================================
-- This is a RESTAURANT DIRECTORY SNAPSHOT — not transactional data.
-- There are no orders, no revenue figures, no customer identities.
-- Every row is one restaurant listing on Zomato's Bengaluru platform
-- at a specific point in time.
--
-- KEY LIMITATIONS TO KEEP IN MIND:
--
-- 1. rate column has 9,852 NULLs (19.3% of all rows).
--    These are NOT missing data — they represent restaurants
--    marked 'NEW' on Zomato with zero reviews yet.
--    Any AVG(rate) query must use WHERE rate IS NOT NULL
--    or results will be understated due to NULL handling.
--
-- 2. approx_cost is SELF-REPORTED by the restaurant owner.
--    It is not verified or enforced by Zomato.
--    Treat it as a positioning signal, not a precise price.
--
-- 3. There is NO time dimension in this dataset.
--    No order dates, no listing dates, no review timestamps.
--    Trend analysis (month-over-month, growth, seasonality)
--    is NOT possible from this data.
--
-- 4. online_order and book_table are binary opt-in decisions
--    made by the restaurant — 1 = opted in, 0 = opted out.
--    They reflect business strategy, not technical capability.
--
-- 5. listed_city partially overlaps with location.
--    location = neighbourhood level (e.g. BTM, Koramangala)
--    listed_city = area cluster level (e.g. Banashankari)
--    Use location for granular analysis.
--
-- All analysis below focuses on restaurant-level patterns:
-- ratings, pricing, cuisine mix, location distribution,
-- and digital service adoption across Bengaluru.
-- ============================================================


-- ===============================
-- 1. Total Restaurants in Dataset
-- 
SELECT
    COUNT(*) AS total_restaurants
FROM
    zomato_restaurants;
-- Result : 51,042


-- =========================
-- 2. Total Unique Locations
-- 
SELECT
	COUNT(DISTINCT LOCATION) AS TOTAL_LOCATIONS
FROM
	ZOMATO_RESTAURANTS;
-- Result : 93


-- ========================
-- 3. Total Unique Cuisines
-- (primary_cuisine — first cuisine listed)
-- 
SELECT
    COUNT(DISTINCT primary_cuisine) AS total_cuisines
FROM
    zomato_restaurants;
-- Result : 87


-- ================================
-- 4. Total Unique Restaurant Types
-- 
SELECT
    COUNT(DISTINCT rest_type) AS total_rest_types
FROM
    zomato_restaurants;
-- Result : 93


-- ====================================================
-- 5. Rating Range and Average (rated restaurants only)
-- NOTE: WHERE rate IS NOT NULL excludes 9,852 NEW
-- restaurants which have no rating yet
-- 
SELECT
	MIN(RATE) AS MIN_RATE,
	MAX(RATE) AS MAX_RATE,
	ROUND(AVG(RATE)::NUMERIC, 2) AS AVG_RATE,
	COUNT(*) AS RATED_COUNT
FROM
	ZOMATO_RESTAURANTS
WHERE
	RATE IS NOT NULL;
-- Result : Min - 1.8 | Max - 4.9 | Avg - 3.70 | Rated - 41,190


-- =====================================
-- 6. Unrated Restaurants (NEW listings)
-- 
SELECT
	COUNT(*) AS UNRATED_COUNT,
	ROUND(
		COUNT(*) * 100.0 / (
			SELECT
				COUNT(*)
			FROM
				ZOMATO_RESTAURANTS
		),
		1
	) AS PCT_OF_TOTAL
FROM
	ZOMATO_RESTAURANTS
WHERE
	RATE IS NULL;
-- Result : 9,852 restaurants (19.3% of all listings have no rating)


-- ============================================
-- 7. Cost Range and Average (₹ for two people)
-- 
SELECT
	MIN(APPROX_COST) AS MIN_COST,
	MAX(APPROX_COST) AS MAX_COST,
	ROUND(AVG(APPROX_COST)::NUMERIC, 0) AS AVG_COST,
	PERCENTILE_CONT(0.5) WITHIN GROUP (
		ORDER BY
			APPROX_COST
	) AS MEDIAN_COST
FROM
	ZOMATO_RESTAURANTS;
-- Result : Min - Rs.40 | Max - Rs.6,000 | Avg - Rs.556 | Median - Rs.400


-- ==========================
-- 8. Votes Range and Average
-- votes = proxy for total customer engagement
-- 
SELECT
	MIN(VOTES) AS MIN_VOTES,
	MAX(VOTES) AS MAX_VOTES,
	ROUND(AVG(VOTES)::NUMERIC, 0) AS AVG_VOTES
FROM
	ZOMATO_RESTAURANTS;
-- Result : Max-votes - 16832, Avg-votes - 285


-- ===========================
-- 9. Online Ordering Adoption
-- 
SELECT
	SUM(ONLINE_ORDER) AS WITH_ONLINE_ORDER,
	COUNT(*) - SUM(ONLINE_ORDER) AS WITHOUT_ONLINE_ORDER,
	ROUND(SUM(ONLINE_ORDER) * 100.0 / COUNT(*), 1) AS PCT_WITH_ONLINE_ORDER
FROM
	ZOMATO_RESTAURANTS;
-- Result : 30,874 opted in (60.5%) | 20,168 opted out (39.5%)


-- ==========================
-- 10. Table Booking Adoption
-- 
SELECT
	SUM(BOOK_TABLE) AS WITH_TABLE_BOOKING,
	COUNT(*) - SUM(BOOK_TABLE) AS WITHOUT_TABLE_BOOKING,
	ROUND(SUM(BOOK_TABLE) * 100.0 / COUNT(*), 1) AS PCT_WITH_TABLE_BOOKING
FROM
	ZOMATO_RESTAURANTS;
-- Result : 6,392 opted in (12.5%) | 44,650 opted out (87.5%)


-- ===============================
-- 11. Price Category Distribution
-- 
SELECT
	PRICE_CATEGORY,
	COUNT(*) AS RESTAURANT_COUNT,
	ROUND(
		COUNT(*) * 100.0 / (
			SELECT
				COUNT(*)
			FROM
				ZOMATO_RESTAURANTS
		),
		1
	) AS PCT_OF_TOTAL
FROM
	ZOMATO_RESTAURANTS
GROUP BY
	PRICE_CATEGORY
ORDER BY
	RESTAURANT_COUNT DESC;
-- Result :
-- Budget     : 26,699  (52.3%)
-- Mid-range  : 16,533  (32.4%)
-- Premium    :  7,810  (15.3%)


-- =============================
-- 12. Rating Label Distribution
-- 
SELECT
	RATING_LABEL,
	COUNT(*) AS RESTAURANT_COUNT,
	ROUND(
		COUNT(*) * 100.0 / (
			SELECT
				COUNT(*)
			FROM
				ZOMATO_RESTAURANTS
		),
		1
	) AS PCT_OF_TOTAL
FROM
	ZOMATO_RESTAURANTS
GROUP BY
	RATING_LABEL
ORDER BY
	RESTAURANT_COUNT DESC;
-- Result :
-- Good       : 20,755  (40.7%)
-- Unrated    :  9,852  (19.3%)
-- Excellent  :  9,126  (17.9%)
-- Average    :  9,094  (17.8%)
-- Poor       :  2,215   (4.3%)


-- ==========================================
-- SECTION 1: RATING AND PERFORMANCE ANALYSIS
-- ==========================================
--
-- Q1. Top 10 most credible restaurants - rate ≥ 4.0 AND votes ≥ 500. (filters out lucky low-vote outliers)
WITH unique_restaurants AS (
    SELECT DISTINCT ON (name, location)
        name,
        location,
        primary_cuisine,
        rest_type,
        rate,
        votes,
        approx_cost,
        price_category,
        online_order,
        book_table
    FROM
        zomato_restaurants
    WHERE
        rate  >= 4.0
        AND votes >= 500
    ORDER BY
        name, location, votes DESC   -- keeps the highest-vote row per restaurant
)
SELECT
    name,
    location,
    primary_cuisine,
    rest_type,
    rate,
    votes,
    approx_cost                                        AS cost_for_two,
    price_category,
    online_order,
    book_table,
    ROUND((rate * LOG(votes + 1))::NUMERIC, 2)         AS credibility_score
FROM
    unique_restaurants
ORDER BY
    credibility_score DESC
LIMIT 10;
--
-- KEY FINDINGS:
--
-- F1. ALL 10 restaurants are Premium (₹900–₹1800 for two).
--     Not a single Budget or Mid-range restaurant made the
--     credibility top 10. Premium customers engage more —
--     they visit more often, review more consistently, and
--     generate the vote volume needed to score high.
--
-- F2. Microbreweries dominate — 3 of 10 spots.
--     Byg Brewski (#1), Toit (#2), Big Pitcher (#9).
--     Bengaluru's craft beer culture drives enormous footfall
--     and review activity at brewery-format venues.
--     This is a Bengaluru-specific pattern not found in other
--     Indian cities at this scale.
--
-- F3. Byg Brewski leads by a significant margin.
--     Score 20.71 vs 19.62 for Toit — a 1.09 gap.
--     Driven by the highest votes in the dataset (16,832)
--     combined with the highest rate (4.9). Both dimensions
--     firing simultaneously makes it the runaway #1.
--
-- F4. Bengaluru's best restaurants overwhelmingly skip
--     online ordering. Only 2 of 10 have online_order = 1
--     (Byg Brewski and Chili's). The other 8 are dine-in only.
--     This directly contradicts the platform-wide 60.5%
--     online ordering adoption rate. Top-rated restaurants
--     choose experience over delivery volume.
--
-- F5. Table booking is the premium signal.
--     7 of 10 accept reservations (book_table = 1).
--     These restaurants invest in managing dine-in capacity,
--     not delivery logistics.
--
-- F6. Toit is the most remarkable outlier.
--     online_order = 0, book_table = 0 — zero digital services.
--     Pure walk-in, no reservations, no delivery.
--     Yet it ranks #2 with 14,956 votes and 4.7 rating.
--     Proof that product quality alone can build massive
--     engagement without any platform integration.
--
-- F7. Chain restaurants hold multiple top-10 positions.
--     AB's Absolute Barbecues → #3 (Marathahalli) + #6 (BTM)
--     The Black Pearl        → #5 (Koramangala) + #7 (Marathahalli)
--     Consistent quality across branches earns compounded trust.
--
-- F8. Truffles at ₹900 is the best value in this list.
--     Lowest cost in the top 10, yet 4th highest credibility
--     score (19.59). Cafe format, Koramangala location,
--     14,726 votes. Strong proof that value-for-money
--     restaurants can compete with fine dining on engagement.
--
-- F9. Quality is geographically distributed.
--     Top 10 spans 7 different locations: Sarjapur Road,
--     Indiranagar, Marathahalli, Koramangala, BTM,
--     Malleshwaram, Old Airport Road.
--     Excellence is not concentrated in one premium pocket.


-- ======================================================================================
-- Q2. Rating tier breakdown across price categories - cross-tab showing % share per tier.
SELECT
	PRICE_CATEGORY,
	COUNT(*) AS TOTAL_RESTAURANTS,
	-- Average rating (rated only)
	ROUND(AVG(RATE)::NUMERIC, 2) AS AVG_RATE,
	-- Excellent tier (rate > 4.0)
	COUNT(
		CASE
			WHEN RATING_LABEL = 'Excellent' THEN 1
		END
	) AS EXCELLENT_COUNT,
	ROUND(
		COUNT(
			CASE
				WHEN RATING_LABEL = 'Excellent' THEN 1
			END
		) * 100.0 / COUNT(*),
		1
	) AS EXCELLENT_PCT,
	-- Good tier (rate 3.5 – 4.0)
	COUNT(
		CASE
			WHEN RATING_LABEL = 'Good' THEN 1
		END
	) AS GOOD_COUNT,
	ROUND(
		COUNT(
			CASE
				WHEN RATING_LABEL = 'Good' THEN 1
			END
		) * 100.0 / COUNT(*),
		1
	) AS GOOD_PCT,
	-- Average tier (rate 3.0 – 3.4)
	COUNT(
		CASE
			WHEN RATING_LABEL = 'Average' THEN 1
		END
	) AS AVERAGE_COUNT,
	ROUND(
		COUNT(
			CASE
				WHEN RATING_LABEL = 'Average' THEN 1
			END
		) * 100.0 / COUNT(*),
		1
	) AS AVERAGE_PCT,
	-- Poor tier (rate < 3.0)
	COUNT(
		CASE
			WHEN RATING_LABEL = 'Poor' THEN 1
		END
	) AS POOR_COUNT,
	ROUND(
		COUNT(
			CASE
				WHEN RATING_LABEL = 'Poor' THEN 1
			END
		) * 100.0 / COUNT(*),
		1
	) AS POOR_PCT,
	-- Unrated (NEW listings with zero reviews)
	COUNT(
		CASE
			WHEN RATING_LABEL = 'Unrated' THEN 1
		END
	) AS UNRATED_COUNT,
	ROUND(
		COUNT(
			CASE
				WHEN RATING_LABEL = 'Unrated' THEN 1
			END
		) * 100.0 / COUNT(*),
		1
	) AS UNRATED_PCT,
	-- Quality score = % of RATED restaurants that are Good or Excellent
	-- Excludes Unrated from denominator for a fair comparison
	ROUND(
		COUNT(
			CASE
				WHEN RATING_LABEL IN ('Good', 'Excellent') THEN 1
			END
		) * 100.0 / NULLIF(
			COUNT(
				CASE
					WHEN RATING_LABEL != 'Unrated' THEN 1
				END
			),
			0
		),
		1
	) AS QUALITY_SCORE_PCT
FROM
	ZOMATO_RESTAURANTS
GROUP BY
	PRICE_CATEGORY
ORDER BY
	CASE PRICE_CATEGORY
		WHEN 'Budget' THEN 1
		WHEN 'Mid-range' THEN 2
		WHEN 'Premium' THEN 3
	END;
--
-- KEY FINDINGS:
--
-- F1. Price DOES predict quality — but not in a straight line.
--     Quality score jumps:
--       Budget → Mid-range : +10.7 points (63.6% → 74.3%)
--       Mid-range → Premium: +17.7 points (74.3% → 92.0%)
--     The Premium jump is far steeper. Paying more is
--     justified most strongly at the very top tier —
--     not so much going from Budget to Mid-range.
--
-- F2. 9 in 10 Premium restaurants are Good or Excellent.
--     A quality score of 92.0% means once a Premium restaurant
--     has been reviewed, it almost always delivers.
--     The ₹800+ price point appears to self-select operators
--     who can sustain quality over many customer visits.
--
-- F3. Premium has more Excellent restaurants than Budget
--     in ABSOLUTE terms — despite being 3.4x smaller.
--       Budget Excellent    :  1,711  (6.4% of 26,699)
--       Mid-range Excellent :  3,146  (19.0% of 16,533)
--       Premium Excellent   :  4,269  (54.7% of  7,810)
--     If you want an Excellent restaurant in Bengaluru,
--     Premium is statistically your best hunting ground
--     even by raw count, not just percentage.
--
-- F4. Mid-range is the most dangerous tier for consumers.
--     poor_pct = 7.0% — HIGHER than both Budget (3.2%)
--     and Premium (2.5%).
--     Mid-range restaurants charge more than Budget but
--     fail more often — they carry premium pricing without
--     consistently delivering premium quality.
--     This is the classic "value trap" tier.
--
-- F5. Budget's real problem is uncertainty, not low quality.
--     28.4% of Budget restaurants are Unrated — the highest
--     of any tier by far (vs 4.0% for Premium).
--     But once a Budget restaurant has been reviewed,
--     63.6% are Good or Excellent — a respectable hit rate.
--     The risk is not that Budget is bad — it's that you
--     don't know which ones are good until you try them.
--
-- F6. The avg_rate gap tells the real story.
--     Budget → Mid-range gap  :  0.11  (3.58 → 3.69) — tiny
--     Mid-range → Premium gap :  0.35  (3.69 → 4.04) — large
--     Spending more within the budget-to-mid range barely
--     improves your expected experience. The meaningful
--     quality jump only arrives at the Premium threshold.
--
-- F7. Premium almost never fails catastrophically.
--     poor_pct = 2.5% — lowest of all three tiers.
--     Only 197 out of 7,810 Premium restaurants are Poor.
--     High price acts as a natural quality filter — operators
--     who cannot deliver quality cannot sustain premium pricing.
--
-- F8. Platform-wide unrated rate is driven entirely by Budget.
--     7,574 of the 9,852 total unrated restaurants (76.9%)
--     are in the Budget tier. These are small, newly listed,
--     or low-traffic restaurants that haven't been discovered.
--     Zomato's first-order acquisition challenge is almost
--     entirely a Budget-tier problem.


-- ====================================================================================================
-- Q3. Does vote volume predict higher ratings? — bucket restaurants by vote ranges, compare avg rating.
WITH
	VOTE_BUCKETS AS (
		SELECT
			RATE,
			VOTES,
			RATING_LABEL,
			CASE
				WHEN VOTES BETWEEN 0 AND 10  THEN '1. Minimal   (0 – 10)'
				WHEN VOTES BETWEEN 11 AND 100  THEN '2. Low       (11 – 100)'
				WHEN VOTES BETWEEN 101 AND 500  THEN '3. Moderate  (101 – 500)'
				WHEN VOTES BETWEEN 501 AND 1000  THEN '4. Good      (501 – 1,000)'
				WHEN VOTES BETWEEN 1001 AND 5000  THEN '5. High      (1,001 – 5,000)'
				ELSE '6. Very High  (5,001+)'
			END AS VOTE_BUCKET
		FROM
			ZOMATO_RESTAURANTS
	)
SELECT
	VOTE_BUCKET,
	COUNT(*) AS TOTAL_RESTAURANTS,
	ROUND(AVG(VOTES)::NUMERIC, 0) AS AVG_VOTES,
	ROUND(AVG(RATE)::NUMERIC, 2) AS AVG_RATING,
	-- How many have no rating yet in this bucket
	COUNT(
		CASE
			WHEN RATE IS NULL THEN 1
		END
	) AS UNRATED_COUNT,
	ROUND(
		COUNT(
			CASE
				WHEN RATE IS NULL THEN 1
			END
		) * 100.0 / COUNT(*),
		1
	) AS UNRATED_PCT,
	-- % of RATED restaurants in this bucket that are Good or Excellent
	ROUND(
		COUNT(
			CASE
				WHEN RATING_LABEL IN ('Good', 'Excellent') THEN 1
			END
		) * 100.0 / NULLIF(
			COUNT(
				CASE
					WHEN RATE IS NOT NULL THEN 1
				END
			),
			0
		),
		1
	) AS QUALITY_SCORE_PCT,
	-- Spread of ratings within each bucket
	MIN(RATE) AS MIN_RATING,
	MAX(RATE) AS MAX_RATING
FROM
	VOTE_BUCKETS
GROUP BY
	VOTE_BUCKET
ORDER BY
	VOTE_BUCKET;
--
-- KEY FINDINGS:
--
-- F1. Yes — vote volume strongly predicts higher ratings.
--     avg_rating rises monotonically across all 6 buckets:
--     3.31 → 3.55 → 3.83 → 4.08 → 4.26 → 4.52
--     This is not random noise — it is a clean, unbroken
--     upward trend. More engagement = higher quality, every
--     single step of the way without exception.
--
-- F2. Quality score tells the story even more clearly.
--     17.6% → 71.4% → 86.1% → 96.6% → 99.8% → 100.0%
--     The jump from Minimal to Low alone is +53.8 points —
--     the single largest gain across the entire range.
--     Once a restaurant earns just 11 votes, it becomes
--     dramatically more likely to be Good or Excellent.
--
-- F3. Every restaurant with 5,000+ votes is Good or Excellent.
--     quality_score_pct = 100.0% for Very High bucket.
--     Not 99% — exactly 100%. All 234 restaurants in this
--     bucket have earned a Good or Excellent rating.
--     Sustained high engagement is the strongest quality
--     signal available on the platform.
--
-- F4. The Very High bucket's minimum rating is 4.1.
--     min_rating = 4.1 for 5,000+ vote restaurants.
--     No restaurant with 5,000+ votes in Bengaluru rates
--     below 4.1. The floor rises with engagement because
--     truly poor restaurants cannot sustain customer
--     traffic long enough to accumulate this many votes.
--
-- F5. The Minimal bucket contains 30.2% of all restaurants
--     but is almost entirely noise.
--     15,434 restaurants — nearly a third of the platform
--     — average just 2 votes each. 63.7% are unrated.
--     Of the rated ones, only 17.6% are Good or Excellent.
--     The Minimal bucket is Zomato's discovery problem:
--     a vast, underexplored inventory that customers
--     cannot evaluate because it lacks social proof.
--
-- F6. Once a restaurant reaches 500 votes, quality
--     is almost guaranteed.
--     Buckets 4, 5, 6 (500+ votes) have quality scores of
--     96.6%, 99.8%, 100.0% respectively.
--     For a consumer: filtering Zomato results to only
--     show restaurants with 500+ votes removes virtually
--     all risk of a poor experience.
--
-- F7. The Low bucket (11–100 votes) has almost zero
--     unrated restaurants — only 2 out of 17,467 (0.0%).
--     This reveals a key platform dynamic: even minimal
--     engagement (11 votes) is enough for Zomato's
--     algorithm to assign a stable aggregate rating.
--     The unrated problem is entirely concentrated
--     in the 0–10 vote zone.
--
-- F8. Rating spread narrows dramatically with more votes.
--     Minimal   : spread = 2.7 to 4.5  (range: 1.8)
--     Moderate  : spread = 1.8 to 4.9  (range: 3.1)
--     High      : spread = 2.8 to 4.9  (range: 2.1)
--     Very High : spread = 4.1 to 4.9  (range: 0.8)
--     At 5,000+ votes, the entire tier lives within a
--     0.8 point window. Ratings converge toward truth
--     as sample size grows — exactly as statistics predicts.
--
-- F9. The platform has a long-tail engagement problem.
--     Top 2 buckets (Minimal + Low) = 32,901 restaurants
--     = 64.5% of all listings on Zomato Bengaluru.
--     Nearly two-thirds of the platform's supply has fewer
--     than 100 votes. These restaurants are functionally
--     invisible to quality-conscious customers who sort
--     by rating + votes. Zomato's growth opportunity is
--     converting these restaurants from invisible to trusted.


-- ================================
-- SECTION 2: LOCATION INTELLIGENCE
-- ================================
-- 
-- Q4. Location leaderboard — restaurant count, avg rating, avg cost for top 15 areas.
SELECT
	LOCATION,
	COUNT(*) AS TOTAL_RESTAURANTS,
	-- What % of Bengaluru's total restaurant supply is here
	ROUND(
		COUNT(*) * 100.0 / (
			SELECT
				COUNT(*)
			FROM
				ZOMATO_RESTAURANTS
		),
		1
	) AS MARKET_SHARE_PCT,
	-- AVG(rate) automatically ignores NULL rows in PostgreSQL
	-- so unrated restaurants never pull this number down
	ROUND(AVG(RATE)::NUMERIC, 2) AS AVG_RATING,
	ROUND(AVG(APPROX_COST)::NUMERIC, 0) AS AVG_COST,
	-- FILTER clause — PostgreSQL-specific conditional aggregation
	-- Counts only rows where condition is true, cleaner than CASE WHEN
	ROUND(
		COUNT(*) FILTER (
			WHERE
				RATING_LABEL IN ('Good', 'Excellent')
		) * 100.0 / NULLIF(
			COUNT(*) FILTER (
				WHERE
					RATE IS NOT NULL
			),
			0
		),
		1
	) AS QUALITY_SCORE_PCT,
	-- Online ordering adoption rate for this specific location
	ROUND(AVG(ONLINE_ORDER) * 100.0, 1) AS ONLINE_ORDER_PCT,
	-- What % of this location's restaurants are still undiscovered
	ROUND(
		COUNT(*) FILTER (
			WHERE
				RATE IS NULL
		) * 100.0 / COUNT(*),
		1
	) AS UNRATED_PCT
FROM
	ZOMATO_RESTAURANTS
GROUP BY
	LOCATION
HAVING
	COUNT(*) >= 100
ORDER BY
	TOTAL_RESTAURANTS DESC
LIMIT
	15;
--
-- KEY FINDINGS:
--
-- F1. Volume and quality are inversely correlated at location level.
--     The top 5 locations by restaurant count all sit BELOW
--     the platform avg_rating of 3.70:
--       BTM        : 3.57 (−0.13 below avg)
--       HSR        : 3.68 (−0.02 below avg)
--       JP Nagar   : 3.68 (−0.02 below avg)
--       Whitefield : 3.62 (−0.08 below avg)
--     Only Koramangala 5th Block (#3 by count) breaks this
--     pattern with 4.01. High density = higher competition
--     = more mediocre operators surviving on volume alone.
--
-- F2. Koramangala 5th Block is the single outstanding location.
--     It is the ONLY location in the top 15 with avg_rating
--     above 4.0. Its quality score of 90.0% matches the
--     Premium price tier from Query 2 (92.0%) — meaning
--     dining in Koramangala 5th Block is statistically as
--     reliable as choosing a Premium restaurant anywhere
--     in the city. Also the lowest unrated_pct (7.4%) —
--     the most mature and well-reviewed restaurant market
--     in Bengaluru.
--
-- F3. Koramangala as a zone dominates quality rankings.
--     4 Koramangala blocks appear in the top 15:
--       5th Block : avg 4.01, quality 90.0%
--       7th Block : avg 3.85, quality 85.4%
--       6th Block : avg 3.78, quality 81.7%
--       1st Block : avg 3.70, quality 76.4%
--     Every single one beats or matches the platform avg.
--     The Koramangala micro-market — driven by its dense
--     tech workforce and high disposable income — has
--     created a self-selecting quality ecosystem where
--     poor restaurants cannot survive customer scrutiny.
--
-- F4. BTM is Bengaluru's volume champion but quality laggard.
--     9.9% of all platform listings (5,056 restaurants)
--     in a single neighbourhood. Yet avg_rating = 3.57,
--     avg_cost = ₹396 (cheapest in top 15), and
--     23.4% unrated. BTM feeds students and early-career
--     workers cheaply at scale — not a quality market,
--     a volume and affordability market.
--
-- F5. Electronic City is the most troubled location.
--     Lowest avg_rating (3.49), lowest online_order_pct
--     (46.2%), and highest unrated_pct (33.2%) in the
--     top 15. Despite being Bengaluru's largest IT corridor
--     with massive captive demand, its restaurants are
--     below-average quality and poorly discovered.
--     This is Zomato's biggest missed opportunity in the
--     top 15 — high population, weak platform penetration.
--
-- F6. HSR is the delivery capital of Bengaluru.
--     online_order_pct = 77.8% — highest of all 15 locations,
--     far above the platform average of 60.5%.
--     HSR's young tech professional demographic orders
--     food online at a rate unmatched by any other major area.
--     This makes HSR the most strategically valuable
--     location for Zomato's delivery business.
--
-- F7. Indiranagar is the best-balanced location.
--     avg_rating 3.83, avg_cost ₹652, quality 80.9%,
--     online_order 66.4%, unrated only 11.4%.
--     Above-average on every single metric simultaneously.
--     Premium pricing, strong quality, mature market,
--     solid digital adoption. The most well-rounded
--     restaurant ecosystem in this top 15.
--
-- F8. Jayanagar is the hidden value champion.
--     avg_cost = ₹477 (one of the lowest in top 15)
--     yet quality_score = 82.5% (third highest overall).
--     Traditional South Bengaluru neighbourhood delivering
--     high quality at mid-range prices. The best
--     cost-to-quality ratio of any location in the top 15.
--
-- F9. The unrated problem is geographically concentrated.
--     3 locations have unrated_pct above 25%:
--       Electronic City  : 33.2%
--       Koramangala 1st  : 31.1%
--       Whitefield       : 25.5%
--     These areas have large numbers of listed restaurants
--     that have never been reviewed — a sign that Zomato
--     has supply it cannot convert into engaged customers.
--
-- F10. Brigade Road commands premium pricing for its brand.
--      avg_cost = ₹649 (second highest in top 15) yet
--      quality_score = 73.5% — below Indiranagar, Jayanagar,
--      and all Koramangala blocks. Customers pay a location
--      premium (MG Road corridor prestige) without receiving
--      proportionally better food quality in return.


-- ================================================================================================
-- Q5. Best value locations — highest avg rating combined with lowest avg cost. (≥ 100 restaurants)
WITH
	LOCATION_METRICS AS (
		SELECT
			LOCATION,
			COUNT(*) AS TOTAL_RESTAURANTS,
			COUNT(RATE) AS RATED_COUNT,
			ROUND(AVG(RATE)::NUMERIC, 2) AS AVG_RATING,
			ROUND(AVG(APPROX_COST)::NUMERIC, 0) AS AVG_COST,
			ROUND(
				COUNT(*) FILTER (
					WHERE
						RATING_LABEL IN ('Good', 'Excellent')
				) * 100.0 / NULLIF(
					COUNT(*) FILTER (
						WHERE
							RATE IS NOT NULL
					),
					0
				),
				1
			) AS QUALITY_SCORE_PCT,
			ROUND(AVG(ONLINE_ORDER) * 100.0, 1) AS ONLINE_ORDER_PCT,
			ROUND(
				COUNT(*) FILTER (
					WHERE
						RATE IS NULL
				) * 100.0 / COUNT(*),
				1
			) AS UNRATED_PCT,
			-- Value score calculated inside the CTE
			-- so RANK() can reference it cleanly in outer SELECT
			ROUND(
				(AVG(RATE) * 100.0 / AVG(APPROX_COST))::NUMERIC,
				3
			) AS VALUE_SCORE
		FROM
			ZOMATO_RESTAURANTS
		GROUP BY
			LOCATION
		HAVING
			COUNT(*) >= 100 -- volume floor
			AND COUNT(RATE) >= 50 -- rated floor
			AND AVG(RATE) >= 3.5 -- quality floor
	)
SELECT
	RANK() OVER (
		ORDER BY
			VALUE_SCORE DESC
	) AS VALUE_RANK,
	LOCATION,
	TOTAL_RESTAURANTS,
	AVG_RATING,
	AVG_COST,
	QUALITY_SCORE_PCT,
	ONLINE_ORDER_PCT,
	UNRATED_PCT,
	VALUE_SCORE
FROM
	LOCATION_METRICS
ORDER BY
	VALUE_SCORE DESC
LIMIT
	15;
--
-- KEY FINDINGS:
--
-- F1. Value ranking and volume ranking are completely different.
--     Q4's top 5 by count: BTM, HSR, Koramangala 5th, JP Nagar, Whitefield.
--     Q5's top 5 by value: City Market, Koramangala 8th, Basavanagudi,
--     Varthur Main Road, Thippasandra.
--     Zero overlap in top 5 between both lists.
--     Bengaluru's biggest restaurant markets are NOT
--     its best value markets. Volume and value are
--     completely independent dimensions on this platform.
--
-- F2. City Market tops value ranking — but for the wrong reason.
--     value_score 1.169 driven entirely by ₹302 avg cost —
--     cheapest location in the entire output.
--     BUT: quality_score = 61.3% (below platform avg),
--     unrated_pct = 38.5% (highest in the top 15),
--     online_order = 27.9% (among the lowest).
--     City Market wins on price but loses on reliability.
--     It is Bengaluru's cheapest food market, not its
--     best value market in any meaningful quality sense.
--
-- F3. Koramangala 8th Block is the TRUE value champion.
--     value_rank #2, but with a critically important
--     difference from City Market:
--     avg_rating  : 3.74  (above platform avg of 3.70)
--     quality_pct : 75.5% (strong reliability)
--     avg_cost    : ₹359  (very affordable)
--     online_order: 72.1% (highly delivery-friendly)
--     It wins on value through BOTH quality AND affordability
--     simultaneously — not just cheap pricing.
--     The best real-world recommendation from this entire query.
--
-- F4. Koramangala 5th Block is absent — cost kills value score.
--     Q4's clear quality winner (avg_rating 4.01, quality 90%)
--     does not appear anywhere in this top 15.
--     Reason: avg_cost ₹664 — the highest denominator penalises
--     it in the value formula despite superior quality.
--     This is the formula's intentional trade-off: excellence
--     at premium price does not qualify as "value."
--
-- F5. Basavanagudi is the most trustworthy value location.
--     unrated_pct = 13.0% — lowest of any top-10 location.
--     684 restaurants, avg_rating 3.67, avg_cost ₹361.
--     Traditional South Bengaluru neighbourhood with a
--     mature, well-reviewed restaurant ecosystem.
--     Low unrated % means you can trust the ratings you
--     see — very little discovery risk here.
--
-- F6. Varthur Main Road, Whitefield is the delivery frontier.
--     online_order_pct = 87.2% — the highest of any location
--     in this entire query output. Nearly 9 in 10 restaurants
--     here accept online orders. This reflects Whitefield's
--     IT corridor culture where office workers and apartment
--     residents overwhelmingly prefer delivery over dine-in.
--     A strategic priority zone for Zomato's delivery ops.
--
-- F7. Majestic is Bengaluru's last traditional food market.
--     online_order_pct = 16.8% — by far the lowest in
--     the entire output. Quality score = 52.3%. Avg cost ₹387.
--     Majestic (KSR Bus Stand area) operates in a pre-digital
--     food economy — transient travellers, bus commuters,
--     daily wage workers. Zomato's platform barely touches
--     this market. Low digital adoption is structural, not a gap.
--
-- F8. BTM appears at #9 — exactly as predicted from Q4.
--     ₹396 avg cost (affordable) drives its value score.
--     But quality_score = 65.6% and avg_rating = 3.57
--     confirm it wins on price, not quality.
--     Bengaluru's volume capital is a mid-tier value market —
--     not the best, not the worst.
--
-- F9. Jeevan Bhima Nagar is the quiet high-performer.
--     unrated_pct = 7.8% — second lowest in the output.
--     online_order = 75.7% — highly delivery-adopted.
--     avg_cost = ₹399 — affordable.
--     268 restaurants, quality 64.4%.
--     A mature, delivery-forward, affordable neighbourhood
--     that appears in no headline ranking yet delivers
--     consistently across every metric.
--
-- F10. The value leader board is dominated by South and
--      East Bengaluru locations.
--      City Market, Basavanagudi, Jayanagar (from Q4),
--      Banashankari, Wilson Garden — all South Bengaluru.
--      Varthur, Whitefield, Electronic City — East corridor.
--      North and Central premium corridors (Indiranagar,
--      Brigade Road, UB City area) are priced out of the
--      value leaderboard entirely despite strong quality scores.


-- ========================================================================================
-- Q6. Most digitally active locations — online ordering adoption % ranked across all areas
WITH
	LOCATION_DIGITAL AS (
		SELECT
			LOCATION,
			COUNT(*) AS TOTAL_RESTAURANTS,
			ROUND(AVG(ONLINE_ORDER) * 100.0, 1) AS ONLINE_ORDER_PCT,
			ROUND(AVG(BOOK_TABLE) * 100.0, 1) AS BOOK_TABLE_PCT,
			ROUND(AVG(RATE)::NUMERIC, 2) AS AVG_RATING,
			ROUND(AVG(APPROX_COST)::NUMERIC, 0) AS AVG_COST,
			-- Weighted digital adoption score (0–100 scale)
			-- Online ordering : 70% weight
			-- Table booking   : 30% weight
			ROUND(
				(AVG(ONLINE_ORDER) * 70.0 + AVG(BOOK_TABLE) * 30.0)::NUMERIC,
				1
			) AS DIGITAL_SCORE
		FROM
			ZOMATO_RESTAURANTS
		GROUP BY
			LOCATION
		HAVING
			COUNT(*) >= 100
	)
SELECT
	RANK() OVER (
		ORDER BY
			ONLINE_ORDER_PCT DESC
	) AS DIGITAL_RANK,
	LOCATION,
	TOTAL_RESTAURANTS,
	ONLINE_ORDER_PCT,
	BOOK_TABLE_PCT,
	-- Scalar subquery: computes platform avg once,
	-- subtracts from each location's value
	-- Positive = above platform avg, Negative = below
	ROUND(
		ONLINE_ORDER_PCT - (
			SELECT
				AVG(ONLINE_ORDER) * 100.0
			FROM
				ZOMATO_RESTAURANTS
		)::NUMERIC,
		1
	) AS VS_PLATFORM_AVG,
	DIGITAL_SCORE,
	AVG_RATING,
	AVG_COST,
	-- CASE WHEN categorisation in SELECT
	-- Turns numeric adoption % into market type label
	CASE
		WHEN ONLINE_ORDER_PCT >= 70 THEN 'Heavy Delivery'
		WHEN ONLINE_ORDER_PCT >= 55 THEN 'Balanced'
		WHEN ONLINE_ORDER_PCT >= 40 THEN 'Dine-in Leaning'
		ELSE 'Traditional'
	END AS MARKET_TYPE
FROM
	LOCATION_DIGITAL
ORDER BY
	ONLINE_ORDER_PCT DESC
LIMIT
	15;
--
-- KEY FINDINGS:
--
-- F1. Every single location in the top 15 is above
--     the platform average of 60.5% online ordering.
--     The LOWEST location here (HBR Layout) is at 67.3% —
--     already 6.8 points above platform avg.
--     This means Bengaluru's digitally active locations
--     are not just slightly ahead — they are all firmly
--     in Heavy Delivery or Balanced territory.
--     The traditional/dine-in markets are completely absent
--     from the top 15, confirming delivery culture is the
--     defining characteristic of Bengaluru's food-tech market.
--
-- F2. Varthur Main Road has 87.2% online ordering
--     and ZERO table booking adoption.
--     book_table_pct = 0.0% — the only location in the
--     entire output with zero reservation culture.
--     Pure last-mile delivery market: IT corridor residents
--     and office workers ordering to their desks or flats.
--     No one is calling ahead for a table here.
--     This is the most extreme delivery-only market
--     in all of Bengaluru.
--
-- F3. Nagawara and Varthur tie at #1 — very different profiles.
--     Both at 87.2% online ordering (platform high).
--     But their digital_scores diverge:
--       Nagawara         : 62.8  (5.9% book_table)
--       Varthur Main Rd  : 61.0  (0.0% book_table)
--     Nagawara has a small but present reservation culture —
--     Varthur has none at all.
--     Same online ordering rate, completely different
--     dining behaviour underneath.
--
-- F4. Delivery culture does NOT mean budget market.
--     The delivery = budget assumption is challenged here:
--       ITPL Main Road, Whitefield : 72.6% online, ₹502 avg cost
--       Sarjapur Road              : 70.0% online, ₹571 avg cost
--       HSR                        : 77.8% online, ₹477 avg cost
--     Mid-to-premium priced locations are also the heaviest
--     delivery markets. Bengaluru's IT workforce orders
--     premium food online — not just cheap meals.
--
-- F5. HSR is Bengaluru's most strategically valuable
--     delivery market by volume.
--     2,494 restaurants × 77.8% online ordering = the largest
--     pool of active delivery restaurants in any single
--     high-adoption location. Every other Heavy Delivery
--     location has under 300 restaurants or well under 75%.
--     HSR alone represents an outsized share of Zomato's
--     delivery revenue concentration in Bengaluru.
--
-- F6. Jayanagar and Sarjapur Road are the most
--     fully-digital locations on the platform.
--     Both have online_order_pct 70%+ AND book_table_pct
--     = 14.6% — the highest reservation adoption in the
--     entire top 15. They have embraced BOTH digital services
--     simultaneously. Jayanagar (traditional South Bengaluru
--     neighbourhood) and Sarjapur Road (new tech corridor)
--     represent opposite ends of the city converging on
--     full digital adoption.
--
-- F7. Koramangala 7th Block leads the Balanced tier
--     on the digital_score metric.
--     online_order 68.5% + book_table 13.8% = digital_score 52.1
--     Highest composite score in the Balanced category.
--     The 7th Block has the highest avg_rating (3.85) and
--     avg_cost (₹593) in the entire top 15 — confirming
--     that premium, quality-driven locations adopt table
--     booking at much higher rates than delivery-only areas.
--
-- F8. Book table adoption separates premium from delivery.
--     The 5 locations with highest book_table_pct:
--       Jayanagar       : 14.6%
--       Sarjapur Road   : 14.6%
--       Koramangala 7th : 13.8%
--       HSR             :  8.7%
--       Koramangala 8th :  5.8%
--     All 5 have avg_rating ≥ 3.68 and avg_cost ≥ ₹359.
--     Table booking adoption is a premium restaurant signal —
--     locations with higher-end dining ecosystems adopt
--     reservations while budget delivery zones skip it.
--
-- F9. Small locations can lead on digital adoption.
--     Nagawara (187 restaurants) and Kaggadasapura (101)
--     are among the smallest locations in the top 15 —
--     yet rank #1 and #4 respectively. Digital adoption
--     is a neighbourhood culture choice, not a function
--     of how many restaurants exist. Small, tech-worker
--     dense residential pockets can out-digitise large
--     traditional commercial areas entirely.
--
-- F10. Kumaraswamy Layout is the most surprising entry.
--      85.3% online ordering — #3 in the city.
--      Yet avg_rating = 3.47 (below platform avg of 3.70)
--      and avg_cost = ₹375 (budget).
--      High delivery adoption with below-average quality
--      — a neighbourhood that relies on Zomato heavily
--      but hasn't developed a quality restaurant culture.
--      Classic volume-over-quality delivery market.


-- ===============================
-- SECTION 3: CUISINE INTELLIGENCE 
-- ===============================
-- 
-- Q7. Dominant cuisine per location — across all 93 areas.
--
-- PART A — Dominant cuisine per location (top 20 by size)
WITH
	CUISINE_COUNTS AS (
		SELECT
			LOCATION,
			PRIMARY_CUISINE,
			COUNT(*) AS CUISINE_COUNT,
			-- Total restaurants in this location
			-- SUM(COUNT(*)) OVER (PARTITION BY location):
			-- aggregates the per-cuisine counts back up
			-- to location level within the same query
			SUM(COUNT(*)) OVER (
				PARTITION BY
					LOCATION
			) AS TOTAL_IN_LOCATION,
			-- Share of this cuisine within its location
			ROUND(
				COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (
					PARTITION BY
						LOCATION
				)::NUMERIC,
				1
			) AS CUISINE_SHARE_PCT,
			-- Avg rating of this cuisine in this location
			ROUND(AVG(RATE)::NUMERIC, 2) AS CUISINE_AVG_RATING
		FROM
			ZOMATO_RESTAURANTS
		GROUP BY
			LOCATION,
			PRIMARY_CUISINE
	),
	RANKED_CUISINES AS (
		SELECT
			LOCATION,
			PRIMARY_CUISINE,
			CUISINE_COUNT,
			TOTAL_IN_LOCATION,
			CUISINE_SHARE_PCT,
			CUISINE_AVG_RATING,
			-- ROW_NUMBER assigns 1 to dominant cuisine per location
			-- PARTITION BY location → separate ranking per location
			-- ORDER BY cuisine_count DESC → most restaurants = rank 1
			-- primary_cuisine ASC → tiebreaker for equal counts
			ROW_NUMBER() OVER (
				PARTITION BY
					LOCATION
				ORDER BY
					CUISINE_COUNT DESC,
					PRIMARY_CUISINE ASC
			) AS RN
		FROM
			CUISINE_COUNTS
	)
SELECT
	LOCATION,
	PRIMARY_CUISINE AS DOMINANT_CUISINE,
	CUISINE_COUNT AS DOMINANT_CUISINE_COUNT,
	TOTAL_IN_LOCATION AS TOTAL_RESTAURANTS,
	CUISINE_SHARE_PCT,
	CUISINE_AVG_RATING
FROM
	RANKED_CUISINES
WHERE
	RN = 1
ORDER BY
	TOTAL_IN_LOCATION DESC
LIMIT
	20;
--
-- KEY FINDINGS:
--
-- F1. North Indian dominates 18 of the top 20 largest locations.
--     Only 2 exceptions in the entire top 20 by restaurant count:
--       Koramangala 5th Block (#3) - Cafe
--       Banashankari (#19)         - South Indian
--     Every other major Bengaluru neighbourhood, regardless
--     of geography, demographics, or price positioning,
--     has North Indian as its single most-supplied cuisine.
--     This confirms Part B's city-wide finding at a
--     granular, neighbourhood-by-neighbourhood level.
--
-- F2. Koramangala 5th Block is the only premium exception.
--     The only top-3 location by size where North Indian
--     does not dominate. Cafe wins with 400 restaurants
--     (16.1% share) and a cuisine_avg_rating of 4.15 —
--     the highest dominant-cuisine rating in the entire
--     top 20 by a significant margin.
--     Koramangala 5th Block's identity is built around
--     coffee culture, brunch dining, and premium all-day
--     casual formats — not the North Indian lunch market.
--     It is the only location in Bengaluru's top 20
--     where a western food format beats North Indian
--     for supply dominance.
--
-- F3. North Indian's dominance share varies dramatically.
--     Lowest share  : Brigade Road      10.6% (still #1)
--     Highest share : Koramangala 1st   37.8%
--     Even where North Indian dominates most weakly
--     (Brigade Road — a premium commercial strip), it still
--     wins despite holding only 1 in 10 restaurants.
--     This means the competition is extremely fragmented —
--     North Indian beats many cuisines that each hold
--     small single-digit shares. It wins by splitting
--     the market, not by monopolising it.
--
-- F4. North Indian consistently rates below each location's
--     overall avg_rating from Q4.
--     Comparing dominant cuisine avg_rating vs location avg:
--       Koramangala 5th: Cafe 4.15 vs location avg 4.01 (+0.14)
--       Jayanagar      : NI   3.78 vs location avg 3.78 (0.00)
--       Indiranagar    : NI   3.69 vs location avg 3.83 (−0.14)
--       BTM            : NI   3.45 vs location avg 3.57 (−0.12)
--     In most locations North Indian rates BELOW the
--     overall location average — meaning other cuisines
--     in those areas actually perform better per restaurant.
--     North Indian wins on volume, not on quality.
--
-- F5. Marathahalli and Bellandur are North Indian's
--     most concentrated strongholds.
--     Marathahalli : 649 NI restaurants, 36.0% share
--     Bellandur    : 461 NI restaurants, 36.4% share
--     Both are IT satellite townships — large migrant
--     worker populations from North India in dense
--     residential clusters. Here North Indian doesn't
--     just win the market — it owns more than a third of
--     all restaurants in the area outright.
--
-- F6. Banashankari is the sole South Indian stronghold
--     in the top 20.
--     South Indian at 20.7% share (187 restaurants) edges
--     out North Indian to claim #1 in a traditional,
--     established South Bengaluru neighbourhood.
--     Banashankari has deeper roots as a Kannada residential
--     area — older demographics, established local
--     restaurant culture, and less IT-driven in-migration
--     than the rest of the top 20. It is the last major
--     location in Bengaluru's top 20 where the native
--     food culture still wins the supply battle.
--
-- F7. Brigade Road is the most diverse location in top 20.
--     North Indian wins at only 10.6% share — meaning
--     89.4% of restaurants belong to other cuisines,
--     spread across continental, fast food, international
--     formats. Brigade Road is Bengaluru's tourist and
--     commercial corridor — no single cuisine dominates
--     because the customer base itself is maximally diverse.
--     It is the closest thing to genuine cuisine plurality
--     in any major Bengaluru location.

-- ====================================================
-- PART B — Which cuisine dominates the most locations?
-- (Run separately after Part A)
-- Uses Part A's logic inside a subquery to summarise
-- cuisine dominance across all 93 locations
-- ====================================================
WITH
	CUISINE_COUNTS AS (
		SELECT
			LOCATION,
			PRIMARY_CUISINE,
			COUNT(*) AS CUISINE_COUNT,
			SUM(COUNT(*)) OVER (
				PARTITION BY
					LOCATION
			) AS TOTAL_IN_LOCATION
		FROM
			ZOMATO_RESTAURANTS
		GROUP BY
			LOCATION,
			PRIMARY_CUISINE
	),
	RANKED_CUISINES AS (
		SELECT
			LOCATION,
			PRIMARY_CUISINE,
			CUISINE_COUNT,
			TOTAL_IN_LOCATION,
			ROW_NUMBER() OVER (
				PARTITION BY
					LOCATION
				ORDER BY
					CUISINE_COUNT DESC,
					PRIMARY_CUISINE ASC
			) AS RN
		FROM
			CUISINE_COUNTS
	),
	DOMINANT_PER_LOCATION AS (
		SELECT
			LOCATION,
			PRIMARY_CUISINE AS DOMINANT_CUISINE,
			CUISINE_COUNT,
			TOTAL_IN_LOCATION
		FROM
			RANKED_CUISINES
		WHERE
			RN = 1
	)
SELECT
	DOMINANT_CUISINE,
	COUNT(*) AS LOCATIONS_DOMINATED,
	ROUND(COUNT(*) * 100.0 / 93, 1) AS PCT_OF_ALL_LOCATIONS,
	SUM(CUISINE_COUNT) AS TOTAL_RESTAURANTS_AS_DOMINANT,
	ROUND(AVG(CUISINE_COUNT), 0) AS AVG_COUNT_PER_LOCATION
FROM
	DOMINANT_PER_LOCATION
GROUP BY
	DOMINANT_CUISINE
ORDER BY
	LOCATIONS_DOMINATED DESC
LIMIT
	10;
--
-- KEY FINDINGS:
--
-- F1. North Indian dominates 65.6% of all Bengaluru locations.
--     61 out of 93 neighbourhoods have North Indian as their
--     single most-supplied cuisine. In a city famous for
--     idli, dosa, and filter coffee — a cuisine from 2,000
--     km away has captured two-thirds of the restaurant
--     supply landscape.
--     This is the most counterintuitive finding in the
--     entire project and the strongest single story to tell.
--
-- F2. The 87-cuisine diversity figure is deeply misleading.
--     Python EDA reported 87 unique primary cuisines.
--     That sounds like rich diversity.
--     SQL reality: only 10 cuisines ever dominate any location.
--     The remaining 77 cuisines exist in Bengaluru but
--     never achieve enough concentration to become the
--     #1 cuisine anywhere. They are long-tail variety —
--     present but not competitive at neighbourhood level.
--     Diversity of supply does not equal diversity of dominance.
--
-- F3. North Indian's depth of penetration is unmatched.
--     avg_count_per_location = 178 restaurants per location
--     it dominates. When North Indian wins an area it wins
--     heavily — not by one or two restaurants but by
--     massive supply concentration.
--     Compare: South Indian wins 14 locations but averages
--     only 68 restaurants per location. North Indian builds
--     a wall of supply; South Indian wins on cultural fit
--     with thinner concentration.
--
-- F4. South Indian cuisine is a minority in its own city.
--     Only 14 of 93 locations (15.1%) have South Indian
--     as their dominant cuisine — in Bengaluru, the
--     cultural heartland of South Indian food.
--     This confirms the in-migration story from Python EDA:
--     massive influx of North Indian IT workers has
--     fundamentally reshaped the city's commercial food
--     supply away from its native cuisine identity.
--
-- F5. Cafe format dominates 6 locations — the premium signal.
--     Cafe as a primary cuisine (coffee shops, all-day
--     breakfast, brunch culture) winning 6 locations tells
--     you exactly where Bengaluru's premium, young
--     professional, Instagram-driven food culture lives.
--     These 6 locations almost certainly include Koramangala,
--     Indiranagar, and Church Street corridors.
--     avg_count_per_location = 109 — a large concentration,
--     meaning these areas have dense cafe ecosystems,
--     not just a few boutique spots.
--
-- F6. Italian dominates exactly 1 location — with 22 restaurants.
--     The highest avg_count_per_location among single-location
--     winners (22). One specific premium neighbourhood has
--     built a concentrated Italian dining scene.
--     Most likely candidate: UB City area, Lavelle Road,
--     or a specific Koramangala block based on Q4/Q5 data.
--     This is Bengaluru's only true cuisine enclave —
--     a neighbourhood whose identity is defined by a
--     single international cuisine.
--
-- F7. Fast Food dominates 4 locations — but barely.
--     avg_count_per_location = 9 — the joint lowest in
--     the output (with Chinese at 5 and Kerala/Biryani at 2).
--     Fast Food wins these locations not because it has
--     many restaurants but because everything else has
--     even fewer. These are likely small, low-density
--     residential areas where the restaurant ecosystem
--     hasn't matured beyond convenience formats.
--
-- F8. Chinese dominates 3 locations — each with only 5 avg.
--     Extremely thin concentration. Chinese winning these
--     3 areas likely means the area has 5 Chinese restaurants
--     vs 4 North Indian — a one-restaurant margin.
--     Not a genuine Chinese food culture hub; more a
--     statistical artefact of very small total restaurant pools.
--
-- F9. Kerala, Biryani, Arabian each win exactly 1 location
--     with 2-5 restaurants. These are the rarest cases
--     of hyper-local cuisine identity — small, tight
--     community-driven food markets where a specific
--     migrant or cultural community has enough concentration
--     to shape the local food supply.
--     Each of these 3 single-location winners likely
--     corresponds to a neighbourhood with a specific
--     religious or regional community cluster.
--
-- F10. The dominance structure is extremely top-heavy.
--      North Indian alone: 65.6% of locations
--      North + South Indian combined: 80.7% of locations
--      Top 3 (+ Cafe): 87.2% of locations
--      The remaining 7 cuisines split 12.8% of locations.
--      Bengaluru's food supply, despite its cosmopolitan
--      reputation, is concentrated in just 2-3 cuisine
--      categories at the neighbourhood level.
--      87 cuisines exist — but 2 cuisines own the map.


-- ==========================================================================================
-- Q8. Cuisine performance table - avg rating, avg cost, restaurant count for top 15 cuisines.
-- 
-- PART A — Top 15 cuisines by restaurant count
WITH
	CUISINE_STATS AS (
		SELECT
			PRIMARY_CUISINE,
			COUNT(*) AS TOTAL_COUNT,
			COUNT(RATE) AS RATED_COUNT,
			ROUND(AVG(RATE)::NUMERIC, 2) AS AVG_RATING,
			ROUND(AVG(APPROX_COST)::NUMERIC, 0) AS AVG_COST,
			ROUND(AVG(VOTES)::NUMERIC, 0) AS AVG_VOTES,
			ROUND(
				COUNT(*) FILTER (
					WHERE
						RATING_LABEL IN ('Good', 'Excellent')
				) * 100.0 / NULLIF(
					COUNT(*) FILTER (
						WHERE
							RATE IS NOT NULL
					),
					0
				),
				1
			) AS QUALITY_SCORE_PCT,
			ROUND(AVG(ONLINE_ORDER) * 100.0, 1) AS ONLINE_ORDER_PCT,
			ROUND(
				COUNT(*) FILTER (
					WHERE
						RATE IS NULL
				) * 100.0 / COUNT(*),
				1
			) AS UNRATED_PCT,
			-- Performance index at cuisine level
			-- mirrors Q1 credibility score formula
			ROUND((AVG(RATE) * LOG(AVG(VOTES) + 1))::NUMERIC, 2) AS PERFORMANCE_INDEX
		FROM
			ZOMATO_RESTAURANTS
		GROUP BY
			PRIMARY_CUISINE
		HAVING
			COUNT(*) >= 50
	)
SELECT
	-- Window function 1: rank by volume
	RANK() OVER (
		ORDER BY
			TOTAL_COUNT DESC
	) AS POPULARITY_RANK,
	-- Window function 2: rank by quality — different ORDER BY
	-- NULLS LAST prevents unrated cuisines topping quality rank
	RANK() OVER (
		ORDER BY
			AVG_RATING DESC NULLS LAST
	) AS QUALITY_RANK,
	PRIMARY_CUISINE,
	TOTAL_COUNT,
	RATED_COUNT,
	AVG_RATING,
	-- Scalar subquery: dynamic platform benchmark
	-- computes platform avg once, reused for every cuisine row
	ROUND(
		(
			AVG_RATING - (
				SELECT
					AVG(RATE)
				FROM
					ZOMATO_RESTAURANTS
				WHERE
					RATE IS NOT NULL
			)
		)::NUMERIC,
		2
	) AS VS_PLATFORM_AVG,
	AVG_COST,
	AVG_VOTES,
	QUALITY_SCORE_PCT,
	ONLINE_ORDER_PCT,
	UNRATED_PCT,
	PERFORMANCE_INDEX,
	CASE
		WHEN AVG_RATING >= 3.9 THEN 'Star Performer'
		WHEN AVG_RATING >= 3.7 THEN 'Above Average'
		WHEN AVG_RATING >= 3.5 THEN 'At Par'
		ELSE 'Below Average'
	END AS PERFORMANCE_TIER
FROM
	CUISINE_STATS
ORDER BY
	TOTAL_COUNT DESC
LIMIT
	15;
--
-- KEY FINDINGS:
--
-- F1. Only 1 of the top 15 popular cuisines is a Star Performer.
--     Continental (#9 popular, #11 quality) is the sole
--     Star Performer in the entire popularity top 15.
--     12 of 15 popular cuisines sit in the "At Par" tier —
--     meaning the overwhelming majority of restaurants
--     customers encounter on Zomato Bengaluru perform
--     at or below the platform average.
--     The most consumed cuisines are not the best cuisines.
--
-- F2. North Indian and South Indian tie at exactly 3.59 —
--     both 0.11 below platform average.
--     Together they represent 17,099 restaurants — 33.5%
--     of all platform listings. Both are quality rank #39
--     (tied). Bengaluru's two most culturally significant
--     cuisines — one dominating supply, one native to
--     the city — perform identically and equally below average.
--     The city's food identity, measured by quality,
--     is defined by cuisines that aren't either of these.
--
-- F3. The popularity-quality gap is widest for Biryani
--     and Fast Food.
--     Biryani   : popularity #5, quality #44  → gap of 39
--     Fast Food : popularity #6, quality #45  → gap of 39
--     These are simultaneously two of Bengaluru's most
--     ordered and worst-rated major cuisines.
--     Both sit below 3.55 avg_rating and below platform avg.
--     High demand with consistently low quality suggests
--     customers order these out of convenience and habit,
--     not because the product is good.
--
-- F4. Cafe is the strongest popular cuisine by quality.
--     popularity #3 (4,281 restaurants), quality rank #16
--     (avg 3.87, +0.17 above platform avg).
--     Only 7.8% unrated — most mature discovery profile
--     in the top 15 by a wide margin.
--     Cafe format (coffee shops, brunch, all-day dining)
--     consistently maintains above-average quality at
--     massive scale. It is the only cuisine in the top 5
--     popular cuisines that rates above platform average.
--
-- F5. Continental punches far above its popularity rank.
--     popularity #9 but quality #11 and the ONLY
--     Star Performer in the top 15 popular list.
--     performance_index 11.71 — highest in Part A.
--     avg_votes 883 — also the highest in Part A by far.
--     1,803 restaurants delivering 3.97 avg_rating with
--     90.7% quality score. Continental achieves near-4.0
--     quality at a scale no other cuisine in Part A matches.
--     This is Bengaluru's best mainstream cuisine option.
--
-- F6. South Indian's engagement is catastrophically low.
--     avg_votes = 88 — the second lowest in the entire
--     top 15 (only Fast Food is lower at 58 and Bakery at 74).
--     4,982 restaurants but each averages only 88 votes.
--     Compare: Continental has 1,803 restaurants but
--     averages 883 votes — 10× more engagement per restaurant.
--     South Indian restaurants in Bengaluru are frequented
--     daily by locals but almost never reviewed — a
--     structural engagement gap. The food may be good
--     but the digital footprint is nearly invisible.
--
-- F7. Fast Food has the lowest avg_votes of any meaningful
--     cuisine at just 58 per restaurant.
--     2,559 Fast Food restaurants averaging 58 votes =
--     pure transactional dining. Customers grab food
--     and leave with zero review behaviour.
--     This explains Fast Food's quality rank #45
--     despite being a high-volume category — when
--     engagement is this low, ratings are unreliable
--     and heavily influenced by a tiny minority of reviewers.
--
-- F8. Bakery has the highest unrated_pct in the top 15 at 32.9%.
--     2,157 bakery listings but 710 have never been reviewed.
--     Bakeries in Bengaluru operate as neighbourhood staples —
--     people buy bread and pastries without ever considering
--     leaving a Zomato review. The category is large in
--     supply but almost entirely invisible to discovery.
--
-- F9. Beverages is the delivery champion of popular cuisines.
--     online_order_pct = 74.0% — the highest of any cuisine
--     in Part A. avg_cost = ₹265 — second cheapest overall.
--     Juice bars, tea stalls, and beverage-focused outlets
--     have embraced delivery more than any other popular
--     cuisine. Their low price point and quick preparation
--     make them ideal delivery products.
--
-- F10. Ice Cream is Part A's quiet overperformer.
--      popularity #12 but quality rank #18 — the best
--      quality rank relative to popularity in the bottom
--      half of this list. avg_rating 3.83 (+0.13),
--      quality_score 80.0%, avg_votes 215.
--      Ice cream parlours attract consistent, happy
--      customers who review positive experiences.
--      The category has virtually zero service failure
--      risk — which keeps ratings reliably above average.


-- ============================================================
-- PART B — Top 15 cuisines by average rating (quality leaders)
-- Same CTE - only ORDER BY changes
WITH
	CUISINE_STATS AS (
		SELECT
			PRIMARY_CUISINE,
			COUNT(*) AS TOTAL_COUNT,
			COUNT(RATE) AS RATED_COUNT,
			ROUND(AVG(RATE)::NUMERIC, 2) AS AVG_RATING,
			ROUND(AVG(APPROX_COST)::NUMERIC, 0) AS AVG_COST,
			ROUND(AVG(VOTES)::NUMERIC, 0) AS AVG_VOTES,
			ROUND(
				COUNT(*) FILTER (
					WHERE
						RATING_LABEL IN ('Good', 'Excellent')
				) * 100.0 / NULLIF(
					COUNT(*) FILTER (
						WHERE
							RATE IS NOT NULL
					),
					0
				),
				1
			) AS QUALITY_SCORE_PCT,
			ROUND(AVG(ONLINE_ORDER) * 100.0, 1) AS ONLINE_ORDER_PCT,
			ROUND((AVG(RATE) * LOG(AVG(VOTES) + 1))::NUMERIC, 2) AS PERFORMANCE_INDEX
		FROM
			ZOMATO_RESTAURANTS
		GROUP BY
			PRIMARY_CUISINE
		HAVING
			COUNT(*) >= 50
	)
SELECT
	RANK() OVER (
		ORDER BY
			AVG_RATING DESC NULLS LAST
	) AS QUALITY_RANK,
	RANK() OVER (
		ORDER BY
			TOTAL_COUNT DESC
	) AS POPULARITY_RANK,
	PRIMARY_CUISINE,
	TOTAL_COUNT,
	AVG_RATING,
	ROUND(
		(
			AVG_RATING - (
				SELECT
					AVG(RATE)
				FROM
					ZOMATO_RESTAURANTS
				WHERE
					RATE IS NOT NULL
			)
		)::NUMERIC,
		2
	) AS VS_PLATFORM_AVG,
	AVG_COST,
	AVG_VOTES,
	QUALITY_SCORE_PCT,
	ONLINE_ORDER_PCT,
	PERFORMANCE_INDEX,
	CASE
		WHEN AVG_RATING >= 3.9 THEN 'Star Performer'
		WHEN AVG_RATING >= 3.7 THEN 'Above Average'
		WHEN AVG_RATING >= 3.5 THEN 'At Par'
		ELSE 'Below Average'
	END AS PERFORMANCE_TIER
FROM
	CUISINE_STATS
ORDER BY
	AVG_RATING DESC NULLS LAST
LIMIT
	15;
--
-- KEY FINDINGS:
--
-- F1. North Indian is completely absent from the quality top 15.
--     The city's #1 cuisine by supply (12,117 restaurants,
--     popularity rank #1, dominating 65.6% of all locations)
--     does not rate well enough to appear in the top 15
--     by avg_rating. The quality threshold for row 15 is
--     3.88 — North Indian almost certainly sits well below
--     this, likely in the 3.5–3.6 range, dragged down by
--     the sheer volume of budget, low-engagement operators.
--     Bengaluru's most supplied cuisine is not its
--     most respected one. Quantity and quality diverge
--     completely at the cuisine level.
--
-- F2. Every single cuisine in the quality top 15 is above
--     the platform average of 3.70.
--     The lowest vs_platform_avg is +0.18 (rows 14-15).
--     The highest is +0.61 (Modern Indian).
--     There is a clean separation: cuisines that make this
--     list are genuinely above-average performers —
--     not marginal cases. The quality top 15 is a legitimately
--     elite group.
--
-- F3. Modern Indian is the highest-rated cuisine (4.31)
--     but ranks only #38 in popularity (111 restaurants).
--     It is Bengaluru's best-kept culinary secret —
--     exceptional quality in a tiny supply pool.
--     100% quality_score_pct: every single rated Modern
--     Indian restaurant in Bengaluru is Good or Excellent.
--     Zero exceptions across 111 restaurants.
--     This is a cuisine that filters out poor operators
--     entirely — likely because premium pricing and
--     sophisticated customers self-select for quality.
--
-- F4. Mediterranean matches Modern Indian on quality_score
--     at 100.0% — equally perfect hit rate.
--     Only 107 restaurants, popularity rank #40.
--     avg_cost ₹1,304 — premium but not the most expensive.
--     avg_votes 1,221 — the highest in the top 4 quality
--     cuisines by engagement. More customers per restaurant
--     than Modern Indian (1,048) or Japanese (879).
--     Smaller supply than Modern Indian, better engagement.
--
-- F5. European leads the performance_index at 13.57 —
--     the best combined quality + engagement score.
--     avg_rating 4.26 (#2 quality) × LOG(1,527 avg_votes)
--     = highest composite score.
--     avg_votes 1,527 — the highest of any cuisine in
--     the entire quality top 15.
--     European restaurants in Bengaluru attract the most
--     engaged, review-active customers of any cuisine —
--     each restaurant building a large, loyal base.
--
-- F6. Japanese has the highest avg_cost in the dataset —
--     ₹1,893 for two people.
--     Yet it ranks #4 on quality (4.19) and #37 on
--     popularity (117 restaurants).
--     Japanese cuisine is Bengaluru's most premium niche —
--     small supply, extremely high price point, above-average
--     quality. Customers who visit Japanese restaurants
--     pay the most and rate them highly, suggesting
--     the format attracts both affluent and discerning diners.
--
-- F7. American cuisine is the best balance of popularity
--     and quality in the top 5.
--     quality_rank #5 (avg 4.16) with popularity_rank #20
--     (532 restaurants). It has the best performance_index
--     of any cuisine in the top 5 at 13.31 — driven by
--     the highest avg_votes (1,580) in the quality top 5.
--     American-format restaurants (burgers, grill, bar food)
--     attract consistently high engagement and rate well.
--     The format that best combines mainstream appeal
--     with genuine quality in Bengaluru.
--
-- F8. Continental is the quality-popularity sweet spot
--     of the entire dataset.
--     quality_rank #11, popularity_rank #9.
--     1,803 restaurants — by far the largest cuisine
--     in the quality top 15. avg_rating 3.97, quality
--     score 90.7%. This cuisine achieves near-4.0 rating
--     at massive scale — proving that volume does not
--     always destroy quality. Continental's wide-format
--     menus (multi-cuisine, fusion, all-day dining) allow
--     diverse operators to consistently satisfy customers.
--     The most commercially viable cuisine profile in
--     the entire analysis.
--
-- F9. Rajasthani cuisine punches far above its weight.
--     quality_rank #12 (avg 3.96), popularity_rank #38
--     (111 restaurants). quality_score_pct = 94.5% —
--     third highest in the entire output.
--     online_order_pct = 82.9% — the HIGHEST of any cuisine
--     in the quality top 15. Rajasthani cuisine has quietly
--     built a high-quality, highly delivery-friendly
--     niche in Bengaluru — mostly through thali-format
--     restaurants beloved by the North Indian migrant
--     community.
--
-- F10. Desserts appears in quality top 15 (tied #14, avg 3.88)
--      but tells a conflicted story.
--      popularity_rank #8 — 2,124 restaurants — by far
--      the largest supply in the quality top 15.
--      BUT avg_votes = only 143 — by far the lowest
--      in the entire output. And performance_index = 8.37
--      — the lowest of all 15 cuisines.
--      Desserts restaurants are numerous and above-average
--      rated, but generate almost no review engagement.
--      Customers visit dessert shops often but rarely
--      leave reviews. The rating is real but the
--      social proof layer (votes) is almost entirely absent.
--      A cuisine with hidden quality and zero discoverability.
--
-- F11. The quality top 13 are ALL Star Performers (avg ≥ 3.9).
--      Only Finger Food and Desserts (both tied at 3.88)
--      fall into Above Average tier.
--      The performance_tier column shows zero Below Average
--      or At Par cuisines in this list — confirming the
--      quality top 15 is a genuinely elevated segment,
--      not a gradual slope from the platform average.
--
-- F12. Online ordering splits quality cuisines into two camps.
--      Delivery-friendly quality cuisines (≥ 60% online):
--        Asian 62.9%, Thai 70.2%, Goan 72.7%,
--        Rajasthani 82.9%, Desserts 65.4%, BBQ 62.5%
--      Premium dine-in quality cuisines (< 50% online):
--        Modern Indian 27.0%, European 40.4%,
--        Mediterranean 37.4%, Continental 46.3%,
--        Finger Food 23.4%
--      The pattern: cuisines with the highest avg_cost
--      tend to have the lowest online ordering adoption.
--      Premium dining is a sit-down, in-person experience
--      — not delivered in a box.


--=====================================
-- SECTION 4: PRICING AND VALUE ANALYSIS 
-- =====================================
--
-- Q9. Price tier performance — avg rating, avg votes, total count per tier (is premium pricing justified?)
WITH
	TIER_STATS AS (
		SELECT
			PRICE_CATEGORY,
			-- Numeric sort key so LAG() and ORDER BY work correctly
			CASE PRICE_CATEGORY
				WHEN 'Budget' THEN 1
				WHEN 'Mid-range' THEN 2
				WHEN 'Premium' THEN 3
			END AS TIER_ORDER,
			COUNT(*) AS TOTAL_RESTAURANTS,
			ROUND(AVG(RATE)::NUMERIC, 2) AS AVG_RATING,
			ROUND(AVG(APPROX_COST)::NUMERIC, 0) AS AVG_COST,
			ROUND(AVG(VOTES)::NUMERIC, 0) AS AVG_VOTES,
			ROUND(AVG(ONLINE_ORDER) * 100.0, 1) AS ONLINE_ORDER_PCT,
			ROUND(AVG(BOOK_TABLE) * 100.0, 1) AS BOOK_TABLE_PCT,
			ROUND(
				COUNT(*) FILTER (
					WHERE
						RATING_LABEL IN ('Good', 'Excellent')
				) * 100.0 / NULLIF(
					COUNT(*) FILTER (
						WHERE
							RATE IS NOT NULL
					),
					0
				),
				1
			) AS QUALITY_SCORE_PCT,
			ROUND(
				COUNT(*) FILTER (
					WHERE
						RATING_LABEL = 'Excellent'
				) * 100.0 / COUNT(*),
				1
			) AS EXCELLENT_PCT,
			ROUND(
				COUNT(*) FILTER (
					WHERE
						RATING_LABEL = 'Poor'
				) * 100.0 / COUNT(*),
				1
			) AS POOR_PCT,
			ROUND(
				COUNT(*) FILTER (
					WHERE
						RATE IS NULL
				) * 100.0 / COUNT(*),
				1
			) AS UNRATED_PCT,
			-- Value score = quality earned per ₹100 spent
			-- consistent with Q5 formula
			ROUND(
				(AVG(RATE) * 100.0 / AVG(APPROX_COST))::NUMERIC,
				3
			) AS VALUE_SCORE
		FROM
			ZOMATO_RESTAURANTS
		GROUP BY
			PRICE_CATEGORY
	)
SELECT
	PRICE_CATEGORY,
	TOTAL_RESTAURANTS,
	-- SUM() OVER () — no PARTITION BY = window spans ALL rows
	-- gives grand total for market share calculation
	ROUND(
		TOTAL_RESTAURANTS * 100.0 / SUM(TOTAL_RESTAURANTS) OVER (),
		1
	) AS MARKET_SHARE_PCT,
	AVG_RATING,
	-- LAG(): subtract previous tier's avg_rating from current
	-- Budget - NULL (no previous tier)
	-- Mid-range - Mid avg_rating minus Budget avg_rating
	-- Premium - Premium avg_rating minus Mid-range avg_rating
	ROUND(
		(
			AVG_RATING - LAG(AVG_RATING) OVER (
				ORDER BY
					TIER_ORDER
			)
		)::NUMERIC,
		2
	) AS RATING_JUMP_VS_PREV,
	AVG_COST,
	ROUND(
		(
			AVG_COST - LAG(AVG_COST) OVER (
				ORDER BY
					TIER_ORDER
			)
		)::NUMERIC,
		0
	) AS COST_JUMP_VS_PREV,
	AVG_VOTES,
	ROUND(
		(
			AVG_VOTES - LAG(AVG_VOTES) OVER (
				ORDER BY
					TIER_ORDER
			)
		)::NUMERIC,
		0
	) AS VOTES_JUMP_VS_PREV,
	QUALITY_SCORE_PCT,
	EXCELLENT_PCT,
	POOR_PCT,
	ONLINE_ORDER_PCT,
	BOOK_TABLE_PCT,
	UNRATED_PCT,
	VALUE_SCORE,
	-- Directly answers the business question per tier transition
	CASE
		WHEN TIER_ORDER = 1 THEN 'Baseline tier'
		WHEN (
			AVG_RATING - LAG(AVG_RATING) OVER (
				ORDER BY
					TIER_ORDER
			)
		) > 0.25 THEN 'Justified — large quality gain'
		WHEN (
			AVG_RATING - LAG(AVG_RATING) OVER (
				ORDER BY
					TIER_ORDER
			)
		) > 0.10 THEN 'Marginal — small quality gain'
		ELSE 'Not justified — minimal quality gain'
	END AS PRICE_JUMP_VERDICT
FROM
	TIER_STATS
ORDER BY
	TIER_ORDER;
--
-- KEY FINDINGS:
--
-- F1. The verdict is split — Mid-range is not worth it,
--     Premium is.
--     Budget → Mid-range: pay ₹320 more (+112%), gain 0.11
--     rating points. Verdict: Marginal.
--     Mid-range → Premium: pay ₹778 more (+129%), gain 0.35
--     rating points. Verdict: Justified.
--     For a customer deciding where to spend, the data says:
--     either stay Budget or go Premium. Mid-range is the
--     most expensive upgrade per quality point gained.
--
-- F2. The rating-jump asymmetry is striking.
--     Mid-range jump  : +0.11 rating for +₹320 cost
--     Premium jump    : +0.35 rating for +₹778 cost
--     Premium's jump is 3.2x larger in rating points
--     but only 2.4x larger in cost.
--     The Premium upgrade is more efficient —
--     you get proportionally more quality per extra rupee
--     at the top tier than at the middle tier.
--
-- F3. Mid-range fails more than Budget.
--     poor_pct: Budget 3.2% → Mid-range 7.0% → Premium 2.5%
--     Mid-range has MORE than double Budget's failure rate —
--     and nearly triple Premium's failure rate.
--     This is the value trap confirmed with hard numbers:
--     Mid-range restaurants charge more than Budget but
--     fail more often. Paying ₹604 average does not
--     protect you from a poor dining experience —
--     it actually increases your risk vs Budget.
--
-- F4. Budget avg_cost is only ₹284 — far lower than expected.
--     The Budget tier (defined as ≤₹400) averages just ₹284.
--     This means the tier is heavily weighted toward very
--     cheap restaurants: ₹40–₹200 street food, quick bites,
--     and delivery kitchens. These aren't just affordable —
--     many are genuinely bare-minimum operations with
--     minimal ambience and service investment.
--     The ₹284 floor explains why Budget's quality score
--     (63.6%) is respectable but not outstanding —
--     a large portion of this tier is ultra-budget dining.
--
-- F5. Premium restaurants get 15.6× more votes than Budget.
--     avg_votes: Budget 65 → Mid-range 294 → Premium 1,015
--     A Premium restaurant attracts on average 950 more
--     reviews than a Budget one. This explains Q1's entire
--     finding — Premium restaurants dominate credibility
--     rankings because they generate the vote volume needed
--     to score high on rate × LOG(votes + 1).
--     High-end restaurants attract engaged, returning,
--     review-writing customers. Budget restaurants serve
--     more transactional one-time visits with no review.
--
-- F6. votes_jump from Mid→Premium (+721) is 3.1×
--     the Budget→Mid jump (+229).
--     Engagement scales non-linearly with price tier.
--     The Premium jump in votes is even steeper than
--     the Premium jump in ratings. Premium restaurants
--     don't just perform better — they create dramatically
--     more social proof and discoverability on the platform.
--     This is a compounding advantage: better quality →
--     more votes → higher ranking → more customers →
--     even more votes. Premium creates a flywheel.
--
-- F7. Online ordering is INVERTED vs expectation.
--     online_order_pct: Budget 58.6% → Mid-range 70.3%
--     → Premium 46.2%
--     The ordering: Mid-range HIGHEST, Premium LOWEST.
--     Premium restaurants are LESS likely to offer
--     online ordering than even Budget restaurants.
--     This directly confirms Q1's finding — 8 of 10
--     top credibility restaurants don't do delivery.
--     Premium dining is deliberately protecting the
--     dine-in experience. They don't need delivery volume;
--     their quality drives walk-in traffic.
--     Mid-range is most delivery-adopted because it serves
--     the tech-worker lunch and convenience segment.
--
-- F8. Table booking is almost exclusively a Premium feature.
--     book_table_pct: Budget 0.3% → Mid-range 9.0%
--                    → Premium 61.9%
--     Budget: essentially zero. 0.3% means roughly 80 of
--     26,699 Budget restaurants accept reservations.
--     Mid-range: 9.0% — limited adoption.
--     Premium: 61.9% — majority. More than 6 in 10 Premium
--     restaurants want you to book ahead.
--     Table booking is not a platform feature — it is a
--     Premium business model signal. It means the restaurant
--     manages capacity, has consistent staffing, and
--     operates at a level where a no-show costs real money.
--
-- F9. Budget delivers 4.3× better value score than Premium.
--     value_score: Budget 1.258 → Mid-range 0.611
--                 → Premium 0.293
--     Budget delivers 1.258 rating points per ₹100 spent.
--     Premium delivers only 0.293 — 4.3× worse value.
--     The practical meaning: if you eat at a Budget
--     restaurant, every ₹100 buys 1.258 "quality units."
--     At Premium, each ₹100 buys only 0.293.
--     Value score degrades monotonically and steeply —
--     each tier upgrade trades value for quality.
--
-- F10. Unrated restaurants are almost entirely a Budget problem.
--      unrated_pct: Budget 28.4% → Mid-range 11.9%
--                  → Premium 4.0%
--      7 in 10 unrated restaurants across the platform
--      are in the Budget tier. Premium is essentially
--      fully reviewed — 96% of Premium restaurants have
--      ratings. The discovery challenge on Zomato is a
--      Budget-tier structural problem, not a platform-wide one.
--
-- FINAL ANSWER TO BUSINESS QUESTION:
--   Is premium pricing justified?
--   - Mid-range upgrade (Budget → Mid): NOT justified.
--     Pay 2.1× more, gain only 0.11 rating points,
--     and actually increase your failure risk (poor_pct 7%).
--   - Premium upgrade (Mid → Premium): YES, justified.
--     Pay 2.3× more, gain 0.35 rating points, near-zero
--     failure risk (2.5%), 92% quality guarantee.
--   - Best value: Budget (value_score 1.258).
--   - Best quality guarantee: Premium (quality 92%, poor 2.5%).
--   - Worst choice: Mid-range (poor 7.0%, marginal quality
--     gain, lowest value score after Premium).

-- ==============================================================================================
-- Q10. Hidden gems - budget restaurants (≤ ₹400) rated ≥ 4.0, ranked by votes (best value finds).
-- 
-- PART A — The Hidden Gems list (top 15 by votes)
--
WITH
	UNIQUE_BUDGET_GEMS AS (
		SELECT DISTINCT
			ON (NAME, LOCATION) NAME,
			LOCATION,
			PRIMARY_CUISINE,
			REST_TYPE,
			RATE,
			VOTES,
			APPROX_COST,
			ONLINE_ORDER,
			BOOK_TABLE
		FROM
			ZOMATO_RESTAURANTS
		WHERE
			PRICE_CATEGORY = 'Budget'
			AND RATE >= 4.0
			AND VOTES >= 100
		ORDER BY
			NAME,
			LOCATION,
			VOTES DESC
	)
SELECT
	RANK() OVER (
		ORDER BY
			VOTES DESC
	) AS GEM_RANK,
	-- NTILE: segments gems into 3 proof bands by vote volume
	NTILE(3) OVER (
		ORDER BY
			VOTES DESC
	) AS PROOF_BUCKET,
	NAME,
	LOCATION,
	PRIMARY_CUISINE,
	REST_TYPE,
	RATE,
	VOTES,
	APPROX_COST AS COST_FOR_TWO,
	-- Quality earned per ₹100 spent
	-- Higher = better value for money
	ROUND((RATE * 100.0 / APPROX_COST)::NUMERIC, 2) AS VALUE_INDEX,
	-- Correlated scalar subquery:
	-- For each gem, what % of ALL rated restaurants does it outrate?
	-- Inner query references outer alias ubg.rate per row
	ROUND(
		(
			SELECT
				COUNT(*)
			FROM
				ZOMATO_RESTAURANTS R2
			WHERE
				R2.RATE < UBG.RATE
				AND R2.RATE IS NOT NULL
		) * 100.0 / (
			SELECT
				COUNT(*)
			FROM
				ZOMATO_RESTAURANTS
			WHERE
				RATE IS NOT NULL
		)::NUMERIC,
		1
	) AS BEATS_PCT_OF_PLATFORM,
	ONLINE_ORDER,
	BOOK_TABLE,
	CASE
		WHEN RATE >= 4.5 THEN 'Exceptional'
		WHEN RATE >= 4.2 THEN 'Excellent'
		ELSE 'Very Good'
	END AS GEM_TIER
FROM
	UNIQUE_BUDGET_GEMS UBG
ORDER BY
	VOTES DESC
LIMIT
	15;
--
-- KEY FINDINGS:
--
-- F1. Three Budget restaurants beat 99%+ of ALL restaurants
--     on the entire platform regardless of price tier.
--     CTR              : 4.8 rating → beats 99.7% of platform
--     Brahmin's Coffee : 4.8 rating → beats 99.7% of platform
--     Milano Ice Cream : 4.9 rating → beats 99.9% of platform
--     Belgian Waffle   : 4.9 rating → beats 99.9% of platform
--     A ₹150 idli breakfast at CTR outrates virtually every
--     Premium restaurant in Bengaluru. This is the single
--     most powerful consumer insight in the entire project.
--
-- F2. Brahmin's Coffee Bar is the ultimate hidden gem.
--     ₹100 for two — the cheapest restaurant in the list.
--     Rate 4.8 — joint highest in top 5.
--     2,679 votes — proven by nearly 3,000 reviewers.
--     value_index = 4.80 — the highest in the entire output
--     and 16.4× better than Premium tier's value_score
--     of 0.293 from Q9.
--     A cup of filter coffee and idli that outperforms
--     Premium fine dining on every measurable metric
--     except ambience. The definition of a hidden gem.
--
-- F3. Basavanagudi is Bengaluru's hidden gem capital.
--     3 of the top 6 gems are in Basavanagudi:
--       Vidyarthi Bhavan (#1), MTR (#4), Brahmin's Coffee (#5)
--     All three are iconic South Indian breakfast institutions
--     — some over 50-80 years old. They have never needed
--     marketing, never needed delivery, never needed table
--     booking. They survive entirely on generational loyalty
--     and product consistency.
--     Q5 also identified Basavanagudi as a top value location.
--     These two findings together confirm: Basavanagudi is
--     Bengaluru's best-kept culinary secret.
--
-- F4. South Indian Quick Bites dominate the top 6.
--     Positions 1, 2, 4, 5, 6 — all South Indian Quick Bites.
--     This completely reframes Q8 Part A's finding that
--     South Indian rates only 3.59 platform-wide.
--     The average is dragged down by thousands of mediocre
--     operators. At the top — where South Indian food is
--     done with craft and consistency — it competes with
--     any cuisine in the world.
--     The cuisine isn't weak. The average operator is weak.
--
-- F5. Zero table bookings across all 15 hidden gems.
--     book_table = 0 for every single restaurant in the list.
--     Not one accepts reservations.
--     Compare: Q9 showed Premium tier has 61.9% book_table.
--     Hidden gems are walk-in only, queue-and-wait
--     institutions. They have no need for reservation
--     management because demand consistently exceeds
--     capacity — the truest signal of genuine popularity.
--     A packed restaurant that needs no reservation system
--     is more proven than an empty premium dining room
--     with an online booking form.
--
-- F6. Dessert Parlors claim 6 of 15 positions.
--     Corner House (#7), Milano (#8), Art of Delight (#9),
--     Berry'd Alive (#10), BelgYum (#13), Belgian Waffle (#15)
--     — all Budget, all Dessert Parlors, all 4.3+ rated.
--     Dessert Parlors are Bengaluru's most reliably excellent
--     Budget format. High product consistency (ice cream
--     quality is hard to vary), low complexity operations,
--     and highly positive emotional associations with the
--     product drive persistent above-average ratings.
--
-- F7. MTR appears in two completely different locations.
--     Basavanagudi (#4, ₹250, rate 4.5, 2,896 votes)
--     Indiranagar  (#11, ₹300, rate 4.3, 1,878 votes)
--     Same brand, consistent quality across branches.
--     Basavanagudi edges out Indiranagar on both rating
--     and votes — the original location outperforms
--     the expansion, though both qualify as proven gems.
--
-- F8. All 15 gems are in proof_bucket = 1.
--     Every restaurant shown has enough votes to be
--     in the top third of ALL qualifying hidden gems
--     by vote volume. These are not marginal cases —
--     they are the most battle-tested, most-reviewed
--     Budget restaurants in Bengaluru. The 100-vote
--     floor was intentionally conservative — these
--     restaurants average 2,500+ votes each.
--
-- F9. Value indexes utterly destroy the Premium tier.
--     Q9 Premium value_score : 0.293
--     Brahmin's Coffee Bar   : 4.80  - 16.4× better
--     CTR                    : 3.20  - 10.9× better
--     Veena Stores           : 3.00  - 10.2× better
--     Vidyarthi Bhavan       : 2.93  -  10.0× better
--     Even the lowest value_index in this list (1.08 for
--     Kota Kachori and Berry'd Alive) is 3.7× better
--     than Premium. Every hidden gem provides more quality
--     per rupee than the most expensive tier on the platform.
--
-- F10. Only one Very Good gem in the top 15 — Maiyas.
--      rate = 4.0 exactly — the minimum threshold.
--      beats_pct_of_platform = 70.2% — noticeably lower
--      than every other gem on the list.
--      At ₹200 with North Indian cuisine, Maiyas is
--      the only non-South-Indian, non-Dessert restaurant
--      in the top 15. It makes the list on votes (1,785)
--      and consistency, not on exceptional ratings.
--      A good neighbourhood restaurant — not iconic.
--
-- F11. Online ordering splits the gems into two cultures.
--      7 of 15 gems accept online ordering (1):
--        CTR, Kota Kachori, Veena Stores, Corner House,
--        Berry'd Alive, BelgYum, Belgian Waffle, Maiyas
--      8 of 15 are dine-in only (0):
--        Vidyarthi Bhavan, MTR (both), Brahmin's Coffee,
--        Milano, Art of Delight, Hari Super Sandwich
--      The most iconic institutions — Brahmin's Coffee (4.80),
--      Vidyarthi Bhavan, MTR — do NOT deliver.
--      The dine-in experience is the product.
--      You cannot replicate filter coffee and hot idli
--      in a delivery box.

-- =====================================================
-- PART B — How rare are hidden gems in the Budget tier?
--
SELECT
	COUNT(*) AS TOTAL_BUDGET_RESTAURANTS,
	-- All rated Budget restaurants
	COUNT(
		CASE
			WHEN RATE IS NOT NULL THEN 1
		END
	) AS RATED_BUDGET,
	-- Gems: rated ≥ 4.0 (regardless of vote count)
	COUNT(
		CASE
			WHEN RATE >= 4.0 THEN 1
		END
	) AS RATED_4_PLUS,
	ROUND(
		COUNT(
			CASE
				WHEN RATE >= 4.0 THEN 1
			END
		) * 100.0 / NULLIF(
			COUNT(
				CASE
					WHEN RATE IS NOT NULL THEN 1
				END
			),
			0
		),
		1
	) AS PCT_OF_RATED_BUDGET,
	-- Proven gems: rated ≥ 4.0 AND votes ≥ 100
	COUNT(
		CASE
			WHEN RATE >= 4.0
			AND VOTES >= 100 THEN 1
		END
	) AS PROVEN_GEMS,
	ROUND(
		COUNT(
			CASE
				WHEN RATE >= 4.0
				AND VOTES >= 100 THEN 1
			END
		) * 100.0 / COUNT(*),
		1
	) AS PCT_OF_ALL_BUDGET,
	-- For context: avg cost and avg rating of proven gems
	ROUND(
		AVG(
			CASE
				WHEN RATE >= 4.0
				AND VOTES >= 100 THEN APPROX_COST
			END
		)::NUMERIC,
		0
	) AS GEMS_AVG_COST,
	ROUND(
		AVG(
			CASE
				WHEN RATE >= 4.0
				AND VOTES >= 100 THEN RATE
			END
		)::NUMERIC,
		2
	) AS GEMS_AVG_RATING
FROM
	ZOMATO_RESTAURANTS
WHERE
	PRICE_CATEGORY = 'Budget';
--
-- KEY FINDINGS:
--
-- F1. Hidden gems are rare but not vanishingly so.
--     2,000 proven gems out of 26,699 Budget restaurants
--     = 7.5% of all Budget listings.
--     1 in 13 Budget restaurants is a proven hidden gem.
--     This is rare enough to make finding them valuable —
--     but abundant enough that a "Budget gems" feature
--     on Zomato would have meaningful supply to surface.
--     Compare: if gems were only 0.5%, the feature would
--     be too thin. At 7.5% it is commercially viable.
--
-- F2. 28,4% of Budget restaurants have never been reviewed —
--     confirmed from Q2. That means 19,125 Budget restaurants
--     are rated and 7,574 are still invisible.
--     Of the 19,125 rated Budget restaurants:
--     14.9% rate 4.0 or above → nearly 1 in 7.
--     The Budget tier's quality problem is not that good
--     restaurants don't exist — it's that 28.4% of the
--     tier hasn't been discovered yet. The unrated pool
--     likely contains hundreds more hidden gems waiting
--     to be found.
--
-- F3. 849 restaurants are "unproven gems" — rated 4.0+
--     but fewer than 100 votes.
--     rated_4_plus (2,849) − proven_gems (2,000) = 849.
--     These restaurants have earned a good rating but
--     haven't been tested by enough customers to be
--     trusted. They are the platform's highest-potential
--     undiscovered restaurants.
--     If Zomato drove 100+ orders to each of these 849
--     restaurants and their quality held, the proven gem
--     pool would grow by 42.5% instantly.
--     This is Zomato's clearest restaurant development
--     opportunity in the Budget segment.
--
-- F4. Proven gems avg cost is ₹306 — only ₹22 above
--     the Budget tier average of ₹284 from Q9.
--     Hidden gems are not clustered at the top of the
--     Budget range (₹350–₹400). They exist throughout
--     the tier — including at ₹100 (Brahmin's Coffee)
--     and ₹150 (Vidyarthi Bhavan, CTR, Veena Stores).
--     Price within the Budget tier is not a predictor
--     of gem status. Quality is distributed across
--     all Budget price points.
--
-- F5. Proven gems avg rating is 4.17 — well above the
--     minimum threshold of 4.0.
--     The 2,000 proven gems don't cluster just above 4.0.
--     Their average of 4.17 shows the pool contains
--     restaurants rated 4.1, 4.2, 4.5, 4.8, 4.9 —
--     a genuine quality distribution, not a marginal group.
--     Compare: Premium tier avg_rating from Q9 = 4.04.
--     Bengaluru's proven Budget gems average HIGHER than
--     the entire Premium tier (4.17 vs 4.04).
--     The 2,000 best Budget restaurants outrate all 7,810
--     Premium restaurants on average.
--
-- F6. The funnel tells the complete story:
--     26,699  Budget restaurants total          (100%)
--     19,125  have been rated at all            (71.6%)
--      7,574  never reviewed — invisible        (28.4%)
--      2,849  rated 4.0+ — potentially good    (14.9% of rated)
--      2,000  proven gems — trusted quality     ( 7.5% of all)
--        849  unproven gems — potential only    ( 4.5% of rated)
--
--     For every 13 Budget restaurants on Zomato Bengaluru,
--     1 is a proven hidden gem.
--     For every 22 Budget restaurants, 1 is unproven
--     but potentially excellent.
--     Combined: roughly 1 in 9 Budget restaurants is
--     either proven or potentially excellent.
--     The platform's discovery problem is not a supply
--     problem — the gems exist. It's a surfacing problem.
--
-- COMBINED Q10 CONCLUSION:
--   2,000 Budget restaurants in Bengaluru (≤ ₹400 for two)
--   rate 4.0+ with at least 100 verified reviews.
--   Their average rating (4.17) beats the entire Premium tier
--   (4.04). Their best performers (Brahmin's Coffee 4.8,
--   CTR 4.8, Milano Ice Cream 4.9) beat 99%+ of ALL
--   restaurants on the platform regardless of price tier.
--   Bengaluru's most remarkable food experiences are
--   not in its Premium restaurants.
--   They are in its tiffin rooms, ice cream parlours,
--   and coffee bars — discovered only by those who know
--   where to look.


-- =======================================
-- SECTION 5: SERVICE AND DIGITAL ADOPTION 
-- =======================================
--
-- Q11. Online ordering vs dine-in only — avg rating, avg cost,count side-by-side comparison.
-- 
-- PART A — Core performance comparison
-- 
SELECT
	CASE
		WHEN ONLINE_ORDER = 1 THEN 'Online Ordering'
		ELSE 'Dine-in Only'
	END AS SERVICE_TYPE,
	COUNT(*) AS TOTAL_RESTAURANTS,
	-- Each group's share of the full platform
	-- SUM() OVER () — no partition = window spans all rows
	ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS PCT_OF_PLATFORM,
	-- Rating: avg and median side by side
	-- AVG automatically ignores NULLs (unrated restaurants)
	ROUND(AVG(RATE)::NUMERIC, 2) AS AVG_RATING,
	-- PERCENTILE_CONT: median rating — robust to outliers
	-- Compares against avg_rating to reveal distribution shape
	ROUND(
		PERCENTILE_CONT(0.5) WITHIN GROUP (
			ORDER BY
				RATE
		)::NUMERIC,
		2
	) AS MEDIAN_RATING,
	-- Signed gap vs platform mean
	ROUND(
		(
			AVG(RATE) - (
				SELECT
					AVG(RATE)
				FROM
					ZOMATO_RESTAURANTS
				WHERE
					RATE IS NOT NULL
			)
		)::NUMERIC,
		2
	) AS VS_PLATFORM_AVG,
	-- Cost: avg and median side by side
	-- Large avg-median gap = expensive outliers present
	ROUND(AVG(APPROX_COST)::NUMERIC, 0) AS AVG_COST,
	ROUND(
		PERCENTILE_CONT(0.5) WITHIN GROUP (
			ORDER BY
				APPROX_COST
		)::NUMERIC,
		0
	) AS MEDIAN_COST,
	-- Engagement
	ROUND(AVG(VOTES)::NUMERIC, 0) AS AVG_VOTES,
	-- What % of each group ALSO has table booking
	-- Reveals whether these two services are adopted together
	ROUND(AVG(BOOK_TABLE) * 100.0, 1) AS ALSO_BOOK_TABLE_PCT,
	-- Quality breakdown
	ROUND(
		COUNT(*) FILTER (
			WHERE
				RATING_LABEL IN ('Good', 'Excellent')
		) * 100.0 / NULLIF(
			COUNT(*) FILTER (
				WHERE
					RATE IS NOT NULL
			),
			0
		),
		1
	) AS QUALITY_SCORE_PCT,
	ROUND(
		COUNT(*) FILTER (
			WHERE
				RATING_LABEL = 'Excellent'
		) * 100.0 / COUNT(*),
		1
	) AS EXCELLENT_PCT,
	ROUND(
		COUNT(*) FILTER (
			WHERE
				RATING_LABEL = 'Poor'
		) * 100.0 / COUNT(*),
		1
	) AS POOR_PCT,
	ROUND(
		COUNT(*) FILTER (
			WHERE
				RATE IS NULL
		) * 100.0 / COUNT(*),
		1
	) AS UNRATED_PCT,
	-- Value score: quality per ₹100 spent
	ROUND(
		(AVG(RATE) * 100.0 / AVG(APPROX_COST))::NUMERIC,
		3
	) AS VALUE_SCORE
FROM
	ZOMATO_RESTAURANTS
GROUP BY
	ONLINE_ORDER
ORDER BY
	ONLINE_ORDER DESC;  -- Online Ordering row first
--
-- KEY FINDINGS:
--
-- F1. Online ordering restaurants outrate dine-in on
--     every single quality metric simultaneously.
--     avg_rating   : 3.72 vs 3.67  (+0.05 advantage)
--     quality_score: 75.4% vs 66.7% (+8.7 points)
--     excellent_pct: 19.6% vs 15.2% (+4.4 points)
--     value_score  : 0.711 vs 0.605 (+17.5% better value)
--     This contradicts Q1's finding that top restaurants
--     avoid delivery. The resolution: Q1 looked at the TOP 10.
--     At the full population level (51,042 restaurants),
--     online ordering restaurants as a GROUP outperform
--     dine-in as a GROUP on every quality measure.
--     Individual excellence and group-level quality
--     are completely different dimensions.
--
-- F2. Both groups have identical median cost — ₹400.
--     avg_cost: Online ₹523 vs Dine-in ₹607 — a ₹84 gap.
--     median_cost: BOTH exactly ₹400 — zero gap.
--     This is the most important pair of numbers in Part A.
--     The ₹84 avg_cost gap between groups is ENTIRELY
--     driven by a small number of expensive dine-in
--     restaurants (₹2,000–₹6,000 range) pulling the
--     dine-in average upward.
--     The TYPICAL (median) restaurant in both groups
--     costs exactly ₹400 for two. At the median level
--     these are not different market segments — they are
--     the same price point, same customer, different
--     service strategy.
--
-- F3. Dine-in restaurants cost MORE but rate LOWER.
--     Online Ordering: ₹523 avg cost, 3.72 avg rating
--     Dine-in Only   : ₹607 avg cost, 3.67 avg rating
--     You pay ₹84 more on average at a dine-in restaurant
--     and receive 0.05 fewer rating points in return.
--     Dine-in is simultaneously more expensive AND
--     lower quality at the population level.
--     This is counterintuitive — dine-in experience is
--     assumed to command a premium for better quality.
--     The data says the opposite at scale.
--
-- F4. Online ordering restaurants have lower median rating
--     than average — revealing a left-skewed distribution.
--     Online: avg_rating 3.72, median_rating 3.80
--     Median > avg means a LEFT tail exists — a subset of
--     low-rated online ordering restaurants is pulling the
--     average below the typical restaurant's rating.
--     These are likely budget delivery kitchens with
--     inconsistent quality pulling the avg down, while
--     the majority (median = 3.80) performs well.
--
-- F5. Dine-in distribution is nearly symmetric.
--     Dine-in: avg_rating 3.67, median_rating 3.70
--     avg ≈ median means no strong outlier tail.
--     Dine-in quality is more uniformly distributed —
--     no dramatic high-end cluster pulling up, no
--     large low-quality tail pulling down.
--     The overall dine-in picture is flat mediocrity
--     rather than a bimodal split between excellent
--     and terrible restaurants.
--
-- F6. The unrated gap is the most striking finding.
--     Online Ordering unrated: 10.7%
--     Dine-in Only unrated   : 32.4%  ← 3× higher
--     Nearly 1 in 3 dine-in restaurants has never
--     been reviewed. Online ordering restaurants
--     are almost fully discovered (89.3% rated).
--     Why: every online order generates a Zomato
--     review prompt. Dine-in restaurants that don't
--     use the app have no automatic review trigger.
--     Zomato's review ecosystem is structurally biased
--     toward generating reviews for delivery orders.
--     Dine-in quality is severely underrepresented
--     in the platform's rating data.
--
-- F7. Table booking is NOT exclusive to either service type.
--     Online Ordering also_book_table_pct : 12.2%
--     Dine-in Only also_book_table_pct    : 13.0%
--     Nearly identical adoption rates — a mere 0.8 point gap.
--     This was unexpected. The assumption was that
--     online ordering and table booking would be
--     mutually exclusive choices (delivery vs dine-in).
--     Instead, restaurants adopt them independently.
--     A restaurant can offer both delivery AND reservations
--     (e.g. a casual dining restaurant that delivers lunch
--     and takes reservations for dinner service).
--     This means Q12's dual-service analysis will find
--     a meaningful overlap — not a clean separation.
--
-- F8. Failure rates are nearly identical across service types.
--     poor_pct: Online 4.4% vs Dine-in 4.2% — 0.2 gap.
--     Service type does not protect against poor quality.
--     Going dine-in does not reduce your risk of a
--     poor experience. The failure rate is a restaurant
--     quality problem — not a service model problem.
--
-- F9. Online ordering value score is 17.5% better.
--     Online: 0.711 vs Dine-in: 0.605.
--     This is driven by two factors compounding:
--     Factor 1: Online restaurants rate higher (3.72 vs 3.67)
--     Factor 2: Online restaurants cost less (₹523 vs ₹607)
--     When both numerator rises AND denominator falls,
--     the value ratio improves dramatically.
--     For a cost-conscious customer who wants reliable
--     quality, online ordering restaurants are
--     statistically the better choice.
--
-- F10. Average votes: Online 305 vs Dine-in 254.
--      Online ordering restaurants generate 20% more
--      reviews per restaurant than dine-in only.
--      Confirmed by F6: every delivery order triggers
--      a Zomato review prompt — a structural engagement
--      advantage that dine-in restaurants cannot match.
--      More votes → more credible ratings → better
--      discoverability in Zomato's search algorithm.
--      Online ordering creates a compounding visibility
--      advantage beyond just delivery revenue.
--
-- NOTE — Composition effect not yet resolved:
--      Dine-in's higher avg_cost (₹607) suggests it has
--      more Premium restaurants than online ordering.
--      Premium restaurants rate higher (4.04 from Q9).
--      If dine-in has more Premium restaurants yet still
--      rates lower overall (3.67 vs 3.72), that means
--      the composition effect works AGAINST dine-in —
--      it has more high-priced restaurants that should
--      rate higher, yet still loses to online ordering.
--      Part B will confirm this interpretation.
	
-- =======================================================
-- PART B — Price tier composition within each service type
--
SELECT
	CASE
		WHEN ONLINE_ORDER = 1 THEN 'Online Ordering'
		ELSE 'Dine-in Only'
	END AS SERVICE_TYPE,
	PRICE_CATEGORY,
	COUNT(*)                                             AS restaurant_count,

    -- % of this tier within its service type
    -- PARTITION BY online_order → separate denominator per group
    -- Online Ordering: Budget% + Mid% + Premium% = 100%
    -- Dine-in Only   : Budget% + Mid% + Premium% = 100%
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (PARTITION BY online_order)
    , 1)                                                              AS pct_within_service,

    -- Rating for this specific tier + service combination
    ROUND(AVG(rate)::NUMERIC, 2)                                      AS avg_rating,
    ROUND(AVG(approx_cost)::NUMERIC, 0)                               AS avg_cost,
    ROUND(AVG(votes)::NUMERIC, 0)                                     AS avg_votes

FROM
    zomato_restaurants
GROUP BY
    online_order,
    price_category
ORDER BY
    online_order DESC,
    CASE price_category
        WHEN 'Budget'    THEN 1
        WHEN 'Mid-range' THEN 2
        WHEN 'Premium'   THEN 3
    END;
--
-- Composition Analysis
-- KEY FINDINGS:
--
-- F1. The online ordering quality advantage is REAL —
--     not a composition artefact.
--     Within-tier rating comparison:
--       Budget    : Online 3.61  vs Dine-in 3.51  → +0.10
--       Mid-range : Online 3.72  vs Dine-in 3.57  → +0.15
--       Premium   : Online 4.10  vs Dine-in 4.00  → +0.10
--     Online ordering restaurants outperform dine-in WITHIN
--     EVERY SINGLE PRICE TIER simultaneously.
--     This is the definitive statistical test: if the
--     Part A quality gap was a composition effect, it would
--     disappear when comparing within the same tier.
--     It does not disappear — it persists and is consistent.
--     The quality advantage of online ordering is genuine.
--
-- F2. Dine-in has nearly double the Premium concentration —
--     yet still loses overall.
--     Dine-in Premium share   : 20.8% (4,198 restaurants)
--     Online Premium share    : 11.7% (3,612 restaurants)
--     From Q9, Premium tier avg_rating = 4.04.
--     Dine-in's higher Premium concentration SHOULD push
--     its overall average above online ordering.
--     Instead dine-in loses overall (3.67 vs 3.72).
--     The composition FAVOURS dine-in and online ordering
--     still wins. This makes the online quality advantage
--     even more significant — it overcomes a structural
--     disadvantage in tier composition.
--
-- F3. Mid-range shows the largest within-tier gap: +0.15.
--     Online Mid-range: 3.72 vs Dine-in Mid-range: 3.57.
--     The mid-range segment (₹401–₹800) is where online
--     ordering creates the most quality separation.
--     These are casual dining and delivery-friendly
--     restaurants in the ₹600 avg cost range.
--     Online ordering restaurants in this bracket invest
--     in food consistency because delivery reviews are
--     more systematic and unforgiving than dine-in reviews —
--     a cold or delayed dish gets reviewed immediately.
--     Quality pressure is higher for delivery operators.
--
-- F4. Premium online restaurants cost ₹242 less than
--     Premium dine-in — yet rate 0.10 higher.
--     Online Premium avg_cost  : ₹1,252, avg_rating: 4.10
--     Dine-in Premium avg_cost : ₹1,494, avg_rating: 4.00
--     Among Premium restaurants specifically, choosing
--     one with online ordering saves ₹242 per meal
--     AND gets you a better rated experience.
--     The premium dine-in markup buys ambience and service —
--     not better food quality as measured by Zomato ratings.
--
-- F5. Dine-in Budget restaurants are nearly invisible.
--     avg_votes: Dine-in Budget = 33 vs Online Budget = 88
--     A dine-in Budget restaurant averages only 33 reviews.
--     This is the lowest engagement of any segment in
--     the entire Part B table — 2.7× lower than online
--     Budget and staggeringly below online Mid-range (341).
--     These are local neighbourhood dhabas and small
--     eateries that never appear on anyone's Zomato feed
--     because they generate almost no review activity.
--     Their 3.51 avg_rating is based on very thin evidence.
--
-- F6. Online ordering generates more votes at every tier.
--     Budget    : 88 vs 33   → online gets 2.7× more votes
--     Mid-range : 341 vs 182 → online gets 1.9× more votes
--     Premium   : 1,126 vs 919 → online gets 1.2× more votes
--     The engagement advantage converges at Premium —
--     Premium dine-in restaurants attract engaged, review-
--     writing customers regardless of delivery status.
--     But at Budget and Mid-range, online ordering's
--     automatic review prompt is a structural advantage
--     that dine-in restaurants simply cannot replicate.
--
-- F7. Online ordering has a healthier tier distribution.
--     Online : 50.7% Budget / 37.6% Mid / 11.7% Premium
--     Dine-in: 54.8% Budget / 24.4% Mid / 20.8% Premium
--     Online ordering has a stronger Mid-range presence
--     (37.6% vs 24.4%). Dine-in is more polarised —
--     more Budget restaurants surviving on walk-in traffic
--     AND more Premium restaurants protecting the dine-in
--     experience, with a relatively thin Mid-range middle.
--     Online ordering's healthier tier distribution
--     explains part of its quality and value advantage —
--     the Mid-range engine (3.72 rating, 11,616 restaurants)
--     is far stronger in the online segment.
--
-- F8. Combined conclusion — three-layer quality story:
--     Layer 1 (Part A): Online ordering restaurants rate
--     higher overall (3.72 vs 3.67) with better quality
--     score (75.4% vs 66.7%) and better value (0.711 vs 0.605).
--
--     Layer 2 (Part B composition): Dine-in has more Premium
--     restaurants (20.8% vs 11.7%) which should push its
--     average higher — yet it still loses overall.
--
--     Layer 3 (Part B within-tier): Online outperforms
--     dine-in within Budget (+0.10), Mid-range (+0.15),
--     and Premium (+0.10) simultaneously.
--
--     All three layers point the same direction.
--     Online ordering restaurants are genuinely better
--     on quality metrics — not by accident, not by
--     composition, not by price tier advantage.
--     The quality pressure of systematic, immediate
--     delivery reviews creates measurably better outcomes
--     than the more forgiving dine-in review environment.
	

-- =================================================================================================
-- Q12. Dual-service restaurants (online ordering + table booking both) vs single-service vs neither.
-- 
-- PART A — Four service segments + platform benchmark row
--
WITH
	SEGMENT_STATS AS (
		SELECT
			CASE
				WHEN ONLINE_ORDER = 1
				AND BOOK_TABLE = 1 THEN '1. Both Services'
				WHEN ONLINE_ORDER = 1
				AND BOOK_TABLE = 0 THEN '2. Online Only'
				WHEN ONLINE_ORDER = 0
				AND BOOK_TABLE = 1 THEN '3. Table Only'
				ELSE '4. Neither'
			END AS SERVICE_SEGMENT,
			COUNT(*) AS TOTAL_RESTAURANTS,
			ROUND(AVG(RATE)::NUMERIC, 2) AS AVG_RATING,
			ROUND(
				PERCENTILE_CONT(0.5) WITHIN GROUP (
					ORDER BY
						RATE
				)::NUMERIC,
				2
			) AS MEDIAN_RATING,
			ROUND(AVG(APPROX_COST)::NUMERIC, 0) AS AVG_COST,
			ROUND(AVG(VOTES)::NUMERIC, 0) AS AVG_VOTES,
			ROUND(
				COUNT(*) FILTER (
					WHERE
						RATING_LABEL IN ('Good', 'Excellent')
				) * 100.0 / NULLIF(
					COUNT(*) FILTER (
						WHERE
							RATE IS NOT NULL
					),
					0
				),
				1
			) AS QUALITY_SCORE_PCT,
			ROUND(
				COUNT(*) FILTER (
					WHERE
						RATING_LABEL = 'Excellent'
				) * 100.0 / COUNT(*),
				1
			) AS EXCELLENT_PCT,
			ROUND(
				COUNT(*) FILTER (
					WHERE
						RATING_LABEL = 'Poor'
				) * 100.0 / COUNT(*),
				1
			) AS POOR_PCT,
			ROUND(
				COUNT(*) FILTER (
					WHERE
						RATE IS NULL
				) * 100.0 / COUNT(*),
				1
			) AS UNRATED_PCT,
			ROUND(
				COUNT(*) FILTER (
					WHERE
						PRICE_CATEGORY = 'Premium'
				) * 100.0 / COUNT(*),
				1
			) AS PREMIUM_PCT,
			ROUND(
				(AVG(RATE) * 100.0 / AVG(APPROX_COST))::NUMERIC,
				3
			) AS VALUE_SCORE
		FROM
			ZOMATO_RESTAURANTS
		GROUP BY
			CASE
				WHEN ONLINE_ORDER = 1
				AND BOOK_TABLE = 1 THEN '1. Both Services'
				WHEN ONLINE_ORDER = 1
				AND BOOK_TABLE = 0 THEN '2. Online Only'
				WHEN ONLINE_ORDER = 0
				AND BOOK_TABLE = 1 THEN '3. Table Only'
				ELSE '4. Neither'
			END
	),
	PLATFORM_TOTAL AS (
		SELECT
			SUM(TOTAL_RESTAURANTS) AS GRAND_TOTAL
		FROM
			SEGMENT_STATS
	),
	COMBINED AS (
		-- Segment rows 
		SELECT
			SERVICE_SEGMENT,
			TOTAL_RESTAURANTS,
			ROUND(
				TOTAL_RESTAURANTS * 100.0 / (
					SELECT
						GRAND_TOTAL
					FROM
						PLATFORM_TOTAL
				),
				1
			) AS PCT_OF_PLATFORM,
			AVG_RATING,
			MEDIAN_RATING,
			ROUND(
				(
					AVG_RATING - (
						SELECT
							AVG(RATE)
						FROM
							ZOMATO_RESTAURANTS
						WHERE
							RATE IS NOT NULL
					)
				)::NUMERIC,
				2
			) AS VS_PLATFORM_AVG,
			AVG_COST,
			AVG_VOTES,
			QUALITY_SCORE_PCT,
			EXCELLENT_PCT,
			POOR_PCT,
			UNRATED_PCT,
			PREMIUM_PCT,
			VALUE_SCORE,
			CASE
				WHEN AVG_RATING >= 3.90 THEN 'Strong signal'
				WHEN AVG_RATING >= 3.75 THEN 'Moderate signal'
				WHEN AVG_RATING >= 3.60 THEN 'Weak signal'
				ELSE 'No signal'
			END AS DIGITAL_VERDICT
		FROM
			SEGMENT_STATS
		UNION ALL
		-- Platform benchmark row 
		SELECT
			'— Platform Average',
			COUNT(*),
			100.0,
			ROUND(AVG(RATE)::NUMERIC, 2),
			ROUND(
				PERCENTILE_CONT(0.5) WITHIN GROUP (
					ORDER BY
						RATE
				)::NUMERIC,
				2
			),
			0.00,
			ROUND(AVG(APPROX_COST)::NUMERIC, 0),
			ROUND(AVG(VOTES)::NUMERIC, 0),
			ROUND(
				COUNT(*) FILTER (
					WHERE
						RATING_LABEL IN ('Good', 'Excellent')
				) * 100.0 / NULLIF(
					COUNT(*) FILTER (
						WHERE
							RATE IS NOT NULL
					),
					0
				),
				1
			),
			ROUND(
				COUNT(*) FILTER (
					WHERE
						RATING_LABEL = 'Excellent'
				) * 100.0 / COUNT(*),
				1
			),
			ROUND(
				COUNT(*) FILTER (
					WHERE
						RATING_LABEL = 'Poor'
				) * 100.0 / COUNT(*),
				1
			),
			ROUND(
				COUNT(*) FILTER (
					WHERE
						RATE IS NULL
				) * 100.0 / COUNT(*),
				1
			),
			ROUND(
				COUNT(*) FILTER (
					WHERE
						PRICE_CATEGORY = 'Premium'
				) * 100.0 / COUNT(*),
				1
			),
			ROUND(
				(AVG(RATE) * 100.0 / AVG(APPROX_COST))::NUMERIC,
				3
			),
			'Benchmark'
		FROM
			ZOMATO_RESTAURANTS
	)
	-- ORDER BY is now OUTSIDE the UNION ALL 
	-- Can reference service_segment column name directly
	-- No CASE expression needed in ORDER BY anymore
	-- '1.' '2.' '3.' '4.' prefixes ensure alphabetical sort
	-- puts segments in correct order automatically
	-- '—' sorts AFTER '4.' alphabetically - benchmark last
SELECT
	*
FROM
	COMBINED
ORDER BY
	SERVICE_SEGMENT;
--
-- KEY FINDINGS:
--
-- F1. Table Only outrates Both Services — the most
--     unexpected finding in the entire project.
--     Table Only   : 4.16 avg_rating (+0.46 above platform)
--     Both Services: 4.13 avg_rating (+0.43 above platform)
--     The assumption was that combining online ordering
--     AND table booking would produce the highest quality.
--     Instead, restaurants with ONLY table booking and
--     NO online ordering rate 0.03 points higher.
--     Table booking alone is a stronger quality signal
--     than both services combined.
--
-- F2. Table Only is the most expensive segment by far.
--     avg_cost ₹1,528 — ₹435 more than Both Services (₹1,093)
--     and ₹1,085 more than Online Only (₹443).
--     Table Only restaurants are premium dine-in venues
--     that have deliberately chosen NOT to deliver.
--     They protect the dine-in experience, charge the
--     most, and rate the highest on the platform.
--     This is the ultimate expression of Q1's finding —
--     Toit (₹1,500, no online ordering, no table booking)
--     was an outlier there, but Table Only as a segment
--     confirms the pattern: the best restaurants
--     often refuse to compromise their format for delivery.
--
-- F3. Table Only has the highest quality score: 98.8%.
--     Both Services : 98.1%  — excellent but second
--     Table Only    : 98.8%  — highest of all segments
--     Nearly 99 in 100 Table Only restaurants that have
--     been reviewed are rated Good or Excellent.
--     This is a tighter quality filter than even Both
--     Services, despite Table Only having no delivery
--     review pressure. Premium dine-in venues with
--     reservations self-select for quality through
--     price barrier and physical experience investment.
--
-- F4. Online Only dramatically underperforms platform average.
--     Online Only avg_rating: 3.65 — BELOW platform 3.70.
--     This is the most important reconciliation with Q11.
--     In Q11 Part A, "Online Ordering" (as a group) rated
--     3.72 — above platform average.
--     But Q11's "Online Ordering" group combined
--     Both Services (4.13) + Online Only (3.65).
--     The 3,777 Both Services restaurants (avg 4.13)
--     pulled the combined group above average despite
--     Online Only (27,097 restaurants) being below average.
--     The Q11 "online ordering advantage" was almost
--     entirely driven by the small Both Services segment.
--     Pure online-only restaurants are actually
--     below-average quality performers.
--
-- F5. Neither segment is the platform's quality floor.
--     34.4% of all restaurants — 17,553 listings —
--     have neither online ordering nor table booking.
--     avg_rating 3.56, quality_score 59.5% — the lowest
--     of all four segments on both metrics.
--     These are traditional neighbourhood restaurants,
--     street food stalls, and small local eateries.
--     They serve local demand through walk-in traffic
--     with no platform investment whatsoever.
--     Yet they represent more than a third of Zomato's
--     entire supply — confirming that the platform's
--     base is built on restaurants that barely use it.
--
-- F6. Both Services has the highest avg_votes: 1,172.
--     Both Services : 1,172 avg_votes — highest
--     Table Only    : 1,126 avg_votes — close second
--     Online Only   :   184 avg_votes — far behind
--     Neither       :   124 avg_votes — lowest
--     Restaurants that invest in both services generate
--     the most review activity — delivery reviews +
--     reservation confirmations create two separate
--     Zomato review touchpoints per customer interaction.
--     This vote volume advantage compounds over time —
--     more reviews → more credible ratings → better
--     search ranking → more customers → more reviews.
--
-- F7. median_rating > avg_rating for Both Services
--     reveals a left tail.
--     Both Services: avg 4.13, median 4.10
--     Median slightly below avg means a small cluster
--     of below-average Both Services restaurants
--     is pulling the mean down slightly.
--     Likely: budget restaurants that adopted both
--     services (perhaps delivery kitchens that also
--     accept reservations) diluting the premium segment.
--     Table Only: avg 4.16, median 4.20
--     Here median > avg — the typical Table Only
--     restaurant actually rates HIGHER than the mean,
--     with a small left tail of underperformers.
--     Table Only's median restaurant is better than
--     its average suggests.
--
-- F8. Platform-level insight from the Neither segment size.
--     17,553 restaurants (34.4%) have zero platform investment.
--     These restaurants are listed on Zomato but don't
--     use any of its revenue-generating features.
--     They contribute to supply count metrics but generate
--     no commission revenue for Zomato.
--     Their avg_votes of 124 means they're discoverable
--     but barely engaged with.
--     Converting even 20% of Neither restaurants into
--     Online Only would add ~3,500 delivery operators
--     to the platform — Zomato's largest single growth
--     opportunity in the Bengaluru market.
--
-- F9. The digital adoption gradient is stark.
--     avg_cost by segment:
--       Table Only    : ₹1,528  (most expensive)
--       Both Services : ₹1,093
--       Neither       :   ₹469
--       Online Only   :   ₹443  (cheapest)
--     Digital services split Bengaluru's restaurant
--     market into two completely separate economies:
--     → Table booking = Premium economy (₹1,093–₹1,528)
--     → Online only / Neither = Budget economy (₹443–₹469)
--     Service adoption and price tier are not just
--     correlated — they define entirely different
--     market segments with almost no overlap.
--
-- F10. Summary — digital verdict by segment:
--     Strong signal  - Both Services + Table Only
--                      Together: 6,392 restaurants (12.5%)
--                      avg_rating 4.13–4.16, quality 98%+
--     Weak signal    - Online Only
--                      27,097 restaurants (53.1%)
--                      avg_rating 3.65, below platform avg
--     No signal      - Neither
--                      17,553 restaurants (34.4%)
--                      avg_rating 3.56, quality 59.5%
--
--     FINAL ANSWER TO BUSINESS QUESTION:
--     Full digital adoption (Both Services) produces strong
--     quality signal — but table booking alone produces
--     an even stronger one (4.16 vs 4.13).
--     Online ordering alone produces WEAK signal — below
--     platform average. The quality associated with online
--     ordering in Q11 was entirely driven by the small
--     subset of restaurants that combined it with table
--     booking. The service that truly predicts quality
--     on Zomato Bengaluru is table booking — not
--     online ordering.

-- =================================================
-- PART B — Service adoption breakdown by price tier
SELECT
	PRICE_CATEGORY,
	COUNT(*) AS TOTAL_IN_TIER,
	ROUND(
		COUNT(*) FILTER (
			WHERE
				ONLINE_ORDER = 1
				AND BOOK_TABLE = 1
		) * 100.0 / COUNT(*),
		1
	) AS BOTH_SERVICES_PCT,
	ROUND(
		COUNT(*) FILTER (
			WHERE
				ONLINE_ORDER = 1
				AND BOOK_TABLE = 0
		) * 100.0 / COUNT(*),
		1
	) AS ONLINE_ONLY_PCT,
ROUND(
	COUNT(*) FILTER (
		WHERE
			ONLINE_ORDER = 0
			AND BOOK_TABLE = 1
	) * 100.0 / COUNT(*),
	1
) AS TABLE_ONLY_PCT,
ROUND(
	COUNT(*) FILTER (
		WHERE
			ONLINE_ORDER = 0
			AND BOOK_TABLE = 0
	) * 100.0 / COUNT(*),
	1
) AS NEITHER_PCT,
-- Tier avg rating for context — from Q9 we know:
-- Budget 3.58 / Mid-range 3.69 / Premium 4.04
ROUND(AVG(RATE)::NUMERIC, 2) AS TIER_AVG_RATING
FROM
    zomato_restaurants
GROUP BY
    price_category
ORDER BY
    CASE price_category
        WHEN 'Budget'    THEN 1
        WHEN 'Mid-range' THEN 2
        WHEN 'Premium'   THEN 3
    END;
--
-- KEY FINDINGS:
--
-- F1. Both Services and Table Only are almost entirely
--     Premium-tier phenomena.
--     Calculating Premium concentration:
--       Table Only total (Part A): 2,615 restaurants
--       Premium Table Only: 29.6% × 7,810 = ~2,311 restaurants
--       - 88.4% of ALL Table Only restaurants are Premium.
--       Both Services total (Part A): 3,777 restaurants
--       Premium Both Services: 32.3% × 7,810 = ~2,522 restaurants
--       - 66.8% of ALL Both Services restaurants are Premium.
--     This is the composition explanation for Part A's
--     quality rankings. Table Only rates 4.16 because
--     nearly 9 in 10 Table Only restaurants are Premium.
--     The service signal and the tier signal are almost
--     perfectly confounded — you cannot separate them.
--
-- F2. Table Only's quality advantage IS a composition effect.
--     Unlike Q11 where online ordering beat dine-in
--     WITHIN every price tier (proving a genuine effect),
--     Table Only's advantage is overwhelmingly explained
--     by Premium concentration (88.4%).
--     Premium tier avg_rating = 4.04 from Q9.
--     Table Only avg_rating = 4.16 — above Premium average.
--     Even within Premium, Table Only is the most expensive
--     sub-segment (₹1,528 vs Premium avg ₹1,382) —
--     it represents the TOP of the Premium tier,
--     not Premium on average.
--     Conclusion: Table Only's rating reflects who it serves
--     (very high-end Premium customers) more than what
--     it does (refuse delivery).
--
-- F3. Budget is essentially a two-segment market:
--     Online Only or Neither. Nothing else.
--     Both Services  : 0.2%  (~53 Budget restaurants)
--     Table Only     : 0.1%  (~27 Budget restaurants)
--     Online Only    : 58.4%
--     Neither        : 41.3%
--     0.2% + 0.1% = 0.3% of Budget restaurants
--     use any form of table booking whatsoever.
--     Table booking does not exist in the Budget tier.
--     99.7% of Budget restaurants either deliver,
--     do nothing, or do both without reservations.
--     The entire Budget tier operates outside Zomato's
--     premium service infrastructure completely.
--
-- F4. Mid-range is Bengaluru's online ordering heartland.
--     Online Only: 63.0% — the highest online-only
--     rate of any tier by a significant margin.
--     More than 6 in 10 Mid-range restaurants are
--     pure delivery operators with no table booking.
--     Mid-range (₹401–₹800) is the sweet spot for
--     Zomato's delivery business — affordable enough
--     to order regularly, quality enough to satisfy,
--     and structured enough to need consistent supply.
--     This is where Zomato earns the most commission
--     volume: 16,533 × 63.0% = ~10,416 restaurants
--     generating delivery orders in the mid-price range.
--
-- F5. 1 in 4 Premium restaurants uses neither service.
--     Neither_pct = 24.2% for Premium tier.
--     0.242 × 7,810 = ~1,890 Premium restaurants with
--     no online ordering and no table booking.
--     These are premium dine-in institutions that
--     operate entirely outside Zomato's transaction
--     layer — listed for discovery and reviews but
--     generating zero direct revenue for the platform.
--     Think: old-school fine dining establishments,
--     private members clubs, and legacy premium
--     restaurants that pre-date Zomato's growth.
--     They are Zomato's highest-value unconverted segment:
--     premium customers already on the platform
--     who could be converted to table booking
--     at minimal operational cost.
--
-- F6. Premium adopts table booking at 61.9% combined.
--     Both Services (32.3%) + Table Only (29.6%) = 61.9%
--     This exactly confirms Q9's book_table_pct for
--     Premium of 61.9%. These two segments together
--     ARE the Premium table-booking market.
--     The split between them (32.3% vs 29.6%) shows
--     the Premium tier is nearly evenly divided between
--     restaurants that also deliver and those that don't.
--
-- F7. Online Only collapses at Premium: 14.0%.
--     Budget: 58.4% → Mid-range: 63.0% → Premium: 14.0%
--     Pure delivery (no reservations) is a Budget and
--     Mid-range strategy. Premium restaurants that adopt
--     online ordering almost always pair it with table
--     booking (Both Services: 32.3%) rather than
--     doing delivery alone (Online Only: 14.0%).
--     Premium delivery without reservations is a rare
--     format — it exists (cloud kitchen premium, luxury
--     meal kits) but is not the dominant Premium model.
--
-- F8. Neither segment persists even in Premium: 24.2%.
--     Budget Neither 41.3% → Mid-range 28.0% → Premium 24.2%
--     The decline is real but incomplete. Even at the
--     highest price tier, nearly a quarter of restaurants
--     have chosen zero platform integration.
--     This is not inability — Premium restaurants have
--     resources to implement both services. It is choice.
--     These restaurants have calculated that Zomato's
--     delivery and reservation features add less value
--     than the operational complexity they introduce.
--     For Zomato, these are the hardest restaurants to
--     convert — they are Premium operators who have
--     actively decided the platform's transaction layer
--     is not worth their participation.
--
-- COMBINED Q12 CONCLUSION:
--   Dual-service adoption (Both Services) produces a
--   strong quality signal (4.13 avg, 98.1% quality score)
--   but it is 66.8% driven by Premium tier concentration.
--   Table Only produces the strongest quality signal (4.16)
--   but is 88.4% Premium — almost entirely a composition effect.
--
--   The genuine insight is not about service adoption
--   creating quality — it is about price tier selecting
--   for service behaviour:
--     Budget    → Online Only or Nothing
--     Mid-range → Online Only dominates
--     Premium   → Splits evenly between full-digital
--                 (Both Services), reservation-only
--                 (Table Only), and neither
--
--   Service adoption is a SYMPTOM of premium positioning,
--   not a CAUSE of quality. The causal chain runs:
--   high quality restaurant → can sustain premium price
--   → serves premium customers who expect table booking
--   → adopts table booking → appears in Table Only segment.
--   Not: adopts table booking → becomes high quality.


