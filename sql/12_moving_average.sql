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
