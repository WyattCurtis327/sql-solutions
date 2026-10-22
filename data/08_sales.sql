-- Revenue is summed per product. North ties Monitor and Tablet at the top
-- rank and drops Keyboard (dense rank 4). South drops Headphones. East has
-- a single product.
CREATE OR REPLACE TABLE sales (
    sale_id INTEGER,
    region VARCHAR,
    product_name VARCHAR,
    revenue INTEGER,
    sale_date DATE
);

INSERT INTO sales (sale_id, region, product_name, revenue, sale_date) VALUES
    (1,  'North', 'Laptop',     500, DATE '2024-01-01'),
    (2,  'North', 'Laptop',     250, DATE '2024-01-02'),
    (3,  'North', 'Monitor',    800, DATE '2024-01-03'),
    (4,  'North', 'Tablet',     800, DATE '2024-01-04'),
    (5,  'North', 'Mouse',      200, DATE '2024-01-05'),
    (6,  'North', 'Keyboard',   150, DATE '2024-01-06'),
    (7,  'South', 'Phone',      900, DATE '2024-02-01'),
    (8,  'South', 'Phone',      100, DATE '2024-02-02'),
    (9,  'South', 'Case',       400, DATE '2024-02-03'),
    (10, 'South', 'Charger',    400, DATE '2024-02-04'),
    (11, 'South', 'Cable',       50, DATE '2024-02-05'),
    (12, 'South', 'Headphones',  40, DATE '2024-02-06'),
    (13, 'East',  'Desk',       300, DATE '2024-03-01');
