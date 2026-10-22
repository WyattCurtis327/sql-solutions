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
