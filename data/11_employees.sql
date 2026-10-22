-- Two roots (CEO, Advisor) and one orphan whose manager_id matches nobody.
-- Roots stay at level 0. The orphan is never reached.
CREATE OR REPLACE TABLE employees (
    employee_id INTEGER,
    name VARCHAR,
    manager_id INTEGER,
    salary INTEGER
);

INSERT INTO employees (employee_id, name, manager_id, salary) VALUES
    (1,  'CEO',     NULL, 200000),
    (2,  'Alice',   1,    120000),
    (3,  'Bob',     1,     90000),
    (4,  'Dan',     2,    130000),
    (5,  'Eve',     2,     80000),
    (6,  'Grace',   4,     90000),
    (7,  'Frank',   3,     95000),
    (8,  'Advisor', NULL, 150000),
    (9,  'Ian',     8,     70000),
    (10, 'Orphan',  999,   60000);
