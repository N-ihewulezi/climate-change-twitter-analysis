-- ============================================================
-- PHASE 3: DATA CLEANING AND TRANSFORMATION
-- ============================================================
-- PURPOSE: Transform raw_tweets into a fully typed, standardised
-- analysis-ready table called clean_tweets.
-- Key decisions:
--   1. No DISTINCT ON needed - audit confirmed 0 duplicates
--   2. No regex guards needed on numeric columns - audit
--      confirmed all values cast cleanly including scientific
--      notation which PostgreSQL NUMERIC handles natively
--   3. Scientific notation values (lng x2, temperature x37)
--      are valid near-zero numbers, kept as-is after casting
--   4. 'undefined' gender mapped to 'Unknown'
--   5. Continent derived from lat/lng bounding boxes
--   6. Sentiment categorised into Positive/Neutral/Negative
--      using thresholds: > 0.05 = Positive, < -0.05 = Negative
--   7. is_aggressive boolean flag added for fast aggregation
--   8. All time components extracted for Power BI slicing
-- ============================================================
-- 3.1 Create the clean typed table
DROP TABLE IF EXISTS CLEAN_TWEETS;

CREATE TABLE CLEAN_TWEETS (
	TWEET_ID BIGINT PRIMARY KEY,
	TWEET_TIMESTAMP TIMESTAMPTZ, -- full datetime with timezone
	TWEET_DATE DATE, -- date only for daily grouping
	TWEET_YEAR SMALLINT, -- 2006 to 2022
	TWEET_MONTH SMALLINT, -- 1 to 12
	TWEET_QUARTER SMALLINT, -- 1 to 4
	TWEET_DAY_OF_WEEK SMALLINT, -- 0=Sunday to 6=Saturday
	LAT NUMERIC(10, 7), -- NULL when no geolocation
	LNG NUMERIC(10, 7), -- NULL when no geolocation
	HAS_COORDINATES BOOLEAN, -- TRUE when both lat and lng present
	TOPIC VARCHAR(100), -- one of 10 standardised topics
	SENTIMENT_SCORE NUMERIC(10, 7), -- range -0.994 to +0.992
	SENTIMENT_CATEGORY VARCHAR(20), -- Positive / Neutral / Negative
	STANCE VARCHAR(20), -- Believer / Denier / Neutral / Unknown
	GENDER VARCHAR(20), -- Male / Female / Unknown
	AGGRESSIVENESS VARCHAR(20), -- Aggressive / Not Aggressive / Unknown
	IS_AGGRESSIVE BOOLEAN, -- TRUE when aggressiveness = Aggressive
	TEMPERATURE_AVG NUMERIC(10, 7), -- local temp deviation in celsius, NULL when no location
	CONTINENT VARCHAR(30), -- derived from lat/lng bounding boxes
	CREATED_AT_RAW TEXT -- original raw value preserved for audit
);

-- 3.2 Optimised INSERT with all cleaning transformations applied
-- PERFORMANCE OPTIMIZATION FOR BULK INSERT
-- work_mem increased to allow faster sorting and hashing operations
-- during large-scale insert (15M+ rows)
-- synchronous_commit disabled temporarily to improve write speed
-- This introduces minimal risk (acceptable for one-time batch load)
-- Settings are reset immediately after insert to maintain durability
SET
	WORK_MEM = '256MB';

SET
	SYNCHRONOUS_COMMIT = OFF;

INSERT INTO
	CLEAN_TWEETS
