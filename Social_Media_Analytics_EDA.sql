-- CLEANING

CREATE OR REPLACE TABLE `portofolio-494904.socialmedia.social_media_clean` AS
SELECT
TRIM(SAFE_CAST(user_id AS STRING)) AS user_id,
SAFE_CAST(age AS INT64) AS age,
TRIM(SAFE_CAST(gender AS STRING)) AS gender,
TRIM(SAFE_CAST(country AS STRING)) AS country,
TRIM(SAFE_CAST(profession AS STRING)) AS profession,
TRIM(SAFE_CAST(primary_platform AS STRING)) AS primary_platform,

SAFE_CAST(platforms_used_count AS INT64) AS platforms_used_count,
SAFE_CAST(daily_usage_hours AS FLOAT64) AS daily_usage_hours,
SAFE_CAST(sessions_per_day AS INT64) AS sessions_per_day,
SAFE_CAST(avg_session_duration_min AS FLOAT64) AS avg_session_duration_min,

TRIM(SAFE_CAST(preferred_device AS STRING)) AS preferred_device,
TRIM(SAFE_CAST(peak_usage_time AS STRING)) AS peak_usage_time,

SAFE_CAST(followers_count AS INT64) AS followers_count,
SAFE_CAST(following_count AS INT64) AS following_count,
SAFE_CAST(posts_per_week AS FLOAT64) AS posts_per_week,
SAFE_CAST(likes_given_per_day AS FLOAT64) AS likes_given_per_day,
SAFE_CAST(comments_per_day AS FLOAT64) AS comments_per_day,
SAFE_CAST(shares_per_day AS FLOAT64) AS shares_per_day,
SAFE_CAST(dms_sent_per_day AS FLOAT64) AS dms_sent_per_day,

TRIM(SAFE_CAST(preferred_content_type AS STRING)) AS preferred_content_type,
TRIM(SAFE_CAST(scroll_speed AS STRING)) AS scroll_speed,

SAFE_CAST(ad_click_rate AS FLOAT64) AS ad_click_rate,
SAFE_CAST(purchased_via_social_media AS STRING) AS purchased_via_social_media,
SAFE_CAST(monthly_spend_via_social_usd AS FLOAT64) AS monthly_spend_via_social_usd,

TRIM(SAFE_CAST(primary_purpose AS STRING)) AS primary_purpose,

SAFE_CAST(sleep_disruption AS FLOAT64) AS sleep_disruption,
SAFE_CAST(self_reported_mental_health_score AS FLOAT64) AS self_reported_mental_health_score,
TRIM(SAFE_CAST(screen_time_concern AS STRING)) AS screen_time_concern,
TRIM(SAFE_CAST(notification_frequency AS STRING)) AS notification_frequency,
TRIM(SAFE_CAST(privacy_setting AS STRING)) AS privacy_setting,
TRIM(SAFE_CAST(influencer_status AS STRING)) AS influencer_status,

SAFE_CAST(account_join_date AS DATE) AS account_join_date,
TRIM(SAFE_CAST(mood_while_scrolling AS STRING)) AS mood_while_scrolling,
SAFE_CAST(takes_social_media_breaks AS BOOL) AS takes_social_media_breaks

FROM `portofolio-494904.socialmedia.social_media_user_behavior`
WHERE user_id IS NOT NULL;

-- FEATURE EGINEERING

CREATE OR REPLACE TABLE `portofolio-494904.socialmedia.social_media_enriched` AS
SELECT *,
--- User segmentation
CASE
  WHEN daily_usage_hours > 4 THEN 'Heavy'
  WHEN daily_usage_hours >= 2 THEN 'Medium'
  ELSE 'Light'
END AS user_segment,

--- Engagement score (custom metric)
(likes_given_per_day + comments_per_day + shares_per_day + dms_sent_per_day) AS total_engagement,

--- Usage category
CASE
  WHEN sessions_per_day >= 8 THEN 'High'
  WHEN sessions_per_day >= 4 THEN 'Medium'
  ELSE 'Low'
END AS session_category,

