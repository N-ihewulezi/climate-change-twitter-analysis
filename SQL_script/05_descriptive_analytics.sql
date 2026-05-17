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
