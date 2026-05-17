-- ============================================================
-- PROJECT:  Climate Change Twitter Sentiment Analysis
-- DATABASE: climate_analysis (PostgreSQL)
-- DATASET:  The Climate Change Twitter Dataset
--           Source: Mendeley Data
--           DOI: https://doi.org/10.17632/mw8yd7z9wc.2
--           Rows: 15,789,411 tweets spanning June 2006 to October 2019
-- AUTHOR:   Nkechi Ihewulezi
-- DATE:     May 3, 2026
-- ============================================================
-- SCRIPT STRUCTURE:
--   PHASE 1  : Database and raw staging table creation
--   PHASE 2  : Data quality audit queries
--   PHASE 3  : Data cleaning and transformation
--   PHASE 4  : Analytical views for Power BI
--   PHASE 5  : Descriptive analytics queries
--   PHASE 6  : Diagnostic analytics queries
-- ============================================================
-- ============================================================
-- PHASE 1: RAW DATA INGESTION
-- ============================================================
-- APPROACH: I imported the entire CSV as TEXT first (except id
-- which PostgreSQL auto-detects as BIGINT). This guarantees a
-- successful import regardless of edge cases such as scientific
-- notation, unexpected blanks, or formatting inconsistencies.
-- I then validate and cast each column only after confirming the
-- data in Phase 2. This is the professional standard approach
-- for large datasets where the contents are unknown upfront.
-- ============================================================
-- 1.1 Create the raw staging table
-- All columns stored as TEXT except id (auto-detected BIGINT)
-- so that the COPY import never fails on a type mismatch.
DROP TABLE IF EXISTS RAW_TWEETS;

CREATE TABLE RAW_TWEETS (
	CREATED_AT TEXT,
	ID BIGINT,
	LNG TEXT,
	LAT TEXT,
	TOPIC TEXT,
	SENTIMENT TEXT,
	STANCE TEXT,
	GENDER TEXT,
	TEMPERATURE_AVG TEXT,
	AGGRESSIVENESS TEXT
);

-- 1.2 Import the CSV file into the staging table
COPY RAW_TWEETS (
	CREATED_AT,
	ID,
	LNG,
	LAT,
	TOPIC,
	SENTIMENT,
	STANCE,
	GENDER,
	TEMPERATURE_AVG,
	AGGRESSIVENESS
)
FROM
	'C:\Users\Nkechi Ihewulezi\Downloads\HNG Internship\The Climate Change Twitter Dataset.csv'
WITH
	(
		FORMAT CSV,
		HEADER TRUE,
		ENCODING 'UTF8',
		DELIMITER ','
	);

-- 1.3 Verify the import completed successfully
-- Expected: 15M+ rows
SELECT
	COUNT(*) AS TOTAL_IMPORTED_ROWS
FROM
	RAW_TWEETS;

-- Data Output: 15,789,411 rows
-- 1.4 Preview the raw data exactly as imported
SELECT
	*
FROM
	RAW_TWEETS
LIMIT
	10;

-- 1.5 Confirm actual column data types PostgreSQL assigned
-- Result confirmed:
--   created_at      TEXT
--   id              BIGINT  (auto-detected)
--   lng             TEXT
--   lat             TEXT
--   topic           TEXT
--   sentiment       TEXT
--   stance          TEXT
--   gender          TEXT
--   temperature_avg TEXT
--   aggressiveness  TEXT
SELECT
	COLUMN_NAME,
	DATA_TYPE,
	UDT_NAME
FROM
	INFORMATION_SCHEMA.COLUMNS
WHERE
	TABLE_NAME = 'raw_tweets'
	AND TABLE_SCHEMA = 'public'
ORDER BY
	ORDINAL_POSITION;

-- ============================================================
-- PHASE 2: DATA QUALITY AUDIT
-- ============================================================
-- PURPOSE: Inspect every column for nulls, blanks, non-numeric
-- values, out-of-range values, unexpected categories, and
-- duplicates before writing any cleaning logic.
-- All findings are documented in comments below each query.
-- ============================================================
-- 2.1 Confirm date format is consistent across all rows
-- FINDING: 100% of rows use format 'YYYY-MM-DD HH:MM:SS+00:00'
--          e.g. '2006-06-06 16:06:42+00:00'
--          PostgreSQL can cast this directly with ::TIMESTAMPTZ
SELECT
	LEFT(CREATED_AT, 30) AS SAMPLE_FORMAT,
	COUNT(*) AS OCCURRENCES
FROM
	RAW_TWEETS
GROUP BY
	LEFT(CREATED_AT, 30)
ORDER BY
	OCCURRENCES DESC
LIMIT
	20;

-- 2.2 Audit the id column
-- FINDING: 0 nulls, all values are valid BIGINTs
--          Range: 6,132 to 1,178,911,891,285,917,696
SELECT
	COUNT(*) AS TOTAL,
	SUM(
		CASE
			WHEN ID IS NULL THEN 1
			ELSE 0
		END
	) AS NULL_IDS,
	MIN(ID) AS MIN_ID,
	MAX(ID) AS MAX_ID
FROM
	RAW_TWEETS;

-- 2.3 Audit the lat column
-- FINDING: 10,481,873 rows have no coordinates (66.4% of data)
--          0 non-numeric values among populated rows
--          0 out-of-range values
--          Valid range: all values fall within [-90, 90]
SELECT
	COUNT(*) AS TOTAL,
	SUM(
		CASE
			WHEN LAT IS NULL
			OR TRIM(LAT) = '' THEN 1
			ELSE 0
		END
	) AS NULL_OR_BLANK,
	SUM(
		CASE
			WHEN LAT IS NOT NULL
			AND TRIM(LAT) != ''
			AND LAT !~ '^-?[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?$' THEN 1
			ELSE 0
		END
	) AS NON_NUMERIC,
	SUM(
		CASE
			WHEN LAT ~ '^-?[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?$'
			AND LAT::NUMERIC NOT BETWEEN -90 AND 90  THEN 1
			ELSE 0
		END
	) AS OUT_OF_RANGE,
	MIN(
		CASE
			WHEN LAT ~ '^-?[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?$' THEN LAT::NUMERIC
		END
	) AS MIN_LAT,
	MAX(
		CASE
			WHEN LAT ~ '^-?[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?$' THEN LAT::NUMERIC
		END
	) AS MAX_LAT
