WITH RECURSIVE reports AS (
    -- anchor: the top manager (no manager of their own) at level 0
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
