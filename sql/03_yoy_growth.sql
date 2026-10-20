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
