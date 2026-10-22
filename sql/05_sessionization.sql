WITH with_prev AS (
    SELECT user_id,
           event_timestamp,
           LAG(event_timestamp) OVER (
               PARTITION BY user_id
               ORDER BY event_timestamp
           ) AS prev_ts
    FROM events
),
flagged AS (
    SELECT user_id,
           event_timestamp,
           CASE
               WHEN prev_ts IS NULL
                 OR DATEDIFF('minute', prev_ts, event_timestamp) > 30
               THEN 1
               ELSE 0
           END AS new_session
    FROM with_prev
),
sessions AS (
    SELECT user_id,
           event_timestamp,
           SUM(new_session) OVER (
               PARTITION BY user_id
               ORDER BY event_timestamp
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS session_id
    FROM flagged
)
SELECT user_id,
       session_id,
       TO_CHAR(MIN(event_timestamp), 'YYYY-MM-DD HH24:MI:SS') AS session_start,
       TO_CHAR(MAX(event_timestamp), 'YYYY-MM-DD HH24:MI:SS') AS session_end,
       COUNT(*) AS event_count
FROM sessions
GROUP BY user_id, session_id
ORDER BY user_id, session_id;
