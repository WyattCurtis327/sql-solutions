SELECT gender,
       day,
       SUM(score_points) OVER (
           PARTITION BY gender
           ORDER BY day, score_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS total
FROM scores
ORDER BY gender, day, score_id;
