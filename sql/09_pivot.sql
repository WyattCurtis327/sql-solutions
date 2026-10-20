SELECT product,
       ROUND(COALESCE(SUM(amount) FILTER (WHERE region = 'North'), 0), 2) AS north,
       ROUND(COALESCE(SUM(amount) FILTER (WHERE region = 'South'), 0), 2) AS south,
       ROUND(COALESCE(SUM(amount) FILTER (WHERE region = 'East'),  0), 2) AS east,
       ROUND(COALESCE(SUM(amount) FILTER (WHERE region = 'West'),  0), 2) AS west
FROM sales
GROUP BY product
ORDER BY product;
