-- Several product/region pairs are missing and should pivot to 0.
-- Apple has two North rows that must be summed.
CREATE OR REPLACE TABLE sales (
    sale_id INTEGER,
    product VARCHAR,
    region VARCHAR,
    amount DECIMAL(10, 2)
);

INSERT INTO sales (sale_id, product, region, amount) VALUES
    (1,  'Apple',  'North', 100.50),
    (2,  'Apple',  'North',  49.49),
    (3,  'Apple',  'South', 200.10),
    (4,  'Apple',  'East',   75.25),
    (5,  'Banana', 'North',  25.10),
    (6,  'Banana', 'West',   74.40),
    (7,  'Banana', 'West',    1.00),
    (8,  'Orange', 'South',  99.99),
    (9,  'Orange', 'East',  250.01),
    (10, 'Pear',   'West',   15.20),
    (11, 'Pear',   'North',   0.10);
