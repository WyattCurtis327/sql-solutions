WITH cohorts AS (
    SELECT user_id,
           DATE_TRUNC('month', MIN(transaction_date))::DATE AS cohort_month
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
           DATE_TRUNC('month', t.transaction_date)::DATE AS activity_month
    FROM transactions t
    JOIN cohorts c ON t.user_id = c.user_id
),
monthly AS (
    SELECT a.cohort_month,
           DATEDIFF('month', a.cohort_month, a.activity_month) AS month_number,
           COUNT(DISTINCT a.user_id) AS active_users,
           cs.cohort_users
    FROM activity a
    JOIN cohort_size cs ON a.cohort_month = cs.cohort_month
    GROUP BY a.cohort_month,
             DATEDIFF('month', a.cohort_month, a.activity_month),
             cs.cohort_users
)
SELECT TO_CHAR(cohort_month, 'YYYY-MM') AS cohort_month,
       month_number,
       active_users,
       ROUND(active_users * 100.0 / cohort_users, 2) AS retention_rate
FROM monthly
ORDER BY cohort_month, month_number;