--- Clean time
    REGEXP_EXTRACT(
        peak_usage_time,
        r'\((.*?)\)'
    ) AS cleaned_time,

--- Age group
CASE
  WHEN age BETWEEN 13 AND 17 THEN '13-17'
  WHEN age BETWEEN 18 AND 24 THEN '18-24'
  WHEN age BETWEEN 25 AND 34 THEN '25-34'
  WHEN age BETWEEN 35 AND 44 THEN '35-44'
  ELSE '45+'
END AS age_group,

--- Monthly Spend Category
CASE
  WHEN monthly_spend_via_social_usd < 25 THEN 'Low Spender'
  WHEN monthly_spend_via_social_usd < 75 THEN 'Medium Spender'
  WHEN monthly_spend_via_social_usd < 150 THEN 'High Spender'
  ELSE 'Premium Spender'
END AS spending_category

FROM `portofolio-494904.socialmedia.social_media_clean`;

--TABLE FINAL

CREATE OR REPLACE TABLE `portofolio-494904.socialmedia.social_media_final` AS
SELECT
-- DIMENSION
primary_platform,
country,
gender,
user_segment,
age_group,
account_join_date,

-- METRICS
COUNT(*) AS total_users,
AVG(daily_usage_hours) AS avg_usage_hours,
AVG(sessions_per_day) AS avg_sessions,
SUM(monthly_spend_via_social_usd) AS revenue,

-- total engagement dihitung langsung
AVG(
  likes_given_per_day +
  comments_per_day +
  shares_per_day +
  dms_sent_per_day
) AS avg_engagement,

AVG(self_reported_mental_health_score) AS avg_mental_health,
AVG(monthly_spend_via_social_usd) AS avg_spend,
AVG(ad_click_rate) AS avg_ad_click_rate,

-- BUSINESS KPI
SAFE_DIVIDE(
  SUM(
    CASE
      WHEN LOWER(TRIM(purchased_via_social_media)) IN ('yes', 'sometimes')
      THEN 1
      ELSE 0
    END
  ),
  CAST(COUNT(*) AS FLOAT64)
) AS purchase_rate,

--- SPEND PER PURCHASED
SAFE_DIVIDE(
  SUM(monthly_spend_via_social_usd),

  SUM(
    CASE
      WHEN LOWER(TRIM(purchased_via_social_media))
           IN ('yes','sometimes')
      THEN 1
      ELSE 0
    END
  )
) AS spend_per_purchase,

---USER ACTIVITY
CASE
  WHEN (
  likes_given_per_day +
  comments_per_day +
  shares_per_day +
  dms_sent_per_day) >= 50 THEN 'Active User'
  ELSE 'Passive User'
  END AS user_activity_type,

FROM `portofolio-494904.socialmedia.social_media_enriched`
GROUP BY
primary_platform, country, gender, user_segment, age_group, account_join_date, user_activity_type;

-- CHART
---USAGE VS MENSELECT
SELECT
ROUND(SAFE_CAST(daily_usage_hours AS FLOAT64), 0) AS usage_group,
AVG(self_reported_mental_health_score) AS avg_mental_health
FROM `portofolio-494904.socialmedia.social_media_enriched`
GROUP BY usage_group
ORDER BY usage_group;

---PLATFORM PERFORMANCE
SELECT
primary_platform,
AVG(
  likes_given_per_day +
  comments_per_day +
  shares_per_day +
  dms_sent_per_day
) AS engagement,
AVG(monthly_spend_via_social_usd) AS spend
FROM `portofolio-494904.socialmedia.social_media_enriched`
GROUP BY primary_platform
ORDER BY engagement DESC;

---USER SEGMENT ANALYSIS
SELECT
user_segment,
AVG(
  likes_given_per_day +
  comments_per_day +
  shares_per_day +
  dms_sent_per_day
) AS engagement,
AVG(monthly_spend_via_social_usd) AS spend,
AVG(self_reported_mental_health_score) AS mental_health
FROM `portofolio-494904.socialmedia.social_media_enriched`
GROUP BY user_segment;
