-- Signups in 2020, 2021, 2023, and 2024. 2022 is absent, so LAG compares
-- 2023 to 2021 rather than to a zero year.
CREATE OR REPLACE TABLE hosts (
    host_id INTEGER,
    host_name VARCHAR,
    country VARCHAR,
    signup_date DATE
);

INSERT INTO hosts (host_id, host_name, country, signup_date) VALUES
    (1,  'Ana', 'US', DATE '2020-01-15'),
    (2,  'Ben', 'US', DATE '2020-06-01'),
    (3,  'Cia', 'CA', DATE '2020-11-20'),
    (4,  'Dan', 'US', DATE '2021-02-01'),
    (5,  'Eve', 'UK', DATE '2021-08-08'),
    (6,  'Fay', 'US', DATE '2023-01-05'),
    (7,  'Gus', 'US', DATE '2023-03-03'),
    (8,  'Hal', 'CA', DATE '2023-07-07'),
    (9,  'Ivy', 'UK', DATE '2023-12-01'),
    (10, 'Joe', 'US', DATE '2024-01-01');
