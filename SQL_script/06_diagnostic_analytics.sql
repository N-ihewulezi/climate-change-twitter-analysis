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