FROM
	RAW_TWEETS;

-- 2.4 Audit the lng column
-- FINDING: 10,481,873 rows have no coordinates (matches lat)
--          2 values written in scientific notation:
--            '-5.2199999999999995e-05' and '9e-05'
--          Both are valid numbers near zero (Prime Meridian, UK)
--          PostgreSQL::NUMERIC handles scientific notation natively
--          0 out-of-range values
SELECT
	COUNT(*) AS TOTAL,
	SUM(
		CASE
			WHEN LNG IS NULL
			OR TRIM(LNG) = '' THEN 1
			ELSE 0
		END
	) AS NULL_OR_BLANK,
	SUM(
		CASE
			WHEN LNG IS NOT NULL
			AND TRIM(LNG) != ''
			AND LNG !~ '^-?[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?$' THEN 1
			ELSE 0
		END
	) AS NON_NUMERIC,
	SUM(
		CASE
			WHEN LNG ~ '^-?[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?$'
			AND LNG::NUMERIC NOT BETWEEN -180 AND 180  THEN 1
			ELSE 0
		END
	) AS OUT_OF_RANGE,
	MIN(
		CASE
			WHEN LNG ~ '^-?[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?$' THEN LNG::NUMERIC
		END
	) AS MIN_LNG,
	MAX(
		CASE
			WHEN LNG ~ '^-?[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?$' THEN LNG::NUMERIC
		END
	) AS MAX_LNG
FROM
	RAW_TWEETS;

-- 2.5 Audit the sentiment column
-- FINDING: 0 nulls, 0 non-numeric values, 0 out-of-range values
--          Range: -0.9942 to +0.9917 (well within [-1, 1])
--          Average: +0.002537 (slightly positive overall)
--          All values can be cast directly with ::NUMERIC
SELECT
	COUNT(*) AS TOTAL,
	SUM(
		CASE
			WHEN SENTIMENT IS NULL
			OR TRIM(SENTIMENT) = '' THEN 1
			ELSE 0
		END
	) AS NULL_OR_BLANK,
	COUNT(SENTIMENT) AS NON_NULL_ROWS,
	SUM(
		CASE
			WHEN SENTIMENT ~ '^-?[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?$' THEN 1
			ELSE 0
		END
	) AS VALID_NUMERIC,
	COUNT(*) - SUM(
		CASE
			WHEN SENTIMENT ~ '^-?[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?$' THEN 1
			ELSE 0
		END
	) AS PROBLEM_ROWS,
	MIN(SENTIMENT::NUMERIC) AS MIN_SENTIMENT,
	MAX(SENTIMENT::NUMERIC) AS MAX_SENTIMENT,
	ROUND(AVG(SENTIMENT::NUMERIC), 6) AS AVG_SENTIMENT
FROM
	RAW_TWEETS;

-- 2.6 Audit the temperature_avg column
-- FINDING: 10,481,873 nulls (matches lat/lng - location-based field)
--          37 values in scientific notation e.g. '-3.1493975e-05'
--          All are valid tiny decimals near zero degrees deviation
--          PostgreSQL::NUMERIC handles them correctly
--          Valid range: -23.289 to +21.004 degrees deviation
SELECT
	COUNT(*) AS TOTAL,
	SUM(
		CASE
			WHEN TEMPERATURE_AVG IS NULL
			OR TRIM(TEMPERATURE_AVG) = '' THEN 1
			ELSE 0
		END
	) AS NULL_OR_BLANK,
	SUM(
		CASE
			WHEN TEMPERATURE_AVG IS NOT NULL
			AND TRIM(TEMPERATURE_AVG) != ''
			AND TEMPERATURE_AVG !~ '^-?[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?$' THEN 1
			ELSE 0
		END
	) AS NON_NUMERIC,
	MIN(
		CASE
			WHEN TEMPERATURE_AVG ~ '^-?[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?$' THEN TEMPERATURE_AVG::NUMERIC
		END
	) AS MIN_TEMP,
	MAX(
		CASE
			WHEN TEMPERATURE_AVG ~ '^-?[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?$' THEN TEMPERATURE_AVG::NUMERIC
		END
	) AS MAX_TEMP,
	ROUND(
		AVG(
			CASE
				WHEN TEMPERATURE_AVG ~ '^-?[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?$' THEN TEMPERATURE_AVG::NUMERIC
			END
		),
		4
	) AS AVG_TEMP
FROM
	RAW_TWEETS;

-- 2.7 Audit all categorical columns
-- FINDING stance:        3 values - believer(71.5%), neutral(20.9%), denier(7.5%)
-- FINDING gender:        3 values - male(65.3%), female(31.0%), undefined(3.7%)
-- FINDING aggressiveness:2 values - not aggressive(71.3%), aggressive(28.7%)
-- All categorical columns have ZERO nulls
SELECT
	'stance' AS COL,
	COALESCE(STANCE, 'NULL') AS VAL,
	COUNT(*) AS N,
	ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 4) AS PCT
FROM
	RAW_TWEETS
GROUP BY
	STANCE
UNION ALL
SELECT
	'gender',
	COALESCE(GENDER, 'NULL'),
	COUNT(*),
	ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 4)
FROM
	RAW_TWEETS
GROUP BY
	GENDER
UNION ALL
SELECT
	'aggressiveness',
	COALESCE(AGGRESSIVENESS, 'NULL'),
	COUNT(*),
	ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 4)
FROM
	RAW_TWEETS
GROUP BY
	AGGRESSIVENESS
ORDER BY
	COL,
	N DESC;

