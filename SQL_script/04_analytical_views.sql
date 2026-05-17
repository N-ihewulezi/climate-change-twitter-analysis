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