USE Waze;
GO

/* =================================================================================
   WAZE USER RETENTION & ENGAGEMENT MASTER AUDIT (2025)
   Prepared for: Portfolio / Executive Presentation
   Description: A comprehensive multi-stage audit of user attrition and behavioral friction.
   ================================================================================= */

-- 1. THE ENGAGEMENT GAP (PASSIVE VS. ACTIVE USERS)
SELECT 
    label,
    ROUND(AVG(driving_days), 2) AS avg_driving_days,
    ROUND(AVG(activity_days), 2) AS avg_activity_days,
    ROUND(AVG(driving_days * 1.0 / NULLIF(activity_days, 0)), 3) AS engagement_ratio
FROM dbo.waze_dataset
WHERE label IS NOT NULL
GROUP BY label;

-- 2. THE COMMUTER THRESHOLD (RETENTION MOAT)
WITH DriverSegments AS (
    SELECT label,
           CASE WHEN driven_km_drives < 500 THEN 'Short Distance (<500km)'
                WHEN driven_km_drives BETWEEN 500 AND 2000 THEN 'Medium Distance (500-2k)'
                ELSE 'Long Distance (2k+)' END AS driver_type
    FROM dbo.waze_dataset WHERE label IS NOT NULL
)
SELECT driver_type, COUNT(*) AS total_users,
       ROUND(SUM(CASE WHEN label = 'churned' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_pct
FROM DriverSegments GROUP BY driver_type ORDER BY churn_rate_pct DESC;

-- 3. THE FAVORITES PARADOX (UTILITY FRICTION)
SELECT 
    CASE WHEN (total_navigations_fav1 + total_navigations_fav2) = 0 THEN 'No Favorites Used' ELSE 'Active Favorites' END AS usage_type,
    COUNT(*) AS user_count,
    ROUND(SUM(CASE WHEN label = 'churned' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_pct
FROM dbo.waze_dataset WHERE label IS NOT NULL
GROUP BY CASE WHEN (total_navigations_fav1 + total_navigations_fav2) = 0 THEN 'No Favorites Used' ELSE 'Active Favorites' END;

-- 4. TRAFFIC FRUSTRATION INDEX (AVG SPEED ESTIMATE)
SELECT label,
       ROUND(AVG(driven_km_drives / NULLIF((duration_minutes_drives / 60.0), 0)), 2) AS avg_km_h
FROM dbo.waze_dataset WHERE label IS NOT NULL AND duration_minutes_drives > 0
GROUP BY label;

-- 5. SEARCH FRUSTRATION (SESSIONS PER DRIVE)
SELECT label,
       ROUND(AVG(sessions * 1.0 / NULLIF(driving_days, 0)), 2) AS sessions_per_driving_day
FROM dbo.waze_dataset WHERE label IS NOT NULL
GROUP BY label;

-- 6. THE 4-YEAR VETERAN PEAK (TENURE BUCKETING)
WITH TenureBuckets AS (
    SELECT label,
           CASE WHEN n_days_after_onboarding < 365 THEN '1. New (<1yr)'
                WHEN n_days_after_onboarding BETWEEN 365 AND 1095 THEN '2. Established (1-3yrs)'
                WHEN n_days_after_onboarding BETWEEN 1095 AND 1825 THEN '3. Veteran (3-5yrs)'
                ELSE '4. Legacy (5yrs+)' END AS tenure_group
    FROM dbo.waze_dataset WHERE label IS NOT NULL
)
SELECT tenure_group, COUNT(*) AS total_users,
       ROUND(SUM(CASE WHEN label = 'churned' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_pct
FROM TenureBuckets GROUP BY tenure_group ORDER BY tenure_group;

-- 7. ONBOARDING HOOK ANALYSIS (NEW USERS ONLY)
SELECT 
    CASE WHEN (total_navigations_fav1 + total_navigations_fav2) > 0 THEN 'New User + Hook (Favs)' ELSE 'New User + No Hook' END AS adoption_status,
    ROUND(SUM(CASE WHEN label = 'churned' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_pct
FROM dbo.waze_dataset WHERE label IS NOT NULL AND n_days_after_onboarding < 365
GROUP BY CASE WHEN (total_navigations_fav1 + total_navigations_fav2) > 0 THEN 'New User + Hook (Favs)' ELSE 'New User + No Hook' END;

-- 8. THE GHOST SEGMENT (ACTIVE BUT NOT DRIVING)
SELECT label, COUNT(*) AS ghost_user_count, AVG(n_days_after_onboarding) AS avg_tenure
FROM dbo.waze_dataset WHERE driving_days = 0 AND activity_days > 5 AND label IS NOT NULL
GROUP BY label;

-- 9. DEVICE RELIABILITY AUDIT
SELECT device, COUNT(*) AS total_users,
       ROUND(SUM(CASE WHEN label = 'churned' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_pct
FROM dbo.waze_dataset WHERE label IS NOT NULL GROUP BY device;

-- 10. PRO-DRIVER SENSITIVITY (SKEW CHECK)
WITH DistPerc AS (SELECT *, PERCENT_RANK() OVER (ORDER BY driven_km_drives) AS p FROM dbo.waze_dataset WHERE label IS NOT NULL)
SELECT CASE WHEN p < 0.95 THEN 'Civilian (Bottom 95%)' ELSE 'Pro (Top 5%)' END AS user_group,
       ROUND(SUM(CASE WHEN label = 'churned' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_pct
FROM DistPerc GROUP BY CASE WHEN p < 0.95 THEN 'Civilian (Bottom 95%)' ELSE 'Pro (Top 5%)' END;