-- 2.8 Audit the topic column
-- FINDING: Exactly 10 distinct topics, 0 nulls
--   Global stance                              4,135,619
--   Importance of Human Intervantion           2,594,941
--   Weather Extremes                           2,464,814
--   Politics                                   1,809,583
--   Undefined / One Word Hashtags              1,305,118
--   Donald Trump versus Science                  996,244
--   Seriousness of Gas Emissions                 903,478
--   Ideological Positions on Global Warming      602,695
--   Impact of Resource Overconsumption           496,924
--   Significance of Pollution Awareness Events   479,995
SELECT
	COALESCE(TOPIC, 'NULL') AS TOPIC_VALUE,
	COUNT(*) AS OCCURRENCES
FROM
	RAW_TWEETS
GROUP BY
	TOPIC
ORDER BY
	OCCURRENCES DESC;

-- 2.9 Duplicate check on id column
-- FINDING: 0 duplicate ids - every row is unique
--          total_rows = distinct_ids = 15,789,411
SELECT
	COUNT(*) AS TOTAL_ROWS,
	COUNT(DISTINCT ID) AS DISTINCT_IDS,
	COUNT(*) - COUNT(DISTINCT ID) AS DUPLICATE_ROWS
FROM
	RAW_TWEETS;

-- ============================================================
-- AUDIT SUMMARY (confirmed from real data)
-- ============================================================
-- Column          | Issues Found
-- ----------------|------------------------------------------
-- created_at      | None. Consistent YYYY-MM-DD HH:MM:SS+00:00
-- id              | None. Clean BIGINT, 0 nulls, 0 duplicates
-- lat             | 10,481,873 blank (66.4%) - expected
-- lng             | 10,481,873 blank, 2 scientific notation
-- sentiment       | None. All numeric, range -0.994 to +0.992
-- temperature_avg | 10,481,873 blank, 37 scientific notation
-- stance          | 3 clean values, 0 nulls
-- gender          | 3 values incl. 'undefined' -> maps to Unknown
-- aggressiveness  | 2 clean values, 0 nulls
-- topic           | 10 clean distinct values, 0 nulls
-- duplicates      | 0
-- ============================================================
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
-- ============================================================
-- PHASE 4: ANALYTICAL VIEWS FOR POWER BI
-- ============================================================
-- PURPOSE: Create pre-aggregated views that Power BI connects
-- to directly. Each view serves a specific dashboard page.
-- Views are faster than raw table queries in Power BI and
-- allow aggregation logic to live in PostgreSQL rather than DAX.
-- ============================================================
-- 4.1 KPI Summary View
-- Powers the executive summary cards on the dashboard overview page
CREATE OR REPLACE VIEW VW_KPI_SUMMARY AS
SELECT
	COUNT(*) AS TOTAL_TWEETS,
	COUNT(DISTINCT TWEET_YEAR) AS YEARS_COVERED,
	MIN(TWEET_YEAR) AS FIRST_YEAR,
	MAX(TWEET_YEAR) AS LAST_YEAR,
	ROUND(AVG(SENTIMENT_SCORE), 4) AS OVERALL_AVG_SENTIMENT,
	COUNT(*) FILTER (
		WHERE
			STANCE = 'Believer'
	) AS TOTAL_BELIEVERS,
	COUNT(*) FILTER (
		WHERE
			STANCE = 'Denier'
	) AS TOTAL_DENIERS,
	COUNT(*) FILTER (
		WHERE
			STANCE = 'Neutral'
	) AS TOTAL_NEUTRALS,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				STANCE = 'Believer'
		) / COUNT(*),
		2
	) AS PCT_BELIEVERS,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				STANCE = 'Denier'
		) / COUNT(*),
		2
	) AS PCT_DENIERS,
	COUNT(*) FILTER (
		WHERE
			IS_AGGRESSIVE
	) AS TOTAL_AGGRESSIVE,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				IS_AGGRESSIVE
		) / COUNT(*),
		2
	) AS OVERALL_AGGR_PCT,
	COUNT(*) FILTER (
		WHERE
			HAS_COORDINATES
	) AS GEOTAGGED_TWEETS,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				HAS_COORDINATES
		) / COUNT(*),
		2
	) AS PCT_GEOTAGGED,
	COUNT(DISTINCT TOPIC) AS DISTINCT_TOPICS
FROM
	CLEAN_TWEETS;

-- 4.2 Yearly Trends View
-- Powers the sentiment and stance trend line charts
-- Answers leadership question 1: how have sentiment and stance shifted over 14 years?
CREATE OR REPLACE VIEW VW_YEARLY_TRENDS AS
SELECT
	TWEET_YEAR,
	COUNT(*) AS TOTAL_TWEETS,
	ROUND(AVG(SENTIMENT_SCORE), 4) AS AVG_SENTIMENT,
	ROUND(STDDEV(SENTIMENT_SCORE), 4) AS SENTIMENT_VOLATILITY,
	COUNT(*) FILTER (
		WHERE
			STANCE = 'Believer'
	) AS BELIEVERS,
	COUNT(*) FILTER (
		WHERE
			STANCE = 'Denier'
	) AS DENIERS,
	COUNT(*) FILTER (
		WHERE
			STANCE = 'Neutral'
	) AS NEUTRALS,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				STANCE = 'Believer'
		) / COUNT(*),
		2
	) AS PCT_BELIEVERS,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				STANCE = 'Denier'
		) / COUNT(*),
		2
	) AS PCT_DENIERS,
	COUNT(*) FILTER (
		WHERE
			IS_AGGRESSIVE
	) AS AGGRESSIVE_COUNT,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				IS_AGGRESSIVE
		) / COUNT(*),
		2
	) AS PCT_AGGRESSIVE,
	ROUND(
		AVG(SENTIMENT_SCORE) - LAG(AVG(SENTIMENT_SCORE)) OVER (
			ORDER BY
				TWEET_YEAR
		),
		4
	) AS YOY_SENTIMENT_CHANGE
FROM
	CLEAN_TWEETS
