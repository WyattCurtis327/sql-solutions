WITH login_days AS (
    SELECT DISTINCT user_id, login_date
    FROM logins
),
numbered AS (
    SELECT user_id,
           login_date,
           ROW_NUMBER() OVER (
               PARTITION BY user_id
               ORDER BY login_date
           ) AS day_number
    FROM login_days
),
grouped AS (
    -- Shift each date back by day_number so consecutive dates share grp.
    SELECT user_id,
           login_date,
           DATEADD('day', -day_number, login_date) AS grp
    FROM numbered
)
SELECT user_id,
       MIN(login_date) AS streak_start,
       MAX(login_date) AS streak_end,
       COUNT(*) AS streak_days
FROM grouped
GROUP BY user_id, grp
HAVING COUNT(*) >= 3
ORDER BY user_id, streak_start;
