SELECT product,
       ROUND(COALESCE(SUM(IFF(region = 'North', amount, NULL)), 0), 2) AS north,
       ROUND(COALESCE(SUM(IFF(region = 'South', amount, NULL)), 0), 2) AS south,
       ROUND(COALESCE(SUM(IFF(region = 'East', amount, NULL)), 0), 2) AS east,
       ROUND(COALESCE(SUM(IFF(region = 'West', amount, NULL)), 0), 2) AS west
FROM sales
GROUP BY product
ORDER BY product;