SELECT
	ID AS TWEET_ID,
	TWEET_TIMESTAMP AS TWEET_TIMESTAMP,
	TWEET_TIMESTAMP::DATE AS TWEET_DATE,
	-- Extract time components for Power BI slicing and grouping
	EXTRACT(
		YEAR
		FROM
			TWEET_TIMESTAMP
	)::SMALLINT AS TWEET_YEAR,
	EXTRACT(
		MONTH
		FROM
			TWEET_TIMESTAMP
	)::SMALLINT AS TWEET_MONTH,
	EXTRACT(
		QUARTER
		FROM
			TWEET_TIMESTAMP
	)::SMALLINT AS TWEET_QUARTER,
	EXTRACT(
		DOW
		FROM
			TWEET_TIMESTAMP
	)::SMALLINT AS TWEET_DAY_OF_WEEK,
	LAT_NUM AS LAT,
	LNG_NUM AS LNG,
	-- has_coordinates: TRUE only when both lat and lng are populated
	-- 10,481,873 rows (66.4%) have no geolocation data
	(
		LAT_NUM IS NOT NULL
		AND LNG_NUM IS NOT NULL
	) AS HAS_COORDINATES,
	-- topic: 10 confirmed clean distinct values
	-- INITCAP ensures consistent title casing e.g. 'weather extremes'
	-- becomes 'Weather Extremes'
	INITCAP(TRIM(TOPIC)) AS TOPIC,
	SENTIMENT_NUM AS SENTIMENT_SCORE,
	-- sentiment_category: derived classification
	-- Positive  : score > +0.05
	-- Negative  : score < -0.05
	-- Neutral   : score between -0.05 and +0.05
	-- Thresholds chosen to create a meaningful neutral band
	CASE
		WHEN SENTIMENT_NUM > 0.05 THEN 'Positive'
		WHEN SENTIMENT_NUM < -0.05 THEN 'Negative'
		ELSE 'Neutral'
	END AS SENTIMENT_CATEGORY,
	-- stance: raw values are lowercase ('believer','denier','neutral')
	-- standardised to title case for display in Power BI
	CASE LOWER(TRIM(STANCE))
		WHEN 'believer' THEN 'Believer'
		WHEN 'denier' THEN 'Denier'
		WHEN 'neutral' THEN 'Neutral'
		ELSE 'Unknown'
	END AS STANCE,
	CASE LOWER(TRIM(GENDER))
		WHEN 'male' THEN 'Male'
		WHEN 'female' THEN 'Female'
		ELSE 'Unknown'
	END AS GENDER,
	CASE LOWER(TRIM(AGGRESSIVENESS))
		WHEN 'aggressive' THEN 'Aggressive'
		WHEN 'not aggressive' THEN 'Not Aggressive'
		ELSE 'Unknown'
	END AS AGGRESSIVENESS,
	(LOWER(TRIM(AGGRESSIVENESS)) = 'aggressive') AS IS_AGGRESSIVE,
	TEMP_NUM AS TEMPERATURE_AVG,
	-- ============================================================
	-- NOTE:
	-- Continent is derived using approximate latitude/longitude
	-- bounding boxes. This is a simplified proxy and may
	-- misclassify border regions (e.g. Eastern Europe, Middle East).
	-- Used for high-level regional trend analysis only.
	-- 66.4% of tweets have no coordinates and are classified as 'Unknown'.
	-- ============================================================
	CASE
		WHEN LAT_NUM IS NULL
		OR LNG_NUM IS NULL THEN 'Unknown'
		WHEN LAT_NUM BETWEEN 15 AND 72
		AND LNG_NUM BETWEEN -170 AND -50  THEN 'North America'
		WHEN LAT_NUM BETWEEN -60 AND 15
		AND LNG_NUM BETWEEN -90 AND -30  THEN 'South America'
		WHEN LAT_NUM BETWEEN 35 AND 70
		AND LNG_NUM BETWEEN -25 AND 40  THEN 'Europe'
		WHEN LAT_NUM BETWEEN -35 AND 37
		AND LNG_NUM BETWEEN -20 AND 55  THEN 'Africa'
		WHEN LAT_NUM BETWEEN 5 AND 80
		AND LNG_NUM BETWEEN 40 AND 180  THEN 'Asia'
		WHEN LAT_NUM BETWEEN -50 AND -5
		AND LNG_NUM BETWEEN 110 AND 180  THEN 'Oceania'
		ELSE 'Other'
	END AS CONTINENT,
	-- created_at_raw: preserve original text value for audit trail
	CREATED_AT_RAW AS CREATED_AT_RAW