WHERE
	TWEET_YEAR BETWEEN 2006 AND 2019
GROUP BY
	TWEET_YEAR
ORDER BY
	TWEET_YEAR;

-- 4.3 Monthly Trends View
-- Powers monthly volume and seasonality charts
CREATE OR REPLACE VIEW VW_MONTHLY_TRENDS AS
SELECT
	TWEET_YEAR,
	TWEET_MONTH,
	TO_CHAR(
		MAKE_DATE(TWEET_YEAR::INT, TWEET_MONTH::INT, 1),
		'YYYY-MM'
	) AS YEAR_MONTH,
	CASE TWEET_MONTH
		WHEN 12 THEN 'Winter'
		WHEN 1 THEN 'Winter'
		WHEN 2 THEN 'Winter'
		WHEN 3 THEN 'Spring'
		WHEN 4 THEN 'Spring'
		WHEN 5 THEN 'Spring'
		WHEN 6 THEN 'Summer'
		WHEN 7 THEN 'Summer'
		WHEN 8 THEN 'Summer'
		ELSE 'Autumn'
	END AS SEASON,
	COUNT(*) AS TOTAL_TWEETS,
	ROUND(AVG(SENTIMENT_SCORE), 4) AS AVG_SENTIMENT,
	COUNT(*) FILTER (
		WHERE
			IS_AGGRESSIVE
	) AS AGGRESSIVE_COUNT,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				IS_AGGRESSIVE
		) / COUNT(*),
		2
	) AS PCT_AGGRESSIVE
FROM
	CLEAN_TWEETS
WHERE
	TWEET_YEAR BETWEEN 2006 AND 2019
GROUP BY
	TWEET_YEAR,
	TWEET_MONTH
ORDER BY
	TWEET_YEAR,
	TWEET_MONTH;

-- 4.4 Topic Analysis View
-- Powers the topic breakdown page
-- Answers leadership question 2: which topics drive the most divisive discourse?
-- Divisiveness score: 1.0 = perfectly 50/50 believers vs deniers (maximally divisive)
--                    0.0 = all one side (no division)
CREATE OR REPLACE VIEW VW_TOPIC_ANALYSIS AS
SELECT
	TOPIC,
	COUNT(*) AS TOTAL_TWEETS,
	ROUND(AVG(SENTIMENT_SCORE), 4) AS AVG_SENTIMENT,
	ROUND(STDDEV(SENTIMENT_SCORE), 4) AS SENTIMENT_VOLATILITY,
	COUNT(*) FILTER (
		WHERE
			STANCE = 'Believer'
	) AS BELIEVERS,
	COUNT(*) FILTER (
		WHERE
			STANCE = 'Denier'
	) AS DENIERS,
	COUNT(*) FILTER (
		WHERE
			STANCE = 'Neutral'
	) AS NEUTRALS,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				STANCE = 'Believer'
		) / NULLIF(COUNT(*), 0),
		2
	) AS PCT_BELIEVERS,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				STANCE = 'Denier'
		) / NULLIF(COUNT(*), 0),
		2
	) AS PCT_DENIERS,
	COUNT(*) FILTER (
		WHERE
			IS_AGGRESSIVE
	) AS AGGRESSIVE_TWEETS,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				IS_AGGRESSIVE
		) / NULLIF(COUNT(*), 0),
		2
	) AS PCT_AGGRESSIVE,
	-- Divisiveness score: 1.0 = maximally divisive (50/50 split)
	-- 0.0 = all one side (no division)
	ROUND(
		1 - ABS(
			COALESCE(
				COUNT(*) FILTER (
					WHERE
						STANCE = 'Believer'
				)::NUMERIC / NULLIF(
					COUNT(*) FILTER (
						WHERE
							STANCE IN ('Believer', 'Denier')
					),
					0
				),
				0.5
			) - 0.5
		) * 2,
		4
	) AS DIVISIVENESS_SCORE
FROM
	CLEAN_TWEETS
GROUP BY
	TOPIC
ORDER BY
	TOTAL_TWEETS DESC;

-- 4.5 Topic Yearly Trends View
-- Shows which topics grew or declined over time
-- Critical for the policy briefing narrative
CREATE OR REPLACE VIEW VW_TOPIC_YEARLY_TRENDS AS
SELECT
	TWEET_YEAR,
	TOPIC,
	COUNT(*) AS TWEET_COUNT,
	ROUND(AVG(SENTIMENT_SCORE), 4) AS AVG_SENTIMENT,
	COUNT(*) FILTER (
		WHERE
			IS_AGGRESSIVE
	) AS AGGRESSIVE_COUNT,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				IS_AGGRESSIVE
		) / NULLIF(COUNT(*), 0),
		2
	) AS PCT_AGGRESSIVE,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				STANCE = 'Believer'
		) / NULLIF(COUNT(*), 0),
		2
	) AS PCT_BELIEVERS,
	RANK() OVER (
		PARTITION BY
			TWEET_YEAR
		ORDER BY
			COUNT(*) DESC
	) AS VOLUME_RANK
FROM
	CLEAN_TWEETS
WHERE
	TWEET_YEAR BETWEEN 2006 AND 2019
GROUP BY
	TWEET_YEAR,
	TOPIC
ORDER BY
	TWEET_YEAR,
	TWEET_COUNT DESC;

