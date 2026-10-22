# SQL Solutions: 12 SQL Patterns

Snowflake

Twelve interview-style SQL patterns, written for Snowflake: deduplication, running totals, year-over-year growth, gaps and islands, sessionization, funnels, retention, top-N, pivots, a self join, a recursive hierarchy, and a moving average.

Each pattern below has a small sample, the query, and the result of running that query on the sample. Load scripts are in [`data/`](data/). Several patterns reuse a table name (`events`, `sales`, `employees`). Every script starts with `CREATE OR REPLACE TABLE`, so load one pattern at a time.

## How to load sample data in Snowflake

In a worksheet, run the pattern's load script, then its query. From SnowSQL, against a database and schema where you can create tables:

```bash
snowsql -d YOUR_DB -s YOUR_SCHEMA -f data/01_customers.sql
snowsql -d YOUR_DB -s YOUR_SCHEMA -f sql/01_dedup.sql
```

The scripts are ordinary `CREATE TABLE` and `INSERT` statements.

## Contents

- [1. Deduplication (ROW_NUMBER)](#1-deduplication-row_number)
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
- [Postgres -> Snowflake changes](#postgres---snowflake-changes)
- [Tests](#tests)

## Patterns

### 1. Deduplication (ROW_NUMBER)

Keep one row per email: the latest `updated_at`, then the smaller `customer_id` when that timestamp ties. Bob B (id 4) stays and Bob Beta (id 5) is marked duplicate, even though both were updated on 2024-01-25. NULL emails fall in one window partition, and the CASE still leaves `is_duplicate` at 0 for every NULL email, so a missing address is not treated as a repeated key.

**Source dataset:** `customers` ([`data/01_customers.sql`](data/01_customers.sql))

| customer_id | email             | name        | phone    | updated_at |
| ----------- | ----------------- | ----------- | -------- | ---------- |
| 1           | alice@example.com | Alice A     | 555-1001 | 2024-01-10 |
| 2           | alice@example.com | Alice Smith | 555-1002 | 2024-02-01 |
| 3           | bob@example.com   | Bob Brown   | 555-2002 | 2024-01-05 |
| 4           | bob@example.com   | Bob B       | 555-2002 | 2024-01-25 |
| 5           | bob@example.com   | Bob Beta    | 555-2099 | 2024-01-25 |
| 6           | carol@example.com | Carol C     | 555-3003 | 2024-03-01 |
| 7           | NULL              | Unknown One | 555-0001 | 2024-01-17 |
| 8           | NULL              | Unknown Two | 555-0002 | 2024-01-18 |

**Query** ([`sql/01_dedup.sql`](sql/01_dedup.sql)):

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

**Output dataset:**

| customer_id | email             | name        | phone    | updated_at | is_duplicate |
| ----------- | ----------------- | ----------- | -------- | ---------- | ------------ |
| 1           | alice@example.com | Alice A     | 555-1001 | 2024-01-10 | 1            |
| 2           | alice@example.com | Alice Smith | 555-1002 | 2024-02-01 | 0            |
| 3           | bob@example.com   | Bob Brown   | 555-2002 | 2024-01-05 | 1            |
| 4           | bob@example.com   | Bob B       | 555-2002 | 2024-01-25 | 0            |
| 5           | bob@example.com   | Bob Beta    | 555-2099 | 2024-01-25 | 1            |
| 6           | carol@example.com | Carol C     | 555-3003 | 2024-03-01 | 0            |
| 7           | NULL              | Unknown One | 555-0001 | 2024-01-17 | 0            |
| 8           | NULL              | Unknown Two | 555-0002 | 2024-01-18 | 0            |

### 2. Running total

Running sum of `score_points` within each gender, ordered by `day`. Bob and Charlie both play on day 1. `score_id` breaks that tie, so Bob's 15 is applied before Charlie's 12 and the two male day-1 totals are 15 then 27. The output does not repeat `score_id`; the source table shows which row came first.

**Source dataset:** `scores` ([`data/02_scores.sql`](data/02_scores.sql))

| score_id | player_name | gender | day | score_points |
| -------- | ----------- | ------ | --- | ------------ |
| 1        | Ava         | F      | 1   | 10           |
| 2        | Bea         | F      | 2   | 20           |
| 3        | Cleo        | F      | 3   | 15           |
| 4        | Bob         | M      | 1   | 15           |
| 5        | Charlie     | M      | 1   | 12           |
| 6        | Ed          | M      | 2   | 18           |
| 7        | Dee         | F      | 4   | 25           |
| 8        | Gus         | M      | 3   | 22           |

**Query** ([`sql/02_running_total.sql`](sql/02_running_total.sql)):

```sql
SELECT gender,
       day,
       SUM(score_points) OVER (
           PARTITION BY gender
           ORDER BY day, score_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS total
FROM scores
ORDER BY gender, day, score_id;
```

**Output dataset:**

| gender | day | total |
| ------ | --- | ----- |
| F      | 1   | 10    |
| F      | 2   | 30    |
| F      | 3   | 45    |
| F      | 4   | 70    |
| M      | 1   | 15    |
| M      | 1   | 27    |
| M      | 2   | 45    |
| M      | 3   | 67    |

### 3. Year-over-year growth (LAG)

Count new hosts per calendar year and compare each year, with `LAG`, to the previous year that has any signups. 2022 is absent, so 2023 is compared with 2021 (4 versus 2, +100%), not with a filled-in zero. 2020 has no baseline, so `prev_year_hosts` and `growth_pct` are NULL. 2024 falls from 4 hosts to 1.

**Source dataset:** `hosts` ([`data/03_hosts.sql`](data/03_hosts.sql))

| host_id | host_name | country | signup_date |
| ------- | --------- | ------- | ----------- |
| 1       | Ana       | US      | 2020-01-15  |
| 2       | Ben       | US      | 2020-06-01  |
| 3       | Cia       | CA      | 2020-11-20  |
| 4       | Dan       | US      | 2021-02-01  |
| 5       | Eve       | UK      | 2021-08-08  |
| 6       | Fay       | US      | 2023-01-05  |
| 7       | Gus       | US      | 2023-03-03  |
| 8       | Hal       | CA      | 2023-07-07  |
| 9       | Ivy       | UK      | 2023-12-01  |
| 10      | Joe       | US      | 2024-01-01  |

**Query** ([`sql/03_yoy_growth.sql`](sql/03_yoy_growth.sql)):

```sql
WITH yearly_hosts AS (
    SELECT YEAR(signup_date) AS signup_year,
           COUNT(*) AS new_hosts
    FROM hosts
    GROUP BY YEAR(signup_date)
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

**Output dataset:**

| signup_year | new_hosts | prev_year_hosts | growth_pct |
| ----------- | --------- | --------------- | ---------- |
| 2020        | 3         | NULL            | NULL       |
| 2021        | 2         | 3               | -33.33     |
| 2023        | 4         | 2               | 100.00     |
| 2024        | 1         | 4               | -75.00     |

### 4. Gaps and islands

Collapse logins to one row per user per day, number those days, and shift each date back by its number with `DATEADD`. Consecutive dates land on the same group key; a gap starts a new group. Streaks shorter than 3 days are dropped. User 1's second login on Jan 2 does not lengthen the streak, and the missing Jan 4 ends it, so Jan 5–6 is excluded. User 2 and user 4 never reach 3 days. User 3 has two separate streaks, Feb 1–3 and Feb 10–12.

**Source dataset:** `logins` ([`data/04_logins.sql`](data/04_logins.sql))

| login_id | user_id | login_date |
| -------- | ------- | ---------- |
| 1        | 1       | 2024-01-01 |
| 2        | 1       | 2024-01-02 |
| 3        | 1       | 2024-01-02 |
| 4        | 1       | 2024-01-03 |
| 5        | 1       | 2024-01-05 |
| 6        | 1       | 2024-01-06 |
| 7        | 2       | 2024-01-01 |
| 8        | 3       | 2024-02-01 |
| 9        | 3       | 2024-02-02 |
| 10       | 3       | 2024-02-03 |
| 11       | 3       | 2024-02-10 |
| 12       | 3       | 2024-02-11 |
| 13       | 3       | 2024-02-12 |
| 14       | 4       | 2024-03-01 |
| 15       | 4       | 2024-03-02 |

**Query** ([`sql/04_gaps_islands.sql`](sql/04_gaps_islands.sql)):

```sql
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
```

**Output dataset:**

| user_id | streak_start | streak_end | streak_days |
| ------- | ------------ | ---------- | ----------- |
| 1       | 2024-01-01   | 2024-01-03 | 3           |
| 3       | 2024-02-01   | 2024-02-03 | 3           |
| 3       | 2024-02-10   | 2024-02-12 | 3           |

### 5. Sessionization

A session starts when a user has no previous event, or when `DATEDIFF('minute', prev_ts, event_timestamp)` is greater than 30. `DATEDIFF` counts minute boundaries. Every sample timestamp is on a whole minute, so a gap of exactly 30 minutes stays in the session and 31 minutes opens a new one. User 101's 09:10 to 09:40 gap stays in session 1 (three events); 09:40 to 10:11 opens session 2; the noon event is session 3 by itself. User 202 splits once. User 303 has a single event.

**Source dataset:** `events` ([`data/05_events.sql`](data/05_events.sql))

| event_id | user_id | event_type | event_timestamp     |
| -------- | ------- | ---------- | ------------------- |
| 1        | 101     | page_view  | 2024-01-15 09:00:00 |
| 2        | 101     | click      | 2024-01-15 09:10:00 |
| 3        | 101     | page_view  | 2024-01-15 09:40:00 |
| 4        | 101     | click      | 2024-01-15 10:11:00 |
| 5        | 101     | purchase   | 2024-01-15 10:20:00 |
| 6        | 101     | page_view  | 2024-01-15 12:00:00 |
| 7        | 202     | page_view  | 2024-01-15 09:00:00 |
| 8        | 202     | click      | 2024-01-15 09:29:00 |
| 9        | 202     | page_view  | 2024-01-15 10:00:00 |
| 10       | 303     | page_view  | 2024-01-16 08:00:00 |

**Query** ([`sql/05_sessionization.sql`](sql/05_sessionization.sql)):

```sql
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
```

**Output dataset:**

| user_id | session_id | session_start       | session_end         | event_count |
| ------- | ---------- | ------------------- | ------------------- | ----------- |
| 101     | 1          | 2024-01-15 09:00:00 | 2024-01-15 09:40:00 | 3           |
| 101     | 2          | 2024-01-15 10:11:00 | 2024-01-15 10:20:00 | 2           |
| 101     | 3          | 2024-01-15 12:00:00 | 2024-01-15 12:00:00 | 1           |
| 202     | 1          | 2024-01-15 09:00:00 | 2024-01-15 09:29:00 | 2           |
| 202     | 2          | 2024-01-15 10:00:00 | 2024-01-15 10:00:00 | 1           |
| 303     | 1          | 2024-01-16 08:00:00 | 2024-01-16 08:00:00 | 1           |

### 6. Funnel analysis

Signup is every row in `users`. Activate means at least one event, engage means at least five, and convert means at least one purchase. The stages are counted separately, not as a nested path. User 2 has five views and no purchase, so they are in engage and not in convert. User 3 has one purchase and no other events, so they are in convert and not in engage. Both of those stages are 2 users, and the step from engage to convert is 100% even though the people differ. User 5 signed up and did nothing else. Cumulative conversion divides each stage by the 5 signups.

**Source dataset:** `users` ([`data/06_funnel.sql`](data/06_funnel.sql))

| user_id | signup_date |
| ------- | ----------- |
| 1       | 2024-01-01  |
| 2       | 2024-01-02  |
| 3       | 2024-01-03  |
| 4       | 2024-01-04  |
| 5       | 2024-01-05  |

**Source dataset:** `events` ([`data/06_funnel.sql`](data/06_funnel.sql))

| event_id | user_id | event_type | event_date |
| -------- | ------- | ---------- | ---------- |
| 1        | 1       | view       | 2024-01-02 |
| 2        | 1       | view       | 2024-01-02 |
| 3        | 1       | click      | 2024-01-03 |
| 4        | 1       | click      | 2024-01-03 |
| 5        | 1       | purchase   | 2024-01-04 |
| 6        | 2       | view       | 2024-01-02 |
| 7        | 2       | view       | 2024-01-02 |
| 8        | 2       | view       | 2024-01-03 |
| 9        | 2       | view       | 2024-01-03 |
| 10       | 2       | view       | 2024-01-04 |
| 11       | 3       | purchase   | 2024-01-05 |
| 12       | 4       | click      | 2024-01-06 |
| 13       | 4       | click      | 2024-01-06 |

**Query** ([`sql/06_funnel.sql`](sql/06_funnel.sql)):

```sql
WITH user_stats AS (
    SELECT u.user_id,
           COUNT(e.event_id) AS event_count,
           COUNT_IF(e.event_type = 'purchase') AS purchase_count
    FROM users u
    LEFT JOIN events e ON u.user_id = e.user_id
    GROUP BY u.user_id
),
funnel AS (
    SELECT 1 AS stage_order, 'signup' AS stage, COUNT(*) AS users_count
    FROM user_stats
    UNION ALL
    SELECT 2, 'activate', COUNT_IF(event_count >= 1)
    FROM user_stats
    UNION ALL
    SELECT 3, 'engage', COUNT_IF(event_count >= 5)
    FROM user_stats
    UNION ALL
    SELECT 4, 'convert', COUNT_IF(purchase_count >= 1)
    FROM user_stats
),
funnel_with_prev AS (
    SELECT stage_order,
           stage,
           users_count,
           LAG(users_count) OVER (ORDER BY stage_order) AS prev_count
    FROM funnel
)
SELECT stage,
       users_count,
       CASE
           WHEN stage_order = 1 THEN 0.0
           ELSE ROUND(users_count * 100.0 / NULLIF(prev_count, 0), 2)
       END AS conversion_from_prev,
       ROUND(
           users_count * 100.0
           / MAX(IFF(stage_order = 1, users_count, NULL)) OVER (),
           2
       ) AS cumulative_conversion
FROM funnel_with_prev
ORDER BY stage_order;
```

**Output dataset:**

| stage    | users_count | conversion_from_prev | cumulative_conversion |
| -------- | ----------- | -------------------- | --------------------- |
| signup   | 5           | 0.00                 | 100.00                |
| activate | 4           | 80.00                | 80.00                 |
| engage   | 2           | 50.00                | 40.00                 |
| convert  | 2           | 100.00               | 40.00                 |

### 7. Retention cohorts

A user's cohort month is the month of their first transaction. `month_number` is the number of months from that month to the month of each later transaction. Two January rows for user 1 still count as one active user. User 2 skips February and returns in March, so the January cohort goes 3, then 1, then 2. User 5 skips March. Users 3 and 6 appear only in month 0.

**Source dataset:** `transactions` ([`data/07_transactions.sql`](data/07_transactions.sql))

| transaction_id | user_id | transaction_date | amount |
| -------------- | ------- | ---------------- | ------ |
| 1              | 1       | 2024-01-08       | 10     |
| 2              | 1       | 2024-01-20       | 12     |
| 3              | 2       | 2024-01-10       | 20     |
| 4              | 3       | 2024-01-15       | 15     |
| 5              | 1       | 2024-02-03       | 8      |
| 6              | 1       | 2024-03-01       | 9      |
| 7              | 2       | 2024-03-02       | 11     |
| 8              | 4       | 2024-02-01       | 30     |
| 9              | 5       | 2024-02-14       | 25     |
| 10             | 4       | 2024-03-05       | 18     |
| 11             | 5       | 2024-04-02       | 22     |
| 12             | 6       | 2024-02-20       | 7      |

**Query** ([`sql/07_retention_cohorts.sql`](sql/07_retention_cohorts.sql)):

```sql
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
```

**Output dataset:**

| cohort_month | month_number | active_users | retention_rate |
| ------------ | ------------ | ------------ | -------------- |
| 2024-01      | 0            | 3            | 100.00         |
| 2024-01      | 1            | 1            | 33.33          |
| 2024-01      | 2            | 2            | 66.67          |
| 2024-02      | 0            | 3            | 100.00         |
| 2024-02      | 1            | 1            | 33.33          |
| 2024-02      | 2            | 1            | 33.33          |

### 8. Top-N per group

Sum revenue by region and product, then keep dense rank 3 or better. Tied products share a rank and do not use up the next one. In North, Monitor and Tablet both total 800 and both sit at rank 1, Laptop is rank 2 at 750, and Mouse is rank 3 at 200, so that region returns four products. Keyboard is rank 4 and drops. South drops Headphones the same way. East has only Desk.

**Source dataset:** `sales` ([`data/08_sales.sql`](data/08_sales.sql))

| sale_id | region | product_name | revenue | sale_date  |
| ------- | ------ | ------------ | ------- | ---------- |
| 1       | North  | Laptop       | 500     | 2024-01-01 |
| 2       | North  | Laptop       | 250     | 2024-01-02 |
| 3       | North  | Monitor      | 800     | 2024-01-03 |
| 4       | North  | Tablet       | 800     | 2024-01-04 |
| 5       | North  | Mouse        | 200     | 2024-01-05 |
| 6       | North  | Keyboard     | 150     | 2024-01-06 |
| 7       | South  | Phone        | 900     | 2024-02-01 |
| 8       | South  | Phone        | 100     | 2024-02-02 |
| 9       | South  | Case         | 400     | 2024-02-03 |
| 10      | South  | Charger      | 400     | 2024-02-04 |
| 11      | South  | Cable        | 50      | 2024-02-05 |
| 12      | South  | Headphones   | 40      | 2024-02-06 |
| 13      | East   | Desk         | 300     | 2024-03-01 |

**Query** ([`sql/08_top_n_per_group.sql`](sql/08_top_n_per_group.sql)):

```sql
WITH product_revenue AS (
    SELECT region,
           product_name,
           SUM(revenue) AS total_revenue
    FROM sales
    GROUP BY region, product_name
)
SELECT region,
       product_name,
       total_revenue,
       DENSE_RANK() OVER (
           PARTITION BY region
           ORDER BY total_revenue DESC
       ) AS region_rank
FROM product_revenue
QUALIFY region_rank <= 3
ORDER BY region, region_rank, product_name;
```

**Output dataset:**

| region | product_name | total_revenue | region_rank |
| ------ | ------------ | ------------- | ----------- |
| East   | Desk         | 300           | 1           |
| North  | Monitor      | 800           | 1           |
| North  | Tablet       | 800           | 1           |
| North  | Laptop       | 750           | 2           |
| North  | Mouse        | 200           | 3           |
| South  | Phone        | 1000          | 1           |
| South  | Case         | 400           | 2           |
| South  | Charger      | 400           | 2           |
| South  | Cable        | 50            | 3           |

### 9. Pivot (conditional aggregation)

Each region becomes a column. `SUM(IFF(...))` adds `amount` only for that region, and `COALESCE(..., 0)` turns a product that never sold there into 0. Apple's two North sales add to 149.99. Pear appears only in North and West.

**Source dataset:** `sales` ([`data/09_sales.sql`](data/09_sales.sql))

| sale_id | product | region | amount |
| ------- | ------- | ------ | ------ |
| 1       | Apple   | North  | 100.50 |
| 2       | Apple   | North  | 49.49  |
| 3       | Apple   | South  | 200.10 |
| 4       | Apple   | East   | 75.25  |
| 5       | Banana  | North  | 25.10  |
| 6       | Banana  | West   | 74.40  |
| 7       | Banana  | West   | 1.00   |
| 8       | Orange  | South  | 99.99  |
| 9       | Orange  | East   | 250.01 |
| 10      | Pear    | West   | 15.20  |
| 11      | Pear    | North  | 0.10   |

**Query** ([`sql/09_pivot.sql`](sql/09_pivot.sql)):

```sql
SELECT product,
       ROUND(COALESCE(SUM(IFF(region = 'North', amount, NULL)), 0), 2) AS north,
       ROUND(COALESCE(SUM(IFF(region = 'South', amount, NULL)), 0), 2) AS south,
       ROUND(COALESCE(SUM(IFF(region = 'East', amount, NULL)), 0), 2) AS east,
       ROUND(COALESCE(SUM(IFF(region = 'West', amount, NULL)), 0), 2) AS west
FROM sales
GROUP BY product
ORDER BY product;
```

**Output dataset:**

| product | north  | south  | east   | west  |
| ------- | ------ | ------ | ------ | ----- |
| Apple   | 149.99 | 200.10 | 75.25  | 0.00  |
| Banana  | 25.10  | 0.00   | 0.00   | 75.40 |
| Orange  | 0.00   | 99.99  | 250.01 | 0.00  |
| Pear    | 0.10   | 0.00   | 0.00   | 15.20 |

### 10. Self join (employee to manager)

Join each employee to their direct manager and keep the row only when the employee's salary is strictly greater. The CEO has no manager, so the inner join drops that row. Carol matches the CEO and Grace matches Dan, so equality is excluded. Frank earns more than Bob; that comparison does not involve the CEO.

**Source dataset:** `employees` ([`data/10_employees.sql`](data/10_employees.sql))

| employee_id | name  | manager_id | salary |
| ----------- | ----- | ---------- | ------ |
| 1           | CEO   | NULL       | 100000 |
| 2           | Alice | 1          | 120000 |
| 3           | Bob   | 1          | 90000  |
| 4           | Carol | 1          | 100000 |
| 5           | Dan   | 2          | 130000 |
| 6           | Eve   | 2          | 80000  |
| 7           | Frank | 3          | 95000  |
| 8           | Grace | 5          | 130000 |

**Query** ([`sql/10_self_join.sql`](sql/10_self_join.sql)):

```sql
SELECT e.name AS employee_name,
       m.name AS manager_name
FROM employees e
JOIN employees m ON e.manager_id = m.employee_id
WHERE e.salary > m.salary
ORDER BY e.employee_id;
```

**Output dataset:**

| employee_name | manager_name |
| ------------- | ------------ |
| Alice         | CEO          |
| Dan           | Alice        |
| Frank         | Bob          |

### 11. Recursive hierarchy (WITH RECURSIVE)

Start at every employee whose `manager_id` is NULL (CEO and Advisor) and walk down `manager_id`, stopping at depth 100 so a cycle cannot run forever. The result is everyone except those roots. Advisor is a root, so Advisor is omitted and Ian is included. Orphan points at manager 999, which matches no row, so Orphan is never reached.

**Source dataset:** `employees` ([`data/11_employees.sql`](data/11_employees.sql))

| employee_id | name    | manager_id | salary |
| ----------- | ------- | ---------- | ------ |
| 1           | CEO     | NULL       | 200000 |
| 2           | Alice   | 1          | 120000 |
| 3           | Bob     | 1          | 90000  |
| 4           | Dan     | 2          | 130000 |
| 5           | Eve     | 2          | 80000  |
| 6           | Grace   | 4          | 90000  |
| 7           | Frank   | 3          | 95000  |
| 8           | Advisor | NULL       | 150000 |
| 9           | Ian     | 8          | 70000  |
| 10          | Orphan  | 999        | 60000  |

**Query** ([`sql/11_recursive_hierarchy.sql`](sql/11_recursive_hierarchy.sql)):

```sql
WITH RECURSIVE reports (employee_id, level) AS (
    -- anchor: top managers (no manager of their own) at level 0
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

**Output dataset:**

| employee_id |
| ----------- |
| 2           |
| 3           |
| 4           |
| 5           |
| 6           |
| 7           |
| 9           |

### 12. 7-day moving average

Sum each calendar day before averaging, so the two Jan 1 visits become 15 and the two Jan 9 visits become 90. The window is the current daily total plus the six preceding rows, and days before the 7th observed day are omitted. Jan 7 has no row. The frame is `ROWS`, not a calendar span, so the gap is not a zero and Jan 8 is still the 7th observed day: (15+20+30+40+50+60+70)/7 = 40.71. Jan 9 drops Jan 1 and adds 90, which is 51.43.

**Source dataset:** `customer_visits` ([`data/12_customer_visits.sql`](data/12_customer_visits.sql))

| visit_id | customer_id | visit_date | amount |
| -------- | ----------- | ---------- | ------ |
| 1        | 1           | 2024-01-01 | 10     |
| 2        | 2           | 2024-01-01 | 5      |
| 3        | 3           | 2024-01-02 | 20     |
| 4        | 4           | 2024-01-03 | 30     |
| 5        | 5           | 2024-01-04 | 40     |
| 6        | 6           | 2024-01-05 | 50     |
| 7        | 7           | 2024-01-06 | 60     |
| 8        | 8           | 2024-01-08 | 70     |
| 9        | 9           | 2024-01-09 | 80     |
| 10       | 10          | 2024-01-09 | 10     |

**Query** ([`sql/12_moving_average.sql`](sql/12_moving_average.sql)):

```sql
WITH daily AS (
    SELECT visit_date, SUM(amount) AS daily_total
    FROM customer_visits
    GROUP BY visit_date
)
SELECT visit_date,
       daily_total,
       ROUND(AVG(daily_total) OVER (
           ORDER BY visit_date
           ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
       ), 2) AS avg_amount
FROM daily
QUALIFY ROW_NUMBER() OVER (ORDER BY visit_date) >= 7
ORDER BY visit_date;
```

**Output dataset:**

| visit_date | daily_total | avg_amount |
| ---------- | ----------- | ---------- |
| 2024-01-08 | 70          | 40.71      |
| 2024-01-09 | 90          | 51.43      |

## Postgres -> Snowflake changes

| Location | Change | Why |
| --- | --- | --- |
| Pattern 2 | `ctid` replaced with `score_id` | Snowflake has no `ctid`. The sample table includes `score_id` so two rows on the same gender and day have a real order. |
| Pattern 3 | `EXTRACT(YEAR FROM signup_date)::INT` replaced with `YEAR(signup_date)` | `YEAR` returns the calendar year. A `::` cast is valid Snowflake; this one was unnecessary. |
| Pattern 4 | `login_date - <integer>` replaced with `DATEADD('day', -day_number, login_date)` | Snowflake's date minus operator subtracts one date from another and returns a number of days. It does not subtract an integer from a date. `DATEADD` with a negative count does. |
| Pattern 5 | `timestamp - timestamp > INTERVAL '30 minutes'` replaced with `DATEDIFF('minute', prev_ts, event_timestamp) > 30` | Snowflake does not subtract two timestamps. `DATEDIFF` counts boundaries of the given unit. On these whole-minute timestamps, more than 30 minute boundaries is the same cutoff as a 30-minute gap. |
| Pattern 6 | `COUNT(...) FILTER (WHERE ...)` replaced with `COUNT_IF(...)`; `MAX(...) FILTER (WHERE ...) OVER ()` replaced with `MAX(IFF(...)) OVER ()` | Snowflake has no aggregate or window `FILTER` clause. |
| Pattern 7 | Month offset rewritten as `DATEDIFF('month', cohort_month, activity_month)`, and that expression is repeated in `GROUP BY` | Same month offset as the old year/month `EXTRACT` arithmetic. The offset is grouped explicitly so the query does not depend on selecting a calculation of grouped columns. `DATE_TRUNC(...)::DATE` stays. |
| Pattern 8 | `WHERE region_rank <= 3` replaced with `QUALIFY` | `QUALIFY` filters on the window result in the same `SELECT`. |
| Pattern 9 | `SUM(amount) FILTER (WHERE region = ...)` replaced with `SUM(IFF(region = ..., amount, NULL))` | Same `FILTER` gap as pattern 6. `COALESCE(..., 0)` still turns a missing region into 0. |
| Pattern 11 | Recursive CTE declares `(employee_id, level)` | Snowflake requires the column list on a recursive CTE. `WITH RECURSIVE` is valid, and Snowflake recommends the keyword when a CTE recurses. |
| Pattern 12 | `WHERE rn >= 7` replaced with `QUALIFY ROW_NUMBER() ... >= 7` | Same cutoff of the first six observed days, without an extra column. |

Patterns 1 and 10 did not need dialect changes. Also left as written, because Snowflake accepts them: `TO_CHAR` formats `YYYY`, `MM`, `DD`, `HH24`, `MI`, and `SS`; the `::DATE` cast; `ROWS BETWEEN` frames; `LAG`, `NULLIF`, `DENSE_RANK`, `ROW_NUMBER`, and `DATE_TRUNC`.

## Tests

[`sql/test_duckdb.py`](sql/test_duckdb.py) loads each script in `data/`, runs the query, and checks the source tables and the output tables in this file. It also checks that each SQL fence matches the file in `sql/`.

The committed SQL is Snowflake. DuckDB is only the local stand-in, and the test rewrites four constructs before execution:

| Snowflake | DuckDB rewrite |
| --- | --- |
| `TIMESTAMP_NTZ` | `TIMESTAMP` |
| `IFF(...)` | `IF(...)` |
| `DATEADD('day', n, d)` | `(d + (n)::INT)` |
| `TO_CHAR(value, format)` | `STRFTIME`, with `YYYY` → `%Y`, `MM` → `%m`, `DD` → `%d`, `HH24` → `%H`, `MI` → `%M`, `SS` → `%S` |

`DATEDIFF`, `COUNT_IF`, `QUALIFY`, `::` casts, `YEAR`, `DATE_TRUNC`, and `WITH RECURSIVE` are executed as written.

```bash
pip install duckdb
python sql/test_duckdb.py
```

The tables above were produced by that DuckDB run. This repository was not executed against a live Snowflake warehouse.
