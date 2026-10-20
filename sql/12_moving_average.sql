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