-- 4.6 Regional Analysis View
-- Powers the map and continent breakdown visuals
-- Answers leadership question 2: which regions drive the most aggressive discourse?
CREATE OR REPLACE VIEW VW_REGIONAL_ANALYSIS AS
SELECT
	CONTINENT,
	COUNT(*) AS TOTAL_TWEETS,
	ROUND(AVG(SENTIMENT_SCORE), 4) AS AVG_SENTIMENT,
	ROUND(STDDEV(SENTIMENT_SCORE), 4) AS SENTIMENT_VOLATILITY,
	COUNT(*) FILTER (
		WHERE
			STANCE = 'Believer'
	) AS BELIEVERS,
	COUNT(*) FILTER (
		WHERE
			STANCE = 'Denier'
	) AS DENIERS,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				STANCE = 'Believer'
		) / NULLIF(COUNT(*), 0),
		2
	) AS PCT_BELIEVERS,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				STANCE = 'Denier'
		) / NULLIF(COUNT(*), 0),
		2
	) AS PCT_DENIERS,
	COUNT(*) FILTER (
		WHERE
			IS_AGGRESSIVE
	) AS AGGRESSIVE_TWEETS,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				IS_AGGRESSIVE
		) / NULLIF(COUNT(*), 0),
		2
	) AS PCT_AGGRESSIVE,
	ROUND(AVG(TEMPERATURE_AVG), 4) AS AVG_TEMP_DEVIATION,
	ROUND(
		1 - ABS(
			COALESCE(
				COUNT(*) FILTER (
					WHERE
						STANCE = 'Believer'
				)::NUMERIC / NULLIF(
					COUNT(*) FILTER (
						WHERE
							STANCE IN ('Believer', 'Denier')
					),
					0
				),
				0.5
			) - 0.5
		) * 2,
		4
	) AS DIVISIVENESS_SCORE
FROM
	CLEAN_TWEETS
WHERE
	CONTINENT != 'Unknown'
GROUP BY
	CONTINENT
ORDER BY
	TOTAL_TWEETS DESC;

-- 4.7 Stance by Region View
-- Cross-tab of who believes what and where
-- Key diagnostic: regional belief patterns
CREATE OR REPLACE VIEW VW_STANCE_BY_REGION AS
SELECT
	CONTINENT,
	TWEET_YEAR,
	COUNT(*) FILTER (
		WHERE
			STANCE = 'Believer'
	) AS BELIEVERS,
	COUNT(*) FILTER (
		WHERE
			STANCE = 'Denier'
	) AS DENIERS,
	COUNT(*) FILTER (
		WHERE
			STANCE = 'Neutral'
	) AS NEUTRALS,
	COUNT(*) AS TOTAL,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				STANCE = 'Believer'
		) / NULLIF(COUNT(*), 0),
		2
	) AS PCT_BELIEVERS,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				STANCE = 'Denier'
		) / NULLIF(COUNT(*), 0),
		2
	) AS PCT_DENIERS,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				IS_AGGRESSIVE
		) / NULLIF(COUNT(*), 0),
		2
	) AS PCT_AGGRESSIVE
FROM
	CLEAN_TWEETS
WHERE
	CONTINENT NOT IN ('Unknown', 'Other')
GROUP BY
	CONTINENT,
	TWEET_YEAR
ORDER BY
	CONTINENT,
	TWEET_YEAR;

-- 4.8 Gender Analysis View
-- Powers gender comparison visuals
CREATE OR REPLACE VIEW VW_GENDER_ANALYSIS AS
SELECT
	GENDER,
	TWEET_YEAR,
	COUNT(*) AS TOTAL_TWEETS,
	ROUND(AVG(SENTIMENT_SCORE), 4) AS AVG_SENTIMENT,
	COUNT(*) FILTER (
		WHERE
			IS_AGGRESSIVE
	) AS AGGRESSIVE_COUNT,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				IS_AGGRESSIVE
		) / NULLIF(COUNT(*), 0),
		2
	) AS PCT_AGGRESSIVE,
	COUNT(*) FILTER (
		WHERE
			STANCE = 'Believer'
	) AS BELIEVERS,
	COUNT(*) FILTER (
		WHERE
			STANCE = 'Denier'
	) AS DENIERS,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				STANCE = 'Believer'
		) / NULLIF(COUNT(*), 0),
		2
	) AS PCT_BELIEVERS
FROM
	CLEAN_TWEETS
WHERE
	GENDER IN ('Male', 'Female')
GROUP BY
	GENDER,
	TWEET_YEAR
ORDER BY
	TWEET_YEAR,
	GENDER;

-- 4.9 Temperature vs Sentiment Correlation View
-- Explores relationship between local temperature deviation
-- and public sentiment / aggressiveness
CREATE OR REPLACE VIEW VW_TEMP_SENTIMENT AS
SELECT
	TWEET_YEAR,
	CONTINENT,
	ROUND(AVG(TEMPERATURE_AVG), 4) AS AVG_TEMP_DEVIATION,
	ROUND(AVG(SENTIMENT_SCORE), 4) AS AVG_SENTIMENT,
	ROUND(AVG(IS_AGGRESSIVE::INT), 4) AS AGGR_RATE,
	COUNT(*) AS TWEET_COUNT
FROM
	CLEAN_TWEETS
WHERE
	TEMPERATURE_AVG IS NOT NULL
	AND SENTIMENT_SCORE IS NOT NULL
	AND TWEET_YEAR BETWEEN 2006 AND 2019
GROUP BY
	TWEET_YEAR,
	CONTINENT
ORDER BY
	TWEET_YEAR,
	CONTINENT;

-- 4.10 Aggressiveness Deep Dive View
-- Multi-dimensional aggressiveness breakdown
-- Used for the drill-through page in Power BI
CREATE OR REPLACE VIEW VW_AGGRESSIVENESS_ANALYSIS AS
SELECT
	TWEET_YEAR,
	TOPIC,
	CONTINENT,
	STANCE,
	GENDER,
	COUNT(*) AS TOTAL_TWEETS,
	COUNT(*) FILTER (
		WHERE
			IS_AGGRESSIVE
	) AS AGGRESSIVE_COUNT,
	ROUND(
		100.0 * COUNT(*) FILTER (
			WHERE
				IS_AGGRESSIVE
		) / NULLIF(COUNT(*), 0),
		2
	) AS PCT_AGGRESSIVE,
	ROUND(AVG(SENTIMENT_SCORE), 4) AS AVG_SENTIMENT
FROM
	CLEAN_TWEETS
WHERE
	TWEET_YEAR BETWEEN 2006 AND 2019
