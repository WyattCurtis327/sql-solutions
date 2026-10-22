-- Two visits on Jan 1 and on Jan 9 are summed into daily totals.
-- Jan 7 has no row. The 7-row frame still treats Jan 8 as the 7th observed day.
CREATE OR REPLACE TABLE customer_visits (
    visit_id INTEGER,
    customer_id INTEGER,
    visit_date DATE,
    amount INTEGER
);

INSERT INTO customer_visits (visit_id, customer_id, visit_date, amount) VALUES
    (1,  1,  DATE '2024-01-01', 10),
    (2,  2,  DATE '2024-01-01',  5),
    (3,  3,  DATE '2024-01-02', 20),
    (4,  4,  DATE '2024-01-03', 30),
    (5,  5,  DATE '2024-01-04', 40),
    (6,  6,  DATE '2024-01-05', 50),
    (7,  7,  DATE '2024-01-06', 60),
    (8,  8,  DATE '2024-01-08', 70),
    (9,  9,  DATE '2024-01-09', 80),
    (10, 10, DATE '2024-01-09', 10);