FROM
	(
		SELECT
			ID,
			CREATED_AT AS CREATED_AT_RAW,
			CREATED_AT::TIMESTAMPTZ AS TWEET_TIMESTAMP,
			SENTIMENT::NUMERIC(10, 7) AS SENTIMENT_NUM,
			CASE
				WHEN TRIM(COALESCE(LAT, '')) = '' THEN NULL
				ELSE LAT::NUMERIC(10, 7)
			END AS LAT_NUM,
			CASE
				WHEN TRIM(COALESCE(LNG, '')) = '' THEN NULL
				ELSE LNG::NUMERIC(10, 7)
			END AS LNG_NUM,
			CASE
				WHEN TRIM(COALESCE(TEMPERATURE_AVG, '')) = '' THEN NULL
				ELSE TEMPERATURE_AVG::NUMERIC(10, 7)
			END AS TEMP_NUM,
			TOPIC,
			STANCE,
			GENDER,
			AGGRESSIVENESS
		FROM
			RAW_TWEETS
	) BASE;

-- 3.3 Reset session settings back to defaults
RESET WORK_MEM;

RESET SYNCHRONOUS_COMMIT;

------------------------------------------------------------------------------------------
-- 3.4 Post-insert validation
-- Row count comparison
SELECT
	(
		SELECT
			COUNT(*)
		FROM
			RAW_TWEETS
	) AS RAW_ROWS,
	(
		SELECT
			COUNT(*)
		FROM
			CLEAN_TWEETS
	) AS CLEAN_ROWS,
	(
		SELECT
			COUNT(*)
		FROM
			RAW_TWEETS
	) - (
		SELECT
			COUNT(*)
		FROM
			CLEAN_TWEETS
	) AS DIFFERENCE;

-- Data Output: raw_rows = clean_rows = 15,789,411, difference = 0
-- Every single row transferred cleanly with zero difference
----------------------------------------------------------------------------------------------
-- Year distribution - confirm date casting worked
SELECT
	TWEET_YEAR,
	COUNT(*) AS TWEETS
FROM
	CLEAN_TWEETS
GROUP BY
	TWEET_YEAR
ORDER BY
	TWEET_YEAR;

-- FINDING:
-- The dataset spans from 2006 to October 2019 based on both raw
-- and cleaned timestamp fields.
-- Although the dataset documentation references coverage up to 2022,
-- the current version used in this project does not contain records
-- beyond 2019.
-- IMPACT:
-- All time-series analysis, trends, and conclusions in this project
-- are limited to the 2006–2019 period.
-- No assumptions are made about post-2019 climate discourse.
--------------------------------------------------------------------------------------------
-- Null and completeness rates after cleaning
SELECT
	COUNT(*) AS TOTAL,
	SUM(
		CASE
			WHEN HAS_COORDINATES THEN 1
			ELSE 0
		END
	) AS GEOTAGGED,
	ROUND(
		100.0 * SUM(
			CASE
				WHEN HAS_COORDINATES THEN 1
				ELSE 0
			END
		) / COUNT(*),
		2
	) AS PCT_GEOTAGGED,
	SUM(
		CASE
			WHEN SENTIMENT_SCORE IS NULL THEN 1
			ELSE 0
		END
	) AS NULL_SENTIMENT,
	SUM(
		CASE
			WHEN TEMPERATURE_AVG IS NULL THEN 1
			ELSE 0
		END
	) AS NULL_TEMP,
	SUM(
		CASE
			WHEN GENDER = 'Unknown' THEN 1
			ELSE 0
		END
	) AS UNKNOWN_GENDER,
	SUM(
		CASE
			WHEN STANCE = 'Unknown' THEN 1
			ELSE 0
		END
	) AS UNKNOWN_STANCE,
	SUM(
		CASE
			WHEN CONTINENT = 'Unknown' THEN 1
			ELSE 0
		END
	) AS UNKNOWN_CONTINENT
