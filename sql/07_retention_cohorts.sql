WITH cohorts AS (
    SELECT user_id,
           DATE_TRUNC('month', MIN(transaction_date))::date AS cohort_month
    FROM transactions
    GROUP BY user_id
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS cohort_users
    FROM cohorts
    GROUP BY cohort_month
),
activity AS (
    SELECT t.user_id,
           c.cohort_month,
           DATE_TRUNC('month', t.transaction_date)::date AS activity_month
    FROM transactions t
    JOIN cohorts c ON t.user_id = c.user_id
)
SELECT TO_CHAR(a.cohort_month, 'YYYY-MM') AS cohort_month,
       ((EXTRACT(YEAR FROM a.activity_month) - EXTRACT(YEAR FROM a.cohort_month)) * 12
        + (EXTRACT(MONTH FROM a.activity_month) - EXTRACT(MONTH FROM a.cohort_month)))::int AS month_number,
       COUNT(DISTINCT a.user_id) AS active_users,
       ROUND(COUNT(DISTINCT a.user_id) * 100.0 / cs.cohort_users, 2) AS retention_rate
FROM activity a
JOIN cohort_size cs ON a.cohort_month = cs.cohort_month
GROUP BY a.cohort_month, a.activity_month, cs.cohort_users
ORDER BY cohort_month, month_number;
