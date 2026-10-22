-- User 1 has a duplicate login on the same day and a 3-day streak, then a
-- 2-day streak after a gap. User 2 is a single day. User 3 has two separate
-- streaks of 3. User 4 has a 2-day streak only.
CREATE OR REPLACE TABLE logins (
    login_id INTEGER,
    user_id INTEGER,
    login_date DATE
);

INSERT INTO logins (login_id, user_id, login_date) VALUES
    (1,  1, DATE '2024-01-01'),
    (2,  1, DATE '2024-01-02'),
    (3,  1, DATE '2024-01-02'),
    (4,  1, DATE '2024-01-03'),
    (5,  1, DATE '2024-01-05'),
    (6,  1, DATE '2024-01-06'),
    (7,  2, DATE '2024-01-01'),
    (8,  3, DATE '2024-02-01'),
    (9,  3, DATE '2024-02-02'),
    (10, 3, DATE '2024-02-03'),
    (11, 3, DATE '2024-02-10'),
    (12, 3, DATE '2024-02-11'),
    (13, 3, DATE '2024-02-12'),
    (14, 4, DATE '2024-03-01'),
    (15, 4, DATE '2024-03-02');
