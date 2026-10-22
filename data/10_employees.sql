-- Direct-manager comparison only. Carol matches the CEO and Grace matches
-- Dan, so equality is excluded. Frank beats Bob without beating the CEO.
CREATE OR REPLACE TABLE employees (
    employee_id INTEGER,
    name VARCHAR,
    manager_id INTEGER,
    salary INTEGER
);

INSERT INTO employees (employee_id, name, manager_id, salary) VALUES
    (1, 'CEO',     NULL, 100000),
    (2, 'Alice',   1,    120000),
    (3, 'Bob',     1,     90000),
    (4, 'Carol',   1,    100000),
    (5, 'Dan',     2,    130000),
    (6, 'Eve',     2,     80000),
    (7, 'Frank',   3,     95000),
    (8, 'Grace',   5,    130000);
