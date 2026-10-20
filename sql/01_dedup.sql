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