GROUP BY
	TWEET_YEAR,
	TOPIC,
	CONTINENT,
	STANCE,
	GENDER
ORDER BY
	AGGRESSIVE_COUNT DESC;

-- 4.11 EXECUTIVE INSIGHT VIEW
--   Provides a high-level executive summary of climate change
--   discourse aggregated by topic. Designed to answer the two
--   core leadership questions in a single view:
--     1. Which topics generate the most aggressive discourse?
--     2. Which topics are most divisive between believers
--        and deniers?
CREATE OR REPLACE VIEW VW_EXECUTIVE_INSIGHTS AS
SELECT
	TOPIC,
	COUNT(*) AS TOTAL_TWEETS,
	ROUND(AVG(SENTIMENT_SCORE), 3) AS AVG_SENTIMENT,
	ROUND(STDDEV(SENTIMENT_SCORE), 3) AS SENTIMENT_VOLATILITY,
	ROUND(AVG(IS_AGGRESSIVE::INT), 3) AS AGGRESSION_RATE,
	ROUND(AVG(IS_AGGRESSIVE::INT) * 100, 2) AS PCT_AGGRESSIVE,
	ROUND(
		COUNT(*) FILTER (
			WHERE
				STANCE = 'Believer'
		)::NUMERIC / NULLIF(
			COUNT(*) FILTER (
				WHERE
					STANCE IN ('Believer', 'Denier')
			),
			0
		),
		3
	) AS BELIEVER_RATIO,
	-- Denier ratio for completeness
	ROUND(
		COUNT(*) FILTER (
			WHERE
				STANCE = 'Denier'
		)::NUMERIC / NULLIF(
			COUNT(*) FILTER (
				WHERE
					STANCE IN ('Believer', 'Denier')
			),
			0
		),
		3
	) AS DENIER_RATIO,
	-- Total believers and deniers for volume context
	COUNT(*) FILTER (
		WHERE
			STANCE = 'Believer'
	) AS BELIEVERS,
	COUNT(*) FILTER (
		WHERE
			STANCE = 'Denier'
	) AS DENIERS
FROM
	CLEAN_TWEETS
GROUP BY
	TOPIC
ORDER BY
	AGGRESSION_RATE DESC;

-- ============================================================
-- PHASE 5: DESCRIPTIVE ANALYTICS
-- ============================================================
-- PURPOSE: Summarise the dataset to understand its key
-- characteristics including distributions, volumes, and
-- central tendencies across all key variables.
-- ============================================================
-- 5.1 Overall dataset KPIs
SELECT
	*
FROM
	VW_KPI_SUMMARY;

-- 5.2 Tweet volume by year
-- Shows the growth of climate discourse over 13 years
SELECT
	TWEET_YEAR,
	COUNT(*) AS TWEETS,
	ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS PCT_OF_TOTAL
FROM
	CLEAN_TWEETS
GROUP BY
	TWEET_YEAR
ORDER BY
	TWEET_YEAR;

-- 5.3 Sentiment score distribution in buckets
-- Creates a histogram-style breakdown of sentiment scores
-- Useful for understanding the shape of the sentiment distribution
SELECT
	ROUND(FLOOR(SENTIMENT_SCORE * 10) / 10, 1) AS SENTIMENT_BUCKET,
	COUNT(*) AS TWEET_COUNT,
	ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS PCT
FROM
	CLEAN_TWEETS
GROUP BY
	ROUND(FLOOR(SENTIMENT_SCORE * 10) / 10, 1)
ORDER BY
	SENTIMENT_BUCKET;

-- 5.4 Stance distribution overall
SELECT
	STANCE,
	COUNT(*) AS TOTAL,
	ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS PCT
FROM
	CLEAN_TWEETS
GROUP BY
	STANCE
ORDER BY
	TOTAL DESC;

-- 5.5 Aggressiveness distribution overall
SELECT
	AGGRESSIVENESS,
	COUNT(*) AS TOTAL,
	ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS PCT
FROM
	CLEAN_TWEETS
GROUP BY
	AGGRESSIVENESS
ORDER BY
	TOTAL DESC;

-- 5.6 Topic volume distribution
SELECT
	TOPIC,
	COUNT(*) AS TOTAL_TWEETS,
	ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS PCT,
	ROUND(AVG(SENTIMENT_SCORE), 4) AS AVG_SENTIMENT
FROM
	CLEAN_TWEETS
GROUP BY
	TOPIC
ORDER BY
	TOTAL_TWEETS DESC;

-- 5.7 Gender distribution
SELECT
	GENDER,
	COUNT(*) AS TOTAL,
	ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS PCT
FROM
	CLEAN_TWEETS
GROUP BY
	GENDER
ORDER BY
	TOTAL DESC;

-- 5.8 Geolocation coverage summary
SELECT
	HAS_COORDINATES,
	COUNT(*) AS TWEETS,
	ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS PCT
FROM
	CLEAN_TWEETS
GROUP BY
	HAS_COORDINATES;

-- 5.9 Continent distribution (geotagged tweets only)
SELECT
	CONTINENT,
	COUNT(*) AS TWEETS,
	ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS PCT
FROM
	CLEAN_TWEETS
WHERE
	CONTINENT NOT IN ('Unknown')
GROUP BY
	CONTINENT
ORDER BY
	TWEETS DESC;

-- 5.10 Sentiment summary statistics by stance
SELECT
	STANCE,
	COUNT(*) AS TWEETS,
	ROUND(MIN(SENTIMENT_SCORE), 4) AS MIN_SENTIMENT,
	ROUND(MAX(SENTIMENT_SCORE), 4) AS MAX_SENTIMENT,
	ROUND(AVG(SENTIMENT_SCORE), 4) AS AVG_SENTIMENT,
	ROUND(STDDEV(SENTIMENT_SCORE), 4) AS STDDEV_SENTIMENT,
	ROUND(
		PERCENTILE_CONT(0.5) WITHIN GROUP (
			ORDER BY
				SENTIMENT_SCORE
		)::NUMERIC,
		4
	) AS MEDIAN_SENTIMENT
