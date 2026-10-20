SELECT e.name AS employee_name,
       m.name AS manager_name
FROM employees e
JOIN employees m ON e.manager_id = m.employee_id
WHERE e.salary > m.salary
ORDER BY e.employee_id;
