SELECT gender,
       day,
       SUM(score_points) OVER (
           PARTITION BY gender
           ORDER BY day, ctid
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS total
FROM scores
ORDER BY gender, day, ctid;