FROM
	CLEAN_TWEETS
GROUP BY
	STANCE
ORDER BY
	TWEETS DESC;

-- ============================================================
-- PHASE 6: DIAGNOSTIC ANALYTICS
-- ============================================================
-- PURPOSE: Investigate relationships and patterns to explain
-- why certain trends or outcomes occur. Includes correlation
-- analysis, segmentation, and drill-down queries.
-- Directly addresses the two leadership questions:
--   Q1: How have sentiment and stance shifted over 14 years?
--   Q2: Which topics and regions drive the most divisive
--       or aggressive discourse?
-- ============================================================
-- 6.1 LEADERSHIP QUESTION 1: Yearly stance and sentiment shift
-- Shows the full 14-year trend with year-over-year changes
SELECT
	TWEET_YEAR,
	TOTAL_TWEETS,
	AVG_SENTIMENT,
	YOY_SENTIMENT_CHANGE,
	PCT_BELIEVERS,
	PCT_DENIERS,
	PCT_AGGRESSIVE
FROM
	VW_YEARLY_TRENDS
ORDER BY
	TWEET_YEAR;

-- 6.2 Sentiment trend with year-over-year change highlighted
-- Identifies which years saw the biggest sentiment shifts
SELECT
	TWEET_YEAR,
	ROUND(AVG(SENTIMENT_SCORE), 4) AS AVG_SENTIMENT,
	ROUND(
		AVG(SENTIMENT_SCORE) - LAG(AVG(SENTIMENT_SCORE)) OVER (
			ORDER BY
				TWEET_YEAR
		),
		4
	) AS YOY_CHANGE,
	CASE
		WHEN AVG(SENTIMENT_SCORE) - LAG(AVG(SENTIMENT_SCORE)) OVER (
			ORDER BY
				TWEET_YEAR
		) > 0 THEN 'Improving'
		WHEN AVG(SENTIMENT_SCORE) - LAG(AVG(SENTIMENT_SCORE)) OVER (
			ORDER BY
				TWEET_YEAR
		) < 0 THEN 'Declining'
		ELSE 'Stable'
	END AS DIRECTION
FROM
	CLEAN_TWEETS
GROUP BY
	TWEET_YEAR
ORDER BY
	TWEET_YEAR;

-- 6.3 LEADERSHIP QUESTION 2: Most divisive topics
-- Ranked by divisiveness score (1.0 = maximally divisive)
SELECT
	TOPIC,
	TOTAL_TWEETS,
	DIVISIVENESS_SCORE,
	PCT_AGGRESSIVE,
	AVG_SENTIMENT,
	SENTIMENT_VOLATILITY,
	BELIEVERS,
	DENIERS,
	PCT_BELIEVERS,
	PCT_DENIERS
FROM
	VW_TOPIC_ANALYSIS
ORDER BY
	DIVISIVENESS_SCORE DESC;

-- 6.4 Most aggressive topics ranked
SELECT
	TOPIC,
	TOTAL_TWEETS,
	PCT_AGGRESSIVE,
	AVG_SENTIMENT,
	DIVISIVENESS_SCORE
FROM
	VW_TOPIC_ANALYSIS
ORDER BY
	PCT_AGGRESSIVE DESC;

-- 6.5 Most aggressive regions ranked
SELECT
	CONTINENT,
	TOTAL_TWEETS,
	PCT_AGGRESSIVE,
	DIVISIVENESS_SCORE,
	AVG_SENTIMENT,
	AVG_TEMP_DEVIATION
FROM
	VW_REGIONAL_ANALYSIS
ORDER BY
	PCT_AGGRESSIVE DESC;

-- 6.6 Aggressiveness by stance
-- Diagnostic: are deniers or believers more aggressive?
SELECT
	STANCE,
	COUNT(*) AS TOTAL_TWEETS,
	SUM(
		CASE
			WHEN IS_AGGRESSIVE THEN 1
			ELSE 0
		END
	) AS AGGRESSIVE,
	ROUND(
		100.0 * SUM(
			CASE
				WHEN IS_AGGRESSIVE THEN 1
				ELSE 0
			END
		) / NULLIF(COUNT(*), 0),
		2
	) AS PCT_AGGRESSIVE,
	ROUND(AVG(SENTIMENT_SCORE), 4) AS AVG_SENTIMENT
FROM
	CLEAN_TWEETS
WHERE
	STANCE IN ('Believer', 'Denier', 'Neutral')
GROUP BY
	STANCE
ORDER BY
	PCT_AGGRESSIVE DESC;

-- 6.7 Aggressiveness by gender
SELECT
	GENDER,
	COUNT(*) AS TOTAL_TWEETS,
	ROUND(
		100.0 * SUM(
			CASE
				WHEN IS_AGGRESSIVE THEN 1
				ELSE 0
			END
		) / NULLIF(COUNT(*), 0),
		2
	) AS PCT_AGGRESSIVE,
	ROUND(AVG(SENTIMENT_SCORE), 4) AS AVG_SENTIMENT
FROM
	CLEAN_TWEETS
WHERE
	GENDER IN ('Male', 'Female')
GROUP BY
	GENDER;

-- 6.8 Pearson correlation coefficients
-- Measures strength of linear relationships between numeric variables
-- Range: -1 (perfect negative) to +1 (perfect positive), 0 = no relationship
SELECT
	ROUND(
		CORR(TEMPERATURE_AVG, SENTIMENT_SCORE)::NUMERIC,
		4
	) AS TEMP_VS_SENTIMENT,
	ROUND(
		CORR(TEMPERATURE_AVG, IS_AGGRESSIVE::INT)::NUMERIC,
		4
	) AS TEMP_VS_AGGRESSION,
	ROUND(
		CORR(SENTIMENT_SCORE, IS_AGGRESSIVE::INT)::NUMERIC,
		4
	) AS SENTIMENT_VS_AGGRESSION,
	COUNT(*) AS SAMPLE_SIZE
