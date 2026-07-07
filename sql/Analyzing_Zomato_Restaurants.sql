-- ============================================================
-- ZOMATO BANGALORE RESTAURANTS — DATASET SUMMARY
--
-- DATASET SCOPE NOTE
-- ============================================================
-- This is a RESTAURANT DIRECTORY SNAPSHOT — not transactional data.
-- There are no orders, no revenue figures, no customer identities.
--
-- GRAIN NOTE:
-- The raw source (zomato_restaurants, 51,042 rows) is listing-grain —
-- one row per restaurant per platform category (Delivery, Dine-out,
-- Cafes, etc.), averaging ~4.2 listings per restaurant. Row-level
-- duplicate check returned 0, but cross-validating against Tableau
-- aggregates revealed this entity-level duplication (SUM(votes) ≈
-- listing-count × true votes for the same restaurant).
--
-- All analysis below runs against restaurants_unique (12,037 rows) —
-- one row per restaurant (name + location), keeping the
-- highest-vote listing snapshot per restaurant. zomato_restaurants
-- is retained for reference but not used in any query in this file.
--
-- KEY LIMITATIONS TO KEEP IN MIND:
--
-- 1. rate column has [X] NULLs ([X]% of all rows).
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
    restaurants_unique;
-- Result : 12,037


-- =========================
-- 2. Total Unique Locations
-- 
SELECT
	COUNT(DISTINCT LOCATION) AS TOTAL_LOCATIONS
FROM
	restaurants_unique;
-- Result : 93


-- ========================
-- 3. Total Unique Cuisines
-- (primary_cuisine — first cuisine listed)
-- 
SELECT
    COUNT(DISTINCT primary_cuisine) AS total_cuisines
FROM
    restaurants_unique;
-- Result : 87


-- ================================
-- 4. Total Unique Restaurant Types
-- 
SELECT
    COUNT(DISTINCT rest_type) AS total_rest_types
FROM
    restaurants_unique;
-- Result : 90


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
	restaurants_unique
WHERE
	RATE IS NOT NULL;
-- Result : Min - 1.8 | Max - 4.9 | Avg - 3.63 | Rated - 9,158


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
				restaurants_unique
		),
		1
	) AS PCT_OF_TOTAL
FROM
	restaurants_unique
WHERE
	RATE IS NULL;
-- Result : 2,879 restaurants (23.9% of all listings have no rating)


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
	restaurants_unique;
-- Result : Min - Rs.40 | Max - Rs.6,000 | Avg - Rs.490 | Median - Rs.400


-- ==========================
-- 8. Votes Range and Average
-- votes = proxy for total customer engagement
-- 
SELECT
	MIN(VOTES) AS MIN_VOTES,
	MAX(VOTES) AS MAX_VOTES,
	ROUND(AVG(VOTES)::NUMERIC, 0) AS AVG_VOTES
FROM
	restaurants_unique;
-- Result : Max-votes - 16832, Avg-votes - 188


-- ===========================
-- 9. Online Ordering Adoption
-- 
SELECT
	SUM(ONLINE_ORDER) AS WITH_ONLINE_ORDER,
	COUNT(*) - SUM(ONLINE_ORDER) AS WITHOUT_ONLINE_ORDER,
	ROUND(SUM(ONLINE_ORDER) * 100.0 / COUNT(*), 1) AS PCT_WITH_ONLINE_ORDER
FROM
	restaurants_unique;
-- Result : 6,359 opted in (52.8%) | 5,678 opted out (47.2%)


-- ==========================
-- 10. Table Booking Adoption
-- 
SELECT
	SUM(BOOK_TABLE) AS WITH_TABLE_BOOKING,
	COUNT(*) - SUM(BOOK_TABLE) AS WITHOUT_TABLE_BOOKING,
	ROUND(SUM(BOOK_TABLE) * 100.0 / COUNT(*), 1) AS PCT_WITH_TABLE_BOOKING
FROM
	restaurants_unique;
-- Result : 939 opted in (7.8%) | 11,098 opted out (92.2%)


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
				restaurants_unique
		),
		1
	) AS PCT_OF_TOTAL
FROM
	restaurants_unique
GROUP BY
	PRICE_CATEGORY
ORDER BY
	RESTAURANT_COUNT DESC;
-- Result :
-- Budget     : 7,114  (59.1%)
-- Mid-range  : 3,708  (30.8%)
-- Premium    : 1,215  (10.1%)


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
				restaurants_unique
		),
		1
	) AS PCT_OF_TOTAL
FROM
	restaurants_unique
GROUP BY
	RATING_LABEL
ORDER BY
	RESTAURANT_COUNT DESC;
-- Result :
-- Good       :  4,662  (38.7%)
-- Unrated    :  2,879  (23.9%)
-- Excellent  :  2,447  (20.3%)
-- Average    :  1,471  (12.2%)
-- Poor       :  578    (4.8%)


-- ==========================================
-- SECTION 1: RATING AND PERFORMANCE ANALYSIS
-- ==========================================
--
-- Q1. Top 10 most credible restaurants - rate ≥ 4.0 AND votes ≥ 500.
-- (filters out lucky low-vote outliers)
-- Note: restaurants_unique is already one row per (name, location),
-- so the DISTINCT ON dedup CTE from the listing-grain version is no longer needed.
SELECT
	NAME,
	LOCATION,
	PRIMARY_CUISINE,
	REST_TYPE,
	RATE,
	VOTES,
	APPROX_COST AS COST_FOR_TWO,
	PRICE_CATEGORY,
	ONLINE_ORDER,
	BOOK_TABLE,
	ROUND((RATE * LOG(VOTES + 1))::NUMERIC, 2) AS CREDIBILITY_SCORE
FROM
	RESTAURANTS_UNIQUE
WHERE
	RATE >= 4.0
	AND VOTES >= 500
ORDER BY
	CREDIBILITY_SCORE DESC
