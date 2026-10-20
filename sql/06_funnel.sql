WITH user_stats AS (
    SELECT u.user_id,
           COUNT(e.event_id) AS event_count,
           COUNT(e.event_id) FILTER (WHERE e.event_type = 'purchase') AS purchase_count
    FROM users u
    LEFT JOIN events e ON u.user_id = e.user_id
    GROUP BY u.user_id
),
funnel AS (
    SELECT 1 AS stage_order, 'signup' AS stage, COUNT(*) AS users_count FROM user_stats
    UNION ALL
    SELECT 2, 'activate', COUNT(*) FILTER (WHERE event_count >= 1) FROM user_stats
    UNION ALL
    SELECT 3, 'engage',   COUNT(*) FILTER (WHERE event_count >= 5) FROM user_stats
    UNION ALL
    SELECT 4, 'convert',  COUNT(*) FILTER (WHERE purchase_count >= 1) FROM user_stats
),
funnel_with_prev AS (
    SELECT stage_order, stage, users_count,
           LAG(users_count) OVER (ORDER BY stage_order) AS prev_count
    FROM funnel
)
SELECT stage,
       users_count,
       CASE WHEN stage_order = 1 THEN 0.0
            ELSE ROUND(users_count * 100.0 / NULLIF(prev_count, 0), 2)
       END AS conversion_from_prev,
       ROUND(users_count * 100.0
             / MAX(users_count) FILTER (WHERE stage_order = 1) OVER (), 2) AS cumulative_conversion
FROM funnel_with_prev
ORDER BY stage_order;
