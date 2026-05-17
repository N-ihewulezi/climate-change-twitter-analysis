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