FROM
	CLEAN_TWEETS;

-- Confirm all categorical values standardised correctly
SELECT
	'stance' AS COL,
	STANCE AS VAL,
	COUNT(*) AS N
FROM
	CLEAN_TWEETS
GROUP BY
	STANCE
UNION ALL
SELECT
	'gender',
	GENDER,
	COUNT(*)
FROM
	CLEAN_TWEETS
GROUP BY
	GENDER
UNION ALL
SELECT
	'aggressiveness',
	AGGRESSIVENESS,
	COUNT(*)
FROM
	CLEAN_TWEETS
GROUP BY
	AGGRESSIVENESS
UNION ALL
SELECT
	'sentiment_category',
	SENTIMENT_CATEGORY,
	COUNT(*)
FROM
	CLEAN_TWEETS
GROUP BY
	SENTIMENT_CATEGORY
UNION ALL
SELECT
	'continent',
	CONTINENT,
	COUNT(*)
FROM
	CLEAN_TWEETS
GROUP BY
	CONTINENT
ORDER BY
	COL,
	N DESC;

-- 3.5 Add indexes AFTER insert completes
-- Adding indexes before insert slows it down significantly
-- These indexes are critical for query performance on 15.7M rows
CREATE INDEX IDX_CT_YEAR ON CLEAN_TWEETS (TWEET_YEAR);

CREATE INDEX IDX_CT_DATE ON CLEAN_TWEETS (TWEET_DATE);

CREATE INDEX IDX_CT_STANCE ON CLEAN_TWEETS (STANCE);

CREATE INDEX IDX_CT_TOPIC ON CLEAN_TWEETS (TOPIC);

CREATE INDEX IDX_CT_GENDER ON CLEAN_TWEETS (GENDER);

CREATE INDEX IDX_CT_AGGR ON CLEAN_TWEETS (IS_AGGRESSIVE);

CREATE INDEX IDX_CT_CONTINENT ON CLEAN_TWEETS (CONTINENT);

CREATE INDEX IDX_CT_COORDS ON CLEAN_TWEETS (HAS_COORDINATES);

CREATE INDEX IDX_CT_SENTIMENT ON CLEAN_TWEETS (SENTIMENT_CATEGORY);

CREATE INDEX IDX_CT_YEAR_TOPIC ON CLEAN_TWEETS (TWEET_YEAR, TOPIC);

CREATE INDEX IDX_CT_YEAR_CONT ON CLEAN_TWEETS (TWEET_YEAR, CONTINENT);

CREATE INDEX IDX_CT_YEAR_STANCE ON CLEAN_TWEETS (TWEET_YEAR, STANCE);

CREATE INDEX IDX_CT_YEAR_TOPIC_AGGR ON CLEAN_TWEETS (TWEET_YEAR, TOPIC, IS_AGGRESSIVE);

---------------------------------------------------------------------------------------------
-- 3.6 Data freshness and temporal coverage check
-- PURPOSE:
-- Validate the true time span of the dataset after transformation
-- and ensure suitability for time-series analysis.
SELECT
	MIN(TWEET_TIMESTAMP) AS EARLIEST_TWEET,
	MAX(TWEET_TIMESTAMP) AS LATEST_TWEET,
	COUNT(DISTINCT TWEET_YEAR) AS TOTAL_YEARS
FROM
	CLEAN_TWEETS;

-- FINDING:
-- The dataset spans from June 2006 to October 2019,
-- covering 14 distinct years of climate-related discourse.
-- VALIDATION:
-- Cross-check performed on raw data confirms identical coverage.
-- No records exist beyond 2019 in this dataset version.
-- IMPACT:
-- All trend analysis, time-based aggregations, and conclusions
-- in this project are limited to the 2006–2019 period.