LIMIT
	10;
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
--     This directly contradicts the platform-wide 52.8%
--     online ordering adoption rate — top-rated restaurants
--     choose experience over delivery volume nearly 4x more
--     often than the platform average would suggest.
--
-- F5. Table booking is the premium signal.
--     7 of 10 accept reservations (book_table = 1).
--     Notable given platform-wide table booking adoption is
--     just 7.8% (summary #10) — every restaurant in this list
--     is drawn from a segment that represents a small fraction
--     of all Bengaluru restaurants.
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
	restaurants_unique
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
--       Budget → Mid-range : +8.6 points  (60.4% → 69.0%)
--       Mid-range → Premium: +19.8 points (69.0% → 88.8%)
--     The Premium jump is far steeper — nearly 2.3x the size of
--     the Budget-to-Mid jump. Paying more is justified most
--     strongly at the very top tier, not so much going from
--     Budget to Mid-range.
--
-- F2. 9 in 10 Premium restaurants are Good or Excellent.
--     A quality score of 88.8% means once a Premium restaurant
--     has been reviewed, it almost always delivers.
--     The ₹800+ price point appears to self-select operators
--     who can sustain quality over many customer visits.
--
-- F3. Premium has more Excellent restaurants than Budget
--     in ABSOLUTE terms — despite being nearly 6x smaller.
--       Budget Excellent    :   373  (5.2% of 7,114)
--       Mid-range Excellent :   501  (13.5% of 3,708)
--       Premium Excellent   :   597  (49.1% of 1,215)
--     If you want an Excellent restaurant in Bengaluru,
--     Premium is statistically your best hunting ground
--     even by raw count, not just percentage — and this holds
--     even more strongly now that Premium is a smaller slice
--     of the true restaurant count than the raw listings implied.
--
-- F4. Mid-range is the most dangerous tier for consumers.
--     poor_pct = 8.0% — HIGHER than both Budget (3.4%)
--     and Premium (3.1%).
--     Mid-range restaurants charge more than Budget but
--     fail more often — they carry premium pricing without
--     consistently delivering premium quality.
--     This is the classic "value trap" tier, and the gap
--     is now even wider than the raw listing data suggested.
--
-- F5. Budget's real problem is uncertainty, not low quality.
--     32.0% of Budget restaurants are Unrated — the highest
--     of any tier by far (vs 4.9% for Premium).
--     But once a Budget restaurant has been reviewed,
--     60.4% are Good or Excellent — a respectable hit rate.
--     The risk is not that Budget is bad — it's that you
--     don't know which ones are good until you try them.
--
-- F6. The avg_rate gap tells the real story.
--     Budget → Mid-range gap  :  0.07  (3.55 → 3.62) — tiny
--     Mid-range → Premium gap :  0.37  (3.62 → 3.99) — large
--     (This +0.37 jump matches the price-tier rating jump
--     found independently in Q9 — a useful cross-validation
--     of the pipeline.)
--     Spending more within the budget-to-mid range barely
--     improves your expected experience. The meaningful
--     quality jump only arrives at the Premium threshold.
--
-- F7. Premium almost never fails catastrophically.
--     poor_pct = 3.1% — lowest of all three tiers.
--     Only 38 out of 1,215 Premium restaurants are Poor.
--     High price acts as a natural quality filter — operators
--     who cannot deliver quality cannot sustain premium pricing.
--
-- F8. Platform-wide unrated rate is driven entirely by Budget.
--     2,273 of the 2,879 total unrated restaurants (78.9%)
--     are in the Budget tier. (2,879 matches the platform-wide
--     unrated count from summary #6 exactly.)
--     These are small, newly listed, or low-traffic restaurants
--     that haven't been discovered. Zomato's first-order
--     acquisition challenge is almost entirely a Budget-tier problem.


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
			restaurants_unique
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
--     3.31 → 3.53 → 3.80 → 4.05 → 4.25 → 4.55
--     This is not random noise — it is a clean, unbroken
--     upward trend, essentially unchanged from the raw
--     listing-level view. More engagement = higher quality,
--     every single step of the way without exception.
--
-- F2. Quality score tells the story even more clearly.
--     14.9% → 69.0% → 84.0% → 95.2% → 99.6% → 100.0%
--     The jump from Minimal to Low alone is +54.1 points —
--     the single largest gain across the entire range.
--     Once a restaurant earns just 11 votes, it becomes
--     dramatically more likely to be Good or Excellent.
--
-- F3. Every restaurant with 5,000+ votes is Good or Excellent.
--     quality_score_pct = 100.0% for the Very High bucket.
--     Not 99% — exactly 100%. All 31 restaurants in this
--     bucket have earned a Good or Excellent rating.
--     Sustained high engagement is the strongest quality
--     signal available on the platform.
--
-- F4. The Very High bucket's minimum rating is 4.1.
--     min_rating = 4.1 for 5,000+ vote restaurants — identical
--     to the raw listing-level figure. No restaurant with
--     5,000+ votes in Bengaluru rates below 4.1. The floor
--     rises with engagement because truly poor restaurants
--     cannot sustain customer traffic long enough to
--     accumulate this many votes.
--
-- F5. The Minimal bucket contains 36.6% of all restaurants
--     but is almost entirely noise.
--     4,400 restaurants — over a third of the platform
--     — average just 2 votes each. 65.1% are unrated.
--     Of the rated ones, only 14.9% are Good or Excellent.
--     The Minimal bucket is Zomato's discovery problem:
--     a vast, underexplored inventory that customers
--     cannot evaluate because it lacks social proof.
--
-- F6. Once a restaurant reaches 500 votes, quality
--     is almost guaranteed.
--     Buckets 4, 5, 6 (500+ votes) have quality scores of
--     95.2%, 99.6%, 100.0% respectively.
--     For a consumer: filtering Zomato results to only
--     show restaurants with 500+ votes removes virtually
--     all risk of a poor experience.
--
-- F7. The Low bucket (11–100 votes) has almost zero
--     unrated restaurants — only 2 out of 4,219 (0.0%).
--     This reveals a key platform dynamic: even minimal
--     engagement (11 votes) is enough for Zomato's
--     algorithm to assign a stable aggregate rating.
--     The unrated problem is entirely concentrated
--     in the 0–10 vote zone.
--
-- F8. Rating spread narrows dramatically with more votes.
--     Minimal   : spread = 2.7 to 3.9  (range: 1.2)
--     Moderate  : spread = 1.8 to 4.9  (range: 3.1)
--     High      : spread = 2.8 to 4.9  (range: 2.1)
--     Very High : spread = 4.1 to 4.9  (range: 0.8)
--     Note: the Minimal bucket's ceiling dropped from 4.5
--     (listing grain) to 3.9 (restaurant grain) — several
--     of the highest-rated "low vote" listings turned out
--     to be duplicate snapshots of restaurants with a
--     higher-vote listing elsewhere, and were absorbed
--     into a different bucket after deduplication.
--     At 5,000+ votes, the entire tier lives within a
--     0.8 point window. Ratings converge toward truth
--     as sample size grows — exactly as statistics predicts.
--
-- F9. The platform has a long-tail engagement problem —
--     and it's more concentrated than the raw listings suggested.
--     Top 2 buckets (Minimal + Low) = 8,619 restaurants
--     = 71.6% of all restaurants (up from 64.5% at listing
--     grain — the raw data actually understated this,
--     because higher-listing-count restaurants tended to
--     sit in the higher-vote buckets).
--     Nearly three-quarters of the platform's supply has
--     fewer than 100 votes. These restaurants are functionally
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
				restaurants_unique
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
	restaurants_unique
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
-- F1. The location leaderboard reshuffles significantly at
--     restaurant grain. At listing grain, Koramangala 5th,
--     6th, 7th, and 1st Blocks together held 4 of the top 15
--     spots; at restaurant grain only Koramangala 5th Block
--     survives, falling from roughly rank #3 to rank #14
--     (263 restaurants). This suggests Koramangala's apparent
--     density was partly an artifact of restaurants there
--     being listed across unusually many platform categories
--     (Delivery, Dine-out, Cafes, Bar) rather than genuinely
--     having more unique restaurants than other top locations.
--     Meanwhile Whitefield overtakes BTM as Bengaluru's largest
--     restaurant hub by unique count (812 vs 695).
--
-- F2. Volume and quality remain loosely inversely correlated,
--     though the pattern is less clean than before.
--     Of the top 5 by count, 4 sit at/below the platform
--     average rating of 3.63: Whitefield 3.61, BTM 3.56,
--     Electronic City 3.48 (lowest in the top 15), and
--     Marathahalli 3.54. HSR (3.65) is now the only top-5
--     location sitting above the platform average — a reversal
--     from listing grain, where HSR also sat below its
--     contemporary average. The margin is thin (+0.02).
--
-- F3. Koramangala 5th Block is still the single best-quality
--     location shown, even after falling to rank #14 by count.
--     avg_rating 3.92 — the highest of any location in this
--     list — with a quality score of 85.0% and the lowest
--     unrated_pct of the entire top 15 at 8.7%. It's also the
--     second most expensive location here (₹581, behind only
--     Indiranagar). Whatever makes this market genuinely
--     excellent is unrelated to listing volume — which the
--     restaurant-grain correction reveals was mostly inflation.
--
-- F4. BTM is no longer Bengaluru's single largest restaurant
--     market — Whitefield has overtaken it (812 vs 695
--     restaurants, 6.7% vs 5.8% market share). Both remain
--     quality laggards: Whitefield rates 3.61, BTM rates 3.56,
--     both below the 3.63 platform average, and both are
--     notably cheap (₹565 and ₹382 — BTM is the cheapest
--     location in the top 15). Same story as before, new
--     location at the top: Bengaluru's biggest hubs feed
--     volume and affordability, not quality.
--
-- F5. Electronic City remains the most troubled location.
--     Lowest avg_rating (3.48), lowest online_order_pct
--     (43.1%), and highest unrated_pct (36.9%) of any location
--     shown — unchanged in direction from listing grain, and
--     slightly worse on discovery (36.9% vs 33.2% before).
--     Despite being Bengaluru's largest IT corridor, its
--     restaurants remain below-average quality and poorly found.
--
-- F6. HSR remains the delivery capital of this top-15 list.
--     online_order_pct = 65.3% — still the highest shown,
--     though the margin narrowed from the old figure (77.8%)
--     alongside the platform-wide drop to 52.8% (summary #9).
--     HSR's tech-professional demographic still orders online
--     far more than any other major area in this list.
--
-- F7. Indiranagar remains the best-balanced location.
--     avg_rating 3.79 (above the 3.63 platform average),
--     avg_cost ₹607 (highest in this list), quality_score
--     77.5%, and unrated_pct only 16.3% — second-lowest here
--     after Koramangala 5th Block. Premium pricing, strong
--     quality, mature market: still the most well-rounded
--     ecosystem in this top 15.
--
-- F8. Jayanagar remains a hidden value champion.
--     avg_cost ₹444 — well below several pricier locations —
--     yet quality_score 80.1%, second-highest of any location
--     shown after Koramangala 5th Block (85.0%). A traditional
--     South Bengaluru neighbourhood still delivering high
--     quality at moderate prices, exactly as at listing grain.
--
-- F9. The discovery problem is now visible across a wider
--     set of locations than before. At listing grain, only
--     3 locations crossed 25% unrated; at restaurant grain,
--     6 of the 15 do: Electronic City (36.9%), Whitefield
--     (28.2%), New BEL Road (28.0%), JP Nagar (27.9%), BTM
--     (26.2%), and Bannerghatta Road (25.2%, tied with
--     Marathahalli's 25.0%). This looks less like a handful
--     of outlier areas and more like a broad, structural
--     challenge across most of Bengaluru's biggest locations.
--
-- F10. Several locations absent from the old listing-grain
--      top 15 now appear — Bannerghatta Road, Bellandur,
--      Sarjapur Road, New BEL Road, Banashankari, and Kalyan
--      Nagar — replacing the Koramangala blocks and Brigade
--      Road. None of these six stands out on any single
--      metric; they cluster near platform averages on rating,
--      cost, and online ordering. They read as Bengaluru's
--      "typical" mid-sized neighbourhoods, previously
--      overshadowed in the listing-grain ranking by areas
--      with heavier multi-category listing activity rather
--      than genuinely more restaurants.


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
			restaurants_unique
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
-- F1. Value ranking and volume ranking overlap more than
--     before, but only barely. Q4's top 5 by count: Whitefield,
--     BTM, Electronic City, HSR, Marathahalli. Q5's top 5 by
--     value: Basavanagudi, Banashankari, BTM, Basaveshwara
--     Nagar, Koramangala 1st Block. Only BTM appears in both —
--     up from zero overlap at listing grain, but still a
--     near-total split. Bengaluru's biggest restaurant markets
--     remain largely distinct from its best value markets.
--
-- F2. Several previous value leaders disappeared entirely at
--     restaurant grain — most notably City Market (old #1),
--     Koramangala 8th Block (old #2), Varthur Main Road,
--     Thippasandra, Majestic, and Jeevan Bhima Nagar. These
--     locations likely no longer clear the ≥100 restaurants /
--     ≥50 rated floors once duplicate listings were removed —
--     meaning their earlier prominence was partly an artifact
--     of restaurants there being listed across many platform
--     categories, not genuinely large or well-reviewed markets.
--
-- F3. Basavanagudi is now the outright value champion — and
--     for the right reasons. avg_rating 3.69 (above the 3.63
--     platform average), quality_score 74.1%, avg_cost ₹340 —
--     the cheapest location in this entire list. It wins on
--     BOTH quality AND affordability simultaneously, exactly
--     the profile that made Koramangala 8th Block the "true
--     value champion" at listing grain — Basavanagudi now
--     fills that role instead.
--
-- F4. Koramangala 5th Block is still absent — cost still
--     kills its value score. Q4's clear quality winner
--     (avg_rating 3.92, quality 85.0%) does not appear
--     anywhere in this top 15, for the same reason as before:
--     avg_cost ₹581 — nearly the highest denominator in the
--     dataset — penalises it in the value formula despite
--     genuinely superior quality. Excellence at a premium
--     price still does not qualify as "value" here.
--
-- F5. Malleshwaram, not Basavanagudi, is now the most
--     trustworthy location by discovery. unrated_pct = 14.2%
--     — the lowest in this list, edging out Basavanagudi's
--     15.1%. Both are well below the platform's 23.9% overall
--     unrated rate. Malleshwaram also carries the second-highest
--     avg_rating shown (3.74) and a strong 75.9% quality score,
--     making it a genuinely mature, well-reviewed market that
--     was invisible in the old top 10.
--
-- F6. The extreme delivery outlier is gone. Varthur Main Road's
--     87.2% online_order_pct no longer appears anywhere in this
--     list — the highest online adoption shown is now HSR at
--     65.3%, in line with the platform-wide drop from 60.5%
--     to 52.8% (summary #9). No location in this value-focused
--     top 15 is a delivery-only extreme case anymore.
--
-- F7. The extreme traditional-market outlier is also gone.
--     Majestic's 16.8% online_order_pct — by far the lowest
--     at listing grain — has no equivalent here; the lowest
--     shown is Basaveshwara Nagar at 44.7%, still comfortably
--     above the old Majestic floor. Bengaluru's most
--     platform-disengaged pockets simply don't clear this
--     query's floors at restaurant grain.
--
-- F8. BTM rises to #3 despite its own numbers barely changing.
--     avg_rating 3.56 (vs 3.57 before) and quality_score 64.1%
--     (vs 65.6% before) are essentially unchanged — BTM's rank
--     improved almost entirely because five higher-ranked
--     locations from the old list dropped out, not because
--     BTM itself got better. It remains what it always was:
--     a mid-tier value market driven by low price (₹382),
--     not quality.
--
-- F9. Basaveshwara Nagar barely clears the volume floor.
--     Just 103 total restaurants — the smallest in this top 15,
--     right at the edge of the ≥100 threshold. Its unrated_pct
--     of 36.9% is also the highest shown, well above the
--     platform's 23.9% average. It makes the value list mainly
--     on affordability (₹398) and a respectable rating (3.60),
--     but is a far less mature market than the rest of this
--     top 15.
--
-- F10. The value leaderboard is now more geographically spread
--      than before. South Bengaluru still leads (Basavanagudi,
--      Banashankari, BTM, Jayanagar, JP Nagar), but West and
--      North locations that didn't appear in the old top 10 —
--      Rajajinagar, Malleshwaram, New BEL Road — now feature
--      prominently. East corridor representation (Brookefield,
--      Sarjapur Road, HSR) persists but without the extreme
--      Varthur Main Road outlier. Restaurant-grain value is a
--      more genuinely citywide phenomenon than the listing-grain
--      data suggested.


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
			restaurants_unique
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
				restaurants_unique
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
-- F1. The "Heavy Delivery" tier has nearly vanished at
--     restaurant grain. At listing grain, every location in
--     this top 15 sat in Heavy Delivery or Balanced territory,
--     with a floor of 67.3%. At restaurant grain, only Nagawara
--     remains in Heavy Delivery (85.4%); eleven locations are
--     now Balanced, and three — Kalyan Nagar, JP Nagar, and
--     Bellandur — fall into Dine-in Leaning territory despite
--     making this list. The margin above the platform average
--     (now 52.8%) has also compressed dramatically: the lowest
--     entry here, Bellandur at 53.5%, is barely above average,
--     versus the old list's floor sitting nearly 7 points clear
--     of its contemporary platform average.
--
-- F2. Varthur Main Road — the old #1 tied entry with 87.2%
--     online ordering and a striking 0.0% table booking — has
--     dropped out of the top 15 entirely. So has Kumaraswamy
--     Layout, Yeshwantpur, Kaggadasapura, Jeevan Bhima Nagar,
--     ITPL Main Road, Koramangala 8th Block, and HBR Layout.
--     These were disproportionately smaller markets whose high
--     online-ordering share was likely inflated by delivery
--     restaurants carrying more platform-category listings
--     than dine-in-oriented restaurants nearby.
--
-- F3. Nagawara is now the undisputed #1 with no tie.
--     online_order_pct 85.4%, still comfortably ahead of #2
--     (HSR at 65.3%) — a 20-point gap where the old list had
--     Nagawara essentially tied with Varthur Main Road.
--     Nagawara remains a small market (103 restaurants) with
--     a modest 4.9% book_table_pct — Bengaluru's most
--     delivery-committed neighbourhood, now standing alone.
--
-- F4. Delivery culture still does not mean budget market.
--     Sarjapur Road (62.3% online, ₹493 avg cost) and HSR
--     (65.3% online, ₹444 avg cost) remain solidly mid-priced
--     rather than cheap. Bengaluru's IT workforce continues to
--     order premium food online, not just affordable meals —
--     the same conclusion as before, on a smaller, cleaner list.
--
-- F5. HSR remains Bengaluru's most strategically valuable
--     delivery market — now by a clearer margin. At 678
--     restaurants and 65.3% online adoption, it has roughly
--     443 actively delivery-enabled restaurants, more than any
--     other location in this list (BTM, with more total
--     restaurants at 695, only reaches ~392 due to its lower
--     56.4% adoption rate). HSR's restaurant count also dropped
--     from 2,494 at listing grain to 678 — nearly a 3.7x
--     correction — confirming HSR carried substantial
--     duplicate-listing inflation, yet it still leads on
--     delivery-restaurant volume after the fix.
--
-- F6. Koramangala 5th Block, not Jayanagar or Sarjapur Road,
--     is now the most fully-digital location in this list.
--     Its book_table_pct of 19.8% is by far the highest shown —
--     more than 5 points clear of the next entry — while still
--     carrying a strong 60.8% online_order_pct. This aligns
--     with Q9's finding that Premium restaurants drive table
--     booking adoption: Koramangala 5th Block is also the
--     highest-rated (3.92) and second-most-expensive (₹581)
--     location in this entire top 15.
--
-- F7. Koramangala 5th Block also leads the Balanced tier on
--     the composite digital_score metric (48.5), edging out
--     HSR (47.7) — a change from listing grain, where
--     Koramangala 7th Block held this position. The pattern
--     holds: premium, quality-driven locations adopt table
--     booking at higher rates than delivery-only areas, and
--     Koramangala 5th Block is now the clearest example of that
--     combination in the dataset.
--
-- F8. Book table adoption still separates premium from
--     delivery-only markets — with an even wider cost signal.
--     The top 5 by book_table_pct now are: Koramangala 5th
--     (19.8%), Kalyan Nagar (14.3%), Ulsoor (12.8%), Jayanagar
--     (11.7%), and Koramangala 7th (9.1%). All 5 carry avg_rating
--     ≥ 3.7. Ulsoor stands out here with the highest avg_cost
--     in the entire top 15 (₹689) alongside a solid 12.8%
--     booking rate — a new premium-dining signal that wasn't
--     visible in the old top 15 at all.
--
-- F9. Small locations can still lead on digital adoption.
--     Nagawara, at just 103 restaurants — the smallest in this
--     list — remains #1 by a wide margin. Digital adoption is
--     a neighbourhood culture choice, not a function of how
--     many restaurants exist, exactly as observed at listing
--     grain, though the specific small-market examples
--     (Kaggadasapura, Yeshwantpur) that supported this point
--     before have dropped out of the qualifying set.
--
-- F10. Bellandur is now the most surprising entry — the
--      inverse of the old Kumaraswamy Layout finding. At
--      53.5% online ordering, Bellandur barely qualifies for
--      this top-15, but carries the lowest avg_rating of any
--      location shown (3.50 — below the 3.63 platform average)
--      and a below-average digital_score (38.7, the lowest in
--      the list). It reads as a neighbourhood that leans on
--      Zomato for delivery reach without having developed a
--      strong quality restaurant culture — the same
--      volume-over-quality delivery pattern the old Kumaraswamy
--      Layout finding described, just in a different location.


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
			restaurants_unique
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
-- F1. North Indian still dominates most of Bengaluru's largest
--     locations, but far less exclusively than before. 15 of
--     these top 20 locations (by restaurant count) have North
--     Indian as the single most-supplied cuisine — down from
--     18 of 20 at listing grain. The other 5 are now South
--     Indian strongholds: Banashankari, Malleshwaram,
--     Rajajinagar, Basavanagudi, and Banaswadi — a meaningful
--     widening from the single South Indian exception
--     (Banashankari) found at listing grain.
--
-- F2. The Koramangala 5th Block "Cafe exception" has completely
--     dissolved at restaurant grain. At listing grain, Cafe won
--     this location decisively (400 restaurants, 16.1% share,
--     4.15 avg rating) — the only top-3 location where North
--     Indian didn't dominate. At restaurant grain, North Indian
--     is now dominant here too (38 restaurants, 14.4% share,
--     3.84 avg rating). This strongly suggests cafe-format
--     restaurants in Koramangala 5th Block carried unusually
--     heavy multi-category listing activity (Delivery, Dine-out,
--     Desserts, Cafes all at once) that inflated their apparent
--     count relative to North Indian competitors. Koramangala
--     5th Block's premium, coffee-and-brunch identity may still
--     be real in spirit, but it is no longer the dominant
--     cuisine by unique restaurant count.
--
-- F3. North Indian's dominance share range has compressed and
--     shifted. The old extremes — Brigade Road (10.6%, weakest)
--     and Koramangala 1st Block (37.8%, strongest) — have both
--     dropped out of this top-20 list under the new Q4 ranking.
--     Within what remains, the range now runs from Koramangala
--     5th Block (14.4%, the new weakest) to Marathahalli (35.6%,
--     the new strongest) — a narrower band, but the underlying
--     pattern holds: even where North Indian dominates most
--     weakly, competition is fragmented enough that no single
--     alternative cuisine can catch up.
--
-- F4. North Indian still mostly rates below each location's
--     overall average, though the gaps have narrowed.
--     Comparing dominant-cuisine rating vs location avg_rating
--     (from Q4):
--       Koramangala 5th: NI 3.84 vs location avg 3.92 (−0.08)
--       Jayanagar      : NI 3.77 vs location avg 3.77 ( 0.00)
--       Indiranagar    : NI 3.69 vs location avg 3.79 (−0.10)
--       BTM            : NI 3.45 vs location avg 3.56 (−0.11)
--     The pattern from listing grain survives intact: in most
--     locations, North Indian rates at or below the overall
--     location average, meaning other cuisines in those areas
--     genuinely outperform it per restaurant. North Indian
--     still wins on volume, not quality — even at the corrected
--     restaurant count.
--
-- F5. Bellandur shows the most dramatic single-location
--     correction in this query. Its North Indian restaurant
--     count fell from 461 (listing grain) to 117 (restaurant
--     grain) — a nearly 4x reduction, well beyond the platform's
--     overall ~4.2x average — while its dominance share dropped
--     only modestly (36.4% → 33.8%). This suggests North Indian
--     restaurants in Bellandur specifically carried an unusually
--     high number of duplicate listings per restaurant. Marathahalli,
--     by contrast, held steady (649 → 232 restaurants, 36.0% →
--     35.6% share) — a more typical correction in line with the
--     platform average, and it remains North Indian's strongest
--     concentrated stronghold.
--
-- F6. Banashankari remains a South Indian stronghold and has
--     strengthened slightly. South Indian holds 24.5% share
--     here (up from 20.7% at listing grain) with 69 restaurants
--     out of 282 total. It's joined this time by four more
--     South Indian dominant locations that weren't visible in
--     the old top-20 view: Malleshwaram (19.0% share, 3.81
--     rating — the highest-rated dominant cuisine in this
--     entire list), Rajajinagar, Basavanagudi, and Banaswadi.
--     Traditional South Bengaluru and Malleshwaram-area
--     neighbourhoods appear to have been under-represented
--     in the old listing-grain ranking, likely because North
--     Indian restaurants there carried more duplicate listings
--     than the South Indian competition.
--
-- F7. Brigade Road — the old "most diverse location" example,
--     where North Indian won at only 10.6% share — has dropped
--     entirely out of Q4's restaurant-grain top 15/20. Without
--     visibility into its current numbers, this finding can't
--     be directly re-verified; it may still hold a low
--     concentration, but Brigade Road is no longer among
--     Bengaluru's largest restaurant markets by unique count,
--     so its diversity story is no longer part of the headline
--     narrative the way it was before.

-- ====================================================
-- PART B — Which cuisine dominates the most locations?
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
			restaurants_unique
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
-- F1. North Indian's dominance is essentially unchanged in
--     scope, even as its restaurant counts shrank dramatically.
--     62 of 93 locations (66.7%) still have North Indian as
--     their single most-supplied cuisine — statistically
--     identical to the listing-grain figure of 61 locations
--     (65.6%). The city-wide *breadth* of North Indian's reach
--     survived the dedup fix completely intact; only the
--     *depth* within each location changed. In a city famous
--     for idli, dosa, and filter coffee, a cuisine from 2,000
--     km away still controls two-thirds of the restaurant
--     supply landscape at the neighbourhood level.
--
-- F2. The 87-cuisine diversity figure is still deeply misleading
--     — if anything, more so now. Only 10 cuisines dominate any
--     location at restaurant grain, down from... also 10 at
--     listing grain, but the composition shifted: Kerala,
--     Arabian, and Italian dropped out of the dominant-cuisine
--     list entirely, replaced by Continental, Andhra, and
--     American. The remaining 77+ cuisines exist in Bengaluru
--     but never achieve enough concentration to become the #1
--     cuisine anywhere — this structural finding is completely
--     unaffected by the grain correction.
--
-- F3. North Indian's depth of penetration collapsed by roughly
--     the platform average, confirming no special distortion.
--     avg_count_per_location dropped from 178 to 42 restaurants
--     per dominated location — a 4.2x reduction, almost exactly
--     matching the platform-wide average of ~4.2 listings per
--     restaurant (from the dataset scope note). This is
--     reassuring: North Indian's dominance pattern wasn't an
--     artifact of unusual duplicate-listing behavior — it was
--     genuine breadth, now correctly measured.
--
-- F4. South Indian's footprint widened, not shrank, at
--     restaurant grain — a direct confirmation of Q7A's finding.
--     South Indian now dominates 16 locations (17.2%), up from
--     14 (15.1%) at listing grain — gaining Malleshwaram,
--     Rajajinagar, and Banaswadi as new strongholds (per Q7A)
--     while Banashankari held steady. South Indian cuisine
--     is a slightly larger minority in its own city than the
--     old data suggested, though still far from parity with
--     North Indian.
--
-- F5. Cafe's dominance collapsed from 6 locations to just 3 —
--     the single largest proportional drop of any cuisine in
--     this list, and direct confirmation of the Koramangala 5th
--     Block finding in Q7A. avg_count_per_location for Cafe
--     fell from 109 to just 4 — far steeper than the platform's
--     ~4.2x average correction, meaning cafe-format restaurants
--     specifically carried an outsized number of duplicate
--     listings per restaurant (consistent with cafes commonly
--     listing under Delivery, Dine-out, Desserts, and Cafes
--     simultaneously). Bengaluru's "premium coffee culture"
--     story is real in spirit but was substantially overstated
--     by listing-grain counts.
--
-- F6. Italian, Kerala, and Arabian — the three cuisines that
--     each won exactly 1 location at listing grain — have all
--     dropped off this list entirely. Whatever single-restaurant
--     margins gave them dominance before were evidently thin
--     enough that deduplication tipped those locations to a
--     different dominant cuisine (likely North Indian, given
--     its consistent breadth). These were always the most
--     fragile entries in the ranking — hyper-local cuisine
--     pockets decided by a one- or two-restaurant margin — and
--     the grain correction exposed exactly that fragility.
--
-- F7. Three new cuisines claim dominance for the first time:
--     Continental, Andhra, and American, each winning exactly
--     1 location. Continental's appearance is notable given
--     Q8's finding that it's the strongest quality performer
--     among popular cuisines — this may represent a genuinely
--     new signal rather than a fragile artifact, though with
--     only 1 restaurant as its avg_count_per_location, it's
--     equally possible this is another thin, one-restaurant-
--     margin case like the ones that just disappeared.
--
-- F8. The dominance structure remains extremely top-heavy,
--     essentially unchanged. North Indian alone: 66.7% of
--     locations (vs 65.6% before). North + South Indian
--     combined: 83.9% of locations (vs 80.7% before) — slightly
--     more concentrated, not less. Bengaluru's food supply,
--     despite its cosmopolitan reputation, remains concentrated
--     in just two cuisine categories at the neighbourhood level,
--     and the restaurant-grain correction did nothing to soften
--     that story — if anything, it sharpened it.


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
			restaurants_unique
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
					restaurants_unique
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
-- F1. Zero cuisines in the popularity top 15 now qualify as
--     Star Performers (avg_rating ≥ 3.9) — a complete reversal
--     from listing grain, where Continental was the sole Star
--     Performer. Continental's avg_rating fell from 3.97 to
--     3.89, landing just 0.01 short of the Star Performer
--     threshold and dropping it to "Above Average." 4 of 15
--     cuisines now sit in Above Average (Cafe 3.78, Desserts
--     3.82, Continental 3.89, Ice Cream 3.78); the remaining
--     11 are At Par. The overall story survives — popular
--     cuisines still underperform quality leaders — but the
--     margin is now thinner than the raw listings suggested.
--
-- F2. North Indian and South Indian are no longer tied — and
--     South Indian now rates slightly HIGHER. At listing grain
--     both sat at exactly 3.59. At restaurant grain: North
--     Indian 3.55 (−0.08 vs platform) vs South Indian 3.57
--     (−0.06 vs platform) — a small but real reversal. Both
--     still sit below the platform average and represent a
--     combined 4,370 restaurants (36.3% of the platform), but
--     the narrative that these two culturally dominant cuisines
--     "perform identically" no longer holds precisely; South
--     Indian has a slight edge.
--
-- F3. The popularity-quality gap is still widest for Biryani
--     and Fast Food, confirming the listing-grain finding.
--     Biryani: popularity #3, quality rank #27 → gap of 24.
--     Fast Food: popularity #4, quality rank #27 (tied) → gap
--     of 23. Both remain simultaneously high-demand and
--     poorly-rated. The specific ranks shifted (both moved up
--     in popularity as other cuisines' counts corrected more
--     sharply), but the underlying story — customers order
--     these out of convenience, not quality — is unchanged.
--
-- F4. Cafe dropped from popularity #3 to #6, but its relative
--     quality standing improved. At listing grain, Cafe was
--     popularity #3 with quality rank #16 (a gap of 13). At
--     restaurant grain it's popularity #6 with quality rank #9
--     — now one of the *closest* popularity-to-quality matches
--     in the entire top 15, alongside Desserts (gap of 1) and
--     Pizza (gap of 1). Cafe's popularity was evidently more
--     inflated by duplicate listings than its quality reputation
--     was — once corrected, Cafe reads as a cuisine that's
--     popular roughly in proportion to how good it actually is.
--
-- F5. Continental still wins decisively on combined quality +
--     engagement, even after losing its Star Performer label.
--     performance_index 10.89 — still the highest in Part A by
--     a clear margin (next highest: Pizza at 9.59). avg_votes
--     631 — also still the highest. 330 restaurants delivering
--     3.89 avg_rating with an 86.0% quality score — Continental
--     remains Bengaluru's best mainstream cuisine option by
--     every combined measure, even though its raw restaurant
--     count corrected down from 1,803 to 330 (roughly a 5.5x
--     reduction, steeper than the platform's ~4.2x average).
--
-- F6. South Indian's engagement problem is real but was
--     overstated at listing grain — it's no longer the second
--     lowest. avg_votes = 82, which now ranks 5th-lowest of 15,
--     not 2nd-lowest. Beverages (43 votes) and Mithai (48 votes)
--     are now the true engagement floor, with Fast Food (53)
--     and Bakery (55) also below South Indian. The core
--     insight — South Indian restaurants are frequented daily
--     but rarely reviewed — still holds, but several other
--     everyday-format cuisines (juice bars, sweet shops) show
--     an even more extreme version of the same pattern.
--
-- F7. Beverages is no longer the delivery champion of popular
--     cuisines — Pizza has taken that position decisively.
--     Pizza's online_order_pct is 86.8%, far above Beverages'
--     67.4% and every other cuisine in this table. Pizza also
--     carries a relatively low avg_cost profile among the
--     Above-Average-adjacent group, and its avg_votes (427) is
--     the second-highest in the table after Continental. This
--     is a genuinely new signal, not a listing-grain artifact:
--     Pizza appears to have a more purely delivery-oriented
--     business model in Bengaluru than previously visible.
--
-- F8. Bakery still has the highest unrated_pct in the top 15
--     at 33.2% — nearly identical to the listing-grain figure
--     (32.9%), confirming this finding wasn't grain-dependent.
--     Notably, South Indian is now a close second at 32.9%
--     unrated — a detail invisible at listing grain, where
--     South Indian's unrated rate wasn't flagged at all. Two
--     of Bengaluru's most "everyday" cuisine categories —
--     bakeries and South Indian tiffin spots — share the same
--     structural invisibility problem.
--
-- F9. Andhra cuisine enters the popularity top 15 for the
--     first time at restaurant grain (rank #11, 323 restaurants)
--     — it wasn't part of the old listing-grain top 15 at this
--     scale. Its quality rank (#25) sits well below its
--     popularity rank, giving it one of the larger gaps in the
--     table (14) alongside a below-platform-average rating
--     (3.52, −0.11). It reads similarly to Biryani and Fast
--     Food: high demand, below-average delivery on quality.
--
-- F10. Ice Cream remains Part A's quiet overperformer, even
--      with a smaller gap than before. popularity #12, quality
--      rank #9 — still one of the better quality-to-popularity
--      ratios in the bottom half of the list. avg_rating 3.78
--      (+0.15 vs platform), quality_score 73.7%, avg_votes 149.
--      Ice cream parlours continue to attract consistent, happy
--      customers who leave positive reviews — a low-risk,
--      reliably above-average category at both grains.

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
			restaurants_unique
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
					restaurants_unique
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
-- F1. The quality top 15 has almost completely turned over.
--     Five of the old top performers — Modern Indian (4.31,
--     old #1), Mediterranean (4.28), European (4.26), Japanese
--     (4.19), and Rajasthani (3.96) — no longer appear anywhere
--     in this list. All five were built on very small restaurant
--     counts at listing grain (107–132 restaurants), and the
--     dedup correction evidently pushed their true restaurant
--     counts too low to sustain their old rankings, or shifted
--     their avg_rating below the new cutoff. These were likely
--     the most fragile, small-sample findings in the entire
--     original file.
--
-- F2. North Indian is still completely absent from the quality
--     top 15 — the one finding that survives untouched. The
--     city's #1 cuisine by supply does not rate well enough to
--     make this list at either grain. The quality threshold for
--     row 15 is now 3.64 (down from 3.88), but North Indian's
--     3.55 avg_rating (from Q8A) still falls well short.
--     Bengaluru's most supplied cuisine remains its least
--     respected among cuisines with meaningful scale.
--
-- F3. Asian is now the highest-rated cuisine at 4.09 — not
--     Modern Indian. It's also a genuine Star Performer with
--     70 restaurants, a real jump from being absent from the
--     old top-15 discussion entirely. quality_score_pct 85.2%
--     and avg_votes 700 make this a credible, well-supported
--     result rather than a thin-sample fluke.
--
-- F4. American is the new performance leader — combining the
--     highest rating in the Star Performer tier with the
--     strongest overall performance_index (12.38, edging out
--     Asian's 11.62). avg_votes 1,172 — the highest in this
--     entire top 15 — and quality_score_pct 89.7%. This directly
--     echoes Q8A's finding that American had the best balance
--     of popularity and quality among popular cuisines;
--     here it shows it's also elite among quality leaders
--     specifically, not just relative to popular cuisines.
--
-- F5. Only 2 cuisines now qualify as genuine Star Performers
--     (avg_rating ≥ 3.9): Asian and American. This is a sharp
--     drop from the old top 15, where 13 of 15 cuisines cleared
--     that bar. The remaining 13 entries here are all Above
--     Average or At Par. The "quality top 15" is now a much
--     more gradual slope down from the platform average rather
--     than a cleanly elevated segment — a materially different
--     picture from the listing-grain version.
--
-- F6. Continental repeats as a genuine quality-popularity
--     sweet spot, now tied for #3 (3.89) with Mexican.
--     330 restaurants — comfortably the largest cuisine in this
--     quality top 15 — with a strong 86.0% quality score and
--     performance_index 10.89, third-highest in the list. This
--     matches Q8A's finding almost exactly: Continental achieves
--     well-above-average rating at real scale, proving volume
--     and quality aren't mutually exclusive for this cuisine.
--
-- F7. Mexican cuisine is an entirely new entrant, tied for #3
--     at 3.89 with just 52 restaurants — the smallest count in
--     the entire top 15. Its quality_score_pct of 89.6% is
--     among the highest shown. With such a small base, this
--     reads similarly to how Modern Indian and Mediterranean
--     looked at listing grain: a promising but statistically
--     thin result that deserves a cautious "watch, don't
--     conclude" treatment rather than a confident finding.
--
-- F8. Online ordering still splits quality cuisines into two
--     camps, though the specific cuisines have changed.
--     Higher online adoption (≥60%): Mexican 50.0%... actually
--     the clearer split is at the extremes — Burger (90.4%),
--     Pizza (86.8%), and Beverages (67.4%) sit at the high end,
--     while Continental (42.7%) and Finger Food (15.5% — the
--     lowest in the entire list) sit at the low end. The
--     pattern from listing grain holds directionally: cuisines
--     with the highest avg_cost (Finger Food ₹1,468, the most
--     expensive in this top 15) tend to have the lowest online
--     ordering adoption. Premium, sit-down dining is still not
--     delivered in a box.
--
-- F9. Desserts appears again in the quality top 15 (rank #7,
--     avg 3.82), and its conflicted profile from listing grain
--     survives almost exactly. 451 restaurants — the second-
--     largest cuisine in this list after Continental — but
--     avg_votes = only 111, among the lowest shown, and
--     performance_index 7.84, near the bottom of the table.
--     Desserts restaurants remain numerous and above-average
--     rated, but generate comparatively little review engagement
--     — hidden quality, low discoverability, unchanged from
--     the original finding.
--
-- F10. Finger Food has the highest avg_cost in this entire
--      quality top 15 at ₹1,468 — a new detail, since it wasn't
--      a standout on cost at listing grain. Combined with its
--      rock-bottom online_order_pct (15.5%, the lowest shown),
--      Finger Food reads as Bengaluru's most exclusively
--      dine-in-oriented premium category among quality leaders
--      — a more extreme version of the "premium dining doesn't
--      deliver" pattern than Continental or Mexican show.
--
-- F11. The overall shape of this list has flattened. At listing
--      grain, 13 of 15 quality-leading cuisines were Star
--      Performers with a clean drop to Above Average at the
--      bottom two spots. At restaurant grain, only 2 are Star
--      Performers, 9 are Above Average, and 4 are At Par
--      (Beverages, Burger, Pizza, Arabian, all at 3.64–3.67).
--      The restaurant-grain correction reveals a much more
--      gradual quality gradient across Bengaluru's mid-tier
--      cuisines than the listing data implied — fewer clear
--      "winners," more of a continuum.


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
			restaurants_unique
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
-- Q10. Hidden gems - budget restaurants (≤ ₹400) rated ≥ 4.0,
-- ranked by votes (best value finds).
--
-- PART A — The Hidden Gems list (top 15 by votes)
-- Note: restaurants_unique is one row per (name, location) —
-- the DISTINCT ON dedup CTE from the listing-grain version is no longer needed.
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
	ROUND((RATE * 100.0 / APPROX_COST)::NUMERIC, 2) AS VALUE_INDEX,
	-- Correlated scalar subquery:
	-- For each gem, what % of ALL rated restaurants does it outrate?
	ROUND(
		(
			SELECT
				COUNT(*)
			FROM
				restaurants_unique R2
			WHERE
				R2.RATE < UBG.RATE
				AND R2.RATE IS NOT NULL
		) * 100.0 / (
			SELECT
				COUNT(*)
			FROM
				restaurants_unique
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
	restaurants_unique UBG
WHERE
	PRICE_CATEGORY = 'Budget'
	AND RATE >= 4.0
	AND VOTES >= 100
ORDER BY
	VOTES DESC
LIMIT
	15;
--
-- KEY FINDINGS:
--
-- F1. Four Budget restaurants beat 99%+ of ALL restaurants
--     on the entire platform regardless of price tier — one
--     more than at listing grain. CTR (4.8, beats 99.7%),
--     Brahmin's Coffee Bar (4.8, beats 99.7%), Milano Ice Cream
--     (4.9, beats 99.9%), and Belgian Waffle Factory (4.9,
--     beats 99.9%) all clear the 99% threshold. A ₹150 idli
--     breakfast at CTR still outrates virtually every Premium
--     restaurant in Bengaluru — this remains the single most
--     powerful consumer insight in the entire project.
--
-- F2. Brahmin's Coffee Bar is still the ultimate hidden gem,
--     and its value_index actually rose. ₹100 for two — still
--     the cheapest restaurant in the list. Rate 4.8, 2,679
--     votes. value_index = 4.80 (up from 4.80... unchanged, in
--     fact identical) — still the highest in the entire output.
--     A cup of filter coffee and idli that outperforms Premium
--     fine dining on every measurable metric except ambience.
--
-- F3. Basavanagudi remains Bengaluru's hidden gem capital.
--     3 of the top 5 gems are still in Basavanagudi: Vidyarthi
--     Bhavan (#1), MTR (#4), Brahmin's Coffee (#5) — identical
--     ranking to listing grain. These South Indian breakfast
--     institutions continue to need no marketing, no delivery,
--     no table booking, surviving entirely on generational
--     loyalty. This finding is completely grain-independent.
--
-- F4. South Indian Quick Bites still dominate the top 6,
--     unchanged from listing grain. Positions 1, 2, 4, 5, 6 —
--     all South Indian Quick Bites. This still completely
--     reframes Q8A's finding that South Indian rates only
--     3.57 platform-wide (now slightly higher than North
--     Indian's 3.55, per Q8A's restaurant-grain correction).
--     At the top, South Indian competes with any cuisine in
--     the world — the average operator is what's weak, not
--     the cuisine.
--
-- F5. Zero table bookings across all 15 hidden gems — confirmed
--     unchanged at restaurant grain. book_table = 0 for every
--     single restaurant in the list, exactly as at listing
--     grain. These remain walk-in only, queue-and-wait
--     institutions where demand consistently exceeds capacity
--     — still the truest signal of genuine popularity in this
--     dataset.
--
-- F6. Dessert Parlors still claim 6 of 15 positions, identical
--     to listing grain: Corner House (#7), Milano (#8), Art of
--     Delight (#9), Berry'd Alive (#10), BelgYum (#13), Belgian
--     Waffle (#15) — same restaurants, same rank positions.
--     Dessert Parlors remain Bengaluru's most reliably excellent
--     Budget format.
--
-- F7. MTR still appears in two locations with the same pattern.
--     Basavanagudi (#4, ₹250, rate 4.5, 2,896 votes) and
--     Indiranagar (#11, ₹300, rate 4.3, 1,878 votes) — identical
--     figures to listing grain. The original location still
--     edges out the expansion on both rating and votes.
--
-- F8. All 15 gems remain in proof_bucket = 1, unchanged. Every
--     restaurant shown has enough votes to sit in the top third
--     of all qualifying hidden gems by volume — these are still
--     the most battle-tested, most-reviewed Budget restaurants
--     in Bengaluru.
--
-- F9. Value indexes still utterly destroy the Premium tier —
--     and by a slightly wider margin now that Premium's
--     restaurant-grain value_score is 0.285 (from Q9, down
--     from 0.293). Brahmin's Coffee Bar (4.80) is now 16.8×
--     better, CTR (3.20) is 11.2× better, Veena Stores (3.00)
--     is 10.5× better — each margin has widened slightly. Every
--     hidden gem provides more quality per rupee than the most
--     expensive tier on the platform, and the gap grew, not
--     shrank, after correcting for duplicate listings.
--
-- F10. Only one Very Good gem in the top 15 — Maiyas, unchanged.
--      rate = 4.0 exactly, beats_pct_of_platform = 76.8%
--      (down from 70.2% at listing grain — the restaurant-grain
--      denominator makes this look like a slightly stronger
--      relative position, though it's still noticeably lower
--      than every other gem on the list). Still the only
--      non-South-Indian, non-Dessert restaurant in the top 15,
--      making the list on votes and consistency rather than
--      exceptional rating.
--
-- F11. Online ordering still splits the gems into two cultures,
--      with one gem switching sides. 8 of 15 gems now accept
--      online ordering (up from 7): CTR, Kota Kachori, Veena
--      Stores, Corner House, Berry'd Alive, BelgYum, Belgian
--      Waffle, and Maiyas — the same eight as before. 7 of 15
--      remain dine-in only: Vidyarthi Bhavan, MTR (both),
--      Brahmin's Coffee, Milano, Art of Delight, Hari Super
--      Sandwich. The most iconic institutions — Brahmin's
--      Coffee (4.80), Vidyarthi Bhavan, MTR — still do NOT
--      deliver. The dine-in experience remains the product.

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
	restaurants_unique
WHERE
	PRICE_CATEGORY = 'Budget';
--
-- KEY FINDINGS:
--
-- F1. Hidden gems are rarer than the raw listings suggested,
--     but still commercially meaningful. 450 proven gems out
--     of 7,114 Budget restaurants = 6.3% of all Budget listings
--     — roughly 1 in 16, down from the old "1 in 13" figure.
--     This is rare enough to make finding them valuable, and
--     still abundant enough that a "Budget gems" discovery
--     feature on Zomato would have real supply to surface.
--
-- F2. The discovery problem in Budget deepened at restaurant
--     grain. 32.0% of Budget restaurants have never been
--     reviewed (up from 28.4% at listing grain — and this
--     figure now matches Q2's Budget unrated_pct exactly,
--     confirming pipeline consistency). That means 4,841
--     Budget restaurants are rated and 2,273 remain invisible.
--     Of the 4,841 rated Budget restaurants, 13.0% rate 4.0
--     or above — close to 1 in 8, essentially unchanged in
--     spirit from the old "1 in 7" figure.
--
-- F3. 178 restaurants are "unproven gems" — rated 4.0+ but
--     fewer than 100 votes (628 rated_4_plus − 450 proven_gems).
--     That's 3.7% of rated Budget restaurants, down from the
--     old 4.5%, but the underlying opportunity is the same
--     shape: restaurants with a good rating that haven't yet
--     been tested by enough customers to be trusted. If Zomato
--     drove 100+ orders to each of these 178 restaurants and
--     quality held, the proven-gem pool would grow by roughly
--     40% — a smaller absolute number than before, but a
--     similar relative growth opportunity.
--
-- F4. Proven gems avg cost is ₹301 — only ₹20 above the
--     restaurant-grain Budget tier average of ₹281 (from Q9).
--     This matches the listing-grain finding almost exactly
--     (old gap was ₹22): hidden gems are not clustered at the
--     top of the Budget price range. They exist throughout the
--     tier, from the cheapest listings up to the ₹400 ceiling.
--     Price within Budget still isn't a predictor of gem status.
--
-- F5. Proven gems avg rating is 4.17 — completely unchanged
--     from the listing-grain figure, and now an even more
--     striking comparison. Q9's restaurant-grain Premium tier
--     avg_rating is 3.99 (down from 4.04 at listing grain), so
--     the gap between Bengaluru's best 450 Budget restaurants
--     and the entire Premium tier has widened from +0.13 to
--     +0.18. The 450 best Budget restaurants outrate all 1,215
--     Premium restaurants by an even larger margin than the
--     raw listings implied.
--
-- F6. The corrected funnel:
--     7,114  Budget restaurants total          (100%)
--     4,841  have been rated at all            (68.1%)
--     2,273  never reviewed — invisible        (32.0%)
--       628  rated 4.0+ — potentially good     (13.0% of rated)
--       450  proven gems — trusted quality     ( 6.3% of all)
--       178  unproven gems — potential only    ( 3.7% of rated)
--
--     For every 16 Budget restaurants on Zomato Bengaluru,
--     1 is a proven hidden gem. For every 40, 1 is unproven
--     but potentially excellent. Combined: roughly 1 in 11
--     Budget restaurants is either proven or potentially
--     excellent — very close to the old "1 in 9" figure. The
--     restaurant-grain correction shrank every absolute count
--     substantially, but left the overall shape of the
--     discovery story intact: the gems exist, and the platform's
--     challenge remains surfacing them, not finding them.
--
-- COMBINED Q10 CONCLUSION:
--   450 Budget restaurants in Bengaluru (≤ ₹400 for two) rate
--   4.0+ with at least 100 verified reviews. Their average
--   rating (4.17) beats the entire Premium tier (3.99) by an
--   even wider margin than the raw listing data suggested.
--   Bengaluru's most remarkable food experiences are still not
--   concentrated in its Premium restaurants — they remain in
--   its tiffin rooms, ice cream parlours, and coffee bars,
--   discovered only by those who know where to look, and this
--   conclusion holds firmly after correcting for duplicate
--   listings.


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
					restaurants_unique
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
	restaurants_unique
GROUP BY
	ONLINE_ORDER
ORDER BY
	ONLINE_ORDER DESC;  -- Online Ordering row first
--
-- KEY FINDINGS:
--
-- F1. Online ordering restaurants still outrate dine-in on
--     every quality metric, and the rating gap actually widened
--     slightly. avg_rating: 3.66 vs 3.59 (+0.07, up from +0.05
--     at listing grain). quality_score: 71.2% vs 60.2% (+11.0
--     points, similar to the old +8.7). excellent_pct: 13.9%
--     vs 10.3% (+3.6 points). The core finding survives the
--     grain correction cleanly.
--
-- F2. The "identical median cost" finding no longer holds —
--     this is the biggest change in Part A. At listing grain,
--     both groups shared an exact median of ₹400. At restaurant
--     grain: online median ₹400, dine-in median ₹350. The
--     typical dine-in restaurant is now cheaper than the
--     typical online restaurant. But dine-in's avg (₹507) still
--     sits well above its own median (₹350) — a ₹157 gap versus
--     online's ₹75 gap (avg ₹475, median ₹400) — meaning dine-in
--     remains a barbell: a cheap majority plus a fatter tail of
--     expensive outliers pulling the average up. These are not
--     the same market at the median level anymore; dine-in
--     skews cheaper at the core but carries more high-end
--     variance.
--
-- F3. Dine-in still costs more on average despite rating lower,
--     though the gap narrowed substantially. Online: ₹475 avg,
--     3.66 rating. Dine-in: ₹507 avg, 3.59 rating. The ₹32
--     average-cost gap (down from ₹84) still means you pay more
--     on average at a dine-in restaurant for a lower rating —
--     but the effect is smaller than before, and as F2 shows,
--     the *typical* dine-in restaurant is actually the cheaper
--     one of the two.
--
-- F4. Online ordering's left-skewed distribution persists.
--     avg_rating 3.66 vs median_rating 3.70 — a small left tail
--     of low-rated online restaurants still pulls the average
--     below the typical restaurant's rating, same shape as
--     before.
--
-- F5. Dine-in's distribution is now even more symmetric than
--     at listing grain. avg 3.59 vs median 3.60 — a gap of just
--     0.01, tighter than the old 0.03. Dine-in quality remains
--     evenly distributed with no dramatic high-end cluster or
--     large low-quality tail — flat mediocrity rather than a
--     bimodal split, now more so than before.
--
-- F6. The unrated gap widened further. Online: 11.6% unrated.
--     Dine-in: 37.8% unrated — a 3.3x gap, up from 3x at listing
--     grain. Nearly 2 in 5 dine-in restaurants have never been
--     reviewed, versus roughly 1 in 9 online restaurants.
--     Zomato's review ecosystem remains structurally biased
--     toward generating reviews for delivery orders.
--
-- F7. Table booking adoption is still nearly identical across
--     service types. Online also_book_table_pct: 7.6%. Dine-in:
--     8.0%. A 0.4 point gap, essentially unchanged from the old
--     0.8 point gap. Restaurants still adopt online ordering and
--     table booking independently, not as mutually exclusive
--     choices.
--
-- F8. Failure rates are no longer nearly identical — online
--     restaurants now fail MORE often than dine-in, reversing
--     the old finding. poor_pct: online 5.3% vs dine-in 4.2%
--     (online is 1.1 points higher). At listing grain these
--     were essentially tied (4.4% vs 4.2%). Combined with F4's
--     left skew, this suggests a real subset of lower-quality
--     online-ordering restaurants — likely budget delivery
--     kitchens — that the old listing-grain averages partially
--     masked. Going dine-in now carries a small quality-risk
--     advantage that wasn't visible before.
--
-- F9. Online ordering's value-score advantage survives but is
--     roughly half the size claimed at listing grain. Online:
--     0.769. Dine-in: 0.709 — an 8.5% advantage, down from the
--     old 17.5%. The direction is unchanged (online remains the
--     better statistical value), but the effect is considerably
--     more modest than the original data suggested.
--
-- F10. Online ordering still generates more engagement per
--      restaurant, and the gap widened. Online: 222 avg votes.
--      Dine-in: 150 avg votes — roughly 48% more, up from the
--      old 20% gap. The structural review-prompt advantage from
--      delivery orders (F6) appears even more pronounced at
--      restaurant grain than the listing data implied.
--
-- NOTE — Composition effect: Part B confirms the online
--      ordering rating advantage (F1) holds within every price
--      tier individually, so it is not an artifact of dine-in
--      having a different price-tier mix. See Part B findings.
	
-- ========================================================
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
    restaurants_unique
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
-- F1. The within-tier online-ordering advantage survives the
--     grain correction fully intact. Budget: online 3.59 vs
--     dine-in 3.49 (+0.10, unchanged from listing grain).
--     Mid-range: online 3.67 vs dine-in 3.51 (+0.16, up slightly
--     from +0.15). Premium: online 4.03 vs dine-in 3.97 (+0.06,
--     down from +0.10). Online ordering restaurants still
--     outperform dine-in within every single price tier
--     simultaneously — the definitive test that the Part A
--     quality gap is genuine, not a composition artefact, holds
--     at both grains.
--
-- F2. Dine-in's Premium concentration advantage shrank but
--     still favours dine-in, and online ordering still wins
--     overall despite it. Dine-in Premium share: 13.2% (down
--     from 20.8%). Online Premium share: 7.4% (down from 11.7%).
--     Dine-in still carries proportionally more Premium
--     restaurants than online — which, given Premium's higher
--     average rating (3.99 from Q9), should favour dine-in's
--     overall average. It still loses overall (3.59 vs 3.66,
--     Part A). This makes the online quality advantage even
--     more notable: it persists despite a structural
--     disadvantage in tier composition.
--
-- F3. Mid-range still shows the largest within-tier gap, now
--     at +0.16 (was +0.15). Online Mid-range: 3.67. Dine-in
--     Mid-range: 3.51. The mid-range segment remains where
--     online ordering creates the most quality separation,
--     consistent with the theory that systematic, immediate
--     delivery reviews create measurable quality pressure that
--     dine-in's more forgiving review environment doesn't
--     replicate.
--
-- F4. Premium online restaurants now cost ₹318 less than
--     Premium dine-in — a wider gap than before — while rating
--     only 0.06 higher, a narrower gap than before. Online
--     Premium: ₹1,206 avg cost, 4.03 avg rating. Dine-in
--     Premium: ₹1,524 avg cost, 3.97 avg rating. Among Premium
--     restaurants, choosing one with online ordering still saves
--     meaningfully more money (up from ₹242) for a smaller but
--     still real rating edge (down from +0.10). The Premium
--     dine-in markup still buys ambience and service, not
--     better measured food quality.
--
-- F5. Dine-in Budget restaurants remain nearly invisible, and
--     the gap widened. avg_votes: dine-in Budget 32 vs online
--     Budget 85 — roughly 2.7x, essentially unchanged from
--     listing grain. These remain the lowest-engagement segment
--     in the entire table, local eateries with almost no review
--     activity supporting their 3.49 avg_rating.
--
-- F6. Online ordering still generates more votes at every tier,
--     and the pattern of convergence at Premium holds. Budget:
--     85 vs 32 (2.7x). Mid-range: 275 vs 127 (2.2x). Premium:
--     970 vs 769 (1.26x, similar to the old 1.2x). The engagement
--     advantage still narrows as price tier rises — Premium
--     dine-in restaurants attract engaged reviewers regardless
--     of delivery status, but Budget and Mid-range still lean
--     heavily on online ordering's automatic review prompt.
--
-- F7. Online ordering's tier distribution advantage is now even
--     more pronounced. Online: 54.8% Budget / 37.9% Mid-range /
--     7.4% Premium. Dine-in: 64.0% Budget / 22.9% Mid-range /
--     13.2% Premium. Dine-in is now more polarised than before
--     — a larger Budget share (64.0% vs the old 54.8%) and
--     thinner Mid-range middle (22.9% vs 24.4%), alongside its
--     persistently larger Premium tail. Online ordering's
--     stronger, more balanced Mid-range presence continues to
--     explain part of its overall quality and value advantage.
--
-- F8. Combined conclusion — the three-layer quality story
--     survives the restaurant-grain correction in full:
--     Layer 1 (Part A): Online ordering restaurants rate higher
--     overall (3.66 vs 3.59) with better quality score (71.2%
--     vs 60.2%) — the value advantage (F9, Part A) narrowed
--     but remains directionally intact.
--     Layer 2 (Part B composition): Dine-in still has a larger
--     Premium share (13.2% vs 7.4%), which should push its
--     average higher — yet it still loses overall.
--     Layer 3 (Part B within-tier): Online outperforms dine-in
--     within Budget (+0.10), Mid-range (+0.16), and Premium
--     (+0.06) simultaneously.
--     All three layers still point the same direction after
--     correcting for duplicate listings — the quality advantage
--     of online ordering restaurants is genuine, not a
--     statistical artefact of the data's original grain.
	

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
			restaurants_unique
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
							restaurants_unique
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
			restaurants_unique
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
-- F1. Table Only still outrates Both Services — and the gap
--     widened. Table Only: 4.15 avg_rating (+0.52 above platform,
--     platform avg now 3.63). Both Services: 4.09 avg_rating
--     (+0.46 above platform). A 0.06 gap, up from the old 0.03.
--     Table booking alone remains a stronger quality signal than
--     combining both digital services, and the effect is more
--     pronounced than the listing-grain data suggested.
--
-- F2. Table Only remains the most expensive segment by a wide
--     margin. avg_cost ₹1,590 — ₹552 more than Both Services
--     (₹1,038) and ₹1,161 more than Online Only (₹429). These
--     figures are all somewhat higher in absolute terms than
--     the old listing-grain numbers, but the relative spread is
--     similar: Table Only restaurants remain premium dine-in
--     venues that have deliberately opted out of delivery,
--     charge the most, and rate the highest on the platform.
--
-- F3. Table Only still has the highest quality score: 97.9%,
--     edging out Both Services' 96.9% — nearly identical to the
--     old 98.8%/98.1% spread. Premium dine-in venues with
--     reservations continue to self-select for quality through
--     price barrier and physical experience investment, at
--     essentially the same rate as before.
--
-- F4. Online Only no longer "dramatically" underperforms the
--     platform average — the effect is now much smaller.
--     avg_rating 3.62 vs platform 3.63 (−0.01), compared to the
--     old −0.05. The reconciliation with Q11 still holds: Q11's
--     combined "Online Ordering" group (avg 3.66) blends this
--     Online Only segment (3.62) with the smaller, higher-rated
--     Both Services segment (4.09) — but the pure online-only
--     restaurant is now essentially AT the platform average
--     rather than meaningfully below it. This is a real softening
--     of the original finding, not just a rounding difference.
--
-- F5. Neither is still the platform's quality floor, and the
--     segment grew substantially. 43.4% of all restaurants —
--     5,225 listings — now have neither online ordering nor
--     table booking, up from 34.4% at listing grain. avg_rating
--     3.52, quality_score 54.9% — both still the lowest of all
--     four segments. Nearly 4 in 10 restaurants on Zomato
--     Bengaluru now represent this fully-disengaged group,
--     an even larger share of the platform's true supply than
--     the listing-grain data implied.
--
-- F6. Both Services still has the highest avg_votes, and the
--     gap over Table Only widened slightly. Both Services:
--     1,026 avg_votes. Table Only: 997 — close behind. Online
--     Only: 156. Neither: 77 — both far behind. The two
--     digitally-invested segments continue to generate the most
--     review activity, with the vote-volume advantage compounding
--     the same way as before.
--
-- F7. The median-vs-average skew directions from listing grain
--     are not directly re-confirmed here since this query does
--     not report median_rating separately by segment at
--     restaurant grain in the columns reviewed — this finding is
--     not verifiable from the current output and should be
--     re-checked against the full Part A result set if median
--     columns are present.
--
-- F8. The platform-level insight from the Neither segment is now
--     more significant, not less. 5,225 restaurants (43.4%) have
--     zero platform investment — up from 34.4% at listing grain.
--     These restaurants are listed on Zomato but generate no
--     commission revenue and use none of its revenue-generating
--     features. Converting even 20% of Neither restaurants into
--     Online Only would now add roughly 1,045 delivery operators
--     to the platform — a smaller absolute number than the old
--     estimate (~3,500), reflecting the corrected, more accurate
--     restaurant count, but still Zomato's largest single growth
--     opportunity in the Bengaluru market by segment size.
--
-- F9. The digital adoption cost gradient survives, with all
--     figures shifted upward. Table Only ₹1,590 (most expensive)
--     → Both Services ₹1,038 → Neither ₹413 → Online Only ₹429
--     (cheapest). Table booking remains the clearest marker of
--     Bengaluru's premium restaurant economy, distinct from the
--     Budget/Mid-range economy that Online Only and Neither
--     restaurants occupy.
--
-- F10. Summary — digital verdict by segment, updated:
--     Strong signal  - Both Services + Table Only
--                      Together: 939 restaurants (7.8% —
--                      matches summary #10's table booking
--                      adoption rate exactly), avg_rating
--                      4.09–4.15, quality 96.9–97.9%
--     Weak signal    - Online Only
--                      5,873 restaurants (48.8%), avg_rating
--                      3.62 — now essentially at platform
--                      average rather than below it
--     No signal      - Neither
--                      5,225 restaurants (43.4%), avg_rating
--                      3.52, quality 54.9%
--
--     FINAL ANSWER TO BUSINESS QUESTION (updated):
--     Full digital adoption (Both Services) still produces a
--     strong quality signal — but table booking alone still
--     produces an even stronger one (4.15 vs 4.09), and this
--     gap widened after correcting for duplicate listings.
--     Online ordering alone no longer clearly underperforms the
--     platform — it sits almost exactly at average. The service
--     that most reliably predicts quality on Zomato Bengaluru
--     remains table booking, and this conclusion is now better
--     supported than it was at listing grain.

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
    restaurants_unique
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
-- F1. Both Services and Table Only remain overwhelmingly
--     Premium-tier phenomena, and the concentration is even
--     more extreme now. Table Only: 32.2% of Premium restaurants
--     (up from 29.6%). Both Services: 24.3% of Premium
--     restaurants (down from 32.3%). Combined, 56.5% of Premium
--     restaurants use some form of table booking — matching
--     Q9's restaurant-grain book_table_pct of 56.5% for Premium
--     exactly. The service signal and the tier signal remain
--     almost perfectly confounded.
--
-- F2. Table Only's quality advantage remains substantially a
--     composition effect, and even more so than before. Premium
--     concentration for Table Only is now 32.2% of the entire
--     Premium tier's restaurants, versus Table Only's own 453
--     total restaurants (Q12A) — meaning the vast majority of
--     Table Only restaurants ARE Premium-tier restaurants.
--     Table Only's avg_rating (4.15) sits above Premium's own
--     tier average (3.99, from Q9), meaning Table Only still
--     represents the top of the Premium tier, not Premium on
--     average — the same conclusion as before, reinforced.
--
-- F3. Budget is now an even more extreme two-segment market —
--     Online Only or Neither, with table booking essentially
--     nonexistent. Both Services: 0.1% (roughly 7 Budget
--     restaurants). Table Only: 0.0% (statistically zero).
--     Combined, barely a tenth of a percent of Budget
--     restaurants use any form of table booking — down from
--     0.3% at listing grain. Table booking does not meaningfully
--     exist in the Budget tier at restaurant grain.
--
-- F4. Mid-range remains Bengaluru's online-ordering heartland,
--     essentially unchanged. Online Only: 60.1% (down slightly
--     from 63.0%) — still by far the highest online-only rate
--     of any tier. More than 6 in 10 Mid-range restaurants
--     remain pure delivery operators with no table booking,
--     confirming Mid-range as Zomato's core delivery-commission
--     segment.
--
-- F5. Roughly 1 in 3.4 Premium restaurants now uses neither
--     service — an increase from the old 1 in 4. Neither_pct
--     for Premium is now 29.3% (up from 24.2%), meaning roughly
--     356 Premium restaurants (29.3% × 1,215) operate entirely
--     outside Zomato's transaction layer. This is a larger
--     share of the Premium tier than the listing data suggested
--     — Zomato's highest-value unconverted segment is bigger
--     than previously estimated, even as its absolute restaurant
--     count is smaller.
--
-- F6. Premium's table-booking split has reversed. At restaurant
--     grain, Table Only (32.2%) now clearly exceeds Both Services
--     (24.3%) within Premium — a meaningful shift from listing
--     grain, where the two were nearly evenly split (32.3% vs
--     29.6%, with Both Services very slightly ahead). More
--     Premium restaurants with table booking now skip online
--     ordering entirely than combine both — a stronger version
--     of the "protect the dine-in experience" pattern than the
--     original data implied.
--
-- F7. Online Only still collapses at Premium, and slightly more
--     sharply than before. Budget: 48.8% → Mid-range: 60.1% →
--     Premium: 14.2% (down from the old 14.0%, essentially
--     unchanged). Pure delivery without reservations remains a
--     Budget and Mid-range strategy; Premium restaurants that
--     adopt online ordering still overwhelmingly pair it with
--     table booking rather than going online-only.
--
-- F8. The Neither segment persists even in Premium at a higher
--     rate than before: 29.3% (up from 24.2%). Even at the
--     highest price tier, nearly 3 in 10 restaurants have chosen
--     zero platform integration — a larger share than the
--     listing-grain data suggested. These remain Zomato's
--     hardest restaurants to convert: Premium operators who have
--     actively decided the platform's transaction layer isn't
--     worth their participation, and there are proportionally
--     more of them than originally thought.
--
-- COMBINED Q12 CONCLUSION (updated):
--   Dual-service adoption (Both Services) still produces a
--   strong quality signal (4.09 avg, 96.9% quality score) but
--   remains substantially driven by Premium tier concentration.
--   Table Only produces an even stronger quality signal (4.15,
--   up from the old 0.03 gap to now 0.06) and is more heavily
--   Premium-concentrated than before (32.2% vs the old 29.6%).
--
--   The core insight is unchanged and, if anything, better
--   supported after correcting for duplicate listings: price
--   tier selects for service behaviour, not the reverse.
--     Budget    → Online Only or Nothing (booking ~0.1%)
--     Mid-range → Online Only dominates (60.1%)
--     Premium   → Splits between full-digital, reservation-only
--                 (now the larger group), and neither (a growing
--                 29.3% share)
--
--   Service adoption remains a SYMPTOM of premium positioning,
--   not a CAUSE of quality — and this causal story is now
--   somewhat more robust than the listing-grain data suggested.


