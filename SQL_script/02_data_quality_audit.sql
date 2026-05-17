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