FROM
	CLEAN_TWEETS
WHERE
	TEMPERATURE_AVG IS NOT NULL
	AND SENTIMENT_SCORE IS NOT NULL;

-- 6.9 Continent and topic combination aggressiveness
-- Identifies which region-topic combinations are hotspots
SELECT
	CONTINENT,
	TOPIC,
	COUNT(*) AS TWEETS,
	ROUND(
		100.0 * SUM(
			CASE
				WHEN IS_AGGRESSIVE THEN 1
				ELSE 0
			END
		) / NULLIF(COUNT(*), 0),
		2
	) AS PCT_AGGRESSIVE,
	ROUND(AVG(SENTIMENT_SCORE), 4) AS AVG_SENTIMENT
FROM
	CLEAN_TWEETS
WHERE
	CONTINENT NOT IN ('Unknown', 'Other')
GROUP BY
	CONTINENT,
	TOPIC
HAVING
	COUNT(*) > 500
ORDER BY
	PCT_AGGRESSIVE DESC
LIMIT
	20;

-- 6.10 Temperature deviation vs sentiment by year
-- Explores whether higher temperature anomalies correlate
-- with more negative or more aggressive discourse
SELECT
	TWEET_YEAR,
	ROUND(AVG(TEMPERATURE_AVG), 3) AS AVG_TEMP_DEVIATION,
	ROUND(AVG(SENTIMENT_SCORE), 4) AS AVG_SENTIMENT,
	ROUND(
		AVG(
			CASE
				WHEN IS_AGGRESSIVE THEN 1.0
				ELSE 0.0
			END
		),
		4
	) AS AGGR_RATE,
	COUNT(*) AS GEOTAGGED_TWEETS
FROM
	CLEAN_TWEETS
WHERE
	TEMPERATURE_AVG IS NOT NULL
GROUP BY
	TWEET_YEAR
ORDER BY
	TWEET_YEAR;

-- 6.11 Stance shift by region over time
-- Who believes what, where, and how has it changed?
SELECT
	*
FROM
	VW_STANCE_BY_REGION
ORDER BY
	CONTINENT,
	TWEET_YEAR;

-- 6.12 Topic growth and decline over 14 years
-- Which topics dominated in which era?
SELECT
	TWEET_YEAR,
	TOPIC,
	TWEET_COUNT,
	VOLUME_RANK,
	AVG_SENTIMENT,
	PCT_AGGRESSIVE
FROM
	VW_TOPIC_YEARLY_TRENDS
WHERE
	VOLUME_RANK <= 3
ORDER BY
	TWEET_YEAR,
	VOLUME_RANK;

-- 6.13 Seasonal aggressiveness pattern
-- Does aggressiveness vary by season?
SELECT
	SEASON,
	SUM(TOTAL_TWEETS) AS TWEETS,
	ROUND(
		SUM(AVG_SENTIMENT * TOTAL_TWEETS) / SUM(TOTAL_TWEETS),
		4
	) AS WEIGHTED_AVG_SENTIMENT,
	ROUND(
		100.0 * SUM(AGGRESSIVE_COUNT) / SUM(TOTAL_TWEETS),
		2
	) AS PCT_AGGRESSIVE
FROM
	VW_MONTHLY_TRENDS
GROUP BY
	SEASON
ORDER BY
	PCT_AGGRESSIVE DESC;

-- 6.14 Pre and post Paris Agreement sentiment shift
-- Paris Agreement signed December 2015
-- Diagnostic: did the agreement affect public sentiment?
SELECT
	CASE
		WHEN TWEET_YEAR < 2015 THEN 'Pre-Paris (2006-2014)'
		WHEN TWEET_YEAR = 2015 THEN 'Paris Agreement Year (2015)'
		ELSE 'Post-Paris (2016-2022)'
	END AS PERIOD,
	COUNT(*) AS TWEETS,
	ROUND(AVG(SENTIMENT_SCORE), 4) AS AVG_SENTIMENT,
	ROUND(
		100.0 * SUM(
			CASE
				WHEN STANCE = 'Believer' THEN 1
				ELSE 0
			END
		) / COUNT(*),
		2
	) AS PCT_BELIEVERS,
	ROUND(
		100.0 * SUM(
			CASE
				WHEN IS_AGGRESSIVE THEN 1
				ELSE 0
			END
		) / COUNT(*),
		2
	) AS PCT_AGGRESSIVE
FROM
	CLEAN_TWEETS
GROUP BY
	CASE
		WHEN TWEET_YEAR < 2015 THEN 'Pre-Paris (2006-2014)'
		WHEN TWEET_YEAR = 2015 THEN 'Paris Agreement Year (2015)'
		ELSE 'Post-Paris (2016-2022)'
	END
ORDER BY
	MIN(TWEET_YEAR);

-- ============================================================
-- END OF SCRIPT
-- ============================================================
-- VIEWS CREATED (connect all of these in Power BI):
--   vw_kpi_summary              -> Executive overview KPI cards
--   vw_yearly_trends            -> Trend line charts over time
--   vw_monthly_trends           -> Monthly/seasonal patterns
--   vw_topic_analysis           -> Topic breakdown page
--   vw_topic_yearly_trends      -> Topic growth over time
--   vw_regional_analysis        -> Map and continent charts
--   vw_stance_by_region         -> Regional belief patterns
--   vw_gender_analysis          -> Gender comparison charts
--   vw_temp_sentiment           -> Temperature correlation
--   vw_aggressiveness_analysis  -> Aggressiveness drill-down
--	 vw_executive_insights		 -> Executive overview page in Power BI dashboard
-- ============================================================
-- DATASET REFERENCE:
-- Effrosynidis, D., Karas, A., Sylaios, G., & Arampatzis, A.
-- (2022). The Climate Change Twitter Dataset (Version 2).
-- Mendeley Data. https://doi.org/10.17632/mw8yd7z9wc.2
-- ============================================================