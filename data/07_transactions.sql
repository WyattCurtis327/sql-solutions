-- January and February cohorts. User 1 transacts twice in January.
-- User 2 skips February. User 5 skips March. User 3 and user 6 are month-0 only.
CREATE OR REPLACE TABLE transactions (
    transaction_id INTEGER,
    user_id INTEGER,
    transaction_date DATE,
    amount INTEGER
);

INSERT INTO transactions (transaction_id, user_id, transaction_date, amount) VALUES
    (1,  1, DATE '2024-01-08', 10),
    (2,  1, DATE '2024-01-20', 12),
    (3,  2, DATE '2024-01-10', 20),
    (4,  3, DATE '2024-01-15', 15),
    (5,  1, DATE '2024-02-03', 8),
    (6,  1, DATE '2024-03-01', 9),
    (7,  2, DATE '2024-03-02', 11),
    (8,  4, DATE '2024-02-01', 30),
    (9,  5, DATE '2024-02-14', 25),
    (10, 4, DATE '2024-03-05', 18),
    (11, 5, DATE '2024-04-02', 22),
    (12, 6, DATE '2024-02-20', 7);
