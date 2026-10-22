# SQL Solutions: 12 SQL Patterns
PostgreSQL

## Contents

- [1. Deduplication (ROW_NUMBER)](#1-deduplication-rownumber)
- [2. Running total](#2-running-total)
- [3. Year-over-year growth (LAG)](#3-year-over-year-growth-lag)
- [4. Gaps and islands](#4-gaps-and-islands)
- [5. Sessionization](#5-sessionization)
- [6. Funnel analysis](#6-funnel-analysis)
- [7. Retention cohorts](#7-retention-cohorts)
- [8. Top-N per group](#8-top-n-per-group)
- [9. Pivot (conditional aggregation)](#9-pivot-conditional-aggregation)
- [10. Self join (employee to manager)](#10-self-join-employee-to-manager)
- [11. Recursive hierarchy (WITH RECURSIVE)](#11-recursive-hierarchy-with-recursive)
- [12. 7-day moving average](#12-7-day-moving-average)
- [How to run](#how-to-run)

## Patterns

### 1. Deduplication (ROW_NUMBER)

Source: [`sql/01_dedup.sql`](sql/01_dedup.sql)

```sql
WITH ranked AS (
    SELECT customer_id, email, name, phone, updated_at,
           ROW_NUMBER() OVER (
               PARTITION BY email
               ORDER BY updated_at DESC, customer_id ASC
           ) AS rn
    FROM customers
)
SELECT customer_id, email, name, phone, updated_at,
       CASE WHEN email IS NULL OR rn = 1 THEN 0 ELSE 1 END AS is_duplicate
FROM ranked
ORDER BY customer_id;
```

### 2. Running total

Source: [`sql/02_running_total.sql`](sql/02_running_total.sql)

```sql
SELECT gender,
       day,
       SUM(score_points) OVER (
           PARTITION BY gender
           ORDER BY day, ctid
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS total
FROM scores
ORDER BY gender, day, ctid;
```

### 3. Year-over-year growth (LAG)

Source: [`sql/03_yoy_growth.sql`](sql/03_yoy_growth.sql)

```sql
WITH yearly_hosts AS (
    SELECT EXTRACT(YEAR FROM signup_date)::int AS signup_year,
           COUNT(*) AS new_hosts
    FROM hosts
    GROUP BY EXTRACT(YEAR FROM signup_date)::int
),
host_growth AS (
    SELECT signup_year,
           new_hosts,
           LAG(new_hosts) OVER (ORDER BY signup_year) AS prev_year_hosts
    FROM yearly_hosts
)
SELECT signup_year,
       new_hosts,
       prev_year_hosts,
       ROUND((new_hosts - prev_year_hosts) * 100.0 / NULLIF(prev_year_hosts, 0), 2) AS growth_pct
FROM host_growth
ORDER BY signup_year;
```

### 4. Gaps and islands

Source: [`sql/04_gaps_islands.sql`](sql/04_gaps_islands.sql)

```sql
WITH login_days AS (
    SELECT DISTINCT user_id, login_date
    FROM logins
),
grouped AS (
    SELECT user_id,
           login_date,
           login_date - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date))::int AS grp
    FROM login_days
)
SELECT user_id,
       MIN(login_date) AS streak_start,
       MAX(login_date) AS streak_end,
       COUNT(*)        AS streak_days
FROM grouped
GROUP BY user_id, grp
HAVING COUNT(*) >= 3
ORDER BY user_id, streak_start;
```

### 5. Sessionization

Source: [`sql/05_sessionization.sql`](sql/05_sessionization.sql)

```sql
WITH with_prev AS (
    SELECT user_id,
           event_timestamp,
           LAG(event_timestamp) OVER (PARTITION BY user_id ORDER BY event_timestamp) AS prev_ts
    FROM events
),
flagged AS (
    SELECT user_id,
           event_timestamp,
           CASE WHEN prev_ts IS NULL
                  OR event_timestamp - prev_ts > INTERVAL '30 minutes'
                THEN 1 ELSE 0 END AS new_session
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
```

### 6. Funnel analysis

Source: [`sql/06_funnel.sql`](sql/06_funnel.sql)

```sql
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
```

### 7. Retention cohorts

Source: [`sql/07_retention_cohorts.sql`](sql/07_retention_cohorts.sql)

```sql
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
```

### 8. Top-N per group

Source: [`sql/08_top_n_per_group.sql`](sql/08_top_n_per_group.sql)

```sql
WITH product_revenue AS (
    SELECT region, product_name, SUM(revenue) AS total_revenue
    FROM sales
    GROUP BY region, product_name
),
ranked_products AS (
    SELECT region, product_name, total_revenue,
           DENSE_RANK() OVER (PARTITION BY region ORDER BY total_revenue DESC) AS region_rank
    FROM product_revenue
)
SELECT *
FROM ranked_products
WHERE region_rank <= 3
ORDER BY region, region_rank, product_name;
```

### 9. Pivot (conditional aggregation)

Source: [`sql/09_pivot.sql`](sql/09_pivot.sql)

```sql
SELECT product,
       ROUND(COALESCE(SUM(amount) FILTER (WHERE region = 'North'), 0), 2) AS north,
       ROUND(COALESCE(SUM(amount) FILTER (WHERE region = 'South'), 0), 2) AS south,
       ROUND(COALESCE(SUM(amount) FILTER (WHERE region = 'East'),  0), 2) AS east,
       ROUND(COALESCE(SUM(amount) FILTER (WHERE region = 'West'),  0), 2) AS west
FROM sales
GROUP BY product
ORDER BY product;
```

### 10. Self join (employee to manager)

Source: [`sql/10_self_join.sql`](sql/10_self_join.sql)

```sql
SELECT e.name AS employee_name,
       m.name AS manager_name
FROM employees e
JOIN employees m ON e.manager_id = m.employee_id
WHERE e.salary > m.salary
ORDER BY e.employee_id;
```

### 11. Recursive hierarchy (WITH RECURSIVE)

Source: [`sql/11_recursive_hierarchy.sql`](sql/11_recursive_hierarchy.sql)

```sql
WITH RECURSIVE reports AS (
    -- anchor: the top manager (no manager of their own) at level 0
    SELECT employee_id, 0 AS level
    FROM employees
    WHERE manager_id IS NULL
    UNION ALL
    -- recursive step: anyone whose manager is already in the result
    SELECT e.employee_id, r.level + 1
    FROM employees e
    JOIN reports r ON e.manager_id = r.employee_id
    WHERE r.level < 100          -- depth guard against cycles
)
SELECT employee_id
FROM reports
WHERE level > 0
ORDER BY employee_id;
```

### 12. 7-day moving average

Source: [`sql/12_moving_average.sql`](sql/12_moving_average.sql)

```sql
WITH daily AS (
    SELECT visit_date, SUM(amount) AS daily_total
    FROM customer_visits
    GROUP BY visit_date
),
moving_avg AS (
    SELECT visit_date,
           daily_total,
           ROUND(AVG(daily_total) OVER (
               ORDER BY visit_date
               ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
           ), 2) AS avg_amount,
           ROW_NUMBER() OVER (ORDER BY visit_date) AS rn
    FROM daily
)
SELECT visit_date, daily_total, avg_amount
FROM moving_avg
WHERE rn >= 7
ORDER BY visit_date;
```

## How to run

The scripts target **PostgreSQL**. Load the example tables from the video, then run a file:

```bash
psql -d yourdb -f sql/01_dedup.sql
```

### Tested in DuckDB
`sql/test_duckdb.py` loads the example data from the video into DuckDB and runs all 12 queries (tested on DuckDB 1.5.5). All 12 reproduce the outputs shown in the video. The test needs two swaps for DuckDB, and it applies them on its own:
- `ctid` → `rowid`
- `TO_CHAR(...)` → `strftime(...)`

```bash
pip install duckdb
cd sql && python test_duckdb.py
```
