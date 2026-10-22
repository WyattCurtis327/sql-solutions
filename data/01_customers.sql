-- Duplicate emails, a same-day tie broken by customer_id, and NULL emails
-- (NULL emails share one window partition but are never flagged as duplicates).
CREATE OR REPLACE TABLE customers (
    customer_id INTEGER,
    email VARCHAR,
    name VARCHAR,
    phone VARCHAR,
    updated_at DATE
);

INSERT INTO customers (customer_id, email, name, phone, updated_at) VALUES
    (1, 'alice@example.com', 'Alice A',     '555-1001', DATE '2024-01-10'),
    (2, 'alice@example.com', 'Alice Smith',  '555-1002', DATE '2024-02-01'),
    (3, 'bob@example.com',   'Bob Brown',    '555-2002', DATE '2024-01-05'),
    (4, 'bob@example.com',   'Bob B',        '555-2002', DATE '2024-01-25'),
    (5, 'bob@example.com',   'Bob Beta',     '555-2099', DATE '2024-01-25'),
    (6, 'carol@example.com', 'Carol C',      '555-3003', DATE '2024-03-01'),
    (7, NULL,                'Unknown One',  '555-0001', DATE '2024-01-17'),
    (8, NULL,                'Unknown Two',  '555-0002', DATE '2024-01-18');
